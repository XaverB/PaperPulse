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
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/AzureWebJobsStorage/)'
    WEBSITE_CONTENTSHARE: toLower(functionAppName)
    WEBSITE_SKIP_CONTENTSHARE_VALIDATION: '1'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
    CosmosDBConnection: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/CosmosDBConnection/)'
    BlobTriggerConnection: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/AzureWebJobsStorage/)'
}
}