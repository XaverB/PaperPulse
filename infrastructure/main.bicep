// main.bicep
targetScope = 'subscription'

@description('The location for the resources')
param location string = 'eastus'

@description('The environment name (dev, test, prod)')
param environmentName string

@description('The resource group name')
param resourceGroupName string = 'rg-${environmentName}'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// Deploy storage resources
module storage './modules/storage.bicep' = {
  scope: rg
  name: 'storageDeployment'
  params: {
    location: location
    environmentName: environmentName
  }
}

// Deploy cognitive services
module cognitive './modules/cognitive.bicep' = {
  scope: rg
  name: 'cognitiveDeployment'
  params: {
    location: location
    environmentName: environmentName
  }
}

// Deploy function app with Key Vault reference
module functions './modules/functions.bicep' = {
  scope: rg
  name: 'functionsDeployment'
  params: {
    location: location
    environmentName: environmentName
    keyVaultName: keyvault.outputs.keyVaultName
  }
}

// Deploy web app
module webApp './modules/webapp.bicep' = {
  scope: rg
  name: 'webAppDeployment'
  params: {
    location: location
    environmentName: environmentName
  }
}

// Deploy Key Vault with secrets
module keyvault './modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvaultDeployment'
  params: {
    location: location
    environmentName: environmentName
    functionAppName: functions.outputs.functionAppName
    storageAccountName: storage.outputs.storageAccountName
    cosmosDbAccountName: storage.outputs.cosmosDbAccountName
  }
  dependsOn: [
    storage
    functions
  ]
}

// Deploy API Management
module apim './modules/apim.bicep' = {
  scope: rg
  name: 'apimDeployment'
  params: {
    location: location
    environmentName: environmentName
    functionAppName: functions.outputs.functionAppName
  }
}

output resourceGroupName string = rg.name
output functionAppName string = functions.outputs.functionAppName