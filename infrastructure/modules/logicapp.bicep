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