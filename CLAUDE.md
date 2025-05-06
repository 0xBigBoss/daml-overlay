# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository provides a Nix flake overlay for DAML (Digital Asset Modeling Language), a platform for building multi-party applications with a strong focus on privacy, security, and integrity. The flake packages the pre-built SDK releases from the official DAML repository.

## Key Commands

### Building and Installation

```bash
# Build the DAML SDK
nix build

# Enter a development shell with DAML available
nix develop

# Install in your profile
nix profile install .#daml-sdk

# Run DAML directly without installing
nix run .#daml-sdk -- <command>
```

### Testing and Verification

```bash
# Verify all hashes in sources.json
./verify-hashes.sh

# Run the comprehensive test script
./test-versions.sh

# Test a specific built package
./result/bin/daml version
```

### Updating DAML Versions

```bash
# Update to the latest version
./update latest

# Update to a specific version
./update 2.8.0
```

### Using DAML (after installation or in dev shell)

```bash
# Check DAML version
daml version

# Create a new project
daml new my-project --template skeleton

# Build a DAML project
daml build

# Run tests
daml test

# Start a local ledger
daml start

# Generate code for different languages
daml codegen js
daml codegen java
```

## Architecture Overview

This repository provides a Nix flake overlay that properly packages the DAML SDK for use in Nix environments. It addresses several key challenges:

1. **Environment Isolation**: DAML typically relies on a global installation and writes to the user's home directory. This packaging redirects all writes to XDG-compliant locations.

2. **Multi-platform Support**: Handles platform-specific binaries for Linux (x86_64, aarch64) and macOS (Intel, Apple Silicon).

3. **Dynamic Linking**: Uses autoPatchelfHook on Linux to properly handle dynamic libraries.

4. **Version Management**: Supports multiple DAML versions with a flexible selection mechanism.

### Key Files

- **flake.nix**: Defines the Nix flake interface, development shells, and outputs
- **default.nix**: Contains the core packaging logic for the DAML SDK
- **sources.json**: Lists available DAML versions with URLs and hashes for each platform
- **update**: Script to fetch new DAML versions and update hashes
- **verify-hashes.sh**: Script to verify the integrity of version hashes
- **test-versions.sh**: Script to test that the package works correctly

### How It Works

The overlay works by:

1. Downloading the official DAML SDK tarball for the specified platform
2. Creating a special directory structure in the Nix store that mimics DAML's expected layout
3. Setting up environment variables and wrapper scripts to redirect user-specific files
4. Enabling proper SDK recognition and preventing modifications to the user's home directory

### Wrapper Scripts

The package creates special wrapper scripts that:
- Set up proper environment variables (DAML_HOME, DAML_SDK_VERSION)
- Direct user data to XDG-compliant locations
- Ensure proper Java runtime configuration

## Adding New Versions

When working with this repository, new DAML versions can be added by:

1. Adding entries to `sources.json` with proper URLs and SHA256 hashes
2. Updating the "latest" entry to point to the newest stable version
3. Validating the changes with `./verify-hashes.sh`

## Common Issues and Solutions

- If Canton sandbox fails with a JAR file access error, ensure the Canton directory is properly included in the directories to copy in `default.nix`
- If DAML commands fail with "SDK Version X.Y.Z is not installed", ensure you're using the correct Nix command or environment variables
- For platform-specific issues, check the dynamic library dependencies in `default.nix`