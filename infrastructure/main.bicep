targetScope = 'subscription'

@description('The location for the resources')
param location string = 'eastus2'

@description('The environment name (dev, test, prod)')
param environmentName string

@description('The resource group name')
param resourceGroupName string = 'rg-${environmentName}'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// Deploy storage resources first
module storage './modules/storage.bicep' = {
  scope: rg
  name: 'storageDeployment'
  params: {
    location: location
    environmentName: environmentName
  }
}


// Deploy cognitive services (can be parallel with storage)
module cognitive './modules/cognitive.bicep' = {
  scope: rg
  name: 'cognitiveDeployment'
  params: {
    location: location
    environmentName: environmentName
  }
}

// Deploy function app after storage
module functions './modules/functions.bicep' = {
  scope: rg
  name: 'functionsDeployment'
  params: {
    location: location
    environmentName: environmentName
    storageAccountName: storage.outputs.storageAccountName
  }
}

// Deploy storage RBAC permissions for function app
module storageRbac './modules/storage-rbac.bicep' = {
  scope: rg
  name: 'storageRbacDeployment'
  params: {
    storageAccountName: storage.outputs.storageAccountName
    functionAppPrincipalId: functions.outputs.functionAppPrincipalId
  }
}

// Deploy Key Vault after function app and storage
module keyvault './modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvaultDeployment'
  params: {
    formRecognizerName: cognitive.outputs.formRecognizerName
    location: location
    environmentName: environmentName
    functionAppPrincipalId: functions.outputs.functionAppPrincipalId
    storageAccountName: storage.outputs.storageAccountName
    cosmosDbAccountName: storage.outputs.cosmosDbAccountName
  }
}

// Update function app settings with Key Vault references
// module functionSettings './modules/function-settings.bicep' = {
//   scope: rg
//   name: 'functionSettingsDeployment'
//   params: {
//     functionAppName: functions.outputs.functionAppName
//     keyVaultName: keyvault.outputs.keyVaultName
//     storageAccountName: storage.outputs.storageAccountName 
//   }
// }

// Deploy web app (can be parallel with function app)
module webApp './modules/webapp.bicep' = {
  scope: rg
  name: 'webAppDeployment'
  params: {
    location: location
    environmentName: environmentName
  }
}

// Deploy API Management after function app
module apim './modules/apim.bicep' = {
  scope: rg
  name: 'apimDeployment'
  params: {
    location: location
    environmentName: environmentName
    functionAppName: functions.outputs.functionAppName
  }
}

// Outputs
output resourceGroupName string = rg.name
output functionAppName string = functions.outputs.functionAppName
output keyVaultName string = keyvault.outputs.keyVaultName
output storageAccountName string = storage.outputs.storageAccountName
output formRecognizerName string = cognitive.outputs.formRecognizerName
output webAppName string = webApp.outputs.staticWebAppName
output apimName string = apim.outputs.apimName // Make sure to add this output in apim.bicep