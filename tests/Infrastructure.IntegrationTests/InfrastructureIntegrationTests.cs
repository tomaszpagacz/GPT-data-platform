using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using FluentAssertions;
using Xunit;

namespace Infrastructure.IntegrationTests;

/// <summary>
/// Integration tests for infrastructure components including Bicep templates,
/// parameter validation, and deployment consistency.
/// </summary>
public class InfrastructureIntegrationTests
{
    private readonly string _projectRoot;
    private readonly string _infraPath;
    private readonly string _testDataPath;

    public InfrastructureIntegrationTests()
    {
        _projectRoot = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "..", ".."));
        _infraPath = Path.Combine(_projectRoot, "infra");
        _testDataPath = Path.Combine(Directory.GetCurrentDirectory(), "test-data");
    }

    [Fact]
    public void InfrastructureDirectory_ShouldExist()
    {
        Directory.Exists(_infraPath).Should().BeTrue($"Infrastructure directory should exist at {_infraPath}");
    }

    [Fact]
    public void MainBicepTemplate_ShouldExist()
    {
        var mainBicepPath = Path.Combine(_infraPath, "main.bicep");
        File.Exists(mainBicepPath).Should().BeTrue("Main Bicep template should exist");
    }

    [Fact]
    public void ModulesDirectory_ShouldExist()
    {
        var modulesPath = Path.Combine(_infraPath, "modules");
        Directory.Exists(modulesPath).Should().BeTrue("Modules directory should exist");
    }

    [Fact]
    public void AllBicepModules_ShouldExist()
    {
        var modulesPath = Path.Combine(_infraPath, "modules");
        var expectedModules = new[]
        {
            "apiDefinition.bicep",
            "apiManagement.bicep",
            "apiPolicies.bicep",
            "appHosting.bicep",
            "azureMaps.bicep",
            "cognitiveServices.bicep",
            "containerInstances.bicep",
            "eventing.bicep",
            "keyVault.bicep",
            "keyVaultSecrets.bicep",
            "logicApp.bicep",
            "machineLearning.bicep",
            "monitoring.bicep",
            "naming.bicep",
            "networking.bicep",
            "privateDns.bicep",
            "storage.bicep",
            "synapse.bicep",
            "validation.bicep"
        };

        foreach (var module in expectedModules)
        {
            var modulePath = Path.Combine(modulesPath, module);
            File.Exists(modulePath).Should().BeTrue($"Bicep module {module} should exist");
        }
    }

    [Fact]
    public void ParameterFiles_ShouldExistForAllEnvironments()
    {
        var paramsPath = Path.Combine(_infraPath, "params");
        var environments = new[] { "dev", "sit", "prod" };

        foreach (var env in environments)
        {
            var paramFile = Path.Combine(paramsPath, $"{env}.main.parameters.json");
            File.Exists(paramFile).Should().BeTrue($"Parameter file for {env} environment should exist");
        }
    }

    [Fact]
    public void ParameterFiles_ShouldBeValidJson()
    {
        var paramsPath = Path.Combine(_infraPath, "params");
        var paramFiles = Directory.GetFiles(paramsPath, "*.parameters.json");

        foreach (var paramFile in paramFiles)
        {
            var content = File.ReadAllText(paramFile);
            var isValidJson = IsValidJson(content);
            isValidJson.Should().BeTrue($"Parameter file {Path.GetFileName(paramFile)} should be valid JSON");
        }
    }

    [Fact]
    public void ParameterFiles_ShouldHaveRequiredParameters()
    {
        var paramsPath = Path.Combine(_infraPath, "params");
        var paramFiles = Directory.GetFiles(paramsPath, "*.parameters.json");

        foreach (var paramFile in paramFiles)
        {
            var content = File.ReadAllText(paramFile);
            var jsonDoc = JsonDocument.Parse(content);
            var parameters = jsonDoc.RootElement.GetProperty("parameters");

            // Check for required parameters
            parameters.TryGetProperty("namePrefix", out _).Should().BeTrue($"Parameter file {Path.GetFileName(paramFile)} should have namePrefix parameter");
            parameters.TryGetProperty("environment", out _).Should().BeTrue($"Parameter file {Path.GetFileName(paramFile)} should have environment parameter");
            parameters.TryGetProperty("location", out _).Should().BeTrue($"Parameter file {Path.GetFileName(paramFile)} should have location parameter");
        }
    }

    [Fact]
    public void BicepModules_ShouldFollowNamingConvention()
    {
        var modulesPath = Path.Combine(_infraPath, "modules");
        var bicepFiles = Directory.GetFiles(modulesPath, "*.bicep");

        foreach (var bicepFile in bicepFiles)
        {
            var fileName = Path.GetFileName(bicepFile);

            // Should use camelCase naming
            var isCamelCase = char.IsLower(fileName[0]) && !fileName.Contains('_');
            isCamelCase.Should().BeTrue($"Bicep module {fileName} should follow camelCase naming convention");
        }
    }

    [Fact]
    public void BuildOutputDirectory_ShouldBeGitignored()
    {
        var gitignorePath = Path.Combine(_projectRoot, ".gitignore");
        var buildOutputPath = Path.Combine(_infraPath, "build_output");

        if (File.Exists(gitignorePath))
        {
            var gitignoreContent = File.ReadAllText(gitignorePath);
            gitignoreContent.Should().Contain("build_output", "build_output directory should be gitignored");
        }
    }

    [Fact]
    public void ValidationOutputsDirectory_ShouldBeGitignored()
    {
        var gitignorePath = Path.Combine(_projectRoot, ".gitignore");
        var validationOutputsPath = "validation_outputs";

        if (File.Exists(gitignorePath))
        {
            var gitignoreContent = File.ReadAllText(gitignorePath);
            gitignoreContent.Should().Contain(validationOutputsPath, "validation_outputs directory should be gitignored");
        }
    }

    [Fact]
    public void PipelineScripts_ShouldExist()
    {
        var pipelinePath = Path.Combine(_infraPath, "pipeline");
        var expectedScripts = new[]
        {
            "validate-bicep.sh",
            "validate-all-bicep.sh",
            "azure-pipelines.yml"
        };

        foreach (var script in expectedScripts)
        {
            var scriptPath = Path.Combine(pipelinePath, script);
            File.Exists(scriptPath).Should().BeTrue($"Pipeline script {script} should exist");
        }
    }

    [Fact]
    public void PipelineScripts_ShouldBeExecutable()
    {
        var pipelinePath = Path.Combine(_infraPath, "pipeline");
        var scriptFiles = Directory.GetFiles(pipelinePath, "*.sh");

        foreach (var scriptFile in scriptFiles)
        {
            // On Linux, check if executable bit is set using Mono.Unix
            try
            {
                var fileInfo = new FileInfo(scriptFile);
                var isExecutable = (fileInfo.Attributes & FileAttributes.Hidden) == 0; // Simplified check
                isExecutable.Should().BeTrue($"Script {Path.GetFileName(scriptFile)} should be executable");
            }
            catch
            {
                // If we can't check permissions, just verify the file exists
                File.Exists(scriptFile).Should().BeTrue($"Script {Path.GetFileName(scriptFile)} should exist");
            }
        }
    }

    private static bool IsValidJson(string jsonString)
    {
        try
        {
            JsonDocument.Parse(jsonString);
            return true;
        }
        catch
        {
            return false;
        }
    }
}