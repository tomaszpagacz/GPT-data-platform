# Logic Apps Development Guide

This guide will help you get started with developing Logic Apps for our data platform. It covers both the Visual Designer approach and the code-first development using VS Code.

## Prerequisites

1. Install the following tools:
   - [Visual Studio Code](https://code.visualstudio.com/)
   - [Azure Logic Apps Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-logicapps)
   - [Azure Account Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.azure-account)
   - [Azurite Storage Emulator](https://github.com/Azure/Azurite)
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

2. Install VS Code Extensions:
   ```bash
   code --install-extension ms-azuretools.vscode-logicapps
   code --install-extension ms-azuretools.vscode-azurelogicapps
   code --install-extension ms-vscode.azure-account
   ```

## Development Approaches

### 1. Visual Designer (Portal)

1. **Access the Designer**
   - Navigate to Azure Portal
   - Create/Open Logic App
   - Use the visual designer interface

2. **Export/Import**
   - Export workflow as ARM template
   - Store in source control
   - Import using ARM deployment

3. **Best Practices**
   - Use parameters for configuration
   - Document workflow in comments
   - Use consistent naming conventions

### 2. Code-First Development

1. Create a new Logic App project:
   ```bash
   mkdir src/logic-apps/my-workflow
   cd src/logic-apps/my-workflow
   ```

2. Initialize project structure:
   ```
   my-workflow/
   ├── workflow.json
   ├── connections.json
   ├── parameters.json
   └── host.json
   ```

3. Define workflow in `workflow.json`:
   ```json
   {
       "definition": {
           "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
           "actions": {},
           "triggers": {},
           "contentVersion": "1.0.0.0",
           "outputs": {}
       }
   }
   ```

## Local Development and Testing

We provide a comprehensive local testing environment that doesn't require any Azure resources.

### Prerequisites

1. Local development tools:
   - Node.js and npm
   - Azurite (Storage Emulator)
   - Azure Functions Core Tools
   - jq (for JSON processing)

2. Install dependencies:
   ```bash
   ./helpers/setup-scripts/install-dependencies.sh
   ```

### Running Local Tests

1. Start the local test environment:
   ```bash
   ./helpers/setup-scripts/test-logic-apps-local.sh
   ```

This script will:
- Start Azurite storage emulator
- Create local settings files
- Start Location Intelligence Function locally
- Start both Logic Apps locally
- Run test cases against local endpoints

### Local Endpoints

When running locally, the services are available at:
- Hello World Logic App: http://localhost:8081
- Travel Assistant Logic App: http://localhost:8082
- Location Intelligence Function: http://localhost:7071

### Manual Local Testing

Test Hello World:
```bash
curl -X POST "http://localhost:8081/api/workflow-trigger" \
     -H "Content-Type: application/json" \
     -d '{"name": "Local Test User"}'
```

Test Travel Assistant:
```bash
curl -X POST "http://localhost:8082/api/workflow-trigger" \
     -H "Content-Type: application/json" \
     -d '{
         "address": "350 5th Ave, New York, NY 10118",
         "targetLanguage": "es",
         "sourceLanguage": "en",
         "currentLocation": {
             "latitude": 40.7484,
             "longitude": -73.9857
         },
         "travelMode": "driving"
     }'
```

### Local Settings

Each Logic App has its own `local.settings.json`:

Hello World:
```json
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "node",
        "WORKFLOWS_SUBSCRIPTION_ID": "00000000-0000-0000-0000-000000000000",
        "WORKFLOWS_RESOURCE_GROUP_NAME": "local-dev",
        "WORKFLOWS_LOCATION_NAME": "local"
    }
}
```

Travel Assistant:
```json
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "node",
        "WORKFLOWS_SUBSCRIPTION_ID": "00000000-0000-0000-0000-000000000000",
        "WORKFLOWS_RESOURCE_GROUP_NAME": "local-dev",
        "WORKFLOWS_LOCATION_NAME": "local",
        "LocationIntelligenceFunctionUrl": "http://localhost:7071",
        "LocationIntelligenceFunctionKey": "local-dev-key"
    }
}
```

## Project Structure

```
src/logic-apps/
├── my-workflow/
│   ├── workflow.json     # Main workflow definition
│   ├── connections.json  # API connections
│   ├── parameters.json   # Parameter values
│   └── host.json        # Runtime configuration
└── shared/
    └── connections/      # Shared API connections
```

## Best Practices

1. **Source Control**
   - Store workflow definitions in source control
   - Use parameters for environment-specific values
   - Include documentation with each workflow

## Testing

### Using the Test Script

We provide a test script to validate Logic Apps functionality across environments:

```bash
./helpers/setup-scripts/test-logic-apps.sh -e <environment> -r <resource-group>
```

Options:
- `-e, --environment`: Target environment (dev, sit, prod)
- `-r, --resource-group`: Azure resource group name
- `-h, --help`: Show help message

Example:
```bash
./helpers/setup-scripts/test-logic-apps.sh -e dev -r my-resource-group
```

### Available Test Cases

1. **Hello World Logic App**
   ```json
   {
       "name": "Test User"
   }
   ```
   Expected response:
   ```json
   {
       "message": "Hello, Test User!",
       "timestamp": "2025-10-04T10:00:00.000Z"
   }
   ```

2. **Travel Assistant Logic App**
   ```json
   {
       "address": "350 5th Ave, New York, NY 10118",
       "targetLanguage": "es",
       "sourceLanguage": "en",
       "currentLocation": {
           "latitude": 40.7484,
           "longitude": -73.9857
       },
       "travelMode": "driving"
   }
   ```
   Expected response:
   ```json
   {
       "destination": {
           "originalAddress": "350 5th Ave, New York, NY 10118",
           "translatedAddress": "350 5ta Avenida, Nueva York, NY 10118",
           "location": {
               "latitude": 40.7484,
               "longitude": -73.9857
           },
           "additionalInfo": {
               "pointOfInterest": "Empire State Building",
               "neighborhood": "Midtown"
           }
       },
       "route": {
           "summary": {
               "distance": "0.5 km",
               "duration": "10 minutos"
           },
           "instructions": [
               "Diríjase al norte por la 5ta Avenida",
               "Gire a la derecha en la Calle 34",
               "Ha llegado a su destino"
           ]
       }
   }
   ```

### Manual Testing

You can also test Logic Apps manually using curl:

```bash
# Get Logic App URL
LOGIC_APP_URL=$(az logic workflow show --name "my-workflow" --resource-group "my-rg" --query "accessEndpoint" -o tsv)

# Test endpoint
curl -X POST "$LOGIC_APP_URL" \
     -H "Content-Type: application/json" \
     -d '{...}'
```

### Monitoring Test Results

View run history:
```bash
# List recent runs
az logic workflow run list \
    --name <workflow-name> \
    --resource-group <resource-group> \
    --query "[].{RunId:name, Status:status, StartTime:startTime}" \
    -o table

# Get details of a specific run
az logic workflow run show \
    --name <workflow-name> \
    --resource-group <resource-group> \
    --run-name <run-id>
```

### Troubleshooting Tests

Common issues and solutions:

1. **Authentication Errors**
   - Check Azure CLI login status
   - Verify resource permissions
   - Validate function keys

2. **404 Not Found**
   - Verify Logic App URLs
   - Check if Logic Apps are running
   - Verify API versions

3. **500 Internal Server Error**
   - Check run history for details
   - Verify dependent services
   - Review application logs

4. **Invalid Parameters**
   - Validate JSON payload schema
   - Check coordinate formats
   - Verify language codes

2. **Error Handling**
   ```json
   {
       "actions": {
           "Scope": {
               "type": "Scope",
               "actions": {},
               "runAfter": {},
               "catch": [
                   {
                       "if": {
                           "equals": ["@result('Scope')", "Failed"]
                       },
                       "actions": {
                           "Handle_Error": {}
                       }
                   }
               ]
           }
       }
   }
   ```

3. **Parameters**
   - Use parameters for:
     - Connection strings
     - URLs
     - Environment-specific values
   - Store sensitive values in Key Vault

4. **Monitoring**
   - Enable diagnostic logs
   - Set up alerts
   - Use correlation IDs

## Common Patterns

1. **HTTP Webhook Pattern**
   ```json
   {
       "triggers": {
           "manual": {
               "type": "Request",
               "kind": "Http",
               "inputs": {
                   "schema": {
                       "type": "object",
                       "properties": {
                           "name": {
                               "type": "string"
                           }
                       }
                   }
               }
           }
       }
   }
   ```

2. **Service Bus Integration**
   ```json
   {
       "triggers": {
           "serviceBusTrigger": {
               "type": "serviceBus",
               "inputs": {
                   "topicName": "mytopic",
                   "subscriptionName": "mysub"
               }
           }
       }
   }
   ```

## Deployment

1. Using Azure CLI:
   ```bash
   az logicapp deployment create \
     --resource-group <resource-group> \
     --name <logic-app-name> \
     --template-file template.json \
     --parameters parameters.json
   ```

2. Using ARM Templates:
   ```bash
   az deployment group create \
     --resource-group <resource-group> \
     --template-file template.json \
     --parameters parameters.json
   ```

## Testing

1. **Local Testing**
   - Use Postman for HTTP triggers
   - Set up local environment variables
   - Test with sample payloads

2. **Integration Testing**
   - Create test environments
   - Use mock services
   - Validate workflow outputs

## Security

1. **Authentication**
   - Use Managed Identity
   - Store secrets in Key Vault
   - Implement RBAC properly

2. **Network Security**
   - Use Private Endpoints
   - Configure firewalls
   - Restrict IP ranges

## Sample Code

Check our Hello World example in `src/logic-apps/hello-world/` for a working implementation following these best practices.

## Monitoring and Troubleshooting

1. **Diagnostic Settings**
   - Enable workflow runtime logs
   - Track execution history
   - Monitor trigger history

2. **Common Issues**
   - Connection problems
   - Authentication failures
   - Timeout issues

## Additional Resources

- [Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)
- [Logic Apps GitHub Samples](https://github.com/Azure/logicapps)
- [Workflow Definition Language Schema](https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json)