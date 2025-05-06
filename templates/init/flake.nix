{
  description = "A basic DAML project template for multi-party application development.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    daml-overlay.url = "github:0xbigboss/daml-overlay";

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
    daml-overlay,
    ...
  } @ inputs: let
    overlays = [
      daml-overlay.overlays.default
    ];

    # Our supported systems are the same as daml-overlay
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in
    flake-utils.lib.eachSystem systems (
      system: let
        pkgs = import nixpkgs {inherit overlays system;};
      in rec {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            # DAML tools
            daml-sdk

            # Additional useful tools for DAML development
            jq
          ];

          shellHook = ''
            echo "DAML SDK ${pkgs.daml-sdk.version} development environment"
            echo "Run 'daml new <project-name> --template quickstart' to create a new DAML project"
          '';
        };

        # For compatibility with older versions of the `nix` binary
        devShell = self.devShells.${system}.default;
      }
    );
}
