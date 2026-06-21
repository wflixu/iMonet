#!/bin/bash
# Auto-set build version to YYYYMMDD.HHMM before each build.
# Used as a scheme pre-action in Xcode.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION=$(date +%Y%m%d.%H%M)

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$PROJECT_DIR/Sources/Info.plist"
echo "Build version set to $VERSION"
