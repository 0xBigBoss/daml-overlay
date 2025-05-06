# Using DAML with Nix

This guide explains how to use the DAML SDK installed via Nix.

## Getting Started

### Installing the DAML SDK

There are several ways to use the DAML SDK provided by this overlay:

#### Option 1: Use the binary directly

```bash
# Build the DAML SDK
nix build

# Run DAML commands using the full path
./result/bin/daml version
./result/bin/daml new my-project
```

#### Option 2: Development shell

```bash
# Enter a shell with DAML in the PATH
nix develop

# Now you can use DAML commands directly
daml version
daml new my-project
```

#### Option 3: Install in your profile

```bash
# Install DAML in your Nix profile
nix profile install .#daml-sdk

# Now you can use DAML commands directly
daml version
daml new my-project
```

### Creating a New DAML Project

```bash
# Create a new project using a template
daml new my-project --template skeleton

# Change to the project directory
cd my-project

# Build the project
daml build

# Run the tests
daml test

# Start a local development ledger
daml start
```

## Working with DAML Projects

### Building and Testing

```bash
# Build the DAML project
daml build

# Run the tests
daml test
```

### Running a Local Ledger

```bash
# Start Canton sandbox and Navigator
daml start
```

### Code Generation

```bash
# Generate JavaScript bindings
daml codegen js

# Generate Java bindings
daml codegen java
```

## Environment Configuration

The DAML SDK uses several environment variables:

- `DAML_HOME`: Points to the DAML SDK installation
- `DAML_SDK_VERSION`: The installed SDK version
- `DAML_USER_DIR`: User-specific data directory (defaults to `$XDG_DATA_HOME/daml` or `~/.local/share/daml`)

When using the Nix package, these are set automatically.

## Project Configuration

DAML projects are configured by `daml.yaml` files. A minimal example:

```yaml
sdk-version: 2.10.0
name: my-project
source: daml
parties:
  - Alice
  - Bob
version: 0.1.0
dependencies:
  - daml-prim
  - daml-stdlib
```

## Common Tasks

### Updating the SDK Version

To update the SDK version for a project, edit the `sdk-version` field in `daml.yaml`.

### Working with the Canton Console

The Canton console provides advanced features for working with the Canton distributed ledger:

```bash
# Start the Canton console
canton

# In the console, you can create participants, domains, etc.
canton> participant1.health.status
```

## Maintaining the Overlay

### Updating to New DAML Versions

When a new version of DAML is released, you can use the included update script:

```bash
# Update to the latest version
./update latest

# Or update to a specific version
./update 2.10.0
```

The update script will:
1. Fetch information about the release from GitHub
2. Download the SDK archives for all supported platforms
3. Verify GPG signatures for each archive
4. Calculate and update SHA256 hashes in `sources.json`
5. Update the "latest" entry if needed

#### Manual Update Process

If you prefer to update manually:

