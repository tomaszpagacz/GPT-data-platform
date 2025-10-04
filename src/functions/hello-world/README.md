# Hello World Azure Function

This is a sample HTTP-triggered Azure Function that demonstrates basic functionality and best practices.

## Features

- HTTP trigger with GET and POST support
- Query string and request body parameter handling
- Structured logging
- Error handling
- Clean code organization

## Local Development

1. Install prerequisites:
   ```bash
   dotnet restore
   ```

2. Run the function locally:
   ```bash
   func start
   ```

3. Test the function:
   ```bash
   # Using curl
   curl "http://localhost:7071/api/HelloHttpTrigger?name=World"

   # Using POST
   curl -X POST "http://localhost:7071/api/HelloHttpTrigger" \
        -H "Content-Type: application/json" \
        -d '{"name": "World"}'
   ```

## Code Structure

- `HelloHttpTrigger.cs`: Main function implementation
- `host.json`: Runtime configuration
- `local.settings.json`: Local development settings
- `hello-world.csproj`: Project file with dependencies

## Best Practices Demonstrated

1. **Proper Error Handling**
   - Uses try-catch for error management
   - Structured logging of errors

2. **Input Validation**
   - Checks for null/empty values
   - Supports multiple input methods (query/body)

3. **Logging**
   - Uses ILogger for structured logging
   - Includes operation context

4. **Clean Code**
   - Clear variable names
   - Proper async/await usage
   - Consistent formatting

## Deployment

1. Publish the function:
   ```bash
   dotnet publish
   ```

2. Deploy to Azure:
   ```bash
   func azure functionapp publish <app-name>
   ```

## Testing

Test different scenarios:

1. No parameters:
   ```bash
   curl "http://localhost:7071/api/HelloHttpTrigger"
   ```

2. Name in query string:
   ```bash
   curl "http://localhost:7071/api/HelloHttpTrigger?name=John"
   ```

3. Name in request body:
   ```bash
   curl -X POST "http://localhost:7071/api/HelloHttpTrigger" \
        -H "Content-Type: application/json" \
        -d '{"name": "John"}'
   ```

## Expected Responses

1. With name parameter:
   ```json
   "Hello, John! This HTTP-triggered function executed successfully."
   ```

2. Without name parameter:
   ```json
   "Welcome to Azure Functions! Pass a name in the query string or in the request body for a personalized response."
   ```