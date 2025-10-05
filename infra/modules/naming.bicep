param namePrefix string
param environment string

var naming = {
  prefix: namePrefix
  eventHubNamespace: '${namePrefix}-evthub-${environment}'
  eventGridTopic: '${namePrefix}-evtgrid-${environment}'
  functionApp: '${namePrefix}-func-${environment}'
  functionPlan: '${namePrefix}-plan-${environment}'
  functionStorage: '${namePrefix}func${environment}'
  keyVault: '${namePrefix}-kv-${environment}'
  logAnalytics: '${namePrefix}-log-${environment}'
  logicApp: '${namePrefix}-logic-${environment}'
  storage: '${namePrefix}stor${environment}'
  synapse: '${namePrefix}-syn-${environment}'
  vnet: '${namePrefix}-vnet-${environment}'
  cognitiveServices: '${namePrefix}-cog-${environment}'
  azureMaps: '${namePrefix}-maps-${environment}'
  // New modern platform services
  purview: '${namePrefix}-purview-${environment}'
  machineLearning: '${namePrefix}-ml-${environment}'
  kubernetes: '${namePrefix}-aks-${environment}'
  fabric: '${namePrefix}-fabric-${environment}'
  containerInstances: '${namePrefix}-aci-${environment}'
  comprehensiveApiGateway: '${namePrefix}-apigw-${environment}'
}

output naming object = naming