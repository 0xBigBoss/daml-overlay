{
  description = "DAML SDK for building privacy-preserving multi-party applications";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";

    # Used for shell.nix
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    systems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      # Import packages from default.nix
      # Prioritize damlVersion from the DAML_VERSION environment variable if set
      envVersion = builtins.getEnv "DAML_VERSION";
      selectedVersion =
        if envVersion != ""
        then envVersion
        else null;
      damlPkgs = import ./default.nix {
        inherit pkgs system;
        damlVersion = selectedVersion;
      };

      # Create a dedicated directory for project-specific DAML data
      # This avoids writing to the user's home directory
      mkDamlProjectDir = name:
        pkgs.runCommand "daml-project-dir-${name}" {} ''
          mkdir -p $out/{cache,packages,packages-v2}
          # Create empty files to initialize the directory structure
          touch $out/.exists
        '';
    in rec {
      # The packages exported by the Flake
      packages = damlPkgs;

      # "Apps" so that `nix run` works
      apps = {
        daml = flake-utils.lib.mkApp {
          drv = packages.daml-sdk;
          name = "daml";
          exePath = "/bin/daml";
        };
        default = apps.daml;
      };

      # nix fmt
      formatter = pkgs.alejandra;

      # Development shell with DAML SDK
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
          packages.daml-sdk
        ];

        # Create a project-specific DAML directory for the shell
        damlProjectDir = mkDamlProjectDir "default";

        shellHook = let
          damlSdk = packages.daml-sdk;
        in ''
          echo "DAML SDK ${damlSdk.version} development environment"
          echo "Run 'daml --help' for available commands"

          # DAML_HOME points to the read-only SDK installation in the nix store
          export DAML_HOME=${damlSdk.passthru.damlHome}
          export DAML_SDK_VERSION=${damlSdk.version}

          # Respect existing XDG_DATA_HOME, otherwise use standard location
          if [ -z "$XDG_DATA_HOME" ]; then
            export XDG_DATA_HOME="$HOME/.local/share"
          fi

          # Set DAML_USER_DIR to a directory in XDG_DATA_HOME if user hasn't already set it
          # This provides persistence across nix shell invocations while respecting XDG spec
          if [ -z "$DAML_USER_DIR" ]; then
            export DAML_USER_DIR="$XDG_DATA_HOME/daml"
            mkdir -p "$DAML_USER_DIR"
          fi

          # Create a project-local daml directory for project-specific data
          # This helps isolate project dependencies from global ones
          mkdir -p .daml

          # Inform the user about configured directories
          echo "DAML environment configured:"
          echo "  • SDK installation: $DAML_HOME"
          echo "  • User directory:   $DAML_USER_DIR"
          echo "  • Project directory: .daml (in current directory)"
        '';
      };

      # For compatibility with older versions of the `nix` binary
      devShell = self.devShells.${system}.default;
    });
  in
    outputs
    // {
      # Overlay that can be imported so you can access the packages
      overlays.default = final: prev: {
        damlPackages = outputs.packages.${prev.system};
        daml-sdk = outputs.packages.${prev.system}.daml-sdk;
      };

      templates.init = {
        path = ./templates/init;
        description = "A basic DAML development environment.";
      };

      # Documentation for exported variables and usage
      meta = {
        maintainers = [];
        description = "DAML SDK flake for building privacy-preserving multi-party applications";
        documentation = ''
          DAML SDK Nix Flake

          This flake provides the Digital Asset Modeling Language (DAML) SDK for building
          distributed applications with privacy, security, and multi-party workflows.
        '';
      };
    };
}
