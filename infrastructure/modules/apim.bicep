// modules/apim.bicep
param location string
param environmentName string
param functionAppName string

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: 'apim3-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: 'admin@paperpulse.com'
    publisherName: 'PaperPulse'    
  }
}

// resource functionApp 'Microsoft.Web/sites@2021-03-01' existing = {
  // name: functionAppName
// }

resource paperpulseApi 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  parent: apim
  name: 'paperpulse-api'
  properties: {
    displayName: 'PaperPulse API'
    apiRevision: '1'
    subscriptionRequired: true
    protocols: [
      'https'
    ]
    path: 'api'
  }
}

resource uploadOperation 'Microsoft.ApiManagement/service/apis/operations@2021-08-01' = {
  parent: paperpulseApi
  name: 'upload-document'
  properties: {
    displayName: 'Upload Document'
    method: 'POST'
    urlTemplate: '/documents'
    description: 'Upload a new document for processing'
    request: {
      headers: [
        {
          name: 'Content-Type'
          required: true
          type: 'string'
          values: ['multipart/form-data']
        }
      ]
    }
  }
}

resource listOperation 'Microsoft.ApiManagement/service/apis/operations@2021-08-01' = {
  parent: paperpulseApi
  name: 'list-documents'
  properties: {
    displayName: 'List Documents'
    method: 'GET'
    urlTemplate: '/documents'
    description: 'List all documents'
  }
}

resource getMetadataOperation 'Microsoft.ApiManagement/service/apis/operations@2021-08-01' = {
  parent: paperpulseApi
  name: 'get-document-metadata'
  properties: {
    displayName: 'Get Document Metadata'
    method: 'GET'
    urlTemplate: '/documents/{id}'
    description: 'Get metadata for a specific document'
    templateParameters: [
      {
        name: 'id'
        type: 'string'
        required: true
        description: 'Document ID'
      }
    ]
  }
}

resource deleteOperation 'Microsoft.ApiManagement/service/apis/operations@2021-08-01' = {
  parent: paperpulseApi
  name: 'delete-document'
  properties: {
    displayName: 'Delete Document'
    method: 'DELETE'
    urlTemplate: '/documents/{id}'
    description: 'Delete a specific document'
    templateParameters: [
      {
        name: 'id'
        type: 'string'
        required: true
        description: 'Document ID'
      }
    ]
  }
}

output apimName string = apim.name