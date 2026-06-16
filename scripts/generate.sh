#!/usr/bin/env bash
#
# (Re)generate the Xcode project from project.yml. The project IS committed and
# normally stable; regenerate only after changing Package.swift (targets/
# products) or project.yml, then commit the result. Also clears stale Xcode/
# SwiftPM caches that cause "Missing package product" / "Couldn't load project".
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen"; exit 1; }

# Clear stale caches that confuse Xcode's package resolution.
rm -rf .swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData/ExcalidrawSwift-* 2>/dev/null || true

xcodegen generate
xcodebuild -resolvePackageDependencies -project ExcalidrawSwift.xcodeproj -scheme ExcalidrawApp >/dev/null
echo "Regenerated ExcalidrawSwift.xcodeproj and cleared caches."
echo "If Xcode is open, quit and reopen ExcalidrawSwift.xcodeproj (not the folder)."
