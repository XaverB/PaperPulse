// modules/functions.bicep
param location string
param environmentName string

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
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      http20Enabled: true
      minTlsVersion: '1.2'
      netFrameworkVersion: 'v8.0'  // Add this line for .NET 8
      cors: {
        allowedOrigins: [
          '*'  // Consider restricting this in production
        ]
      }
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        // Add these settings for .NET 8 isolated
        {
          name: 'DOTNET_VERSION'
          value: '8.0'
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