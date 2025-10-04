# Helpers Directory

This directory contains various helper scripts and test data for the GPT-data-platform project. These resources are designed to make development, testing, and deployment easier across different environments.

## Directory Structure

```
helpers/
├── setup-scripts/      # Scripts for environment setup and testing
│   ├── setup-dev-environment.sh     # Sets up development environment
│   ├── test-distance-function.sh    # Tests the distance calculation function
│   └── check-workspace-details.sh   # Verifies workspace environment setup
└── test-data/         # Test data files for various functions
    └── distance-test-cases.json     # Test cases for distance calculation
```

## Setup Scripts

### setup-dev-environment.sh

This script sets up a development environment with all necessary tools and dependencies:

- .NET SDK 6.0
- Azure Functions Core Tools
- Bicep CLI
- Azure CLI

Usage:
```bash
cd helpers/setup-scripts
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