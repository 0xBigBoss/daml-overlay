{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
  damlVersion ? null,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);

  # Define target version with the following precedence:
  # 1. Explicitly provided damlVersion parameter
  # 2. DAML_VERSION environment variable
  # 3. Default to "latest"
  envVersion = builtins.getEnv "DAML_VERSION";
  selectedVersion =
    if damlVersion != null
    then damlVersion
    else if envVersion != ""
    then envVersion
    else "latest";

  # Access relevant data from sources.json
  # This handles either "latest" or specific version tags
  versionData =
    if builtins.hasAttr selectedVersion sources
    then sources.${selectedVersion}
    else throw "DAML version '${selectedVersion}' not found in sources.json";

  # Create a base derivation for fetching DAML SDK
  mkDamlSdkPackage = {
    version,
    pname ? "daml-sdk",
  }: let
    # Select appropriate platform data based on system architecture
    platformData = versionData.platforms.${system} or (throw "Unsupported system: ${system}");

    # Get tarball information for verification
    tarball = {
      url = platformData.url;
      sha256 = platformData.sha256;
      # Convert GitHub release URL to one that can use the official GPG signature
      # Official GPG signature is at same URL with .asc appended
      signatureUrl = platformData.url + ".asc";
    };

    # Create a derivation for fetching the archive with verification
    daml-archive = pkgs.fetchurl {
      url = tarball.url;
      sha256 = tarball.sha256;
      # Note: We're not validating GPG signature here because nix-prefetch-url has
      # already verified the hash. In a production system, you might want to add
      # additional GPG verification from Digital Asset's key.
    };

    # Java is a key dependency for DAML
    javaPackage = pkgs.jdk17;
  in
    pkgs.stdenv.mkDerivation {
      inherit version;
      pname = pname;

      src = daml-archive;

      # Add required tools and runtime dependencies
      nativeBuildInputs =
        (lib.optionals pkgs.stdenv.isLinux [
          pkgs.autoPatchelfHook
        ])
        ++ [
          pkgs.makeWrapper
        ];

      # Add required runtime dependencies
      buildInputs = [
        javaPackage
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        pkgs.stdenv.cc.cc.lib # libstdc++
        pkgs.glibc # GNU libc compatibility
        pkgs.zlib
        pkgs.ncurses
      ];

      dontBuild = true;
      dontPatch = true;
      dontConfigure = true;

      # Extract the archive and install files
      installPhase = ''
        # Create output directories
        mkdir -p $out/bin
        mkdir -p $out/share/daml-sdk

        # Extract the archive to the share directory
        tar -xzf $src -C $out/share/daml-sdk --strip-components=1

        # Read the actual version from the daml_version.txt file
        ACTUAL_VERSION=$(cat $out/share/daml-sdk/daml_version.txt)

        # Create a read-only DAML_HOME directory in the nix store
        # This eliminates the need to write to user's home directory
        mkdir -p $out/share/daml-sdk/.daml
        mkdir -p $out/share/daml-sdk/.daml/bin
        mkdir -p $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION

        # Create installation status files that would normally be written at install time
        echo "$ACTUAL_VERSION" > $out/share/daml-sdk/.daml/sdk/version
        touch $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/install.status
        
        # Create an sdk-config.yaml that disables auto-install and update checks
        cat > $out/share/daml-sdk/.daml/sdk/sdk-config.yaml <<EOF
auto-install: false
update-check: never
EOF
        cp $out/share/daml-sdk/.daml/sdk/sdk-config.yaml $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/sdk-config.yaml
        
        # Setup helper directories needed for DAML SDK operation
        mkdir -p $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/bin
        
        # Copy the daml-helper directory (preserving structure)
        if [ -d $out/share/daml-sdk/daml-helper ]; then
          mkdir -p $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/daml-helper
          cp -Lr $out/share/daml-sdk/daml-helper/* $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/daml-helper/
          chmod -R +x $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/daml-helper
        fi
        
        # Copy other SDK directories needed for tools
        for dir in daml damlc daml-libs studio templates sdk-config.yaml canton; do
          if [ -e $out/share/daml-sdk/$dir ]; then
            cp -Lr $out/share/daml-sdk/$dir $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/
            if [ -d $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/$dir ]; then
              chmod -R +x $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/$dir 2>/dev/null || true
            fi
          fi
        done
        
        # Create symlinks to top-level binaries
        for bin in $(find $out/share/daml-sdk -maxdepth 1 -type f -executable | grep -v "/.daml/"); do
          ln -sf $bin $out/share/daml-sdk/.daml/sdk/$ACTUAL_VERSION/bin/$(basename $bin)
        done

        # Create our customized wrapper script that respects XDG directories
        cat > $out/bin/daml <<EOF
#!/bin/sh
# Respect existing DAML_HOME if set, otherwise use our nix store path
if [ -z "\$DAML_HOME" ]; then
  export DAML_HOME="$out/share/daml-sdk/.daml"
fi

# Set SDK version from the actual installed version
export DAML_SDK_VERSION="$ACTUAL_VERSION"

# Respect existing DAML_USER_DIR if set
if [ -z "\$DAML_USER_DIR" ]; then
  # Respect XDG_DATA_HOME if set, otherwise use standard XDG location
  if [ -n "\$XDG_DATA_HOME" ]; then
    export DAML_USER_DIR="\$XDG_DATA_HOME/daml"
  else
    export DAML_USER_DIR="\$HOME/.local/share/daml"
  fi
fi

# Create user directory if it doesn't exist
mkdir -p "\$DAML_USER_DIR"

# Execute the real DAML command with proper environment
exec env JAVA_HOME="${javaPackage}" PATH="${lib.makeBinPath [javaPackage]}:\$PATH" "$out/share/daml-sdk/daml/daml" "\$@"
EOF
        chmod +x $out/bin/daml

        # Create symlinks for any additional binaries if needed
        if [ -f $out/share/daml-sdk/canton/canton.jar ]; then
          # Create a wrapper script for Canton
          cat > $out/bin/canton <<EOF
#!/bin/sh
# Use proper Java environment
exec env JAVA_HOME="${javaPackage}" "${javaPackage}/bin/java" -jar "$out/share/daml-sdk/canton/canton.jar" "\$@"
EOF
          chmod +x $out/bin/canton
        fi
      '';

      # Provide additional output data to flake consumers
      passthru = {
        inherit javaPackage;
        damlHome = "$out/share/daml-sdk/.daml";
      };

      meta = {
        description = "DAML SDK - Build and deploy multi-party applications with strong privacy and security guarantees";
        homepage = "https://www.digitalasset.com/daml";
        license = pkgs.lib.licenses.asl20;
        platforms = pkgs.lib.platforms.unix;
        mainProgram = "daml";
      };
    };

  # Create the daml-sdk package
  daml-sdk = mkDamlSdkPackage {
    version = versionData.version;
  };
in {
  inherit daml-sdk;
  default = daml-sdk;
}