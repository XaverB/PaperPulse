param location string
param environmentName string

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: 'kv-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: tenant().tenantId
    accessPolicies: []
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}