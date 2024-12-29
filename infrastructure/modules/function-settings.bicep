// modules/function-settings.bicep
param functionAppName string
param keyVaultName string

resource functionApp 'Microsoft.Web/sites@2021-03-01' existing = {
  name: functionAppName
}

resource functionAppSettings 'Microsoft.Web/sites/config@2021-03-01' = {
  parent: functionApp
  name: 'appsettings'
properties: {
    AzureWebJobsStorage: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/AzureWebJobsStorage/)'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
    CosmosDBConnection: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/CosmosDBConnection/)'
    BlobTriggerConnection: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/AzureWebJobsStorage/)'
}
}