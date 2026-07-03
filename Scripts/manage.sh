#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/SmartHomeConductor.xcodeproj"
SCHEME="SmartHomeConductor"
DERIVED_DATA="$ROOT_DIR/DerivedData"

usage() {
  cat <<USAGE
Conductor app manager

Usage:
  ./Scripts/manage.sh list
  ./Scripts/manage.sh build
  ./Scripts/manage.sh open
  ./Scripts/manage.sh git-init

Commands:
  list      Show available schemes and destinations.
  build     Build the iOS simulator app.
  open      Open the project in Xcode.
  git-init  Initialize a git repo in this app folder.
USAGE
}

case "${1:-}" in
  list)
    xcodebuild -project "$PROJECT" -derivedDataPath "$DERIVED_DATA" -list
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -derivedDataPath "$DERIVED_DATA" -showdestinations
    ;;
  build)
    xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration Debug \
      -derivedDataPath "$DERIVED_DATA" \
      -destination 'generic/platform=iOS Simulator' \
      CODE_SIGNING_ALLOWED=NO \
      build
    ;;
  open)
    open "$PROJECT"
    ;;
  git-init)
    cd "$ROOT_DIR"
    git init
    git add .
    git commit -m "Start SwiftUI smart home app"
    ;;
  *)
    usage
    exit 1
    ;;
esac
