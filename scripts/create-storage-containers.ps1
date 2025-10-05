#Requires -Version 7.0
<#
.SYNOPSIS
    Creates Azure Storage containers for medallion architecture and additional data platform containers.

.DESCRIPTION
    This script creates the standard medallion architecture containers (bronze, silver, gold)
    plus additional containers commonly used in data platforms. It supports both Azure CLI
    and Azure PowerShell authentication methods.

.PARAMETER StorageAccountName
    Name of the Azure Storage account

.PARAMETER ResourceGroupName
    Name of the resource group containing the storage account

.PARAMETER SubscriptionId
    Azure subscription ID (optional, uses default if not specified)

.PARAMETER Containers
    Array of container names to create (optional, uses default medallion + additional containers)

.PARAMETER UseAzCli
    Use Azure CLI for authentication instead of Azure PowerShell

.EXAMPLE
    # Create default containers using Azure CLI
    .\create-storage-containers.ps1 -StorageAccountName "mystorage" -ResourceGroupName "myrg" -UseAzCli

.EXAMPLE
    # Create custom containers using Azure PowerShell
    .\create-storage-containers.ps1 -StorageAccountName "mystorage" -ResourceGroupName "myrg" -Containers @("bronze", "silver", "gold")

.NOTES
    Author: GPT Data Platform Team
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string[]]$Containers = @(
        # Medallion Architecture
        "bronze",      # Raw data landing zone
        "silver",      # Cleaned and processed data
        "gold",        # Business-ready curated data

        # Testing & Development
        "test",        # Test data and validation datasets
        "functional",  # Functional testing data

        # Data Processing
        "raw",         # Alternative raw data or different data types
        "temp",        # Temporary processing data
        "checkpoints", # Streaming checkpoints and state

        # Operations
        "logs",        # Application and system logs
        "metadata",    # Data catalog metadata and schemas
        "archive",     # Archived historical data
        "quarantine"   # Data that failed validation or processing
    ),

    [Parameter(Mandatory = $false)]
    [switch]$UseAzCli
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Colors for output
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"
$Cyan = "Cyan"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-AzureConnection {
    param([bool]$UseAzCli)

    Write-ColorOutput "🔍 Checking Azure authentication..." $Cyan

    if ($UseAzCli) {
        try {
            $account = az account show --output json | ConvertFrom-Json
            Write-ColorOutput "✅ Azure CLI authenticated as: $($account.user.name)" $Green
            return $true
        }
        catch {
            Write-ColorOutput "❌ Azure CLI authentication failed. Please run 'az login' first." $Red
            return $false
        }
    }
    else {
        try {
            $context = Get-AzContext
            if ($null -eq $context) {
                throw "No Azure context found"
            }
            Write-ColorOutput "✅ Azure PowerShell authenticated as: $($context.Account.Id)" $Green
            return $true
        }
        catch {
            Write-ColorOutput "❌ Azure PowerShell authentication failed. Please run 'Connect-AzAccount' first." $Red
            return $false
        }
    }
}

function Get-StorageAccountInfo {
    param(
        [string]$StorageAccountName,
        [string]$ResourceGroupName,
        [string]$SubscriptionId,
        [bool]$UseAzCli
    )

    Write-ColorOutput "🔍 Retrieving storage account information..." $Cyan

    if ($UseAzCli) {
        $azCommand = "az storage account show --name $StorageAccountName --resource-group $ResourceGroupName --output json"
        if ($SubscriptionId) {
            $azCommand += " --subscription $SubscriptionId"
        }

        try {
            $storageAccount = Invoke-Expression $azCommand | ConvertFrom-Json
            return @{
                Name = $storageAccount.name
                ResourceGroup = $storageAccount.resourceGroup
                Location = $storageAccount.location
                Kind = $storageAccount.kind
                Sku = $storageAccount.sku.name
            }
        }
        catch {
            Write-ColorOutput "❌ Failed to retrieve storage account information: $_" $Red
            return $null
        }
    }
    else {
        try {
            if ($SubscriptionId) {
                Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
            }

            $storageAccount = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName
            return @{
                Name = $storageAccount.StorageAccountName
                ResourceGroup = $storageAccount.ResourceGroupName
                Location = $storageAccount.Location
                Kind = $storageAccount.Kind
                Sku = $storageAccount.Sku.Name
            }
        }
        catch {
            Write-ColorOutput "❌ Failed to retrieve storage account information: $_" $Red
            return $null
        }
    }
}

function Get-StorageAccountKey {
    param(
        [string]$StorageAccountName,
        [string]$ResourceGroupName,
        [string]$SubscriptionId,
        [bool]$UseAzCli
    )

    if ($UseAzCli) {
        $azCommand = "az storage account keys list --account-name $StorageAccountName --resource-group $ResourceGroupName --output json"
        if ($SubscriptionId) {
            $azCommand += " --subscription $SubscriptionId"
        }

        try {
            $keys = Invoke-Expression $azCommand | ConvertFrom-Json
            return $keys[0].value
        }
        catch {
            Write-ColorOutput "❌ Failed to retrieve storage account key: $_" $Red
            return $null
        }
    }
    else {
        try {
            if ($SubscriptionId) {
                Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
            }

            $keys = Get-AzStorageAccountKey -Name $StorageAccountName -ResourceGroupName $ResourceGroupName
            return $keys[0].Value
        }
        catch {
            Write-ColorOutput "❌ Failed to retrieve storage account key: $_" $Red
            return $null
        }
    }
}

