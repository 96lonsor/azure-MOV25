// Modul 1, händelsekedjan för Novatrix-ärenden.
//
// Kedjan: ny blob i containern arenden -> Event Grid -> Azure Function ->
// rad i Table Storage + anrop till en Logic App -> mejl (Outlook) och notis (Teams).
//
// Mallen körs i två steg, eftersom Event Grid kontrollerar att funktionen finns
// när prenumerationen skapas. Först körs mallen med skapaPrenumeration=false,
// sedan laddas funktionskoden upp, och sist körs mallen igen med true.

@description('Region för alla resurser.')
param location string = resourceGroup().location

@description('Prefix för resursnamnen.')
param namePrefix string = 'novatrix'

@description('Vart notismejlet ska skickas.')
param notisMejl string

@description('Id för Teams-teamet "Novatrix support" (samma som i V39).')
param teamsGroupId string

@description('Id för kanalen "Ärenden" i teamet.')
param teamsChannelId string

@description('Skapa Event Grid-prenumerationen. Sätts till true först när funktionskoden är uppladdad.')
param skapaPrenumeration bool = false

@description('Object id för den som testar (az ad signed-in-user show --query id). Tomt = ingen extra roll.')
param utvecklareObjectId string = ''

var suffix = uniqueString(resourceGroup().id)
var tags = {
  projekt: 'novatrix'
  uppgift: '6B'
  modul: 'modul-1'
}

// Rollernas inbyggda id:n, så att det syns vilken behörighet som delas ut.
var roller = {
  blobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  blobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  blobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  tableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
}

// ---------------------------------------------------------------------------
// Novatrix-lagringen: ärenden som blobar, plus en tabell för ärenderegistret.
// ---------------------------------------------------------------------------

resource novatrixStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${namePrefix}${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: novatrixStorage
  name: 'default'
}

resource arendenContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'arenden'
}

// Hit hamnar händelser som Event Grid inte lyckas leverera efter alla omförsök.
resource deadletterContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'deadletter'
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: novatrixStorage
  name: 'default'
}

resource arendeTabell 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = {
  parent: tableService
  name: 'arenderegister'
}

// ---------------------------------------------------------------------------
// Övervakning: arbetsytan återanvänds i modul 3.
// ---------------------------------------------------------------------------

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${namePrefix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${namePrefix}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// ---------------------------------------------------------------------------
// Logic App som skickar mejl och Teams-notis. Anslutningarna till Outlook och
// Teams skapas här men måste godkännas en gång i portalen (inloggning).
// ---------------------------------------------------------------------------

resource office365Connection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'office365'
  location: location
  tags: tags
  properties: {
    displayName: 'Novatrix Outlook'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
  }
}

resource teamsConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'teams'
  location: location
  tags: tags
  properties: {
    displayName: 'Novatrix Teams'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'teams')
    }
  }
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-${namePrefix}-notis'
  location: location
  tags: tags
  properties: {
    state: 'Enabled'
    parameters: {
      '$connections': {
        value: {
          office365: {
            connectionId: office365Connection.id
            connectionName: office365Connection.name
            id: office365Connection.properties.api.id
          }
          teams: {
            connectionId: teamsConnection.id
            connectionName: teamsConnection.name
            id: teamsConnection.properties.api.id
          }
        }
      }
    }
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                arendeId: { type: 'string' }
                namn: { type: 'string' }
                epost: { type: 'string' }
                meddelande: { type: 'string' }
                tidpunkt: { type: 'string' }
              }
            }
          }
        }
      }
      actions: {
        Skicka_mejl: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
            body: {
              To: notisMejl
              Subject: 'Nytt ärende @{triggerBody()?[\'arendeId\']}'
              Body: '<p>Namn: @{triggerBody()?[\'namn\']}</p><p>E-post: @{triggerBody()?[\'epost\']}</p><p>Meddelande: @{triggerBody()?[\'meddelande\']}</p><p>Ärende-id: @{triggerBody()?[\'arendeId\']}</p>'
              Importance: 'Normal'
            }
          }
        }
        Posta_i_Teams: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'teams\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/beta/teams/conversation/message/poster/@{encodeURIComponent(\'Flow bot\')}/location/@{encodeURIComponent(\'Channel\')}'
            body: {
              recipient: {
                groupId: teamsGroupId
                channelId: teamsChannelId
              }
              messageBody: '<p>Nytt ärende @{triggerBody()?[\'arendeId\']} från @{triggerBody()?[\'namn\']} (@{triggerBody()?[\'epost\']}): @{triggerBody()?[\'meddelande\']}</p>'
            }
          }
        }
        Svara: {
          runAfter: {
            Skicka_mejl: [ 'Succeeded' ]
            Posta_i_Teams: [ 'Succeeded' ]
          }
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Key Vault med Logic Appens anrops-URL. URL:en innehåller en signatur, så den
// läggs här i stället för i koden eller repot. Funktionen läser den med sin
// hanterade identitet.
// ---------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv${namePrefix}${take(suffix, 9)}'
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 7
  }
}

