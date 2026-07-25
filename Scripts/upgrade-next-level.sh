#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SmartHomeConductor full verification"
echo "Repository: $ROOT_DIR"
echo
git -C "$ROOT_DIR" status --short --branch
echo

"$ROOT_DIR/Scripts/manage.sh" verify

echo
echo "Ready to launch:"
echo "  ./Scripts/manage.sh run-ios"
echo "  ./Scripts/manage.sh run-mac"
