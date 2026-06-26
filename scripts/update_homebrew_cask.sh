#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CloudflareStatusBar"
TAP_REPO="${TAP_REPO:-sushaantu/homebrew-cloudflare-status-bar}"
TAP_BRANCH="${TAP_BRANCH:-main}"
VERSION="${VERSION:-}"
ZIP_PATH="${ZIP_PATH:-}"
SHA256="${SHA256:-}"

if [[ -z "$VERSION" ]]; then
  echo "error: VERSION is required" >&2
  exit 1
fi

if [[ -z "$SHA256" ]]; then
  if [[ -z "$ZIP_PATH" ]]; then
    ZIP_PATH="dist/$APP_NAME-$VERSION.zip"
  fi
  if [[ ! -f "$ZIP_PATH" ]]; then
    echo "error: ZIP_PATH does not exist: $ZIP_PATH" >&2
    exit 1
  fi
  SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
fi

WORK_ROOT="${RUNNER_TEMP:-}"
if [[ -z "$WORK_ROOT" ]]; then
  WORK_ROOT="$(mktemp -d)"
fi
TAP_DIR="$WORK_ROOT/homebrew-cloudflare-status-bar"

rm -rf "$TAP_DIR"
if [[ -n "${HOMEBREW_TAP_TOKEN:-}" ]]; then
  git clone "https://x-access-token:$HOMEBREW_TAP_TOKEN@github.com/$TAP_REPO.git" "$TAP_DIR"
else
  git clone "https://github.com/$TAP_REPO.git" "$TAP_DIR"
fi

cd "$TAP_DIR"
git checkout "$TAP_BRANCH"

CASK_FILE="Casks/cloudflare-status-bar.rb"
if [[ ! -f "$CASK_FILE" ]]; then
  echo "error: cask file not found: $CASK_FILE" >&2
  exit 1
fi

VERSION="$VERSION" SHA256="$SHA256" ruby -0pi -e '
  gsub(/version "[^"]+"/, "version \"#{ENV.fetch("VERSION")}\"")
  gsub(/sha256 "[^"]+"/, "sha256 \"#{ENV.fetch("SHA256")}\"")
' "$CASK_FILE"

if git diff --quiet -- "$CASK_FILE"; then
  echo "Homebrew cask already points at $VERSION ($SHA256)"
  exit 0
fi

git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
git add "$CASK_FILE"
git commit -m "Update CloudflareStatusBar to $VERSION"
git push origin "HEAD:$TAP_BRANCH"
