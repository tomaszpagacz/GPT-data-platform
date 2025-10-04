const { app } = require('@azure/functions');

app.http('workflow', {
    methods: ['POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        context.log('Processing hello-world request');
        
        const body = await request.json();
        const name = body && body.name;
        
        if (!name) {
            return {
                status: 400,
                body: JSON.stringify({
                    error: "Please provide a name in the request body"
                })
            };
        }

        return {
            status: 200,
            body: JSON.stringify({
                status: "success",
                data: {
                    message: `Hello, ${name}!`,
                    greeting: {
                        text: `Hello, ${name}!`,
                        language: "en"
                    }
                },
                metadata: {
                    timestamp: new Date().toISOString(),
                    version: "1.0.0",
                    service: "hello-world"
                }
            })
        };
    }
});
