#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! DEVELOPER_DIR="$(/usr/bin/xcode-select -p 2>/dev/null)"; then
  echo "error: Apple Command Line Tools are unavailable." >&2
  echo "Run install-homebrew.sh so Homebrew can provision them." >&2
  exit 69
fi

export DEVELOPER_DIR
export ENV_FILE="/dev/null"
export ARCHIVE_DIR="$ROOT_DIR/.build/homebrew-archive"
export ARCHIVE_APP_PATH="${HOMEBREW_APP_PATH:-$ROOT_DIR/Tobisk Tag Editor.app}"
export CODE_SIGN_IDENTITY="-"

"$ROOT_DIR/build" archive

# A locally compiled app should not inherit the downloaded source tree's
# quarantine marker.
/usr/bin/xattr -dr com.apple.quarantine "$ARCHIVE_APP_PATH" 2>/dev/null || true
