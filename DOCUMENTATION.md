# DAML Overlay for Nix

This documentation explains the structure of the DAML SDK releases and how the Nix overlay is designed to package it properly.

## DAML SDK Structure

The DAML SDK is a collection of tools and libraries for building, testing, and deploying DAML applications. The SDK is distributed as a tarball with the following structure:

### Top-Level Directories

- `canton/`: Contains the Canton JAR file which provides a distributed ledger implementation
- `daml/`: Contains the main `daml` CLI executable
- `daml-helper/`: Contains helper utilities used by the DAML CLI
- `daml-libs/`: Contains DAML library archives (DAR files) for DAML Script and Triggers
- `daml-sdk/`: Contains the core DAML SDK JAR and related files
- `daml2js/`: Tools for generating JavaScript bindings from DAML models
- `damlc/`: The DAML compiler
- `studio/`: Visual Studio Code extension for DAML development
- `templates/`: Project templates for different types of DAML applications

### Key Files

- `daml_version.txt`: Contains the version of the DAML SDK
- `sdk-config.yaml`: Configuration for the DAML SDK
- `install.sh`: Installation script (for manual installations)

## DAML Initialization and Configuration

When running DAML commands, the SDK needs several environment variables and configuration files:

1. `DAML_HOME`: Points to the root directory of the DAML SDK
2. `DAML_SDK_VERSION`: The version of the installed DAML SDK
3. `.daml/` directory: Used for configuration and caching

The SDK often attempts to write to directories within its installation path, which is problematic in Nix's read-only store.

## Nix Overlay Implementation

Our Nix overlay addresses these issues by:

1. Creating a custom `.daml` directory within the Nix store package
2. Configuring environment variables to use this directory
3. Directing user-specific files to XDG-compliant locations

### Key Components in `default.nix`

- **Source Management**: Uses `sources.json` to track URLs and hashes for different DAML versions
- **Platform Detection**: Selects appropriate download URLs based on the system architecture
- **Custom Installation**: Creates a directory structure that allows DAML to run from the Nix store
- **Environment Setup**: Configures proper environment variables in wrapper scripts

### Wrapper Script

The wrapper script handles several key functions:

1. Detects XDG data directory or falls back to `~/.local/share/daml`
2. Creates user-specific directories for DAML data
3. Sets environment variables to tell DAML where to find its components
4. Executes the actual DAML command

### Development Shell

The development shell in `flake.nix` sets up:

1. DAML SDK in the PATH
2. Proper environment variables
3. XDG directories for user data

## Files and Dependencies

The package has the following dependencies:

- Java JDK 11 (used to run the JVM components)
- Various platform-specific libraries (for Linux):
  - `libstdc++` (from gcc)
  - GNU libc
  - zlib
  - ncurses

### Platform-Specific Archives

Despite similar names, the DAML SDK archives for Linux and macOS contain different binaries and libraries:

1. **macOS archives** (`daml-sdk-x.x.x-macos.tar.gz`):
   - Contain macOS-specific dynamic libraries (`.dylib` files)
   - Used for both Intel (x86_64) and Apple Silicon (aarch64) Macs
   - Include macOS-specific launcher scripts

2. **Linux archives** (`daml-sdk-x.x.x-linux.tar.gz`):
   - Contain Linux-specific shared objects (`.so` files)
   - Used for both x86_64 and aarch64 Linux systems
   - Include additional utilities for Linux compatibility

### SHA256 Hash Verification

The `sources.json` file contains SHA256 hashes for each platform-specific archive. These hashes are critical for:

1. Security validation of downloaded archives
2. Nix's content-addressed storage system
3. Proper cache utilization across builds

To update or verify these hashes:

1. Use the `verify-hashes.sh` script to check all archives
2. Update individual hashes in `sources.json` using:
   ```bash
   nix-hash --type sha256 --base64 daml-sdk-x.x.x-platform.tar.gz
   ```
3. Format the hash with `sha256-` prefix for Nix compatibility

**Important:** Each platform requires its specific hash. Using incorrect hashes will cause Nix builds to fail or download unexpected archive versions.

### GPG Signature Verification

The DAML SDK releases are signed with Digital Asset's GPG key. We include a verification process to ensure the authenticity of the downloads:

1. The `import-gpg-key.sh` script contains Digital Asset's official GPG public key
2. The `verify-hashes.sh` script verifies both SHA256 hashes and GPG signatures of archives
3. The `update` script checks signatures when fetching new versions

To manually verify signatures:

```bash
# Import the key if not already done
./import-gpg-key.sh

# Verify a specific version
./verify-hashes.sh 2.10.0

# Verify all versions
./verify-hashes.sh
```

The GPG verification process ensures that the downloaded DAML SDK archives have not been tampered with and come directly from Digital Asset.

## Progress and Achievements

We've successfully:

