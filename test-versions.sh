#!/usr/bin/env bash
set -euo pipefail

echo "Testing version selection..."

# Verify hashes first
if [[ -f "./verify-hashes.sh" ]]; then
  echo -e "\n\nVerifying hashes across all platforms..."
  ./verify-hashes.sh
fi

# Test default (latest) version
echo -e "\n\nTesting default (latest) version:"
LATEST_PATH=$(nix-build --no-out-link)
echo "Built at: $LATEST_PATH"
$LATEST_PATH/bin/daml --version

# Test specific version with command-line parameter
echo -e "\n\nTesting specific version (2.10.0) via command-line parameter:"
SPECIFIC_PATH=$(nix-build --no-out-link --argstr damlVersion "2.10.0")
echo "Built at: $SPECIFIC_PATH"
$SPECIFIC_PATH/bin/daml --version

# Test another specific version with command-line parameter
echo -e "\n\nTesting specific version (2.8.0) via command-line parameter:"
SPECIFIC_PATH_2=$(nix-build --no-out-link --argstr damlVersion "2.8.0")
echo "Built at: $SPECIFIC_PATH_2"
$SPECIFIC_PATH_2/bin/daml --version

# Test with environment variable
echo -e "\n\nTesting version via environment variable:"
ENV_PATH=$(DAML_VERSION=2.10.0 nix-build --no-out-link)
echo "Built at: $ENV_PATH"
$ENV_PATH/bin/daml --version

echo -e "\n\nAll tests completed!"