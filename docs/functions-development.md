# Azure Functions Development Guide

> **Last Updated:** 2025-01-15
> **Audience:** Developer
> **Prerequisites:** .NET 8.0 SDK, Azure CLI, Visual Studio Code, Azure Functions Core Tools

## Overview

This guide provides comprehensive instructions for developing Azure Functions within the GPT Data Platform. It covers environment setup, project creation, best practices, deployment, and troubleshooting for both .NET and Node.js/TypeScript functions.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Creating a New Function Project](#creating-a-new-function-project)
- [Local Development](#local-development)
- [Project Structure](#project-structure)
- [Best Practices](#best-practices)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

## Prerequisites

### Required Tools

1. **Development Environment:**
   - [Visual Studio Code](https://code.visualstudio.com/)
   - [Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools)
   - [.NET 8.0 SDK](https://dotnet.microsoft.com/download) (for C# functions with isolated worker runtime)
   - [Node.js](https://nodejs.org/) (for JavaScript/TypeScript functions, v18+ recommended)

2. **Azure Tools:**
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
   - [Azure Functions Extension for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)

3. **VS Code Extensions:**
   ```bash
   code --install-extension ms-azuretools.vscode-azurefunctions
   code --install-extension ms-dotnettools.csharp
   code --install-extension ms-vscode.vscode-typescript-next
   ```

## Creating a New Function Project

1. Create a new directory for your function:
   ```bash
   mkdir src/functions/my-function
   cd src/functions/my-function
   ```

2. Initialize a new function project:
   ```bash
   # For C#
   func init --worker-runtime dotnet

   # For JavaScript
   func init --worker-runtime node --language javascript

   # For TypeScript
   func init --worker-runtime node --language typescript
   ```

3. Add a new function to your project:
   ```bash
   func new --template "HTTP trigger" --name MyHttpTrigger
   ```

## Local Development

1. Install dependencies:
   ```bash
   # For .NET
   dotnet restore

   # For Node.js
   npm install
   ```

2. Start the function locally:
   ```bash
   func start
   ```

3. Test your function:
   ```bash
   curl http://localhost:7071/api/MyHttpTrigger?name=World
   ```

## Project Structure

```
src/functions/my-function/
├── .vscode/                # VS Code settings
├── bin/                    # Compiled output (.NET)
├── obj/                    # Build artifacts (.NET)
├── MyHttpTrigger/         # Function code
│   ├── function.json      # Function configuration
│   └── index.js/cs        # Function implementation
├── host.json              # Runtime configuration
├── local.settings.json    # Local settings and connection strings
└── *.csproj/package.json  # Project file
```

## Best Practices

1. **Secret Management**
   - Never commit secrets to source control
   - Use Key Vault references in your app settings
   - Local development should use `local.settings.json` (gitignored)

2. **Error Handling**
   ```csharp
   try
   {
       // Your function logic
   }
   catch (Exception ex)
   {
       log.LogError($"Error processing request: {ex.Message}");
       throw; // Let Azure Functions handle the error response
   }
   ```

3. **Dependency Injection**
   - Use constructor injection for services
   - Register dependencies in `Startup.cs` (.NET)
   - Use dependency injection for better testability

4. **Logging**
   - Use structured logging
   - Include correlation IDs
   - Log appropriate detail level
   ```csharp
   log.LogInformation("Processing request for {name}", name);
   ```

5. **Configuration**
   - Use strongly-typed configuration where possible
   - Follow configuration hierarchy:
     1. Local development: `local.settings.json`
     2. Azure: Application settings in Azure Portal
     3. Key Vault references for secrets

## Deployment

1. Build your function:
   ```bash
   # .NET
   dotnet publish

   # Node.js
   npm run build # if TypeScript
   ```

2. Deploy using Azure CLI:
   ```bash
   az functionapp deployment source config-zip \
     -g <resource-group> \
     -n <app-name> \
     --src <zip-file-path>
   ```

## Monitoring

1. View logs in real-time:
   ```bash
   az webapp log tail --name <function-app-name> \
     --resource-group <resource-group>
   ```

2. Use Application Insights:
   - Enable App Insights in your function app
   - Use correlation IDs for request tracking
   - Set up alerts for errors and performance issues

## Common Issues and Solutions

1. **CORS Issues**
   - Configure CORS in Azure Portal or `host.json`
   - Allow specific origins only
   - Test CORS locally using `local.settings.json`

2. **Authentication/Authorization**
   - Use Azure AD for enterprise apps
   - Implement function-level auth
   - Test auth locally with appropriate tools

3. **Performance**
   - Use async/await properly
   - Implement caching where appropriate
   - Monitor execution time and memory usage

## Sample Code

Check our Hello World example in `src/functions/hello-world/` for a working implementation following these best practices.

## Related Documentation

- [Platform Architecture](architecture.md) - Understanding the overall system design
- [Logic Apps Development](logic-apps-development.md) - Workflow development guide
- [API Management](api-management-deployment.md) - API gateway configuration
- [Deployment Troubleshooting](deployment-troubleshooting.md) - Common deployment issues
- [RBAC Implementation](rbac-implementation-guide.md) - Access control setup

## Next Steps

After completing function development:

1. Review [Logic Apps Development](logic-apps-development.md) for workflow integration
2. Configure [API Management](api-management-deployment.md) for your function APIs
3. Set up monitoring and alerting as described in operational documentation
4. Follow deployment procedures in the main README

## Additional Resources

- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
- [Azure Functions GitHub Repository](https://github.com/Azure/Azure-Functions)
- [Azure Functions University](https://github.com/marcduiker/azure-functions-university)