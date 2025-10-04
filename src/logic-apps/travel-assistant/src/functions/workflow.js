const { app } = require('@azure/functions');

app.http('workflow', {
    methods: ['POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        context.log('Processing travel-assistant request');

        const body = await request.json();
        const { destination, duration } = body || {};
        
        if (!destination || !duration) {
            return {
                status: 400,
                body: JSON.stringify({
                    error: "Please provide all required fields: destination and duration"
                })
            };
        }

        try {
            // Mock response for local testing
            return {
                status: 200,
                body: JSON.stringify({
                    status: "success",
                    data: {
                        trip: {
                            destination: {
                                name: destination,
                                type: "city",
                                coordinates: {
                                    lat: 48.8566,
                                    lon: 2.3522
                                }
                            },
                            duration: {
                                value: duration,
                                unit: duration.includes("day") ? "days" : "hours"
                            },
                            recommendedActivities: [
                                {
                                    name: "Visit local landmarks",
                                    category: "sightseeing",
                                    duration: "2-3 hours"
                                },
                                {
                                    name: "Try local cuisine",
                                    category: "dining",
                                    duration: "1-2 hours"
                                },
                                {
                                    name: "Experience local culture",
                                    category: "culture",
                                    duration: "flexible"
                                }
                            ],
                            weather: {
                                current: {
                                    temperature: 22,
                                    unit: "celsius",
                                    conditions: "sunny"
                                },
                                forecast: "Clear skies throughout your stay"
                            }
                        },
                        route: {
                            summary: {
                                distance: {
                                    value: 1.5,
                                    unit: "km"
                                },
                                duration: {
                                    value: 10,
                                    unit: "minutes"
                                }
                            },
                            instructions: [
                                {
                                    step: 1,
                                    action: "Go straight",
                                    distance: "500m"
                                },
                                {
                                    step: 2,
                                    action: "Turn right",
                                    distance: "750m"
                                },
                                {
                                    step: 3,
                                    action: "You have reached your destination",
                                    distance: "250m"
                                }
                            ]
                        }
                    },
                    metadata: {
                        timestamp: new Date().toISOString(),
                        version: "1.0.0",
                        service: "travel-assistant"
                    }
                })
            };
        } catch (error) {
            context.error('Error processing travel assistant request:', error);
            return {
                status: 500,
                body: JSON.stringify({
                    error: "An error occurred processing your request"
                })
            };
        }
    }
});
