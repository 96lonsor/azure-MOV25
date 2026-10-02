using 'main.bicep'

// Teamet "Novatrix support" och kanalen "Ärenden" från V39.
param teamsGroupId = '36dda78d-d47a-43e7-a474-13261a245e50'
param teamsChannelId = '19:9N5ZvIvBHX_R5_U6SFUwmDOxmnIB_mlzaMm4RBKfNiE1@thread.tacv2'

// Läses från miljövariabler så att personliga uppgifter inte hamnar i repot.
param notisMejl = readEnvironmentVariable('NOTIS_MEJL')
param utvecklareObjectId = readEnvironmentVariable('UTVECKLARE_OBJECT_ID', '')
param skapaPrenumeration = bool(readEnvironmentVariable('SKAPA_PRENUMERATION', 'false'))
