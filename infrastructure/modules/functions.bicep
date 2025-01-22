param location string
param environmentName string
param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAccountName
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: 'plan-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'

resource formRecognizer 'Microsoft.CognitiveServices/accounts@2021-10-01' existing = {
  name: 'fr-${environmentName}-${uniqueString(resourceGroup().id)}'
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: 'func-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    use32BitWorkerProcess: false
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      scmIpSecurityRestrictions: []
      cors: {
        allowedOrigins: [
          '*'
        ]
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('func-${environmentName}-${uniqueString(resourceGroup().id)}')
        }
        {
          name: 'FormRecognizerEndpoint'
          value: '@Microsoft.KeyVault(SecretUri=https://kv-${environmentName}-${uniqueString(resourceGroup().id)}${environment().suffixes.keyvaultDns}/secrets/FormRecognizerEndpoint/)'
        }
        {
          name: 'FormRecognizerKey'
          value: '@Microsoft.KeyVault(SecretUri=https://kv-${environmentName}-${uniqueString(resourceGroup().id)}${environment().suffixes.keyvaultDns}/secrets/FormRecognizerKey/)'
        }
        {
          name: 'CosmosDBConnection'
          value: '@Microsoft.KeyVault(SecretUri=https://kv-${environmentName}-${uniqueString(resourceGroup().id)}${environment().suffixes.keyvaultDns}/secrets/CosmosDBConnection/)'
        }
        {
          name: 'WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED'
          value: '1'
        }
      ]
    }
  }
}

output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId