// main.bicep
targetScope = 'subscription'

param location string = 'eastus'
param environmentName string
param resourceGroupName string = 'rg-${environmentName}'

// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module storage './modules/storage.bicep' = {
  name: 'storageDeployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
  }
}

module cognitive './modules/cognitive.bicep' = {
  name: 'cognitiveDeployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
  }
}

module functions './modules/functions.bicep' = {
  name: 'functionsDeployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
    storageAccountName: storage.outputs.storageAccountName
    cosmosDbAccountName: storage.outputs.cosmosDbAccountName
  }
}

module webApp './modules/webapp.bicep' = {
  name: 'webAppDeployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
  }
}

module keyvault './modules/keyvault.bicep' = {
  name: 'keyvaultDeployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
  }
}

// ./modules/storage.bicep
param location string
param environmentName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: 'st${environmentName}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
  name: 'cosmos-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: true
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
}

output storageAccountName string = storageAccount.name
output cosmosDbAccountName string = cosmosAccount.name

// ./modules/cognitive.bicep
param location string
param environmentName string

resource formRecognizer 'Microsoft.CognitiveServices/accounts@2021-10-01' = {
  name: 'fr-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'FormRecognizer'
  properties: {
    customSubDomainName: 'fr-${environmentName}-${uniqueString(resourceGroup().id)}'
    networkAcls: {
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
  }
}

// ./modules/functions.bicep
param location string
param environmentName string
param storageAccountName string
param cosmosDbAccountName string

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
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
      ]
    }
  }
}

// ./modules/webapp.bicep
param location string
param environmentName string

resource staticWebApp 'Microsoft.Web/staticSites@2021-03-01' = {
  name: 'stapp-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

// ./modules/keyvault.bicep
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

// ./modules/logicapp.bicep
param location string
param environmentName string

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        When_a_blob_is_added_or_modified: {
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/datasets/default/triggers/batch/onupdatedfile'
            queries: {
              folderId: 'JTJm'
              maxFileCount: 10
            }
          }
          recurrence: {
            frequency: 'Minute'
            interval: 3
          }
          splitOn: '@triggerBody()'
        }
      }
      actions: {}
    }
  }
}