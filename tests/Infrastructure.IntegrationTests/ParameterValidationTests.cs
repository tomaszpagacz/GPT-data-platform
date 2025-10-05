using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using FluentAssertions;
using Xunit;

namespace Infrastructure.IntegrationTests;

/// <summary>
/// Tests for parameter file validation and consistency.
/// </summary>
public class ParameterValidationTests
{
    private readonly string _projectRoot;
    private readonly string _paramsPath;
    private readonly string _testDataPath;

    public ParameterValidationTests()
    {
        _projectRoot = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "..", ".."));
        _paramsPath = Path.Combine(_projectRoot, "infra", "params");
        _testDataPath = Path.Combine(Directory.GetCurrentDirectory(), "test-data");
    }

    [Fact]
    public void ParameterFiles_ShouldHaveConsistentStructure()
    {
        var paramFiles = Directory.GetFiles(_paramsPath, "*.parameters.json");

        foreach (var paramFile in paramFiles)
        {
            var content = File.ReadAllText(paramFile);
            var jsonDoc = JsonDocument.Parse(content);

            // Should have parameters object
            jsonDoc.RootElement.TryGetProperty("parameters", out var parameters).Should().BeTrue(
                $"Parameter file {Path.GetFileName(paramFile)} should have parameters object");

            // Should have $schema
            jsonDoc.RootElement.TryGetProperty("$schema", out var schema).Should().BeTrue(
                $"Parameter file {Path.GetFileName(paramFile)} should have $schema property");
        }
    }

    [Fact]
    public void EnvironmentParameterFiles_ShouldHaveCorrectEnvironmentValues()
    {
        var environments = new[] { "dev", "sit", "prod" };

        foreach (var env in environments)
        {
            var paramFile = Path.Combine(_paramsPath, $"{env}.main.parameters.json");
            if (File.Exists(paramFile))
            {
                var content = File.ReadAllText(paramFile);
                var jsonDoc = JsonDocument.Parse(content);

                var environmentParam = jsonDoc.RootElement
                    .GetProperty("parameters")
                    .GetProperty("environment")
                    .GetProperty("value");

                environmentParam.GetString().Should().Be(env,
                    $"Environment parameter in {env}.main.parameters.json should be '{env}'");
            }
        }
    }

    [Fact]
    public void ParameterFiles_ShouldHaveValidLocations()
    {
        var paramFiles = Directory.GetFiles(_paramsPath, "*.parameters.json");
        var validLocations = new[] { "switzerlandnorth", "switzerlandwest", "global" };

        foreach (var paramFile in paramFiles)
        {
            var content = File.ReadAllText(paramFile);
            var jsonDoc = JsonDocument.Parse(content);

            var parameters = jsonDoc.RootElement.GetProperty("parameters");

            if (parameters.TryGetProperty("location", out var locationParam))
            {
                var location = locationParam.GetProperty("value").GetString();
                validLocations.Should().Contain(location,
                    $"Location '{location}' in {Path.GetFileName(paramFile)} should be a valid Azure region");
            }
        }
    }

    [Fact]
    public void NamePrefix_ShouldFollowNamingConvention()
    {
        var paramFiles = Directory.GetFiles(_paramsPath, "*.parameters.json");

        foreach (var paramFile in paramFiles)
        {
            var content = File.ReadAllText(paramFile);
            var jsonDoc = JsonDocument.Parse(content);

            var parameters = jsonDoc.RootElement.GetProperty("parameters");

            if (parameters.TryGetProperty("namePrefix", out var namePrefixParam))
            {
                var namePrefix = namePrefixParam.GetProperty("value").GetString();

                // Should be 3-11 characters, lowercase alphanumeric
                namePrefix.Should().MatchRegex("^[a-z0-9]{3,11}$",
                    $"Name prefix '{namePrefix}' in {Path.GetFileName(paramFile)} should be 3-11 lowercase alphanumeric characters");
            }
        }
    }

    [Fact]
    public void SubnetAddressPrefixes_ShouldBeValidCIDRs()
    {
        var paramFiles = Directory.GetFiles(_paramsPath, "*.parameters.json");

        foreach (var paramFile in paramFiles)
        {
            var content = File.ReadAllText(paramFile);
            var jsonDoc = JsonDocument.Parse(content);

            var parameters = jsonDoc.RootElement.GetProperty("parameters");

            if (parameters.TryGetProperty("subnetAddressPrefixes", out var subnetsParam))
            {
                var subnets = subnetsParam.GetProperty("value");

                foreach (var subnetProperty in subnets.EnumerateObject())
                {
                    var cidr = subnetProperty.Value.GetString();
                    if (!string.IsNullOrEmpty(cidr))
                    {
                        IsValidCidr(cidr).Should().BeTrue(
                            $"CIDR '{cidr}' for subnet '{subnetProperty.Name}' in {Path.GetFileName(paramFile)} should be valid");
                    }
                }
            }
        }
    }

    [Fact]
    public void VnetAddressSpace_ShouldBeValidCIDR()
    {
        var paramFiles = Directory.GetFiles(_paramsPath, "*.parameters.json");

        foreach (var paramFile in paramFiles)
        {
            var content = File.ReadAllText(paramFile);
            var jsonDoc = JsonDocument.Parse(content);

            var parameters = jsonDoc.RootElement.GetProperty("parameters");

            if (parameters.TryGetProperty("vnetAddressSpace", out var vnetParam))
            {
                var cidr = vnetParam.GetProperty("value").GetString();
                if (!string.IsNullOrEmpty(cidr))
                {
                    IsValidCidr(cidr).Should().BeTrue(
                        $"VNet CIDR '{cidr}' in {Path.GetFileName(paramFile)} should be valid");
                }
            }
        }
    }

    [Fact]
    public void Tags_ShouldBeConsistentAcrossEnvironments()
    {
        var paramFiles = Directory.GetFiles(_paramsPath, "*.parameters.json");
        var tagSets = new Dictionary<string, JsonElement>();

        foreach (var paramFile in paramFiles)
        {
            var content = File.ReadAllText(paramFile);
            var jsonDoc = JsonDocument.Parse(content);

            var parameters = jsonDoc.RootElement.GetProperty("parameters");

            if (parameters.TryGetProperty("tags", out var tagsParam))
            {
                var tags = tagsParam.GetProperty("value");
                var env = Path.GetFileNameWithoutExtension(paramFile).Split('.')[0];
                tagSets[env] = tags.Clone();
            }
        }

        // All environments should have project tag
        foreach (var kvp in tagSets)
        {
            kvp.Value.TryGetProperty("project", out var projectTag).Should().BeTrue(
                $"Environment {kvp.Key} should have project tag");

            projectTag.GetString().Should().Be("gpt-data-platform",
                $"Project tag in environment {kvp.Key} should be 'gpt-data-platform'");
        }
    }

    private static bool IsValidCidr(string cidr)
    {
        if (string.IsNullOrEmpty(cidr)) return false;

        var parts = cidr.Split('/');
        if (parts.Length != 2) return false;

        if (!int.TryParse(parts[1], out var prefixLength)) return false;
        if (prefixLength < 0 || prefixLength > 32) return false;

        var ipParts = parts[0].Split('.');
        if (ipParts.Length != 4) return false;

        foreach (var ipPart in ipParts)
        {
            if (!int.TryParse(ipPart, out var octet)) return false;
            if (octet < 0 || octet > 255) return false;
        }

        return true;
    }
}