1. ✅ Set up a file structure in the Nix store that DAML can use without modification
2. ✅ Created working wrapper scripts that direct all writes to appropriate locations
3. ✅ Made the DAML SDK recognize itself as properly installed
4. ✅ Enabled key functionality like new project creation
5. ✅ Provided a development shell with the correct environment

## Archive Extraction Process

The DAML SDK archives are extracted during the build process as follows:

1. Archives are downloaded via Nix's `fetchurl` function with SHA256 validation
2. The archive is extracted to `$out/share/daml-sdk` with `--strip-components=1` to remove the version prefix
3. The actual version is read from the `daml_version.txt` file
4. A metadata directory is created at `$out/share/daml-sdk/.daml` for DAML to use
5. Version information and installation status files are created
6. Required SDK components are copied to the version-specific directory:
   - Canton JAR and related files
   - DAML compiler (damlc)
   - DAML helper utilities
   - SDK libraries and templates
   - Configuration files
7. Executable permissions are preserved using `chmod -R +x` on critical directories
8. Symlinks are created for executable files in `$out/bin`

### File Permissions

Maintaining proper executable permissions is critical for DAML to function correctly:

1. **Native Binaries**:
   - `daml-helper/daml-helper`
   - Various tools in the `daml` directory
   - Platform-specific utilities

2. **JAR Files**:
   - `canton/canton.jar` (needs executable permission for Java to access it)

3. **Shell Scripts**:
   - Custom wrapper scripts in `$out/share/daml-sdk/.daml/bin/daml`
   - Final executable symlinks in `$out/bin/daml` and `$out/bin/canton`

## DAML Command Execution Flow

When executing a DAML command (e.g., `daml new project`), the following happens:

1. Our wrapper script sets up the environment (DAML_HOME, DAML_SDK_VERSION, etc.)
2. The script executes the real DAML executable from the Nix store
3. DAML loads its configuration from the `.daml/sdk` directory in our package
4. For project-specific operations, DAML writes to the user's XDG directory

## Caveats and Limitations

- Some DAML tools might still attempt to write to unexpected locations
- User projects are created in the current directory, not in the Nix store
- The Canton console may need additional configuration for some advanced features

## Future Improvements

Potential areas for improvement:

1. Better integration with Nix development shells (automatic project setup)
2. Support for multiple concurrent DAML SDK versions
3. Integration with IDE tooling (VS Code Extension)
4. Testing with more complex DAML workflows

## Testing the Overlay

The overlay can be tested by:

1. Building the package: `nix build`
2. Running DAML commands: `./result/bin/daml version`
3. Creating a new project: `./result/bin/daml new my-project --template skeleton`
4. Testing Canton sandbox: `./result/bin/daml sandbox`
5. Using a development shell: `nix develop`

### Canton Integration

For Canton functionality to work properly:
1. The Canton JAR file (`canton.jar`) must be properly included in the SDK structure
2. The directory structure must mirror what the DAML CLI expects:
   - Original location: `/nix/store/xxx-daml-sdk-x.x.x/share/daml-sdk/canton/canton.jar`
   - Required location: `/nix/store/xxx-daml-sdk-x.x.x/share/daml-sdk/.daml/sdk/x.x.x/canton/canton.jar`
3. The `default.nix` file must include `canton` in the list of directories to copy

## Platform Detection and Architecture Handling

The `default.nix` file contains logic to handle different platforms and architectures:

### System Detection

The overlay uses Nix's system detection to determine the appropriate archive:

```nix
platformData = versionData.platforms.${system} or (throw "Unsupported system: ${system}");
```

This selects the correct platform data from `sources.json` based on the Nix system identifier:
- `x86_64-linux`: Linux on Intel/AMD 64-bit
- `aarch64-linux`: Linux on ARM 64-bit
- `x86_64-darwin`: macOS on Intel
- `aarch64-darwin`: macOS on Apple Silicon (M1/M2)

### Architecture-Specific Dependencies

For Linux systems, additional dependencies are conditionally included:

```nix
buildInputs = [
  javaPackage
] ++ lib.optionals pkgs.stdenv.isLinux [
  pkgs.stdenv.cc.cc.lib # libstdc++
  pkgs.glibc # GNU libc compatibility
  pkgs.zlib
  pkgs.ncurses
];
```

For Linux builds, `autoPatchelfHook` is used to automatically handle the dynamic linking of binaries:

```nix
nativeBuildInputs =
  (lib.optionals pkgs.stdenv.isLinux [
    pkgs.autoPatchelfHook
  ])
  ++ [
    pkgs.makeWrapper
  ];
```

## References

- [DAML Documentation](https://docs.daml.com/)
- [Nix Package Manager](https://nixos.org/manual/nix/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Content-Addressed Nix](https://nixos.org/manual/nix/stable/store/content-addressed.html)