#!/bin/bash
set -e

# Script to trigger release-publish workflows for all unpublished packages
# This script is used by the release-tag workflow after tags are created

echo "Starting package release workflow triggers..."

# Check if GH_TOKEN is set
if [ -z "$GH_TOKEN" ]; then
  echo "Error: GH_TOKEN environment variable is not set"
  exit 1
fi

# Counter for tracking
TOTAL_PACKAGES=0
SUCCESS_COUNT=0
FAILED_PACKAGES=()

# Run melos exec to trigger workflows for each package
# --no-published: Only unpublished packages
# --no-private: Exclude private packages
# --order-dependents: Process in dependency order
# -c 1: Run one at a time (concurrency 1)
echo "Triggering workflows for unpublished packages..."
melos exec \
  -c 1 \
  --no-published \
  --no-private \
  --order-dependents \
  -- bash -c '
    PACKAGE_NAME="${MELOS_PACKAGE_NAME}"
    PACKAGE_VERSION="${MELOS_PACKAGE_VERSION}"
    REF="${PACKAGE_NAME}-v${PACKAGE_VERSION}"

    echo "----------------------------------------"
    echo "Processing: $PACKAGE_NAME v$PACKAGE_VERSION"
    echo "Ref: $REF"

    if gh workflow run release-publish.yml --ref "$REF"; then
      echo "✓ Successfully triggered workflow for $PACKAGE_NAME"
      exit 0
    else
      echo "✗ Failed to trigger workflow for $PACKAGE_NAME"
      exit 1
    fi
  ' || {
    echo "Error: Some package workflows failed to trigger"
    exit 1
  }

echo "----------------------------------------"
echo "All package release workflows triggered successfully!"
