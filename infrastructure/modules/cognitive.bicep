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
    restore: false            
    enableSoftDelete: false   
  }
}

output formRecognizerName string = formRecognizer.name