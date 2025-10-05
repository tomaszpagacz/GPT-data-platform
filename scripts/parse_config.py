#!/usr/bin/env python3
"""
YAML Configuration Parser for Automated Daily Cleanup Script
"""
import yaml
import sys
import os

def load_config(config_file):
    """Load and parse YAML configuration file"""
    try:
        with open(config_file, 'r') as f:
            return yaml.safe_load(f) or {}
    except Exception as e:
        print(f"Error loading config: {e}", file=sys.stderr)
        return {}

def main():
    if len(sys.argv) != 3:
        print("Usage: parse_config.py <config_file> <key>", file=sys.stderr)
        sys.exit(1)

    config_file = sys.argv[1]
    key = sys.argv[2]

    config = load_config(config_file)

    if key == "enabledEnvironments":
        envs = config.get('enabledEnvironments', 'dev,sit')
        if isinstance(envs, str):
            print(','.join(envs.split(',')))
        elif isinstance(envs, list):
            print(','.join(envs))
        else:
            print('dev,sit')
    elif key == "notificationEmail":
        print(config.get('notificationEmail', ''))
    elif key == "slackWebhook":
        print(config.get('slackWebhook', ''))
    elif key == "dryRun":
        dry_run = config.get('dryRun', False)
        print('true' if dry_run else 'false')
    else:
        print('', file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()