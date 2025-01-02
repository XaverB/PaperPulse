param location string
param environmentName string

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: 'plan-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true  // Required for Linux
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: 'func-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'functionapp,linux'  // Explicitly specify Linux
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    reserved: true  // Required for Linux
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      scmIpSecurityRestrictions: []
      basicAuthEnabled: true
      cors: {
        allowedOrigins: [
          '*'
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
        {
          name: 'DOTNET_VERSION'
          value: '8.0'
        }
        {
          name: 'WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED'
          value: '1'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'false'
        }
      ]
    }
  }
}

output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId