param location string
param environmentName string

resource staticWebApp 'Microsoft.Web/staticSites@2021-03-01' = {
  name: 'stapp-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    allowConfigFileUpdates: true
    provider: 'Custom'
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

output staticWebAppName string = staticWebApp.name
output staticWebAppDefaultHostname string = staticWebApp.properties.defaultHostname
output staticWebAppId string = staticWebApp.id