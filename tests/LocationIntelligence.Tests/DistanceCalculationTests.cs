using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Internal;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;
using LocationIntelligence.Models;
using LocationIntelligence.Services;
using Moq;

namespace LocationIntelligence.Tests
{
    public class DistanceCalculationTests
    {
        private readonly ILogger<DistanceCalculationFunction> logger = NullLoggerFactory.Instance.CreateLogger<DistanceCalculationFunction>();
        private readonly Mock<IAzureMapsService> mockMapsService;

        public DistanceCalculationTests()
        {
            mockMapsService = new Mock<IAzureMapsService>();
        }

        private HttpRequest CreateTestRequest(object content)
        {
            var json = JsonSerializer.Serialize(content);
            var stream = new MemoryStream(Encoding.UTF8.GetBytes(json));
            
            var context = new DefaultHttpContext();
            var request = new DefaultHttpRequest(context)
            {
                Body = stream,
                ContentType = "application/json"
            };

            return request;
        }

        [Fact]
        public async Task TestNYCToLA()
        {
            // Arrange
            var request = new
            {
                origin = new { latitude = 40.7128, longitude = -74.0060 },
                destination = new { latitude = 34.0522, longitude = -118.2437 }
            };

            var httpRequest = CreateTestRequest(request);

            mockMapsService.Setup(m => m.GetRouteDistanceAsync(
                It.Is<Coordinate>(c => Math.Abs(c.Latitude - 40.7128) < 0.0001 && Math.Abs(c.Longitude - (-74.0060)) < 0.0001),
                It.Is<Coordinate>(c => Math.Abs(c.Latitude - 34.0522) < 0.0001 && Math.Abs(c.Longitude - (-118.2437)) < 0.0001)
            )).ReturnsAsync(3935.75);

            var function = new DistanceCalculationFunction(mockMapsService.Object, logger);

            // Act
            var result = await function.Run(httpRequest);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var response = Assert.IsType<DistanceResponse>(okResult.Value);
            
            Assert.InRange(response.DistanceInKilometers, 3934.5, 3937); // Approximately 3935.75 km ± 1.25
            Assert.InRange(response.DistanceInMiles, 2443.5, 2446.5); // Approximately 2444.55 miles ± 1
        }

        [Fact]
        public async Task TestLondonToParis()
        {
            // Arrange
            var request = new
            {
                origin = new { latitude = 51.5074, longitude = -0.1278 },
                destination = new { latitude = 48.8566, longitude = 2.3522 }
            };

            var httpRequest = CreateTestRequest(request);

            mockMapsService.Setup(m => m.GetRouteDistanceAsync(
                It.Is<Coordinate>(c => Math.Abs(c.Latitude - 51.5074) < 0.0001 && Math.Abs(c.Longitude - (-0.1278)) < 0.0001),
                It.Is<Coordinate>(c => Math.Abs(c.Latitude - 48.8566) < 0.0001 && Math.Abs(c.Longitude - 2.3522) < 0.0001)
            )).ReturnsAsync(343.47);

            var function = new DistanceCalculationFunction(mockMapsService.Object, logger);

            // Act
            var result = await function.Run(httpRequest);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var response = Assert.IsType<DistanceResponse>(okResult.Value);
            
            Assert.InRange(response.DistanceInKilometers, 343, 344); // Approximately 343.47 km
            Assert.InRange(response.DistanceInMiles, 213, 214); // Approximately 213.42 miles
        }

        [Theory]
        [InlineData("{}")]
        [InlineData("{\"origin\":null,\"destination\":null}")]
        [InlineData("{\"origin\":{\"latitude\":0},\"destination\":{\"latitude\":0}}")]
        public async Task TestInvalidInput(string jsonRequest)
        {
            // Arrange
            var stream = new MemoryStream(Encoding.UTF8.GetBytes(jsonRequest));
            var context = new DefaultHttpContext();
            var request = new DefaultHttpRequest(context)
            {
                Body = stream,
                ContentType = "application/json"
            };

            var function = new DistanceCalculationFunction(mockMapsService.Object, logger);

            // Act
            var result = await function.Run(request);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result);
        }
    }
}