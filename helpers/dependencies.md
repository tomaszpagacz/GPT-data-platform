# Project Dependencies

## NuGet Packages

### Main Project Dependencies (location-intelligence.csproj)
- Microsoft.NET.Sdk.Functions
- Microsoft.Azure.Functions.Extensions
- Microsoft.Extensions.Http
- Microsoft.Extensions.DependencyInjection
- System.Text.Json
- System.Web.HttpUtility

### Test Project Dependencies (LocationIntelligence.Tests.csproj)

#### Recent Package Upgrades
- Upgraded `xunit.runner.visualstudio` from default version to 2.5.7 to fix test discovery and execution issues

```xml
<PackageReference Include="Microsoft.AspNetCore.Http" Version="2.2.2" />
<PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.1.0" />
<PackageReference Include="Moq" Version="4.18.4" />
<PackageReference Include="xunit" Version="2.9.3" />
<PackageReference Include="xunit.runner.visualstudio" Version="2.5.7">
    <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    <PrivateAssets>all</PrivateAssets>
</PackageReference>
<PackageReference Include="coverlet.collector" Version="3.1.2">
    <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    <PrivateAssets>all</PrivateAssets>
</PackageReference>
<PackageReference Include="Microsoft.Extensions.Configuration" Version="6.0.0" />
<PackageReference Include="RichardSzalay.MockHttp" Version="6.0.0" />
```

## Development Tools

### .NET SDK
- Version: 6.0

### Azure Functions Core Tools
Required for local development and testing of Azure Functions

### VS Code Extensions
- C# for Visual Studio Code (powered by OmniSharp)
- Azure Functions
- Bicep
- REST Client (if using `.http` files for API testing)

## Infrastructure Dependencies

### Azure Resources
- Azure Functions (for hosting)
- Azure Maps (for distance calculations)
- Azure Key Vault (for secrets management)

### Infrastructure as Code
- Bicep for Azure Resource Management
- Azure CLI for deployment

## Testing Dependencies
- xUnit as the test framework
- Moq for mocking
- RichardSzalay.MockHttp for HTTP client mocking
- Microsoft.NET.Test.Sdk for test execution
- coverlet.collector for code coverage

## Environment Setup Scripts
All setup scripts are located in `/helpers/setup-scripts/`:
- `setup-dev-environment.sh`: Main development environment setup
- `check-workspace-details.sh`: Workspace validation
- `test-distance-function.sh`: Function testing utility

## CI/CD Dependencies
- GitHub Actions (if using GitHub for CI/CD)
- Azure DevOps Pipelines (if using Azure DevOps)

## How to Install Dependencies

### Development Environment Setup
1. Install .NET 6.0 SDK:
```bash
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --version 6.0.100
```

2. Install Azure Functions Core Tools:
```bash
npm install -g azure-functions-core-tools@4
```

3. Restore NuGet packages:
```bash
dotnet restore
```

4. Install required VS Code extensions:
```bash
code --install-extension ms-dotnettools.csharp
code --install-extension ms-azuretools.vscode-azurefunctions
code --install-extension ms-vscode.azurecli
code --install-extension ms-azuretools.vscode-bicep
```

### Test Environment Setup
```bash
dotnet add package Microsoft.NET.Test.Sdk
dotnet add package xunit
dotnet add package xunit.runner.visualstudio --version 2.5.7
dotnet add package Moq
dotnet add package RichardSzalay.MockHttp
dotnet add package coverlet.collector
```