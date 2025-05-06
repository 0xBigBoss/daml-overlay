# DAML Nix Flake Overlay

This repository provides a Nix flake overlay for [DAML](https://www.digitalasset.com/daml), a platform for building multi-party applications with a strong focus on privacy, security, and integrity. The flake packages the pre-built SDK releases from the official DAML repository.

## Features

- Packages DAML SDK with runtime and tools
- Downloads pre-built binaries directly from official releases
- Works on multiple platforms: Linux (x86_64, aarch64) and macOS (Intel/Apple Silicon)
- Properly handles dynamic linking and dependencies
- Provides a convenient development shell with DAML pre-configured
- Support for Canton network integration
- **No modification of HOME directory** - all user data is stored in XDG-compliant locations
- Proper installation recognition - the DAML SDK recognizes itself as installed without manual steps

## Usage

### As a Flake (Recommended)

In your `flake.nix` file:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    daml-overlay.url = "github:0xbigboss/daml-overlay";
  };

  outputs = { self, nixpkgs, daml-overlay, ... }:
    let
      system = "x86_64-linux"; # or x86_64-darwin, aarch64-darwin, aarch64-linux
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ daml-overlay.overlays.default ];
      };
    in {
      # Use DAML in your packages
      packages.default = pkgs.mkShell {
        buildInputs = [
          pkgs.daml-sdk
        ];
      };
    };
}
```

### Command Line Usage

```sh
# Install and run daml (latest version)
$ nix run github:0xbigboss/daml-overlay#daml-sdk

# Open a shell with DAML available
$ nix develop github:0xbigboss/daml-overlay

# Build DAML
$ nix build github:0xbigboss/daml-overlay#daml-sdk

# Use DAML within your shell
$ nix shell github:0xbigboss/daml-overlay#daml-sdk
```

### Non-Flake Usage (Legacy Nix)

If you're not using flakes, you can still use this package through the `default.nix` compatibility layer:

```nix
let
  damlOverlay = import (fetchTarball "https://github.com/0xbigboss/daml-overlay/archive/main.tar.gz");
  pkgs = import <nixpkgs> { overlays = [ damlOverlay ]; };
in pkgs.mkShell {
  buildInputs = [ pkgs.daml-sdk ];
}
```

## Available Packages and Outputs

The flake provides the following outputs:

- `packages.<s>.daml-sdk`: The DAML SDK with runtime and tools
- `packages.<s>.canton`: The Canton synchronization service (when available)
- `packages.<s>.default`: Same as `daml-sdk`

- `apps.<s>.daml`: Run the `daml` command
- `apps.<s>.canton`: Run the `canton` command
- `apps.<s>.default`: Run the `daml` command

- `devShells.<s>.default`: A development shell with DAML SDK
- `devShells.<s>.canton`: A development shell with DAML SDK and Canton

- `overlays.default`: An overlay that adds DAML packages to nixpkgs

## Templates

This flake provides the following templates:

### DAML Template

A basic DAML project template for application development:

```sh
# Create a new project using the DAML template
$ mkdir my-daml-project
$ cd my-daml-project
$ nix flake init -t github:0xbigboss/daml-overlay#init
```

The template includes:
- Nix configuration with DAML SDK available
- Direnv integration for automatic environment loading
- Basic project structure

After initializing the template:

```sh
# Enter the development environment
$ nix develop

# Create a new DAML project
$ daml new my-project --template quickstart
```

## Updating to New Versions

### Automatic Updates

The flake includes an update script to fetch the latest DAML versions and update all hashes:

```sh
# Update to the latest version
$ ./update latest

# Update to a specific version
$ ./update 2.8.0
```

### Manual Updates

You can also manually update the flake to use new DAML versions by:

1. Updating the SHA256 hashes in `sources.json` for each platform
2. Updating the version information

### Verifying Hashes and Signatures

This package includes tools to verify both the SHA256 hashes and GPG signatures of DAML SDK downloads:

```sh
# Import Digital Asset's GPG key (if not already imported)
$ ./import-gpg-key.sh

# Verify hashes and signatures across all platforms
$ ./verify-hashes.sh

# Verify a specific version
$ ./verify-hashes.sh 2.10.0
```

The verification process ensures that:
1. The SHA256 hashes in `sources.json` match the actual downloads
2. The GPG signatures from Digital Asset are valid
3. The downloads haven't been tampered with

## Version Selection

This flake supports multiple DAML versions:

### Latest Releases

By default, the flake uses the "latest" release. This is the recommended version for most users.

### Specific Versions

You can pin to specific versions by adding them to `sources.json` and then selecting them:

```sh
# Using environment variable with nix-build (legacy)
$ DAML_VERSION=2.8.0 nix-build

# Using environment variable with flakes (requires --impure flag)
$ DAML_VERSION=2.8.0 nix develop --impure
$ DAML_VERSION=2.8.0 nix build --impure .#daml-sdk

# Using command-line argument with nix-build (legacy)
$ nix-build --argstr damlVersion 2.8.0
```

### Version Selection Precedence

The version selection follows this precedence:
1. Command-line argument (when using `nix-build --argstr damlVersion "version"`)
2. Environment variable `DAML_VERSION`
3. Default to "latest" if neither is specified

## Development

### Testing the Flake

To test that the flake is working correctly:

```sh
# Run the comprehensive test script
$ ./test-versions.sh

# Or run individual tests:

# Check the flake structure
$ nix flake check

# Build the DAML package
$ nix build .#daml-sdk

# Test the binary
$ ./result/bin/daml version

# Create a new DAML project
$ ./result/bin/daml new test-project --template skeleton

# Test the Canton sandbox
$ nix develop
$ daml sandbox  # Should start successfully

# Test the development shell
$ nix develop
$ daml version
$ daml new test-project
```

### Troubleshooting

#### Canton Sandbox Issues

If you encounter an error like this when running `daml sandbox`:

```
Error: Unable to access jarfile /nix/store/xxx-daml-sdk-x.x.x/share/daml-sdk/.daml/sdk/x.x.x/canton/canton.jar
```

This indicates that the Canton directory is not being properly copied to the SDK directory. The fix is to ensure that the `canton` directory is included in the list of directories to copy in the `default.nix` file.

### Platform Compatibility

The flake is designed to work on all supported platforms:

- **Linux (x86_64)**: Includes proper dynamic linking support for NixOS and other Linux distributions using required runtime dependencies.
- **Linux (aarch64)**: Supports ARM64 Linux systems.
- **macOS (Intel/Apple Silicon)**: Works with native macOS binaries.

If you encounter any platform-specific issues, please report them in the GitHub issues.

### Technical Architecture

This overlay uses several key techniques to make DAML work well within Nix:

1. **Custom Directory Structure**: Creates a `.daml` directory within the Nix store package, making the SDK self-contained
2. **Wrapper Scripts**: Uses custom wrapper scripts that redirect writes to XDG-compliant locations
3. **Environment Variable Configuration**: Sets `DAML_HOME`, `DAML_SDK_VERSION`, and other variables properly
4. **Dynamic Linking Support**: Handles platform-specific library dependencies

For complete details on how the overlay works, see the [DOCUMENTATION.md](./DOCUMENTATION.md) file.

## License

This flake is released under the MIT License. DAML itself is developed by [Digital Asset](https://github.com/digital-asset/daml) and is released under its own license.