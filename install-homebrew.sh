#!/usr/bin/env bash
set -euo pipefail

TAP="kellertobias/tosk-tag"
TAP_URL="https://github.com/kellertobias/tosk-tag.git"
CASK="$TAP/tosk-tag"

if [[ "$(/usr/bin/uname -s)" != "Darwin" ]]; then
  echo "error: Tosk Tag requires macOS." >&2
  exit 69
fi

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    printf '%s\n' /opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    printf '%s\n' /usr/local/bin/brew
  fi
}

BREW_BIN="$(find_brew || true)"

if [[ -z "$BREW_BIN" ]]; then
  echo "==> Installing Homebrew and Apple's required developer tools"
  /bin/bash -c "$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(find_brew || true)"
fi

if [[ -z "$BREW_BIN" ]]; then
  echo "error: Homebrew installation did not provide a usable brew command." >&2
  exit 69
fi

eval "$("$BREW_BIN" shellenv)"

if ! /usr/bin/xcrun --find swift >/dev/null 2>&1; then
  echo "==> Installing Apple's Swift build tools"
  /usr/bin/xcode-select --install 2>/dev/null || true
  echo "==> Waiting for the Command Line Tools installation to finish"
  until /usr/bin/xcrun --find swift >/dev/null 2>&1; do
    /bin/sleep 10
  done
fi

echo "==> Adding the Tosk Tag tap"
brew tap "$TAP" "$TAP_URL"

if brew list --cask tosk-tag >/dev/null 2>&1; then
  echo "==> Rebuilding and reinstalling Tosk Tag from the latest source"
  brew reinstall --cask "$CASK"
else
  echo "==> Building and installing Tosk Tag from source"
  brew install --cask "$CASK"
fi

echo "==> Tosk Tag is installed in /Applications"
