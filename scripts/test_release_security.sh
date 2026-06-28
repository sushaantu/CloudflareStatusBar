#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

fail() {
  echo "error: $*" >&2
  exit 1
}

write_resolve_tag_script() {
  local output_path="$1"
  ruby -ryaml -e '
    workflow = YAML.load_file(ARGV.fetch(0))
    step = workflow.fetch("jobs").fetch("release").fetch("steps").find do |candidate|
      candidate["name"] == "Resolve tag"
    end
    raise "Resolve tag step not found" unless step
    File.write(ARGV.fetch(1), "#!/usr/bin/env bash\nset -euo pipefail\n" + step.fetch("run"))
  ' ".github/workflows/release.yml" "$output_path"
  chmod +x "$output_path"
}

test_release_workflow_tag_validation() {
  local tmp_dir resolve_script output_file pwned
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN
  resolve_script="$tmp_dir/resolve_tag.sh"
  output_file="$tmp_dir/github_output"
  pwned="$tmp_dir/pwned"
  write_resolve_tag_script "$resolve_script"

  if rg -qF 'tag="${{ inputs.tag }}"' ".github/workflows/release.yml"; then
    fail "workflow still interpolates inputs.tag directly into shell"
  fi
  rg -qF 'INPUT_TAG: ${{ inputs.tag }}' ".github/workflows/release.yml" ||
    fail "workflow no longer passes inputs.tag through an environment variable"

  if EVENT_NAME="workflow_dispatch" \
    INPUT_TAG="v1.2.3\"; touch \"$pwned\"; echo \"" \
    REF_NAME="" \
    GITHUB_OUTPUT="$output_file" \
    bash "$resolve_script" >"$tmp_dir/malicious.stdout" 2>"$tmp_dir/malicious.stderr"; then
    fail "malicious workflow_dispatch tag was accepted"
  fi
  [[ ! -e "$pwned" ]] || fail "malicious workflow_dispatch tag executed shell content"
  [[ ! -s "$output_file" ]] || fail "malicious workflow_dispatch tag wrote GitHub outputs"

  : >"$output_file"
  EVENT_NAME="workflow_dispatch" \
    INPUT_TAG="v1.2.3" \
    REF_NAME="" \
    GITHUB_OUTPUT="$output_file" \
    bash "$resolve_script" >"$tmp_dir/valid.stdout" 2>"$tmp_dir/valid.stderr"
  grep -qx "tag=v1.2.3" "$output_file" || fail "valid manual tag output missing"
  grep -qx "version=1.2.3" "$output_file" || fail "valid manual version output missing"

  : >"$output_file"
  EVENT_NAME="push" \
    INPUT_TAG="" \
    REF_NAME="v2.3.4" \
    GITHUB_OUTPUT="$output_file" \
    bash "$resolve_script" >"$tmp_dir/push.stdout" 2>"$tmp_dir/push.stderr"
  grep -qx "tag=v2.3.4" "$output_file" || fail "valid push tag output missing"
  grep -qx "version=2.3.4" "$output_file" || fail "valid push version output missing"
}

write_fake_git() {
  local output_path="$1"
  cat >"$output_path" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

command_name="$1"
shift

case "$command_name" in
  clone)
    target="${*: -1}"
    mkdir -p "$target/Casks"
    cat >"$target/Casks/cloudflare-status-bar.rb" <<'RUBY'
cask "cloudflare-status-bar" do
  version "0.0.1"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/sushaantu/CloudflareStatusBar/releases/download/v#{version}/CloudflareStatusBar-#{version}.zip"
  name "CloudflareStatusBar"
  desc "Native macOS menu bar app for Cloudflare"
  homepage "https://github.com/sushaantu/CloudflareStatusBar"
end
RUBY
    ;;
  checkout | config | add | commit | push)
    ;;
  diff)
    exit 1
    ;;
  *)
    echo "unexpected git command: $command_name" >&2
    exit 64
    ;;
