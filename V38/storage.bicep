// Exempel: ett enda storage account, skrivet i Bicep.
// Bicep is a shorter, cleaner language that compiles down to the same ARM JSON.
// Deploy it with:
//   az deployment group create -g rg-novatrix --template-file storage.bicep
// See the JSON it produces:
//   az bicep build --file storage.bicep

@description('Prefix used in the storage account name.')
param namePrefix string = 'novatrix'

@description('Region, defaults to the resource group location.')
param location string = resourceGroup().location

// A storage account name must be globally unique, so we build one from the prefix
// plus a short hash of the resource group.
var storageName = 'st${namePrefix}${uniqueString(resourceGroup().id)}'

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

output storageAccountName string = storageName
