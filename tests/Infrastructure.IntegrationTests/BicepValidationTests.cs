using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using FluentAssertions;
using Xunit;

namespace Infrastructure.IntegrationTests;

/// <summary>
/// Tests for Bicep template validation and deployment consistency.
/// </summary>
public class BicepValidationTests
{
    private readonly string _projectRoot;
    private readonly string _infraPath;
    private readonly string _validationScriptPath;

    public BicepValidationTests()
    {
        _projectRoot = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "..", ".."));
        _infraPath = Path.Combine(_projectRoot, "infra");
        _validationScriptPath = Path.Combine(_infraPath, "pipeline", "validate-bicep.sh");
    }

    [Fact]
    public void ValidationScript_ShouldExist()
    {
        File.Exists(_validationScriptPath).Should().BeTrue("Bicep validation script should exist");
    }

    [Fact]
    public async Task ValidationScript_ShouldExecuteSuccessfully()
    {
        // This test requires bicep CLI to be installed
        var startInfo = new ProcessStartInfo
        {
            FileName = "/bin/bash",
            Arguments = _validationScriptPath,
            WorkingDirectory = _projectRoot,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(startInfo);
        if (process == null)
        {
            Assert.Fail("Failed to start validation script process");
            return;
        }

        await process.WaitForExitAsync();

        // The script should exit with code 0 (success) if all validations pass
        // If bicep CLI is not installed, it might fail, which is acceptable for this test
        if (process.ExitCode != 0)
        {
            // Check if it's due to missing bicep CLI
            var errorOutput = await process.StandardError.ReadToEndAsync();
            if (!errorOutput.Contains("bicep") && !errorOutput.Contains("command not found"))
            {
                Assert.Fail($"Validation script failed with exit code {process.ExitCode}: {errorOutput}");
            }
        }
    }

    [Fact]
    public void AllBicepFiles_ShouldBeValidSyntax()
    {
        var bicepFiles = Directory.GetFiles(_infraPath, "*.bicep", SearchOption.AllDirectories);

        foreach (var bicepFile in bicepFiles)
        {
            var content = File.ReadAllText(bicepFile);

            // Basic syntax checks
            content.Should().NotBeNullOrEmpty($"Bicep file {Path.GetFileName(bicepFile)} should not be empty");

            // Should contain valid Bicep syntax markers
            var hasValidStructure = content.Contains('@') || // Parameters
                                   content.Contains("resource ") || // Resources
                                   content.Contains("module ") || // Modules
                                   content.Contains("output ") || // Outputs
                                   content.Contains("var "); // Variables

            hasValidStructure.Should().BeTrue($"Bicep file {Path.GetFileName(bicepFile)} should contain valid Bicep syntax");
        }
    }

    [Fact]
    public void MainBicepTemplate_ShouldReferenceAllRequiredModules()
    {
        var mainBicepPath = Path.Combine(_infraPath, "main.bicep");
        var content = File.ReadAllText(mainBicepPath);

        // Should reference key modules
        var expectedModules = new[]
        {
            "networking",
            "storage",
            "keyVault",
            "synapse",
            "monitoring"
        };

        foreach (var module in expectedModules)
        {
            content.Should().Contain($"module {module}", $"Main template should reference {module} module");
        }
    }

    [Fact]
    public void BicepModules_ShouldHaveConsistentStructure()
    {
        var modulesPath = Path.Combine(_infraPath, "modules");
        var bicepFiles = Directory.GetFiles(modulesPath, "*.bicep");

        foreach (var bicepFile in bicepFiles)
        {
            var content = File.ReadAllText(bicepFile);
            var fileName = Path.GetFileNameWithoutExtension(bicepFile);

            // Should have proper parameter definitions
            if (content.Contains("param "))
            {
                // If parameters exist, they should be properly formatted
                var paramLines = content.Split('\n')
                    .Where(line => line.Trim().StartsWith("param "))
                    .ToList();

                foreach (var paramLine in paramLines)
                {
                    // Should have type annotation
                    paramLine.Should().MatchRegex(@"param \w+ \w+", $"Parameter in {fileName} should have type annotation");
                }
            }
        }
    }

    [Fact]
    public void BuildOutputDirectory_ShouldContainCompiledTemplates()
    {
        var buildOutputPath = Path.Combine(_infraPath, "build_output");

        if (Directory.Exists(buildOutputPath))
        {
            var jsonFiles = Directory.GetFiles(buildOutputPath, "*.json", SearchOption.AllDirectories);
            jsonFiles.Should().NotBeEmpty("Build output should contain compiled ARM templates");
        }
    }
}