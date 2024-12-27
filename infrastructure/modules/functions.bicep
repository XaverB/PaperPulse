// modules/functions.bicep
param location string
param environmentName string
param storageAccountName string
param cosmosDbAccountName string
param keyVaultName string

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: 'plan-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: 'func-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      http20Enabled: true
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: [
          '*'  // Consider restricting this in production
        ]
      }
      appSettings: [
       {
          name: 'AzureWebJobsStorage'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/AzureWebJobsStorage/)'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
         {
          name: 'CosmosDBConnection'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/CosmosDBConnection/)'
        }
      ]
    }
  }
}

output functionAppName string = functionApp.name