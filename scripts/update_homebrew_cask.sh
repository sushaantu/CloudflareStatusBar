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

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: VERSION must match MAJOR.MINOR.PATCH, for example 1.6.1" >&2
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

if [[ ! "$SHA256" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "error: SHA256 must be a 64-character hexadecimal digest" >&2
  exit 1
fi
SHA256="$(printf '%s' "$SHA256" | tr '[:upper:]' '[:lower:]')"

if [[ -z "${RUNNER_TEMP:-}" ]]; then
  WORK_ROOT="$(mktemp -d)"
  trap 'rm -rf "$WORK_ROOT"' EXIT
else
  WORK_ROOT="$RUNNER_TEMP"
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
  version = ENV.fetch("VERSION")
  sha256 = ENV.fetch("SHA256")
  unless version.match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)
    abort "error: invalid VERSION"
  end
  unless sha256.match?(/\A[0-9a-f]{64}\z/)
    abort "error: invalid SHA256"
  end
  gsub(/version "[^"]+"/, "version #{version.inspect}")
  gsub(/sha256 "[^"]+"/, "sha256 #{sha256.inspect}")
' "$CASK_FILE"

ruby -c "$CASK_FILE" >/dev/null
if command -v brew >/dev/null 2>&1; then
  if ! brew audit --cask "$CASK_FILE"; then
    if [[ "${REQUIRE_BREW_AUDIT:-0}" == "1" ]]; then
      exit 1
    fi
    echo "warning: brew audit failed; continuing because REQUIRE_BREW_AUDIT is not set" >&2
  fi
else
  echo "warning: brew not found; skipping cask audit" >&2
fi

if git diff --quiet -- "$CASK_FILE"; then
  echo "Homebrew cask already points at $VERSION ($SHA256)"
  exit 0
fi

git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
git add "$CASK_FILE"
git commit -m "Update CloudflareStatusBar to $VERSION"
git push origin "HEAD:$TAP_BRANCH"
