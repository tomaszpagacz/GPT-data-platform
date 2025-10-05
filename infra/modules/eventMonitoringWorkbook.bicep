param workbookDisplayName string = 'Storage Events Monitor'
param location string = resourceGroup().location
param tags object = {}

var workbookContent = loadTextContent('storageEventsWorkbook.json')

resource workbook 'Microsoft.Insights/workbooks@2021-08-01' = {
  name: guid('storage-events-workbook')
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: workbookContent
    version: '1.0'
    sourceId: 'Azure Monitor'
    category: 'workbook'
  }
}