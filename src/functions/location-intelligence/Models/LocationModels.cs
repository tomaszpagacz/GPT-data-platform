using System;

namespace LocationIntelligence.Models
{
    public class Coordinate
    {
        public double Latitude { get; set; }
        public double Longitude { get; set; }
    }

    public class DistanceRequest
    {
        public Coordinate Origin { get; set; }
        public Coordinate Destination { get; set; }
    }

    public class DistanceResponse
    {
        public double DistanceInKilometers { get; set; }
        public double DistanceInMiles { get; set; }
    }
}