function Create-StorageContainer {
    param(
        [string]$StorageAccountName,
        [string]$StorageAccountKey,
        [string]$ContainerName,
        [bool]$UseAzCli
    )

    Write-ColorOutput "📦 Creating container: $ContainerName" $Yellow

    if ($UseAzCli) {
        try {
            $result = az storage container create `
                --name $ContainerName `
                --account-name $StorageAccountName `
                --account-key $StorageAccountKey `
                --output json

            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Container '$ContainerName' created successfully" $Green
                return $true
            }
            else {
                Write-ColorOutput "⚠️  Container '$ContainerName' may already exist or creation failed" $Yellow
                return $false
            }
        }
        catch {
            Write-ColorOutput "❌ Failed to create container '$ContainerName': $_" $Red
            return $false
        }
    }
    else {
        try {
            $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
            $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue

            if ($null -eq $container) {
                New-AzStorageContainer -Name $ContainerName -Context $context -Permission Off | Out-Null
                Write-ColorOutput "✅ Container '$ContainerName' created successfully" $Green
                return $true
            }
            else {
                Write-ColorOutput "ℹ️  Container '$ContainerName' already exists" $Cyan
                return $true
            }
        }
        catch {
            Write-ColorOutput "❌ Failed to create container '$ContainerName': $_" $Red
            return $false
        }
    }
}

function Show-ContainerPurpose {
    Write-ColorOutput "`n📋 Container Purposes:" $Cyan
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $Cyan

    $containerDescriptions = @{
        "bronze" = "Raw data landing zone - initial ingestion point for all data sources"
        "silver" = "Cleaned and processed data - transformed, validated, and enriched data"
        "gold" = "Business-ready curated data - aggregated, modeled data for analytics and reporting"
        "test" = "Test data and validation datasets - used for testing pipelines and applications"
        "functional" = "Functional testing data - datasets for functional testing scenarios"
        "raw" = "Alternative raw data storage - for different data types or ingestion methods"
        "temp" = "Temporary processing data - intermediate results and temporary files"
        "checkpoints" = "Streaming checkpoints and state - for Spark Streaming, Event Hubs, etc."
        "logs" = "Application and system logs - audit trails, error logs, performance metrics"
        "metadata" = "Data catalog metadata and schemas - table schemas, data lineage, quality metrics"
        "archive" = "Archived historical data - cold storage for compliance and historical analysis"
        "quarantine" = "Data quarantine zone - data that failed validation or processing rules"
    }

    foreach ($container in $Containers) {
        $description = $containerDescriptions[$container]
        if ($description) {
            Write-ColorOutput "• $container" $Yellow
            Write-ColorOutput "  └─ $description" $Gray
        }
    }

    Write-ColorOutput ""
}

# Main script execution
Write-ColorOutput "🚀 Azure Storage Container Creation Script" $Cyan
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $Cyan

# Validate parameters
if ($Containers.Count -eq 0) {
    Write-ColorOutput "❌ No containers specified. Please provide container names or use default list." $Red
    exit 1
}

# Check Azure authentication
if (-not (Test-AzureConnection -UseAzCli $UseAzCli)) {
    exit 1
}

# Get storage account information
$storageInfo = Get-StorageAccountInfo -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -UseAzCli $UseAzCli
if ($null -eq $storageInfo) {
    exit 1
}

Write-ColorOutput "📊 Storage Account Details:" $Cyan
Write-ColorOutput "  Name: $($storageInfo.Name)" $White
Write-ColorOutput "  Resource Group: $($storageInfo.ResourceGroup)" $White
Write-ColorOutput "  Location: $($storageInfo.Location)" $White
Write-ColorOutput "  Kind: $($storageInfo.Kind)" $White
Write-ColorOutput "  SKU: $($storageInfo.Sku)" $White
Write-ColorOutput ""

# Get storage account key
$storageKey = Get-StorageAccountKey -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -UseAzCli $UseAzCli
if ($null -eq $storageKey) {
    exit 1
}

# Show container purposes
Show-ContainerPurpose

# Create containers
$createdCount = 0
$failedCount = 0

Write-ColorOutput "🔨 Creating containers..." $Cyan
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $Cyan

foreach ($container in $Containers) {
    if (Create-StorageContainer -StorageAccountName $StorageAccountName -StorageAccountKey $storageKey -ContainerName $container -UseAzCli $UseAzCli) {
        $createdCount++
    }
    else {
        $failedCount++
    }
}

# Summary
Write-ColorOutput "`n📈 Summary:" $Cyan
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $Cyan
Write-ColorOutput "✅ Containers created/existing: $createdCount" $Green
Write-ColorOutput "❌ Containers failed: $failedCount" $(if ($failedCount -gt 0) { $Red } else { $Green })

if ($failedCount -eq 0) {
    Write-ColorOutput "`n🎉 All containers processed successfully!" $Green
    Write-ColorOutput "💡 Next steps:" $Cyan
    Write-ColorOutput "   • Configure appropriate RBAC permissions for data access" $White
    Write-ColorOutput "   • Set up data lifecycle management policies" $White
    Write-ColorOutput "   • Configure monitoring and alerting for storage metrics" $White
}
else {
    Write-ColorOutput "`n⚠️  Some containers failed to create. Please check the errors above." $Yellow
    exit 1
}