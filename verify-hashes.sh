#!/usr/bin/env bash
set -euo pipefail

# Script to verify hashes in sources.json according to DAML's official documentation
# Checks both SHA256 hashes and GPG signatures if available

# Import shared GPG key functions
source "$(dirname "$0")/import-gpg-key.sh"

# Function to download a file and get its hash
get_file_hash() {
  local url=$1
  local tmp_file
  tmp_file=$(mktemp)
  
  if ! curl -s -L -f -o "$tmp_file" "$url"; then
    echo "Error: Failed to download $url"
    rm "$tmp_file"
    return 1
  fi
  
  # Get the Nix-compatible hash
  local hash
  hash=$(nix-hash --type sha256 --flat --base32 "$tmp_file")
  
  # Clean up
  rm "$tmp_file"
  
  echo "$hash"
}

# Function to check if GPG signature is valid
verify_gpg_signature() {
  local file=$1
  local signature=$2
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local result=1
  
  # Download the file and signature
  if ! curl -s -L -f -o "$tmp_dir/file" "$file"; then
    echo "Error: Failed to download $file"
    rm -rf "$tmp_dir"
    return 1
  fi
  
  if ! curl -s -L -f -o "$tmp_dir/signature.asc" "$signature"; then
    echo "Error: Failed to download signature $signature"
    rm -rf "$tmp_dir"
    return 1
  fi
  
  # Ensure we have the Digital Asset key using our shared function
  ensure_gpg_key
  
  # Verify the signature
  if gpg --verify "$tmp_dir/signature.asc" "$tmp_dir/file" &>/dev/null; then
    echo "✅ GPG signature verified successfully!"
    result=0
  else
    echo "❌ GPG signature verification failed!"
    result=1
  fi
  
  # Clean up
  rm -rf "$tmp_dir"
  return $result
}

# Check for required tools
for cmd in curl jq nix-hash gpg; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: Required command '$cmd' not found"
    exit 1
  fi
done

# Check sources.json
if [[ ! -f sources.json ]]; then
  echo "Error: sources.json not found"
  exit 1
fi

# Parse JSON and verify hashes
echo "Verifying hashes in sources.json..."

# Function to verify a specific version
verify_version() {
  local version=$1
  echo "==========================================="
  echo "Checking version: $version"
  echo "==========================================="
  
  # Check if version exists in sources.json
  if [[ "$(jq -r ".[\"$version\"] | type" sources.json)" == "null" ]]; then
    echo "Error: Version $version not found in sources.json"
    return 1
  fi
  
  # Get the tag from sources.json
  tag=$(jq -r ".[\"$version\"].tag" sources.json)
  echo "Release tag: $tag"
  
  # Check each platform
  platforms=("aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux")
  
  # Track verification result
  local all_verified=true
  
  for platform in "${platforms[@]}"; do
    echo ""
    echo "Checking platform: $platform..."
    
    # Get the URL and expected hash from sources.json
    url=$(jq -r ".[\"$version\"].platforms[\"$platform\"].url" sources.json)
    expected_hash=$(jq -r ".[\"$version\"].platforms[\"$platform\"].sha256" sources.json)
    
    # Skip if the platform doesn't exist in the JSON
    if [[ "$url" == "null" ]]; then
      echo "  Skipping platform $platform (not found in sources.json)"
      continue
    fi
    
    # Check signature URL
    signature_url="${url}.asc"
    
    echo "  Archive URL:       $url"
    echo "  Signature URL:     $signature_url"
    echo "  Expected hash:     $expected_hash"
    
    # If the expected hash is a placeholder, skip verification
    if [[ "$expected_hash" == *"placeholder"* ]]; then
      echo "  Warning: Hash is a placeholder, skipping verification"
      all_verified=false
      continue
    fi
    
    # Check if we can access the file
    if ! curl -s -I -f "$url" &>/dev/null; then
      echo "  ❌ Archive file not accessible at $url"
      all_verified=false
      continue
    fi
    
    # 1. Verify SHA256 hash
    echo "  Verifying SHA256 hash..."
    
    local actual_hash
    if actual_hash=$(get_file_hash "$url"); then
      echo "  Actual hash:       sha256-$actual_hash"
      
      if [[ "sha256-$actual_hash" == "$expected_hash" ]]; then
        echo "  ✅ SHA256 hash verified successfully!"
      else
        echo "  ❌ SHA256 hash verification failed!"
        echo "     - Expected: $expected_hash"
        echo "     - Actual:   sha256-$actual_hash"
        all_verified=false
      fi
    else
      echo "  ❌ Failed to download and hash file"
      all_verified=false
    fi
    
    # 2. Verify GPG signature if available
    echo "  Verifying GPG signature..."
    
    if curl -s -I -f "$signature_url" &>/dev/null; then
      if verify_gpg_signature "$url" "$signature_url"; then
        echo "  ✅ GPG signature verified successfully!"
      else
        echo "  ❌ GPG signature verification failed!"
        all_verified=false
      fi
    else
      echo "  ⚠️ No GPG signature available at $signature_url"
    fi
    
    # Verification summary for this platform
    if [[ $all_verified == true ]]; then
      echo "  ✅ All verifications passed for $platform"
    else
      echo "  ⚠️ Some verifications failed for $platform"
    fi
  done
  
  echo ""
  echo "Version $version verification summary:"
  if [[ $all_verified == true ]]; then
    echo "✅ All platforms verified successfully!"
  else
    echo "⚠️ Some platforms had verification issues - check the logs above"
  fi
  echo ""
}

# Get a specific version to check if provided as an argument
if [[ $# -gt 0 ]]; then
  VERSION_TO_CHECK="$1"
  verify_version "$VERSION_TO_CHECK"
  exit 0
fi

# Otherwise, verify all versions
echo "Verifying latest version..."
verify_version "latest"

# Get all specific versions (excluding latest and canary)
specific_versions=$(jq -r 'keys[] | select(. != "latest" and . != "canary")' sources.json)

# Verify each specific version
for version in $specific_versions; do
  verify_version "$version"
done

echo "Hash verification complete!"