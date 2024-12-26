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

// Deploy function app
module functions './modules/functions.bicep' = {
  scope: rg
  name: 'functionsDeployment'
  params: {
    location: location
    environmentName: environmentName
    storageAccountName: storage.outputs.storageAccountName
    cosmosDbAccountName: storage.outputs.cosmosDbAccountName
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

// Deploy key vault
module keyvault './modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvaultDeployment'
  params: {
    location: location
    environmentName: environmentName
  }
}

// Deploy logic app
module logicapp './modules/logicapp.bicep' = {
  scope: rg
  name: 'logicAppDeployment'
  params: {
    location: location
    environmentName: environmentName
  }
}

output resourceGroupName string = rg.name