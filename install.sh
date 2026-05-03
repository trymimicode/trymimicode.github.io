#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="https://github.com/alvinliju/mimicode"
INSTALL_DIR="$HOME/.local/mimicode"
BIN_DIR="$HOME/.local/bin"
VENV_DIR="$INSTALL_DIR/venv"

# Helper functions
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

fail() {
    print_error "$1"
    exit 1
}

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        fail "Unsupported OS: $OSTYPE"
    fi
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

install_ripgrep() {
    print_info "Installing ripgrep..."

    if check_command brew; then
        brew install ripgrep
    elif check_command apt-get; then
        sudo apt-get update && sudo apt-get install -y ripgrep
    elif check_command dnf; then
        sudo dnf install -y ripgrep
    elif check_command pacman; then
        sudo pacman -S --noconfirm ripgrep
    elif check_command zypper; then
        sudo zypper install -y ripgrep
    else
        fail "Could not determine package manager. Please install ripgrep manually from https://github.com/BurntSushi/ripgrep/releases"
    fi

    if check_command rg; then
        print_success "ripgrep installed"
    else
        fail "ripgrep installation failed"
    fi
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check Python 3
    if ! check_command python3; then
        fail "Python 3 is not installed. Please install Python 3.9+ first."
    fi
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    print_success "Python $PYTHON_VERSION found"

    # Check pip
    if ! check_command pip3; then
        fail "pip3 is not installed. Please install pip3."
    fi
    print_success "pip3 found"

    # Check/install ripgrep
    if ! check_command rg; then
        print_info "ripgrep not found"
        install_ripgrep
    else
        print_success "ripgrep found"
    fi

    # Warn about git (optional but recommended)
    if ! check_command git; then
        print_info "git not found (recommended for future updates)"
    else
        print_success "git found"
    fi
}

clone_mimicode() {
    print_header "Setting Up mimicode"

    if [ -d "$INSTALL_DIR" ]; then
        print_info "mimicode already exists at $INSTALL_DIR"
        print_info "Updating existing installation..."
        cd "$INSTALL_DIR"
        if [ -d ".git" ]; then
            git pull origin main 2>/dev/null || print_info "Could not pull latest (offline or not a git repo)"
        fi
    else
        print_info "Cloning mimicode to $INSTALL_DIR..."
        mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone "$GITHUB_REPO" "$INSTALL_DIR" || fail "Failed to clone repository"
    fi

    print_success "mimicode ready at $INSTALL_DIR"
}

setup_python_env() {
    print_header "Setting Up Python Environment"

    cd "$INSTALL_DIR"

    # Create virtual environment
    if [ ! -d "$VENV_DIR" ]; then
        print_info "Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
        print_success "Virtual environment created"
    else
        print_info "Virtual environment already exists"
    fi

    # Activate and install dependencies
    print_info "Installing Python dependencies..."
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel > /dev/null 2>&1
    pip install -r requirements.txt > /dev/null 2>&1 || fail "Failed to install dependencies"
    print_success "Python dependencies installed"
}

add_to_path() {
    print_header "Adding to PATH"

    mkdir -p "$BIN_DIR"

    # Create wrapper script
    WRAPPER="$BIN_DIR/mimicode"
    cat > "$WRAPPER" << 'EOF'
#!/bin/bash
source "$HOME/.local/mimicode/venv/bin/activate"
exec python3 "$HOME/.local/mimicode/agent.py" "$@"
EOF

    chmod +x "$WRAPPER"
    print_success "Wrapper script created at $WRAPPER"

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        print_success "$BIN_DIR is already in PATH"
    else
        print_info "Adding $BIN_DIR to PATH..."

        # Detect shell
        if [ -n "$ZSH_VERSION" ]; then
            SHELL_RC="$HOME/.zshrc"
        else
            SHELL_RC="$HOME/.bashrc"
        fi

        if ! grep -q "$BIN_DIR" "$SHELL_RC"; then
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
            print_success "Added to $SHELL_RC"
        fi

        print_info "Run this to update your current shell:"
        print_info "  source $SHELL_RC"
    fi
}

verify_installation() {
    print_header "Verifying Installation"

    source "$VENV_DIR/bin/activate"
    cd "$INSTALL_DIR"

    # Run dependency check
    if python3 check_deps.py > /dev/null 2>&1; then
        print_success "All dependencies verified"
    else
        print_info "Running dependency check..."
        python3 check_deps.py || print_info "Some dependencies may need attention, but mimicode should work"
    fi
}

show_usage() {
    print_header "Installation Complete!"

    echo ""
    echo -e "${GREEN}mimicode is ready to use!${NC}"
    echo ""
    echo "Quick start:"
    echo -e "  ${YELLOW}mimicode${NC}              # Start interactive mode"
    echo -e "  ${YELLOW}mimicode \"prompt\"${NC}    # Run a single task"
    echo -e "  ${YELLOW}mimicode --tui${NC}        # Start TUI mode"
    echo ""
    echo "Set your API key:"
    echo -e "  ${YELLOW}export ANTHROPIC_API_KEY=\"sk-ant-...\"${NC}"
    echo ""
    echo "Location: $INSTALL_DIR"
    echo ""
    echo "Need help? Run: mimicode --help"
    echo ""
}

# Main installation flow
main() {
    print_header "mimicode Installer"

    detect_os
    check_prerequisites
    clone_mimicode
    setup_python_env
    add_to_path
    verify_installation
    show_usage
}

main "$@"
