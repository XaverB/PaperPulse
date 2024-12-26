// modules/storage.bicep
param location string
param environmentName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: 'st${environmentName}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
  name: 'cosmos-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: true
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
}

output storageAccountName string = storageAccount.name
output cosmosDbAccountName string = cosmosAccount.name