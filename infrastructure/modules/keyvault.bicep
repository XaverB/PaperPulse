// Key Vault with improved configuration
param location string
param environmentName string
param functionAppPrincipalId string
param storageAccountName string
param cosmosDbAccountName string

// Get references to existing resources
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: cosmosDbAccountName
}

resource formRecognizer 'Microsoft.CognitiveServices/accounts@2021-10-01' existing = {
  name: 'fr-${environmentName}-${uniqueString(resourceGroup().id)}'
}

// Key Vault with network rules and access policies
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: functionAppPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// Storage Account Connection
resource storageConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'AzureWebJobsStorage'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
}

// Cosmos DB Connection
resource cosmosConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'CosmosDBConnection'
  properties: {
    value: cosmosDb.listConnectionStrings().connectionStrings[0].connectionString
  }
}

// Form Recognizer Connection
resource formRecognizerConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'FormRecognizerConnection'
  properties: {
    value: formRecognizer.listKeys().key1
  }
}

output keyVaultName string = keyVault.name