#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CloudflareStatusBar"
PROJECT="CloudflareStatusBar.xcodeproj"
SCHEME="CloudflareStatusBar"
CONFIGURATION="Release"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

require_cmd xcodebuild
require_cmd xcrun
require_cmd ditto
require_cmd shasum

VERSION="${VERSION:-}"
if [[ -z "$VERSION" ]]; then
  if TAG="$(git describe --tags --exact-match 2>/dev/null)"; then
    VERSION="${TAG#v}"
  else
    VERSION="$(
      xcodebuild -showBuildSettings \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" 2>/dev/null |
        awk '/MARKETING_VERSION/ { print $3; exit }'
    )"
  fi
fi

if [[ -z "$VERSION" ]]; then
  echo "error: failed to determine VERSION" >&2
  exit 1
fi

TEAM_ID="${TEAM_ID:-}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
if [[ -z "$TEAM_ID" ]]; then
  echo "error: TEAM_ID is required for Developer ID signing" >&2
  exit 1
fi

BUILD_ROOT="$REPO_ROOT/build/release"
ARCHIVE_PATH="$BUILD_ROOT/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_ROOT/export"
EXPORT_OPTIONS="$BUILD_ROOT/ExportOptions.plist"
DIST_DIR="$REPO_ROOT/dist"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
NOTARY_ZIP="$BUILD_ROOT/$APP_NAME-notary.zip"
FINAL_ZIP="$DIST_DIR/$APP_NAME-$VERSION.zip"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$DIST_DIR"

cat >"$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>$SIGNING_IDENTITY</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>stripSwiftSymbols</key>
  <true/>
</dict>
</plist>
PLIST

echo "Building $APP_NAME $VERSION with Developer ID signing..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  clean archive

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: exported app not found at $APP_PATH" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E 'Authority=|TeamIdentifier=|Signature=' || true

if [[ "${SKIP_NOTARIZATION:-0}" == "1" ]]; then
  echo "warning: SKIP_NOTARIZATION=1; output will not pass Gatekeeper for Homebrew downloads" >&2
else
  notary_args=()
  if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    notary_args=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
  elif [[ -n "${ASC_KEY_PATH:-}" || -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
    key_path="${ASC_KEY_PATH:-${APP_STORE_CONNECT_API_KEY_PATH:-}}"
    key_id="${ASC_KEY_ID:-${APP_STORE_CONNECT_KEY_ID:-}}"
    issuer_id="${ASC_ISSUER_ID:-${APP_STORE_CONNECT_ISSUER_ID:-}}"
    if [[ ! -f "$key_path" ]]; then
      echo "error: API key file not found at $key_path" >&2
      exit 1
    fi
    if [[ -z "$key_id" ]]; then
      echo "error: set ASC_KEY_ID or APP_STORE_CONNECT_KEY_ID for API key notarization" >&2
      exit 1
    fi
    if [[ -z "$issuer_id" ]]; then
      echo "error: set ASC_ISSUER_ID or APP_STORE_CONNECT_ISSUER_ID for API key notarization" >&2
      exit 1
    fi
    notary_args=(--key "$key_path" --key-id "$key_id" --issuer "$issuer_id")
  else
    if [[ -z "${APPLE_ID:-}" || -z "${APP_SPECIFIC_PASSWORD:-}" ]]; then
      echo "error: set NOTARY_KEYCHAIN_PROFILE, App Store Connect API key vars, or APPLE_ID and APP_SPECIFIC_PASSWORD for notarization" >&2
      exit 1
    fi
    notary_args=(--apple-id "$APPLE_ID" --password "$APP_SPECIFIC_PASSWORD" --team-id "$TEAM_ID")
  fi

  echo "Submitting $APP_NAME for notarization..."
  rm -f "$NOTARY_ZIP"
  ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP_PATH" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --wait "${notary_args[@]}"
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  spctl --assess --type execute --verbose=4 "$APP_PATH"
fi

rm -f "$FINAL_ZIP"
ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP_PATH" "$FINAL_ZIP"

SHA256="$(shasum -a 256 "$FINAL_ZIP" | awk '{ print $1 }')"
echo "Created $FINAL_ZIP"
echo "sha256: $SHA256"
