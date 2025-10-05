# Azure Functions Development Guide

This guide will help you get started with developing Azure Functions for our data platform. It includes step-by-step instructions for setting up your development environment, creating your first function, and following best practices.

## Prerequisites

1. Install the following tools:
   - [Visual Studio Code](https://code.visualstudio.com/)
   - [Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools)
   - [Node.js](https://nodejs.org/) (for JavaScript/TypeScript functions)
   - [.NET 8.0 SDK](https://dotnet.microsoft.com/download) (for C# functions with isolated worker runtime)
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
   - [Azure Functions Extension for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)

2. Install VS Code Extensions:
   ```bash
   code --install-extension ms-azuretools.vscode-azurefunctions
   code --install-extension ms-dotnettools.csharp
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

## Additional Resources

- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
- [Azure Functions GitHub Repository](https://github.com/Azure/Azure-Functions)
- [Azure Functions University](https://github.com/marcduiker/azure-functions-university)