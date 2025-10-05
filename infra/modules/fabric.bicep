@description('Name of the Microsoft Fabric capacity.')
param name string

@description('Azure region for deployment.')
param location string

@description('Tags applied to all resources.')
param tags object = {}

@description('SKU for Microsoft Fabric capacity.')
@allowed([
  'F2'
  'F4'
  'F8'
  'F16'
  'F32'
  'F64'
  'F128'
  'F256'
  'F512'
])
param sku string = 'F2'

@description('Administrator email addresses.')
param administrators array

@description('Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Enable automatic scaling.')
param enableAutoScale bool = true

@description('Maximum capacity units for auto-scaling.')
param maxCapacityUnits int = 4

@description('Minimum capacity units for auto-scaling.')
param minCapacityUnits int = 1

// Microsoft Fabric Capacity
resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: administrators
    }
    state: 'Active'
  }
}

// Auto-scale settings for Fabric capacity
resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (enableAutoScale) {
  name: '${name}-autoscale'
  location: location
  tags: tags
  properties: {
    enabled: enableAutoScale
    targetResourceUri: fabricCapacity.id
    profiles: [
      {
        name: 'Default'
        capacity: {
          minimum: string(minCapacityUnits)
          maximum: string(maxCapacityUnits)
          default: string(minCapacityUnits)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CU'
              metricNamespace: 'Microsoft.Fabric/capacities'
              metricResourceUri: fabricCapacity.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 80
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CU'
              metricNamespace: 'Microsoft.Fabric/capacities'
              metricResourceUri: fabricCapacity.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT15M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT20M'
            }
          }
        ]
      }
      {
        name: 'BusinessHours'
        capacity: {
          minimum: string(minCapacityUnits + 1)
          maximum: string(maxCapacityUnits)
          default: string(minCapacityUnits + 1)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CU'
              metricNamespace: 'Microsoft.Fabric/capacities'
              metricResourceUri: fabricCapacity.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
        recurrence: {
          frequency: 'Week'
          schedule: {
            timeZone: 'UTC'
            days: [
              'Monday'
              'Tuesday'
              'Wednesday'
              'Thursday'
              'Friday'
            ]
            hours: [
              8
            ]
            minutes: [
              0
            ]
          }
        }
      }
    ]
    notifications: [
      {
        operation: 'Scale'
        email: {
          sendToSubscriptionAdministrator: true
          sendToSubscriptionCoAdministrators: true
          customEmails: administrators
        }
      }
    ]
  }
}

// Diagnostic settings for Fabric capacity
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-logs'
  scope: fabricCapacity
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'Engine'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'Service'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'Gateway'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

// Activity log alerts for Fabric operations
resource activityLogAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: '${name}-activity-alert'
  location: 'Global'
  tags: tags
  properties: {
    enabled: true
    scopes: [
      fabricCapacity.id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Fabric/capacities/write'
        }
        {
          field: 'status'
          equals: 'Failed'
        }
      ]
    }
    actions: {
      actionGroups: []
    }
    description: 'Alert for Microsoft Fabric capacity operations'
  }
}

// Metric alerts for capacity utilization
resource capacityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${name}-capacity-alert'
  location: 'Global'
  tags: tags
  properties: {
    description: 'Alert when Fabric capacity utilization is high'
    severity: 2
    enabled: true
    scopes: [
      fabricCapacity.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: 90
          name: 'HighCapacityUtilization'
          metricNamespace: 'Microsoft.Fabric/capacities'
          metricName: 'CU'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: []
  }
}

output fabricCapacityId string = fabricCapacity.id
output fabricCapacityName string = fabricCapacity.name
output fabricCapacityLocation string = fabricCapacity.location
output fabricCapacityState string = fabricCapacity.properties.state