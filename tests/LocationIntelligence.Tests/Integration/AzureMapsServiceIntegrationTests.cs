using Xunit;
using Microsoft.Extensions.Configuration;
using LocationIntelligence.Services;
using LocationIntelligence.Tests.Helpers;
using RichardSzalay.MockHttp;
using System.Net;
using System.Text.Json;

namespace LocationIntelligence.Tests.Integration
{
    public class AzureMapsServiceIntegrationTests : IDisposable
    {
        private readonly MockHttpMessageHandler _mockHttp;
        private readonly IConfiguration _configuration;
        private readonly AzureMapsService _service;
        private readonly TestData _testData;
        private const string BaseUrl = "https://atlas.microsoft.com";
        private const string ApiKey = "test-key";

        public AzureMapsServiceIntegrationTests()
        {
            _mockHttp = new MockHttpMessageHandler();
            
            // Setup configuration
            var configValues = new Dictionary<string, string>
            {
                {"AzureMapsEndpoint", BaseUrl},
                {"AzureMapsKey", ApiKey}
            };
            _configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(configValues)
                .Build();

            // Create service with mocked HTTP client
            var client = _mockHttp.ToHttpClient();
            client.BaseAddress = new Uri(BaseUrl);
            _service = new AzureMapsService(_configuration, client);

            _testData = TestDataLoader.LoadTestData();
        }

        [Fact]
        public async Task GetRouteDistance_SuccessfulRequest_ReturnsCorrectDistance()
        {
            // Arrange
            var testCase = TestDataLoader.GetTestCaseByName("NYC to LA - Driving");
            var expectedResponse = testCase.MockResponse;
            
            _mockHttp.When($"{BaseUrl}/route/directions/json*")
                .WithQueryString("subscription-key", ApiKey)
                .WithQueryString("api-version", "1.0")
                .Respond("application/json", JsonSerializer.Serialize(expectedResponse));

            // Act
            var distance = await _service.GetRouteDistanceAsync(
                testCase.Input.Origin,
                testCase.Input.Destination);

            // Assert
            Assert.Equal(testCase.ExpectedDistanceKm, distance, 2); // Compare with 2 decimal precision
        }

        [Fact]
        public async Task GetRouteDistance_InvalidCoordinates_ThrowsException()
        {
            // Arrange
            var testCase = TestDataLoader.GetTestCaseByName("Invalid Coordinates Test");
            
            _mockHttp.When($"{BaseUrl}/route/directions/json*")
                .Respond(HttpStatusCode.BadRequest, "application/json", 
                    JsonSerializer.Serialize(testCase.MockResponse));

            // Act & Assert
            await Assert.ThrowsAsync<Exception>(() => 
                _service.GetRouteDistanceAsync(
                    testCase.Input.Origin,
                    testCase.Input.Destination));
        }

        [Fact]
        public async Task GetRouteDistance_NetworkError_ThrowsException()
        {
            // Arrange
            var testCase = TestDataLoader.GetTestCaseByName("London to Paris - With Tunnel");
            
            _mockHttp.When($"{BaseUrl}/route/directions/json*")
                .Respond(HttpStatusCode.ServiceUnavailable);

            // Act & Assert
            await Assert.ThrowsAsync<HttpRequestException>(() => 
                _service.GetRouteDistanceAsync(
                    testCase.Input.Origin,
                    testCase.Input.Destination));
        }

        [Theory]
        [InlineData("NYC to LA - Driving")]
        [InlineData("London to Paris - With Tunnel")]
        [InlineData("Zurich Local - One Way Streets")]
        public async Task GetRouteDistance_VariousRoutes_ReturnsExpectedDistances(string testCaseName)
        {
            // Arrange
            var testCase = TestDataLoader.GetTestCaseByName(testCaseName);
            
            _mockHttp.When($"{BaseUrl}/route/directions/json*")
                .Respond("application/json", JsonSerializer.Serialize(testCase.MockResponse));

            // Act
            var distance = await _service.GetRouteDistanceAsync(
                testCase.Input.Origin,
                testCase.Input.Destination);

            // Assert
            Assert.Equal(testCase.ExpectedDistanceKm, distance, 2);
        }

        public void Dispose()
        {
            _mockHttp.Dispose();
        }
    }
}