#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/SmartHomeConductor.xcodeproj"
SCHEME="SmartHomeConductor"
IOS_DERIVED_DATA="$ROOT_DIR/DerivedData"
MAC_DERIVED_DATA="$ROOT_DIR/DerivedData-Catalyst"
SIMULATOR_NAME="${CONDUCTOR_SIMULATOR:-iPhone 17 Pro}"
BUNDLE_ID="app.conductor.smart.home"

usage() {
  cat <<USAGE
Conductor app manager

Usage:
  ./Scripts/manage.sh list
  ./Scripts/manage.sh build
  ./Scripts/manage.sh build-ios
  ./Scripts/manage.sh build-mac
  ./Scripts/manage.sh test
  ./Scripts/manage.sh verify
  ./Scripts/manage.sh run-ios
  ./Scripts/manage.sh run-mac
  ./Scripts/manage.sh open

Commands:
  list       Show schemes and available destinations.
  build      Build the iPhone Simulator app.
  build-ios  Build the iPhone Simulator app.
  build-mac  Build the Mac Catalyst app.
  test       Run unit tests on the latest matching iPhone Simulator.
  verify     Build iPhone, run tests, and build Mac Catalyst.
  run-ios    Build, install, and launch in iPhone Simulator.
  run-mac    Build and launch the Mac Catalyst app.
  open       Open the project in Xcode.

Optional environment:
  CONDUCTOR_SIMULATOR="iPhone 17 Pro"
  CONDUCTOR_SIMULATOR_UDID="<simulator UUID>"
USAGE
}

resolve_simulator_udid() {
  if [[ -n "${CONDUCTOR_SIMULATOR_UDID:-}" ]]; then
    printf '%s\n' "$CONDUCTOR_SIMULATOR_UDID"
    return
  fi

  xcrun simctl list devices available --json |
    /usr/bin/ruby -W0 -rjson -e '
      target = ARGV.fetch(0)
      data = JSON.parse(STDIN.read).fetch("devices")
      candidates = data.flat_map do |runtime, devices|
        devices
          .select { |device| device["isAvailable"] && device["name"] == target }
          .map { |device| [runtime.scan(/\d+/).map(&:to_i), device.fetch("udid")] }
      end
      abort("No available simulator named #{target}") if candidates.empty?
      puts candidates.max_by(&:first).last
    ' "$SIMULATOR_NAME"
}

build_ios() {
  echo "Building iPhone Simulator..."
  xcodebuild -quiet \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$IOS_DERIVED_DATA" \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
  echo "iPhone build passed."
}

build_mac() {
  echo "Building Mac Catalyst..."
  xcodebuild -quiet \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$MAC_DERIVED_DATA" \
    -destination 'generic/platform=macOS,variant=Mac Catalyst' \
    CODE_SIGNING_ALLOWED=NO \
    build
  echo "Mac Catalyst build passed."
}

test_ios() {
  local simulator_udid
  simulator_udid="$(resolve_simulator_udid)"
  echo "Running tests on $SIMULATOR_NAME ($simulator_udid)..."
  xcodebuild -quiet \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$IOS_DERIVED_DATA" \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    CODE_SIGNING_ALLOWED=NO \
    test
  echo "Tests passed."
}

run_ios() {
  local simulator_udid
  simulator_udid="$(resolve_simulator_udid)"

  xcrun simctl boot "$simulator_udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$simulator_udid" -b

  xcodebuild -quiet \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$IOS_DERIVED_DATA" \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    CODE_SIGNING_ALLOWED=NO \
    build

  xcrun simctl install \
    "$simulator_udid" \
    "$IOS_DERIVED_DATA/Build/Products/Debug-iphonesimulator/SmartHomeConductor.app"
  xcrun simctl launch "$simulator_udid" "$BUNDLE_ID"
  open -a Simulator
}

run_mac() {
  build_mac
  open "$MAC_DERIVED_DATA/Build/Products/Debug-maccatalyst/SmartHomeConductor.app"
}

case "${1:-}" in
  list)
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations
    ;;
  build | build-ios)
    build_ios
    ;;
  build-mac)
    build_mac
    ;;
  test)
    test_ios
    ;;
  verify)
    build_ios
    test_ios
    build_mac
    echo "Conductor verification passed for iPhone and Mac."
    ;;
  run-ios)
    run_ios
    ;;
  run-mac)
    run_mac
    ;;
  open)
    open "$PROJECT"
    ;;
  *)
    usage
    exit 1
    ;;
esac
