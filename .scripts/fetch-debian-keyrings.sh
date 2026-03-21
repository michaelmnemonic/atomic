#!/usr/bin/env bash

set -euo pipefail

# Configuration
DEB_URL="http://ftp.debian.org/debian/pool/main/d/debian-archive-keyring/debian-archive-keyring_2025.1_all.deb"
DEB_NAME="debian-archive-keyring_2025.1_all.deb"
KEYRINGS_DIR=".keyrings"

# Create a temporary directory for extraction
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading Debian archive keyring..."
curl -sSL "$DEB_URL" -o "$TMP_DIR/$DEB_NAME"

echo "Extracting .deb package..."
cd "$TMP_DIR"
ar x "$DEB_NAME"

# Check if data.tar.xz or data.tar.zst is present (Debian uses zst in newer versions)
DATA_ARCHIVE=""
if [ -f data.tar.xz ]; then
    DATA_ARCHIVE="data.tar.xz"
elif [ -f data.tar.zst ]; then
    DATA_ARCHIVE="data.tar.zst"
elif [ -f data.tar.gz ]; then
    DATA_ARCHIVE="data.tar.gz"
fi

if [ -z "$DATA_ARCHIVE" ]; then
    echo "Error: No data archive found in the .deb package."
    exit 1
fi

echo "Unpacking $DATA_ARCHIVE..."
mkdir -p unpacked
tar -xf "$DATA_ARCHIVE" -C unpacked

# Return to the project root
cd - > /dev/null

echo "Populating $KEYRINGS_DIR..."
if [ -d "$KEYRINGS_DIR" ]; then
    echo "Clearing existing contents of $KEYRINGS_DIR..."
    rm -rf "${KEYRINGS_DIR:?}"/*
fi
mkdir -p "$KEYRINGS_DIR"

# Copy all keyrings from the unpacked location to .keyrings
cp "$TMP_DIR/unpacked/usr/share/keyrings/"* "$KEYRINGS_DIR/"

echo "Debian keyrings updated successfully in $KEYRINGS_DIR/"