1. Download the new SDK archives from the [DAML GitHub releases](https://github.com/digital-asset/daml/releases)
2. Calculate the SHA256 hashes for each archive:
   ```bash
   nix-hash --type sha256 --base64 daml-sdk-x.x.x-linux.tar.gz
   nix-hash --type sha256 --base64 daml-sdk-x.x.x-macos.tar.gz
   ```
3. Verify GPG signatures:
   ```bash
   ./import-gpg-key.sh  # If you haven't already
   gpg --verify daml-sdk-x.x.x-linux.tar.gz.asc daml-sdk-x.x.x-linux.tar.gz
   gpg --verify daml-sdk-x.x.x-macos.tar.gz.asc daml-sdk-x.x.x-macos.tar.gz
   ```
4. Add the new version to `sources.json`:
   ```json
   "x.x.x": {
     "version": "x.x.x",
     "tag": "vx.x.x",
     "platforms": {
       "aarch64-darwin": {
         "url": "https://github.com/digital-asset/daml/releases/download/vx.x.x/daml-sdk-x.x.x-macos.tar.gz",
         "sha256": "sha256-your_hash_here"
       },
       "aarch64-linux": {
         "url": "https://github.com/digital-asset/daml/releases/download/vx.x.x/daml-sdk-x.x.x-linux.tar.gz",
         "sha256": "sha256-your_hash_here"
       },
       "x86_64-darwin": {
         "url": "https://github.com/digital-asset/daml/releases/download/vx.x.x/daml-sdk-x.x.x-macos.tar.gz",
         "sha256": "sha256-your_hash_here"
       },
       "x86_64-linux": {
         "url": "https://github.com/digital-asset/daml/releases/download/vx.x.x/daml-sdk-x.x.x-linux.tar.gz",
         "sha256": "sha256-your_hash_here"
       }
     }
   }
   ```
5. Update the "latest" entry in `sources.json` if needed
6. Verify everything with `./verify-hashes.sh`

### Verifying Archive Integrity

The overlay includes tools to verify both the SHA256 hashes and GPG signatures of DAML SDK archives:

```bash
# Import the Digital Asset GPG key (if not already done)
./import-gpg-key.sh

# Run the verification script for all versions
./verify-hashes.sh

# Or verify a specific version
./verify-hashes.sh 2.10.0

# This will:
# 1. Download the archives 
# 2. Check their SHA256 hashes against sources.json
# 3. Verify the GPG signatures from Digital Asset
# Any issues will be reported
```

If you encounter hash mismatches:
1. Verify you've downloaded the correct file
2. Re-calculate the hash:
   ```bash
   nix-hash --type sha256 --base64 /path/to/archive.tar.gz
   ```
3. Update `sources.json` with the correct hash (prefixed with `sha256-`)

### GPG Signature Verification

All DAML SDK archives are signed by Digital Asset using their GPG key. The verification process ensures the authenticity of downloads:

```bash
# Import the Digital Asset GPG key
./import-gpg-key.sh

# The verification script checks signatures automatically
./verify-hashes.sh 

# When updating to new versions, signatures are checked
./update latest
```

If a signature verification fails, it could indicate:
1. The download was corrupted or tampered with
2. The signature file is missing or incorrect
3. You don't have Digital Asset's GPG key imported

The `import-gpg-key.sh` script contains Digital Asset's official GPG key, so running it should resolve key-related issues.

## Additional Resources

- [DAML Documentation](https://docs.daml.com/)
- [Canton Documentation](https://www.canton.io/docs/)
- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [DAML GitHub Releases](https://github.com/digital-asset/daml/releases)

## Troubleshooting

### Common Issues

#### "SDK Version X.Y.Z is not installed"

If you see this error, ensure you're using the right Nix command:

```bash
# For the development shell
nix develop

# Or when directly using the built package
./result/bin/daml ...
```

#### Unable to access Canton JAR file

If you see an error like this when running `daml sandbox`:

```
Error: Unable to access jarfile /nix/store/xxx-daml-sdk-x.x.x/share/daml-sdk/.daml/sdk/x.x.x/canton/canton.jar
```

This indicates that the Canton directory is not being properly copied to the SDK directory. The fix is to modify the `default.nix` file to include the `canton` directory in the list of directories to copy:

```nix
# Copy other SDK directories needed for tools
for dir in daml damlc daml-libs studio templates sdk-config.yaml canton; do
  if [ -e $out/share/daml-sdk/$dir ]; then
    cp -Lr $out/share/daml-sdk/$dir $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/
    # ... rest of the code
  fi
done
```

#### Permission Errors

The DAML SDK will store user data in `$XDG_DATA_HOME/daml` or `~/.local/share/daml`. Ensure you have write permissions to this directory.

#### DAML Project Not Building

Check that your project's `sdk-version` in `daml.yaml` matches the version provided by the Nix package.

For other issues, check the [DOCUMENTATION.md](./DOCUMENTATION.md) file for technical details about the Nix packaging.