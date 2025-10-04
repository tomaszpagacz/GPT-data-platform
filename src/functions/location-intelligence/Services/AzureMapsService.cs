using System;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using LocationIntelligence.Models;

namespace LocationIntelligence.Services
{
    public interface IAzureMapsService
    {
        Task<double> GetRouteDistanceAsync(Coordinate origin, Coordinate destination);
    }

    public class AzureMapsService : IAzureMapsService
    {
        private readonly HttpClient _httpClient;
        private readonly string _mapsEndpoint;
        private readonly string _mapsKey;

        public AzureMapsService(IConfiguration configuration, HttpClient httpClient)
        {
            _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
            _mapsEndpoint = configuration["AzureMapsEndpoint"] ?? throw new ArgumentNullException("AzureMapsEndpoint configuration is missing");
            _mapsKey = configuration["AzureMapsKey"] ?? throw new ArgumentNullException("AzureMapsKey configuration is missing");
            
            // Ensure endpoint doesn't end with a slash
            _mapsEndpoint = _mapsEndpoint.TrimEnd('/');
        }

        public async Task<double> GetRouteDistanceAsync(Coordinate origin, Coordinate destination)
        {
            var query = HttpUtility.ParseQueryString(string.Empty);
            query["subscription-key"] = _mapsKey;
            query["api-version"] = "1.0";
            query["query"] = $"{origin.Latitude},{origin.Longitude}:{destination.Latitude},{destination.Longitude}";
            
            var requestUrl = $"{_mapsEndpoint}/route/directions/json?{query}";
            
            try
            {
                var response = await _httpClient.GetAsync(requestUrl);
                response.EnsureSuccessStatusCode();
                
                var content = await response.Content.ReadAsStringAsync();
                var routeResponse = JsonSerializer.Deserialize<AzureMapsRouteResponse>(content);
                
                if (routeResponse?.Routes == null || routeResponse.Routes.Length == 0)
                {
                    throw new Exception("No route found between the specified coordinates");
                }

                // Azure Maps returns distance in meters, convert to kilometers
                return routeResponse.Routes[0].Summary.LengthInMeters / 1000.0;
            }
            catch (HttpRequestException ex)
            {
                if (ex.StatusCode == System.Net.HttpStatusCode.BadRequest)
                {
                    throw new Exception("Invalid coordinates provided", ex);
                }
                throw;
            }
        }
    }
}