using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using System.IO;
using System.Text.Json;
using LocationIntelligence.Models;
using LocationIntelligence.Services;

namespace LocationIntelligence
{
    public class DistanceCalculationFunction
    {
        private readonly IAzureMapsService _mapsService;
        private readonly ILogger<DistanceCalculationFunction> _logger;

        public DistanceCalculationFunction(IAzureMapsService mapsService, ILogger<DistanceCalculationFunction> logger)
        {
            _mapsService = mapsService ?? throw new ArgumentNullException(nameof(mapsService));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        [FunctionName("CalculateDistance")]
        public async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req)
        {
            _logger.LogInformation("Processing distance calculation request");

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            var request = JsonSerializer.Deserialize<DistanceRequest>(requestBody, options);

            if (request?.Origin == null || request?.Destination == null)
            {
                return new BadRequestObjectResult("Please provide both origin and destination coordinates");
            }

            // Validate coordinate ranges
            if (!IsValidCoordinate(request.Origin) || !IsValidCoordinate(request.Destination))
            {
                return new BadRequestObjectResult("Coordinates must be within valid ranges: latitude (-90 to 90), longitude (-180 to 180)");
            }

            try
            {
                var distance = await _mapsService.GetRouteDistanceAsync(request.Origin, request.Destination);

                var response = new DistanceResponse
                {
                    DistanceInKilometers = distance,
                    DistanceInMiles = distance * 0.621371
                };

                return new OkObjectResult(response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error calculating distance: {Message}", ex.Message);
                return new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }
        }

        private static bool IsValidCoordinate(Coordinate coordinate)
        {
            if (coordinate == null) return false;

            return coordinate.Latitude >= -90 && coordinate.Latitude <= 90 &&
                   coordinate.Longitude >= -180 && coordinate.Longitude <= 180;
        }
    }
}