esac
SH
  chmod +x "$output_path"
}

write_fake_brew() {
  local output_path="$1"
  cat >"$output_path" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_BREW_LOG:?}"
if [[ "$1" != "audit" || "$2" != "--cask" || ! -f "$3" ]]; then
  echo "unexpected brew invocation: $*" >&2
  exit 64
fi
if [[ "${FAKE_BREW_FAIL:-0}" == "1" ]]; then
  echo "fake brew audit failure" >&2
  exit 1
fi
SH
  chmod +x "$output_path"
}

test_cask_updater_validation() {
  local tmp_dir run_root fake_bin valid_sha cask_file brew_log
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN
  run_root="$tmp_dir/run"
  fake_bin="$tmp_dir/bin"
  valid_sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  mkdir -p "$run_root" "$fake_bin"

  if VERSION='1.2.3"; system("touch /tmp/cask-version-pwned") #' \
    SHA256="$valid_sha" \
    RUNNER_TEMP="$run_root" \
    scripts/update_homebrew_cask.sh >"$tmp_dir/bad-version.stdout" 2>"$tmp_dir/bad-version.stderr"; then
    fail "malicious VERSION was accepted"
  fi
  grep -q "VERSION must match" "$tmp_dir/bad-version.stderr" ||
    fail "malicious VERSION did not fail at version validation"
  [[ ! -d "$run_root/homebrew-cloudflare-status-bar" ]] ||
    fail "malicious VERSION reached tap checkout"

  if VERSION="1.2.3" \
    SHA256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; system("touch /tmp/cask-sha-pwned") #' \
    RUNNER_TEMP="$run_root" \
    scripts/update_homebrew_cask.sh >"$tmp_dir/bad-sha.stdout" 2>"$tmp_dir/bad-sha.stderr"; then
    fail "malicious SHA256 was accepted"
  fi
  grep -q "SHA256 must be" "$tmp_dir/bad-sha.stderr" ||
    fail "malicious SHA256 did not fail at sha validation"
  [[ ! -d "$run_root/homebrew-cloudflare-status-bar" ]] ||
    fail "malicious SHA256 reached tap checkout"

  write_fake_git "$fake_bin/git"
  write_fake_brew "$fake_bin/brew"
  brew_log="$tmp_dir/brew.log"
  FAKE_BREW_LOG="$brew_log" \
    PATH="$fake_bin:$PATH" \
    VERSION="1.2.3" \
    SHA256="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" \
    RUNNER_TEMP="$run_root" \
    scripts/update_homebrew_cask.sh >"$tmp_dir/valid-cask.stdout" 2>"$tmp_dir/valid-cask.stderr"

  cask_file="$run_root/homebrew-cloudflare-status-bar/Casks/cloudflare-status-bar.rb"
  grep -qx '  version "1.2.3"' "$cask_file" || fail "valid cask version was not written"
  grep -qx "  sha256 \"$valid_sha\"" "$cask_file" || fail "valid cask sha256 was not normalized and written"
  grep -qx "audit --cask Casks/cloudflare-status-bar.rb" "$brew_log" ||
    fail "brew cask audit was not run before push"

  if FAKE_BREW_LOG="$brew_log" \
    FAKE_BREW_FAIL="1" \
    PATH="$fake_bin:$PATH" \
    VERSION="1.2.3" \
    SHA256="$valid_sha" \
    REQUIRE_BREW_AUDIT="1" \
    RUNNER_TEMP="$run_root" \
    scripts/update_homebrew_cask.sh >"$tmp_dir/required-audit.stdout" 2>"$tmp_dir/required-audit.stderr"; then
    fail "required brew audit failure was ignored"
  fi
  grep -q "fake brew audit failure" "$tmp_dir/required-audit.stderr" ||
    fail "required brew audit failure was not surfaced"
}

test_release_workflow_tag_validation
test_cask_updater_validation

echo "release security checks passed"
