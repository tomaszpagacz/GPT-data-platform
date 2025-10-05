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
            
            // Verify response structure and reasonable values
            Assert.True(response.DistanceInKilometers > 0, "Distance in kilometers should be positive");
            Assert.True(response.DistanceInMiles > 0, "Distance in miles should be positive");
            Assert.InRange(response.DistanceInMiles, response.DistanceInKilometers * 0.62137 * 0.99, response.DistanceInKilometers * 0.62137 * 1.01);
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
            
            // Verify response structure and reasonable values
            Assert.True(response.DistanceInKilometers > 0, "Distance in kilometers should be positive");
            Assert.True(response.DistanceInMiles > 0, "Distance in miles should be positive");
            Assert.InRange(response.DistanceInMiles, response.DistanceInKilometers * 0.62137 * 0.99, response.DistanceInKilometers * 0.62137 * 1.01);
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

        [Theory]
        [InlineData(91, 0, 48.8566, 2.3522)]  // Invalid latitude (> 90)
        [InlineData(-91, 0, 48.8566, 2.3522)] // Invalid latitude (< -90)
        [InlineData(48.8566, 181, 51.5074, -0.1278)] // Invalid longitude (> 180)
        [InlineData(48.8566, -181, 51.5074, -0.1278)] // Invalid longitude (< -180)
        public async Task TestInvalidCoordinateRanges(double originLat, double originLon, double destLat, double destLon)
        {
            // Arrange
            var request = new
            {
                origin = new { latitude = originLat, longitude = originLon },
                destination = new { latitude = destLat, longitude = destLon }
            };

            var httpRequest = CreateTestRequest(request);
            var function = new DistanceCalculationFunction(mockMapsService.Object, logger);

            // Act
            var result = await function.Run(httpRequest);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result);
        }

        [Fact]
        public async Task TestAzureMapsAuthenticationError()
        {
            // Arrange
            var request = new
            {
                origin = new { latitude = 51.5074, longitude = -0.1278 },
                destination = new { latitude = 48.8566, longitude = 2.3522 }
            };

            var httpRequest = CreateTestRequest(request);

            mockMapsService.Setup(m => m.GetRouteDistanceAsync(It.IsAny<Coordinate>(), It.IsAny<Coordinate>()))
                .ThrowsAsync(new Exception("Azure Maps authentication failed. Check API key configuration"));

            var function = new DistanceCalculationFunction(mockMapsService.Object, logger);

            // Act
            var result = await function.Run(httpRequest);

            // Assert
            var statusResult = Assert.IsType<StatusCodeResult>(result);
            Assert.Equal(StatusCodes.Status500InternalServerError, statusResult.StatusCode);
        }

        [Fact]
        public async Task TestAzureMapsRateLimitError()
        {
            // Arrange
            var request = new
            {
                origin = new { latitude = 51.5074, longitude = -0.1278 },
                destination = new { latitude = 48.8566, longitude = 2.3522 }
            };

            var httpRequest = CreateTestRequest(request);

            mockMapsService.Setup(m => m.GetRouteDistanceAsync(It.IsAny<Coordinate>(), It.IsAny<Coordinate>()))
                .ThrowsAsync(new Exception("Azure Maps rate limit exceeded. Please retry later"));

            var function = new DistanceCalculationFunction(mockMapsService.Object, logger);

            // Act
            var result = await function.Run(httpRequest);

            // Assert
            var statusResult = Assert.IsType<StatusCodeResult>(result);
            Assert.Equal(StatusCodes.Status500InternalServerError, statusResult.StatusCode);
        }

        [Fact]
        public async Task TestAzureMapsServiceUnavailable()
        {
            // Arrange
            var request = new
            {
                origin = new { latitude = 51.5074, longitude = -0.1278 },
                destination = new { latitude = 48.8566, longitude = 2.3522 }
            };

            var httpRequest = CreateTestRequest(request);

            mockMapsService.Setup(m => m.GetRouteDistanceAsync(It.IsAny<Coordinate>(), It.IsAny<Coordinate>()))
                .ThrowsAsync(new Exception("Azure Maps service is temporarily unavailable. Please try again later"));

            var function = new DistanceCalculationFunction(mockMapsService.Object, logger);

            // Act
            var result = await function.Run(httpRequest);

            // Assert
            var statusResult = Assert.IsType<StatusCodeResult>(result);
            Assert.Equal(StatusCodes.Status500InternalServerError, statusResult.StatusCode);
        }

        [Fact]
        public async Task TestAzureMapsTimeout()
        {
            // Arrange
            var request = new
            {
                origin = new { latitude = 51.5074, longitude = -0.1278 },
                destination = new { latitude = 48.8566, longitude = 2.3522 }
            };

            var httpRequest = CreateTestRequest(request);

            mockMapsService.Setup(m => m.GetRouteDistanceAsync(It.IsAny<Coordinate>(), It.IsAny<Coordinate>()))
                .ThrowsAsync(new Exception("Azure Maps request timed out. The service may be experiencing high latency"));

            var function = new DistanceCalculationFunction(mockMapsService.Object, logger);

            // Act
            var result = await function.Run(httpRequest);

            // Assert
            var statusResult = Assert.IsType<StatusCodeResult>(result);
            Assert.Equal(StatusCodes.Status500InternalServerError, statusResult.StatusCode);
        }

        [Fact]
        public async Task TestAzureMapsJsonParsingError()
        {
            // Arrange
            var request = new
            {
                origin = new { latitude = 51.5074, longitude = -0.1278 },
                destination = new { latitude = 48.8566, longitude = 2.3522 }
            };

            var httpRequest = CreateTestRequest(request);

            mockMapsService.Setup(m => m.GetRouteDistanceAsync(It.IsAny<Coordinate>(), It.IsAny<Coordinate>()))
                .ThrowsAsync(new Exception("Failed to parse Azure Maps API response. The response format may have changed"));

            var function = new DistanceCalculationFunction(mockMapsService.Object, logger);

            // Act
            var result = await function.Run(httpRequest);

            // Assert
            var statusResult = Assert.IsType<StatusCodeResult>(result);
            Assert.Equal(StatusCodes.Status500InternalServerError, statusResult.StatusCode);
        }

        [Theory]
        [InlineData("invalid json")]
        [InlineData("{\"invalid\": \"json\"}")]
        [InlineData("{\"origin\": \"not an object\", \"destination\": {\"latitude\": 0, \"longitude\": 0}}")]
        [InlineData("{\"origin\": {\"latitude\": \"not a number\", \"longitude\": 0}, \"destination\": {\"latitude\": 0, \"longitude\": 0}}")]
        public async Task TestMalformedJsonRequests(string jsonRequest)
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
            var result = await function.Run(httpRequest);

            // Assert - Should either return BadRequest or InternalServerError depending on how JSON deserialization fails
            Assert.True(result is BadRequestObjectResult || result is StatusCodeResult, 
                "Result should be BadRequest or StatusCodeResult for malformed requests");
        }
    }
}