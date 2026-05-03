# mimicode Windows Installer (PowerShell)
# Run with: irm https://trymimicode.github.io/install.ps1 | iex

param(
    [switch]$Force = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$GITHUB_REPO = "https://github.com/alvinliju/mimicode"
$INSTALL_DIR = "$env:LOCALAPPDATA\mimicode"
$BIN_DIR = "$env:LOCALAPPDATA\mimicode\bin"
$VENV_DIR = "$INSTALL_DIR\venv"

# Helper functions
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "→ $Text" -ForegroundColor Yellow
}

function Exit-WithError {
    param([string]$Message)
    Write-Error-Custom $Message
    exit 1
}

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Install-Ripgrep {
    Write-Info "Installing ripgrep..."

    # Try scoop first (most reliable)
    if (Test-CommandExists scoop) {
        try {
            scoop install ripgrep
            Write-Success "ripgrep installed via scoop"
            return
        }
        catch {
            Write-Info "scoop install failed, trying alternatives..."
        }
    }

    # Try chocolatey
    if (Test-CommandExists choco) {
        try {
            choco install ripgrep -y
            Write-Success "ripgrep installed via chocolatey"
            return
        }
        catch {
            Write-Info "chocolatey install failed, trying alternatives..."
        }
    }

    # Try winget (Windows 11)
    if (Test-CommandExists winget) {
        try {
            winget install BurntSushi.ripgrep
            Write-Success "ripgrep installed via winget"
            return
        }
        catch {
            Write-Info "winget install failed, trying direct download..."
        }
    }

    # Manual download fallback
    Write-Info "Downloading ripgrep manually..."
    $RipgrepVersion = "14.1.0"
    $RipgrepUrl = "https://github.com/BurntSushi/ripgrep/releases/download/$RipgrepVersion/ripgrep-$RipgrepVersion-x86_64-pc-windows-msvc.zip"

    try {
        $TempDir = New-Item -ItemType Directory -Path "$env:TEMP\ripgrep_install" -Force | Select-Object -ExpandProperty FullName
        $ZipPath = "$TempDir\ripgrep.zip"

        Write-Info "Downloading from GitHub..."
        Invoke-WebRequest -Uri $RipgrepUrl -OutFile $ZipPath -ErrorAction Stop

        Write-Info "Extracting..."
        Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force

        # Find rg.exe and copy to bin
        $RgExe = Get-ChildItem -Path $TempDir -Filter "rg.exe" -Recurse | Select-Object -First 1
        if ($RgExe) {
            $BinPath = "$INSTALL_DIR\bin"
            New-Item -ItemType Directory -Path $BinPath -Force | Out-Null
            Copy-Item -Path $RgExe.FullName -Destination "$BinPath\rg.exe" -Force
            Write-Success "ripgrep installed"

            # Add to PATH if needed
            Add-ToPATH $BinPath
        }
        else {
            Exit-WithError "Could not find rg.exe in downloaded archive"
        }

        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Exit-WithError "Failed to install ripgrep: $_`n`nPlease install manually from: https://github.com/BurntSushi/ripgrep/releases"
    }
}

function Add-ToPATH {
    param([string]$Path)

    $CurrentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($CurrentPath -notlike "*$Path*") {
        Write-Info "Adding $Path to user PATH..."
        [Environment]::SetEnvironmentVariable("PATH", "$Path;$CurrentPath", "User")

        # Also add to current session
        $env:PATH = "$Path;$env:PATH"
        Write-Success "Added to PATH"
    }
}

function Check-Prerequisites {
    Write-Header "Checking Prerequisites"

    # Check Python 3
    if (-not (Test-CommandExists python)) {
        Exit-WithError "Python 3 is not installed.`n`nDownload from: https://www.python.org/downloads`n`nMake sure to check 'Add Python to PATH' during installation."
    }

    $PythonVersion = python --version 2>&1
    Write-Success "Found: $PythonVersion"

    # Check pip
    if (-not (Test-CommandExists pip)) {
        Exit-WithError "pip is not installed. Try: python -m ensurepip --upgrade"
    }
    Write-Success "pip found"

    # Check/install ripgrep
    if (-not (Test-CommandExists rg)) {
        Write-Info "ripgrep not found"
        Install-Ripgrep
    }
    else {
        Write-Success "ripgrep found"
    }

    # Check git (optional)
    if (-not (Test-CommandExists git)) {
        Write-Info "git not found (optional, for future updates)"
    }
    else {
        Write-Success "git found"
    }
}

