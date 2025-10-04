using System.Text.Json;
using LocationIntelligence.Models;

namespace LocationIntelligence.Tests.Helpers
{
    public static class TestDataLoader
    {
        private static readonly string TestDataPath = Path.GetFullPath(Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory,
            "test-data",
            "distance-test-cases.json"
        ));

        static TestDataLoader()
        {
            Console.WriteLine($"Current directory: {Directory.GetCurrentDirectory()}");
            Console.WriteLine($"Parent directories: {string.Join(" -> ", GetParentDirectories(Directory.GetCurrentDirectory()))}");
            Console.WriteLine($"Test data path: {TestDataPath}");
        }

        private static IEnumerable<string> GetParentDirectories(string path)
        {
            var current = Directory.GetParent(path);
            while (current != null)
            {
                yield return current.FullName;
                current = current.Parent;
            }
        }

        private static TestData? _testData;

        public static TestData LoadTestData()
        {
            if (_testData != null)
            {
                Console.WriteLine($"Using cached test data with {_testData.TestCases.Length} test cases");
                return _testData;
            }

            var path = Path.GetFullPath(TestDataPath);
            Console.WriteLine($"Looking for test data at: {path}");
            
            if (!File.Exists(path))
                throw new FileNotFoundException($"Test data file not found at {path}");

            var jsonContent = File.ReadAllText(path);
            Console.WriteLine($"Read {jsonContent.Length} bytes of JSON data");
            
            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };
            
            _testData = JsonSerializer.Deserialize<TestData>(jsonContent, options) 
                ?? throw new InvalidOperationException("Failed to deserialize test data");
                
            Console.WriteLine($"Loaded {_testData.TestCases.Length} test cases:");
            foreach (var testCase in _testData.TestCases)
            {
                Console.WriteLine($"  - {testCase.Name}");
            }

            return _testData;
        }

        public static TestCase GetTestCaseByName(string name)
        {
            var testData = LoadTestData();
            var testCase = testData.TestCases.FirstOrDefault(tc => string.Equals(tc.Name, name, StringComparison.OrdinalIgnoreCase));
            
            if (testCase == null)
            {
                Console.WriteLine($"Available test cases:");
                foreach (var tc in testData.TestCases)
                {
                    Console.WriteLine($"  - '{tc.Name}' (Length: {tc.Name.Length})");
                }
                throw new ArgumentException($"Test case '{name}' not found");
            }
            
            return testCase;
        }
    }

    public class TestData
    {
        public TestCase[] TestCases { get; set; } = Array.Empty<TestCase>();
        public ApiResponseExamples ApiResponseExamples { get; set; } = new();
    }

    public class TestCase
    {
        public string Name { get; set; } = string.Empty;
        public DistanceRequest Input { get; set; } = new();
        public double ExpectedDistanceKm { get; set; }
        public string Description { get; set; } = string.Empty;
        public AzureMapsRouteResponse? MockResponse { get; set; }
        public bool ExpectedError { get; set; }
        public string[] Tags { get; set; } = Array.Empty<string>();
        public RouteOptions? RouteOptions { get; set; }
    }

    public class ApiResponseExamples
    {
        public AzureMapsRouteResponse? SuccessResponse { get; set; }
        public object? ErrorResponse { get; set; }
    }

    public class RouteOptions
    {
        public string Mode { get; set; } = string.Empty;
        public string[]? Avoid { get; set; }
        public string? ComputeTravelTimeFor { get; set; }
    }
}