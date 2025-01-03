param location string
param environmentName string
param functionAppPrincipalId string
param storageAccountName string
param cosmosDbAccountName string
param formRecognizerName string

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: false
    softDeleteRetentionInDays: 7       
  }
}

// Get references to existing resources
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: cosmosDbAccountName
}

// Assign Function App Managed Identity access to Key Vault
resource functionAppKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, functionAppPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Store secrets in Key Vault
resource storageConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'AzureWebJobsStorage'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
  }
}

resource cosmosConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'CosmosDBConnection'
  properties: {
    value: cosmosDb.listConnectionStrings().connectionStrings[0].connectionString
  }
}

resource formRecognizer 'Microsoft.CognitiveServices/accounts@2021-10-01' existing = {
  name: formRecognizerName
}

resource formRecognizerEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'FormRecognizerEndpoint'
  properties: {
    value: formRecognizer.properties.endpoint
  }
}

resource formRecognizerKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault 
  name: 'FormRecognizerKey'
  properties: {
    value: formRecognizer.listKeys().key1
  }
}

output keyVaultName string = keyVault.name