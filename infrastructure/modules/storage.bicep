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

// File Services resource
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2021-08-01' = {
  parent: storageAccount
  name: 'default'
}

// Add file share for function app
resource functionStorageShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-08-01' = {
  parent: fileServices
  name: '${environmentName}-content'
  properties: {
    shareQuota: 5120
    enabledProtocols: 'SMB'
  }
}

// Blob Services resource
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-08-01' = {
  parent: storageAccount
  name: 'default'
}

// Add blob container for documents
resource documentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  parent: blobServices
  name: 'documents'
  properties: {
    publicAccess: 'None'
  }
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
  name: 'cosmos-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
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

// Add Cosmos DB database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-10-15' = {
  parent: cosmosAccount
  name: 'PaperPulse'
  properties: {
    resource: {
      id: 'PaperPulse'
    }
  }
}

// Add Cosmos DB container
resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
  parent: cosmosDatabase
  name: 'Metadata'
  properties: {
    resource: {
      id: 'Metadata'
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
      }
    }
  }
}

output storageAccountName string = storageAccount.name
output cosmosDbAccountName string = cosmosAccount.name