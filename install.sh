#!/usr/bin/env bash
set -euo pipefail

# mimicode installer (macOS & Linux)
#
# Downloads a prebuilt mimicode binary (no Go toolchain required) and installs
# it to ~/.local/bin, then adds that directory to your PATH via the correct
# profile file for your shell (zsh, bash, or fish).
#
# Quick install:
#   curl -fsSL https://raw.githubusercontent.com/trymimicode/mimicode-go/main/install.sh | bash
#
# Overrides:
#   INSTALL_DIR=$HOME/bin   ...   install location (default: ~/.local/bin)
#   MIMICODE_BASE_URL=...         release download base (used by CI tests)

REPO="trymimicode/mimicode-go"
BINARY_NAME="mimicode"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
BASE_URL="${MIMICODE_BASE_URL:-https://github.com/$REPO/releases/latest/download}"

echo "🚀 Installing mimicode..."

# ── Detect OS / architecture ─────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
    Linux)  OS="linux" ;;
    Darwin) OS="darwin" ;;
    *)      echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac
case "$ARCH" in
    x86_64)        ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)             echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# ── Download the prebuilt binary ─────────────────────────────────────────────
BINARY_FILE="$BINARY_NAME-$OS-$ARCH"
DOWNLOAD_URL="$BASE_URL/$BINARY_FILE"
TMP_BIN="$(mktemp)"
trap 'rm -f "$TMP_BIN"' EXIT

echo "  Downloading $BINARY_FILE..."
if command -v curl >/dev/null 2>&1; then
    HTTP_CODE="$(curl -fL -w '%{http_code}' -o "$TMP_BIN" "$DOWNLOAD_URL" 2>/dev/null || echo 000)"
elif command -v wget >/dev/null 2>&1; then
    if wget -qO "$TMP_BIN" "$DOWNLOAD_URL"; then HTTP_CODE="200"; else HTTP_CODE="000"; fi
else
    echo "❌ Need curl or wget to download mimicode."; exit 1
fi

if [ "$HTTP_CODE" != "200" ] || [ ! -s "$TMP_BIN" ]; then
    echo "❌ Could not download a prebuilt binary for $OS/$ARCH (HTTP $HTTP_CODE)."
    echo "   Check available downloads at https://github.com/$REPO/releases"
    exit 1
fi

# ── Install ──────────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
mv -f "$TMP_BIN" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"
trap - EXIT
echo "✓ $BINARY_NAME installed to $INSTALL_DIR/$BINARY_NAME"

# ── Add INSTALL_DIR to PATH using the right profile for the active shell ──────
add_to_path() {
    # Already reachable in this session — nothing to wire up.
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) return 0 ;;
    esac

    local shell_name profile line
    shell_name="$(basename "${SHELL:-sh}")"
    case "$shell_name" in
        zsh)
            profile="${ZDOTDIR:-$HOME}/.zshrc"
            line="export PATH=\"$INSTALL_DIR:\$PATH\""
            ;;
        bash)
            # macOS login shells read .bash_profile; Linux uses .bashrc.
            if [ "$OS" = "darwin" ]; then profile="$HOME/.bash_profile"; else profile="$HOME/.bashrc"; fi
            line="export PATH=\"$INSTALL_DIR:\$PATH\""
            ;;
        fish)
            profile="$HOME/.config/fish/config.fish"
            line="fish_add_path \"$INSTALL_DIR\""
            mkdir -p "$(dirname "$profile")"
            ;;
        *)
            profile="$HOME/.profile"
            line="export PATH=\"$INSTALL_DIR:\$PATH\""
            ;;
    esac

    touch "$profile"
    if grep -qF "$INSTALL_DIR" "$profile" 2>/dev/null; then
        echo "✓ PATH entry already present in $profile"
    else
        printf '\n# Added by mimicode installer\n%s\n' "$line" >> "$profile"
        echo "✓ Added $INSTALL_DIR to PATH in $profile"
    fi
    echo "  Restart your shell or run: source \"$profile\""
}
add_to_path

# ── Verify ───────────────────────────────────────────────────────────────────
if ! "$INSTALL_DIR/$BINARY_NAME" --version >/dev/null 2>&1; then
    echo "⚠️  Installed but '$BINARY_NAME --version' failed — check the output above."
fi

# ── Dependency / environment checks ──────────────────────────────────────────
if ! command -v rg >/dev/null 2>&1; then
    echo ""
    echo "⚠️  ripgrep (rg) is required but not installed."
    case "$OS" in
        darwin) echo "   Install: brew install ripgrep" ;;
        linux)  echo "   Install: sudo apt install ripgrep   # Debian/Ubuntu"
                echo "            sudo dnf install ripgrep   # Fedora" ;;
    esac
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo ""
    echo "⚠️  ANTHROPIC_API_KEY not set."
    echo "   Get a key at https://console.anthropic.com/settings/keys then run:"
    echo "     $BINARY_NAME key --set your-key-here"
    echo "   or set it in your shell:"
    echo "     export ANTHROPIC_API_KEY=\"your-key-here\""
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Usage:"
echo "  $BINARY_NAME \"add tests to calc.go\""
echo "  $BINARY_NAME --tui"
echo "  $BINARY_NAME -s myfeature \"continue working\""
echo ""
echo "Docs: https://github.com/$REPO"