function Clone-Mimicode {
    Write-Header "Setting Up mimicode"

    if (Test-Path $INSTALL_DIR) {
        Write-Info "mimicode already exists at $INSTALL_DIR"
        Write-Info "Updating existing installation..."

        Push-Location $INSTALL_DIR
        if (Test-Path ".git") {
            try {
                git pull origin main 2>$null
                Write-Info "Repository updated"
            }
            catch {
                Write-Info "Could not pull latest version"
            }
        }
        Pop-Location
    }
    else {
        Write-Info "Cloning mimicode to $INSTALL_DIR..."

        try {
            git clone $GITHUB_REPO $INSTALL_DIR -q
            Write-Success "Repository cloned"
        }
        catch {
            Exit-WithError "Failed to clone repository: $_`n`nMake sure git is installed and you have internet connection."
        }
    }

    Write-Success "mimicode ready at $INSTALL_DIR"
}

function Setup-PythonEnv {
    Write-Header "Setting Up Python Environment"

    Push-Location $INSTALL_DIR

    # Create virtual environment
    if (-not (Test-Path $VENV_DIR)) {
        Write-Info "Creating virtual environment..."
        python -m venv $VENV_DIR
        Write-Success "Virtual environment created"
    }
    else {
        Write-Info "Virtual environment already exists"
    }

    # Activate venv and install dependencies
    Write-Info "Installing Python dependencies..."
    & "$VENV_DIR\Scripts\pip.exe" install --upgrade pip setuptools wheel *>$null
    & "$VENV_DIR\Scripts\pip.exe" install -r requirements.txt *>$null

    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Failed to install Python dependencies"
    }

    Write-Success "Python dependencies installed"
    Pop-Location
}

function Create-Wrapper {
    Write-Header "Creating Command Wrapper"

    # Create bin directory
    New-Item -ItemType Directory -Path $BIN_DIR -Force | Out-Null

    # Create batch wrapper
    $WrapperPath = "$BIN_DIR\mimicode.cmd"
    @"
@echo off
setlocal
call "$VENV_DIR\Scripts\activate.bat"
python "$INSTALL_DIR\agent.py" %*
endlocal
"@ | Set-Content -Path $WrapperPath -Encoding ASCII

    Write-Success "Wrapper script created at $WrapperPath"

    # Add to PATH
    Add-ToPATH $BIN_DIR
}

function Verify-Installation {
    Write-Header "Verifying Installation"

    Push-Location $INSTALL_DIR

    # Run dependency check
    try {
        & "$VENV_DIR\Scripts\python.exe" check_deps.py *>$null
        Write-Success "All dependencies verified"
    }
    catch {
        Write-Info "Some dependencies may need attention, but mimicode should work"
    }

    Pop-Location
}

function Show-Usage {
    Write-Header "Installation Complete!"

    Write-Host ""
    Write-Host "mimicode is ready to use!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Quick start:"
    Write-Host "  mimicode              # Start interactive mode" -ForegroundColor Yellow
    Write-Host "  mimicode ""prompt""    # Run a single task" -ForegroundColor Yellow
    Write-Host "  mimicode --tui        # Start TUI mode" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Set your API key:"
    Write-Host "  `$env:ANTHROPIC_API_KEY = ""sk-ant-...""" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Location: $INSTALL_DIR"
    Write-Host ""
    Write-Host "Need help? Run: mimicode --help"
    Write-Host ""
}

# Main installation flow
function Install-Mimicode {
    Write-Header "mimicode Installer"

    Check-Prerequisites
    Clone-Mimicode
    Setup-PythonEnv
    Create-Wrapper
    Verify-Installation
    Show-Usage
}

# Run installation
Install-Mimicode
