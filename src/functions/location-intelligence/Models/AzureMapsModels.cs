using System.Text.Json.Serialization;

namespace LocationIntelligence.Models
{
    public class AzureMapsRouteResponse
    {
        [JsonPropertyName("routes")]
        public Route[] Routes { get; set; }
    }

    public class Route
    {
        [JsonPropertyName("summary")]
        public RouteSummary Summary { get; set; }
    }

    public class RouteSummary
    {
        [JsonPropertyName("lengthInMeters")]
        public double LengthInMeters { get; set; }

        [JsonPropertyName("travelTimeInSeconds")]
        public double TravelTimeInSeconds { get; set; }
    }
}