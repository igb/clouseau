#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Install build deps if missing
if ! dpkg -l debhelper &>/dev/null || dpkg -l debhelper | grep -q '^un'; then
    echo "Installing build dependencies..."
    sudo apt-get install -y debhelper
fi

# Clean previous build artifacts
rm -f ../clouseau_*.deb ../clouseau_*.changes ../clouseau_*.buildinfo

echo "Building package..."
dpkg-buildpackage -us -uc -b

DEB=$(ls ../clouseau_*.deb 2>/dev/null | head -1)
if [ -z "$DEB" ]; then
    echo "Build failed: no .deb produced" >&2
    exit 1
fi

echo "Built: $DEB"
