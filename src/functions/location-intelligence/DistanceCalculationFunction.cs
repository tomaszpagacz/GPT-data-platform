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

            if (request?.Origin == null || request?.Destination == null ||
                request?.Origin?.Latitude == 0 || request?.Origin?.Longitude == 0 ||
                request?.Destination?.Latitude == 0 || request?.Destination?.Longitude == 0)
            {
                return new BadRequestObjectResult("Please provide valid coordinates for both origin and destination");
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

        private static double CalculateHaversineDistance(double lat1, double lon1, double lat2, double lon2)
        {
            // Convert latitude and longitude from degrees to radians
            lat1 = ToRad(lat1);
            lon1 = ToRad(lon1);
            lat2 = ToRad(lat2);
            lon2 = ToRad(lon2);

            // Haversine formula
            double dLat = lat2 - lat1;
            double dLon = lon2 - lon1;
            double a = Math.Sin(dLat/2) * Math.Sin(dLat/2) +
                      Math.Cos(lat1) * Math.Cos(lat2) *
                      Math.Sin(dLon/2) * Math.Sin(dLon/2);
            double c = 2 * Math.Asin(Math.Sqrt(a));

            // Earth's radius in kilometers
            const double radius = 6371;
            return radius * c;
        }

        private static double ToRad(double degree)
        {
            return degree * Math.PI / 180;
        }
    }
}