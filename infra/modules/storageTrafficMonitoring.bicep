@description('Name of the storage account to monitor')
param storageAccountName string

@description('Name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Email addresses for alert notifications')
param alertEmailAddresses array

@description('Threshold for egress data in GB per hour')
param egressThresholdGB int = 50

@description('Threshold for unusual access patterns (number of unique IPs)')
param unusualAccessThreshold int = 10

@description('Tags for the resources')
param tags object = {}

// Reference existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAccountName
}

// Reference existing Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

// Create Action Group for alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2021-09-01' = {
  name: '${storageAccountName}-traffic-monitor-ag'
  location: 'global'
  properties: {
    groupShortName: 'StgTraffic'
    enabled: true
    emailReceivers: [for email in alertEmailAddresses: {
      name: 'Email ${indexOf(alertEmailAddresses, email)}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
  }
}

// Enable detailed diagnostic settings for storage account
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccountName}-traffic-diag'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
  }
}

// Create metric alerts for egress traffic
resource egressVolumeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${storageAccountName}-egress-volume-alert'
  location: 'global'
  properties: {
    description: 'Alert when egress traffic volume exceeds threshold'
    severity: 2
    enabled: true
    scopes: [
      storageAccount.id
    ]
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'EgressVolume'
          metricNamespace: 'Microsoft.Storage/storageAccounts'
          metricName: 'Egress'
          operator: 'GreaterThan'
          threshold: egressThresholdGB * 1000000000 // Convert GB to bytes
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Create scheduled query for monitoring unusual access patterns
resource unusualAccessAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: '${storageAccountName}-unusual-access-alert'
  location: location
  properties: {
    displayName: 'Storage Unusual Access Pattern Alert'
    description: 'Alert when storage account accessed from unusual number of IP addresses'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    criteria: {
      allOf: [
        {
          query: '''
StorageBlobLogs
| where TimeGenerated > ago(1h)
| summarize dcount(CallerIpAddress) by bin(TimeGenerated, 1h)
| where dcount_CallerIpAddress > ${unusualAccessThreshold}
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

// Create query for monitoring large file downloads
resource largeFileDownloadsAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: '${storageAccountName}-large-downloads-alert'
  location: location
  properties: {
    displayName: 'Storage Large File Downloads Alert'
    description: 'Alert when large files are downloaded from storage'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    criteria: {
      allOf: [
        {
          query: '''
StorageBlobLogs
| where OperationName in ("GetBlob")
| where ResponseBodySize > 100000000 // 100MB
| summarize TotalDownloads=count(), TotalBytes=sum(ResponseBodySize), IPAddresses=make_set(CallerIpAddress) by BlobUrl
| where TotalBytes > 1000000000 // 1GB
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

// Create traffic analysis workbook
resource trafficWorkbook 'Microsoft.Insights/workbooks@2021-08-01' = {
  name: guid('${storageAccountName}-traffic-workbook')
  location: location
  kind: 'shared'
  properties: {
    displayName: '${storageAccountName} Traffic Analysis'
    serializedData: loadTextContent('storageTrafficWorkbook.json')
    sourceId: storageAccount.id
    category: 'storageInsights'
    version: '1.0'
  }
}

output actionGroupId string = actionGroup.id
output workbookId string = trafficWorkbook.name