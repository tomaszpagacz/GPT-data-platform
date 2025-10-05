# Helpers Directory

This directory contains unified helper scripts and test data for the GPT-data-platform project. These resources are designed to make development, testing, and deployment easier across different environments.

## Directory Structure

```
helpers/
├── setup-scripts/      # Consolidated scripts for environment setup and testing
│   ├── unified-setup.sh              # Master environment setup script (replaces multiple setup scripts)
│   ├── unified-test-functions.sh     # Comprehensive Functions & Logic Apps testing
│   ├── check-workspace-details.sh    # Verifies workspace environment setup
│   └── [legacy scripts]              # Original scripts (for reference, can be removed)
└── test-data/         # Test data files for various functions
    └── distance-test-cases.json     # Test cases for distance calculation
```

## Unified Scripts

### unified-setup.sh

**Replaces**: `setup-dev-environment.sh`, `install-dependencies.sh`, `setup-local-environment.sh`

This master script provides comprehensive environment setup with multiple options:

- **Full Setup**: Complete environment with all tools (.NET 8, Azure CLI, Functions Core Tools, Bicep, VS Code extensions)
- **Development Only**: Minimal setup for development without Azure CLI
- **Environment Check**: Validate current environment without installing anything
- **Selective Updates**: Update specific components (e.g., .NET version)

Usage:
```bash
cd helpers/setup-scripts

# Complete setup for new environment
./unified-setup.sh --full

# Development-only setup (no Azure CLI)
./unified-setup.sh --dev-only

# Check current environment
./unified-setup.sh --check

# Update .NET to version 8.0
./unified-setup.sh --update-dotnet

# Show all options
./unified-setup.sh --help
```

**Key Features**:
- .NET 8.0 SDK installation and validation
- Azure Functions Core Tools v4
- Azure CLI and Bicep CLI
- Node.js 18+ and npm
- VS Code extension management
- Project dependency validation
- Color-coded output and progress indication

### unified-test-functions.sh

**Replaces**: `test-functions-local.sh`, `test-functions-local-v2.sh`

Comprehensive local testing for Azure Functions and Logic Apps:

Usage:
```bash
# Run with default settings
./unified-test-functions.sh

# Verbose output with detailed logging
./unified-test-functions.sh --verbose

# Test only the distance function
./unified-test-functions.sh --test-distance

# Use specific ports
./unified-test-functions.sh --functions-port 8080 --logic-apps-port 8081

# Check dependencies only
./unified-test-functions.sh --check-deps

# Show all options
./unified-test-functions.sh --help
```

**Key Features**:
- Automatic port detection and management
- Comprehensive dependency checking
- Distance function testing with test cases
- Multiple function app support
- Graceful cleanup on exit
- Logic Apps preparation (extensible)
- Real-time health monitoring

### check-workspace-details.sh

Validates the workspace environment and reports on:
- Platform health status including Microsoft Fabric
- .NET 8 runtime validation
- Azure service connectivity
- Function app configuration
- Modern platform component verification

## Migration from Legacy Scripts

The following legacy scripts are **replaced** by the unified versions:

| Legacy Script | Replaced By | Notes |
|---------------|-------------|--------|
| `setup-dev-environment.sh` | `unified-setup.sh --dev-only` | Basic development setup |
| `install-dependencies.sh` | `unified-setup.sh --full` | Complete dependency installation |
| `setup-local-environment.sh` | `unified-setup.sh --check` + setup | Environment validation and setup |
| `test-functions-local.sh` | `unified-test-functions.sh` | Enhanced with better port management |
| `test-functions-local-v2.sh` | `unified-test-functions.sh` | Includes all v2 improvements |

## Test Data

### distance-test-cases.json

Test cases for validating the distance calculation function with various geographic scenarios:
- Short distances (same city)
- Medium distances (between cities)
- Long distances (international)
- Edge cases (antimeridian, polar regions)

## Quick Start

For new developers setting up the environment:

```bash
# 1. Full environment setup
./helpers/setup-scripts/unified-setup.sh --full

# 2. Verify installation
./helpers/setup-scripts/unified-setup.sh --check

# 3. Test Functions locally
./helpers/setup-scripts/unified-test-functions.sh --verbose

# 4. Check platform health
./helpers/setup-scripts/check-workspace-details.sh
```

## Troubleshooting

Common issues and solutions:

1. **Port conflicts**: Use `--functions-port` and `--logic-apps-port` options
2. **.NET version issues**: Run `./unified-setup.sh --update-dotnet`
3. **Missing dependencies**: Run `./unified-setup.sh --check` to identify gaps
4. **Permission errors**: Some installations may require `sudo` privileges

For additional help, run any script with `--help` option.
chmod +x setup-dev-environment.sh
./setup-dev-environment.sh
```

### test-distance-function.sh

This script tests the Distance Calculation Function using predefined test cases:

- Reads test cases from `test-data/distance-test-cases.json`
- Makes HTTP requests to the locally running function
- Displays results for each test case

Usage:
```bash
# First, start the function app
cd src/functions/location-intelligence
func start

# Then, in another terminal:
cd helpers/setup-scripts
chmod +x test-distance-function.sh
./test-distance-function.sh
```

## Test Data

### distance-test-cases.json

Contains test cases for the Distance Calculation Function:
- NYC to LA
- London to Paris
- Sydney to Tokyo

Each test case includes:
- Input coordinates (origin and destination)
- Expected distance
- Description

### check-workspace-details.sh

This script performs comprehensive checks of the development environment:

- Verifies GitHub Codespace environment
- Checks .NET SDK and required packages
- Validates Azure Functions Core Tools
- Confirms project structure and references
- Checks local settings and configurations

Usage:
```bash
cd helpers/setup-scripts
chmod +x check-workspace-details.sh
./check-workspace-details.sh
```

The script provides color-coded output to easily identify:
- ✓ (Green): Passed checks
- ✗ (Red): Failed or missing components
- Detailed version and configuration information

## Adding New Helpers

When adding new helper scripts or test data:

1. Place scripts in appropriate subdirectory
2. Update this README with usage instructions
3. Ensure scripts are executable (`chmod +x`)
4. Add any new test data in appropriate format
5. Document dependencies and requirements