resource logicAppUrlSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'logicapp-url'
  properties: {
    value: listCallbackUrl('${logicApp.id}/triggers/manual', '2019-05-01').value
  }
}

// ---------------------------------------------------------------------------
// Funktionsappen på Flex Consumption. Den har ett eget lagringskonto för sin
// interna drift, så att den inte behöver mer än läsrätt på Novatrix-kontot.
// ---------------------------------------------------------------------------

resource funcStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stfunc${take(suffix, 10)}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource funcBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: funcStorage
  name: 'default'
}

resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: funcBlobService
  name: 'deployments'
}

resource funcPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'plan-${namePrefix}-func'
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: 'func-${namePrefix}-${take(suffix, 6)}'
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: funcPlan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${funcStorage.properties.primaryEndpoints.blob}${deploymentContainer.name}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 10
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'python'
        version: '3.12'
      }
    }
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: funcStorage.name
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'TABLE_ENDPOINT'
          value: novatrixStorage.properties.primaryEndpoints.table
        }
        {
          name: 'TABLE_NAME'
          value: arendeTabell.name
        }
        {
          // Key Vault-referens: plattformen hämtar hemligheten med appens identitet.
          name: 'LOGICAPP_URL'
          value: '@Microsoft.KeyVault(SecretUri=${logicAppUrlSecret.properties.secretUri})'
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Behörigheter för funktionens identitet (least privilege).
// ---------------------------------------------------------------------------

// Läsa ärendeblobarna, inget mer.
resource rollBlobLas 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: novatrixStorage
  name: guid(novatrixStorage.id, functionApp.id, roller.blobDataReader)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roller.blobDataReader)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Skriva rader i ärenderegistret.
resource rollTabell 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: novatrixStorage
  name: guid(novatrixStorage.id, functionApp.id, roller.tableDataContributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roller.tableDataContributor)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Full blobrätt, men bara på funktionens eget driftkonto (kod och interna lås).
resource rollFuncStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: funcStorage
  name: guid(funcStorage.id, functionApp.id, roller.blobDataOwner)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roller.blobDataOwner)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Läsa hemligheter i valvet.
resource rollKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, functionApp.id, roller.keyVaultSecretsUser)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roller.keyVaultSecretsUser)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Event Grid: lagringskontot som källa och en prenumeration mot funktionen.
// ---------------------------------------------------------------------------

resource systemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: 'evgt-${namePrefix}-storage'
  location: location
  tags: tags
  // Egen identitet så att Event Grid kan skriva dead-letter utan lagringsnyckel.
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    source: novatrixStorage.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource prenumeration 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = if (skapaPrenumeration) {
  parent: systemTopic
  name: 'nytt-arende-till-funktion'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionApp.id}/functions/HanteraArende'
        maxEventsPerBatch: 1
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
      // Bara ärendefilerna i arenden, inte bifogade bilder.
      subjectBeginsWith: '/blobServices/default/containers/arenden/'
      subjectEndsWith: '.json'
    }
    retryPolicy: {
      maxDeliveryAttempts: 10
      eventTimeToLiveInMinutes: 1440
    }
    deadLetterWithResourceIdentity: {
      identity: {
        type: 'SystemAssigned'
      }
      deadLetterDestination: {
        endpointType: 'StorageBlob'
        properties: {
          resourceId: novatrixStorage.id
          blobContainerName: deadletterContainer.name
        }
      }
    }
  }
  dependsOn: [
    rollDeadletter
  ]
}

// Event Grid behöver skrivrätt för dead-letter. Helst hade rollen bara gällt
// deadletter-containern, men Event Grid kontrollerar behörigheten på kontonivå
// när prenumerationen skapas och nekar annars, så rollen ligger på kontot.
resource rollDeadletter 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: novatrixStorage
  name: guid(novatrixStorage.id, systemTopic.id, roller.blobDataContributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roller.blobDataContributor)
    principalId: systemTopic.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Valfritt: ger den som kör mallen rätt att ladda upp testärenden och läsa tabellen.
resource rollUtvecklareBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(utvecklareObjectId)) {
  scope: novatrixStorage
  name: guid(novatrixStorage.id, utvecklareObjectId, roller.blobDataContributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roller.blobDataContributor)
    principalId: utvecklareObjectId
    principalType: 'User'
  }
}

resource rollUtvecklareTabell 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(utvecklareObjectId)) {
  scope: novatrixStorage
  name: guid(novatrixStorage.id, utvecklareObjectId, roller.tableDataContributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roller.tableDataContributor)
    principalId: utvecklareObjectId
    principalType: 'User'
  }
}

output storageAccountName string = novatrixStorage.name
output functionAppName string = functionApp.name
output logicAppName string = logicApp.name
output keyVaultName string = keyVault.name
output logWorkspaceId string = logWorkspace.id
