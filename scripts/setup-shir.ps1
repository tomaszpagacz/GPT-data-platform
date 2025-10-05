# Script to install and configure Synapse Self-Hosted Integration Runtime
param(
    [Parameter(Mandatory=$true)]
    [string]$SynapseWorkspaceName,

    [Parameter(Mandatory=$true)]
    [string]$IntegrationRuntimeName
)

# Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Log file path
$logFile = "C:\shir-setup.log"

function Write-Log {
    param($Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

function Install-Prerequisites {
    Write-Log "Installing prerequisites..."
    
    # Install necessary PowerShell modules
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Install-Module -Name Az -AllowClobber -Scope AllUsers -Force
        Write-Log "Successfully installed Az PowerShell module"
    }
    catch {
        Write-Log "Error installing prerequisites: $_"
        throw
    }
}

function Download-IntegrationRuntime {
    Write-Log "Downloading Integration Runtime..."
    
    $downloadUrl = "https://download.microsoft.com/download/E/4/7/E4771905-1079-445B-8BF9-8A1A075D8A10/IntegrationRuntime_5.0.exe"
    $installerPath = "C:\IntegrationRuntime.exe"
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
        Write-Log "Successfully downloaded Integration Runtime installer"
        return $installerPath
    }
    catch {
        Write-Log "Error downloading Integration Runtime: $_"
        throw
    }
}

function Install-IntegrationRuntime {
    param($InstallerPath)
    Write-Log "Installing Integration Runtime..."
    
    try {
        $process = Start-Process -FilePath $InstallerPath -ArgumentList "/quiet" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "Successfully installed Integration Runtime"
        }
        else {
            throw "Installation failed with exit code: $($process.ExitCode)"
        }
    }
    catch {
        Write-Log "Error installing Integration Runtime: $_"
        throw
    }
}

function Configure-IntegrationRuntime {
    param(
        $SynapseWorkspaceName,
        $IntegrationRuntimeName
    )
    Write-Log "Configuring Integration Runtime for workspace: $SynapseWorkspaceName"
    
    try {
        # Connect using managed identity
        Connect-AzAccount -Identity

        # Get the auth key from Synapse
        $workspace = Get-AzSynapseWorkspace -Name $SynapseWorkspaceName
        $authKey = Get-AzSynapseIntegrationRuntimeKey -WorkspaceName $SynapseWorkspaceName -Name $IntegrationRuntimeName

        # Configure IR using PowerShell
        $irService = Get-Service -Name "DIAHostService"
        if ($irService.Status -ne "Running") {
            Start-Service -Name "DIAHostService"
            Write-Log "Started Integration Runtime service"
        }

        # Register IR with auth key
        $cmd = "C:\Program Files\Microsoft Integration Runtime\5.0\SharedInstallationFiles\IntegrationRuntime.exe"
        $args = @("-RegisterNewNode", $authKey.AuthKey1)
        $process = Start-Process -FilePath $cmd -ArgumentList $args -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Successfully registered Integration Runtime"
        }
        else {
            throw "Registration failed with exit code: $($process.ExitCode)"
        }
    }
    catch {
        Write-Log "Error configuring Integration Runtime: $_"
        throw
    }
}

function Test-IntegrationRuntime {
    Write-Log "Testing Integration Runtime configuration..."
    
    try {
        $service = Get-Service -Name "DIAHostService"
        if ($service.Status -eq "Running") {
            Write-Log "Integration Runtime service is running"
            return $true
        }
        else {
            Write-Log "Integration Runtime service is not running"
            return $false
        }
    }
    catch {
        Write-Log "Error testing Integration Runtime: $_"
        return $false
    }
}

# Main execution flow
try {
    Write-Log "Starting SHIR installation process..."
    
    Install-Prerequisites
    $installerPath = Download-IntegrationRuntime
    Install-IntegrationRuntime -InstallerPath $installerPath
    Configure-IntegrationRuntime -SynapseWorkspaceName $SynapseWorkspaceName -IntegrationRuntimeName $IntegrationRuntimeName
    
    if (Test-IntegrationRuntime) {
        Write-Log "SHIR installation and configuration completed successfully"
        exit 0
    }
    else {
        Write-Log "SHIR installation completed but service is not running"
        exit 1
    }
}
catch {
    Write-Log "Fatal error during SHIR setup: $_"
    exit 1
}