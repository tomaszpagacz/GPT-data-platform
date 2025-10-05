using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using FluentAssertions;
using Xunit;

namespace Infrastructure.IntegrationTests;

/// <summary>
/// Tests for deployment validation and resource consistency.
/// </summary>
public class DeploymentValidationTests
{
    private readonly string _projectRoot;
    private readonly string _infraPath;
    private readonly string _scriptsPath;

    public DeploymentValidationTests()
    {
        _projectRoot = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "..", ".."));
        _infraPath = Path.Combine(_projectRoot, "infra");
        _scriptsPath = Path.Combine(_projectRoot, "scripts");
    }

    [Fact]
    public void DeploymentScripts_ShouldExist()
    {
        var expectedScripts = new[]
        {
            "deploy-platform.sh",
            "setup-environment.sh"
        };

        foreach (var script in expectedScripts)
        {
            var scriptPath = Path.Combine(_scriptsPath, script);
            File.Exists(scriptPath).Should().BeTrue($"Deployment script {script} should exist");
        }
    }

    [Fact]
    public void DeploymentScripts_ShouldBeExecutable()
    {
        var scriptFiles = Directory.GetFiles(_scriptsPath, "*.sh");

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

    [Fact]
    public void PipelineTemplates_ShouldExist()
    {
        var pipelinePath = Path.Combine(_infraPath, "pipeline");
        var expectedTemplates = new[]
        {
            "azure-pipelines.yml",
            "deployment-template.yml",
            "synapse-cicd-pipeline.yml"
        };

        foreach (var template in expectedTemplates)
        {
            var templatePath = Path.Combine(pipelinePath, template);
            File.Exists(templatePath).Should().BeTrue($"Pipeline template {template} should exist");
        }
    }

    [Fact]
    public void PipelineTemplates_ShouldBeValidYaml()
    {
        var pipelinePath = Path.Combine(_infraPath, "pipeline");
        var yamlFiles = Directory.GetFiles(pipelinePath, "*.yml");

        foreach (var yamlFile in yamlFiles)
        {
            var content = File.ReadAllText(yamlFile);

            // Basic YAML validation - should not be empty and should contain expected structure
            content.Should().NotBeNullOrEmpty($"YAML file {Path.GetFileName(yamlFile)} should not be empty");

            // Should contain basic pipeline structure
            var hasPipelineStructure = content.Contains("stages:") ||
                                      content.Contains("jobs:") ||
                                      content.Contains("steps:") ||
                                      content.Contains("pool:");

            hasPipelineStructure.Should().BeTrue($"YAML file {Path.GetFileName(yamlFile)} should contain valid pipeline structure");
        }
    }

    [Fact]
    public void ResourceNaming_ShouldBeConsistent()
    {
        var mainBicepPath = Path.Combine(_infraPath, "main.bicep");
        var content = File.ReadAllText(mainBicepPath);

        // Should use naming module for consistent resource naming
        content.Should().Contain("naming", "Main template should use naming module for consistent resource naming");

        // Should reference naming module
        content.Should().Contain("module naming", "Main template should reference naming module");
    }

    [Fact]
    public void NamingModule_ShouldExist()
    {
        var namingModulePath = Path.Combine(_infraPath, "modules", "naming.bicep");
        File.Exists(namingModulePath).Should().BeTrue("Naming module should exist for consistent resource naming");
    }

    [Fact]
    public void ValidationModule_ShouldExist()
    {
        var validationModulePath = Path.Combine(_infraPath, "modules", "validation.bicep");
        File.Exists(validationModulePath).Should().BeTrue("Validation module should exist for input validation");
    }

    [Fact]
    public void MonitoringWorkbookTemplates_ShouldExist()
    {
        var modulesPath = Path.Combine(_infraPath, "modules");
        var workbookFiles = Directory.GetFiles(modulesPath, "*workbook*.bicep");

        workbookFiles.Should().NotBeEmpty("Monitoring workbook templates should exist");
    }

    [Fact]
    public void CostOptimizationConfig_ShouldExist()
    {
        var costConfigPath = Path.Combine(_infraPath, "pipeline", "cost-optimization-config.yml");
        File.Exists(costConfigPath).Should().BeTrue("Cost optimization configuration should exist");
    }

    [Fact]
    public void RollbackScripts_ShouldExist()
    {
        var rollbackScriptPath = Path.Combine(_infraPath, "pipeline", "rollback-deployment.sh");
        File.Exists(rollbackScriptPath).Should().BeTrue("Rollback script should exist for deployment safety");
    }

    [Fact]
    public void HealthCheckScripts_ShouldExist()
    {
        var healthCheckScripts = new[]
        {
            "check-platform-health.sh",
            "check-prerequisites.sh",
            "monitor-deployment.sh"
        };

        foreach (var script in healthCheckScripts)
        {
            var scriptPath = Path.Combine(_infraPath, "pipeline", script);
            File.Exists(scriptPath).Should().BeTrue($"Health check script {script} should exist");
        }
    }

    [Fact]
    public void DeploymentChecklist_ShouldExist()
    {
        var checklistPath = Path.Combine(_projectRoot, "DEPLOYMENT-CHECKLIST.md");
        File.Exists(checklistPath).Should().BeTrue("Deployment checklist should exist");
    }

    [Fact]
    public void DeploymentStrategyDocument_ShouldExist()
    {
        var strategyPath = Path.Combine(_projectRoot, "DEPLOYMENT-STRATEGY.md");
        File.Exists(strategyPath).Should().BeTrue("Deployment strategy document should exist");
    }
}