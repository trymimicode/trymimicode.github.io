#Requires -Version 5.1
<#
.SYNOPSIS
    mimicode installer for Windows.

.DESCRIPTION
    Downloads a prebuilt mimicode binary (no Go toolchain required) and installs
    it to a per-user location, then adds that location to your user PATH so you
    can run `mimicode` from any terminal. No administrator rights required.

.EXAMPLE
    irm https://raw.githubusercontent.com/trymimicode/mimicode-go/main/install.ps1 | iex

.EXAMPLE
    # Override the install location:
    $env:INSTALL_DIR = "C:\tools\mimicode"; .\install.ps1
#>

$ErrorActionPreference = "Stop"

$Repo       = "trymimicode/mimicode-go"
$BinaryName = "mimicode"
$BaseUrl    = if ($env:MIMICODE_BASE_URL) { $env:MIMICODE_BASE_URL } else { "https://github.com/$Repo/releases/latest/download" }

# Per-user, no-admin location. Added to the user PATH below so `mimicode` works
# from anywhere.
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "Programs\mimicode" }

Write-Host "Installing mimicode..." -ForegroundColor Cyan

# ── Detect architecture and download the prebuilt binary ─────────────────────
$arch = if ([Environment]::Is64BitOperatingSystem) {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
} else { "amd64" }

$asset = "$BinaryName-windows-$arch.exe"
$url   = "$BaseUrl/$asset"
$tmp   = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N") + ".exe")

Write-Host "  Downloading $asset..."
try {
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "ERR Could not download a prebuilt binary for windows/$arch." -ForegroundColor Red
    Write-Host "    Check available downloads at https://github.com/$Repo/releases"
    exit 1
}

# ── Install ──────────────────────────────────────────────────────────────────
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
$dest = Join-Path $InstallDir "$BinaryName.exe"
Move-Item -Path $tmp -Destination $dest -Force
Write-Host "OK  $BinaryName installed to $dest" -ForegroundColor Green

# ── Add install dir to the user PATH (persistent) and current session ────────
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
$paths = $userPath.Split(';') | Where-Object { $_ -ne "" }
if ($paths -notcontains $InstallDir) {
    $newPath = (@($InstallDir) + $paths) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "OK  Added $InstallDir to your user PATH" -ForegroundColor Green
    Write-Host "    (Open a new terminal for the PATH change to take effect.)"
} else {
    Write-Host "OK  PATH entry already present" -ForegroundColor Green
}
if (($env:Path -split ';') -notcontains $InstallDir) {
    $env:Path = "$InstallDir;$env:Path"
}

# ── Verify ───────────────────────────────────────────────────────────────────
try {
    & $dest --version | Out-Null
} catch {
    Write-Host "WARN Installed but 'mimicode --version' failed - check the output above." -ForegroundColor Yellow
}

# ── Dependency / environment checks ──────────────────────────────────────────
if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "WARN ripgrep (rg) is required but not installed." -ForegroundColor Yellow
    Write-Host "     Install: winget install BurntSushi.ripgrep.MSVC"
}

if (-not $env:ANTHROPIC_API_KEY) {
    Write-Host ""
    Write-Host "WARN ANTHROPIC_API_KEY not set." -ForegroundColor Yellow
    Write-Host "     Get a key at https://console.anthropic.com/settings/keys then set it:"
    Write-Host "       setx ANTHROPIC_API_KEY `"your-key-here`""
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage:"
Write-Host "  mimicode `"add tests to calc.go`""
Write-Host "  mimicode --tui"
Write-Host "  mimicode -s myfeature `"continue working`""
Write-Host ""
Write-Host "Docs: https://github.com/$Repo"
