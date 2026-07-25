#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Conductor next-level upgrade runner"
echo "Project: $ROOT_DIR"
echo

echo "Step 1/4: verify git state"
git status --short --branch
echo

echo "Step 2/4: list new integration targets"
echo "- TP-Link / Tapo"
echo "- MDV / Midea"
echo "- Xiaomi"
echo "- Electrolux"
echo "- Samsung"
echo "- Shelly"
echo

echo "Step 3/4: build iOS simulator app"
xcodebuild \
  -project "$ROOT_DIR/SmartHomeConductor.xcodeproj" \
  -scheme SmartHomeConductor \
  -configuration Debug \
  -derivedDataPath "$ROOT_DIR/DerivedData" \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
echo

echo "Step 4/4: next commands"
echo "  git add ."
echo "  git commit -m 'Upgrade brand integrations and device controls'"
echo "  git push"
echo
echo "Done. Open with: ./Scripts/manage.sh open"
