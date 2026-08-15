<#
    Build the VBNote installer (Universal x64 / ARM64).

    Usage:
      .\build.ps1                   # Automatically detects native architecture
      .\build.ps1 -Architecture arm64
      .\build.ps1 -Architecture x64
#>
[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')]
    [string]$Architecture,

    # Skip the Rust build, for when only the wizard or the script changed.
    [switch]$SkipEmulator
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Auto-detect architecture if not specified
if (-not $Architecture) {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        $Architecture = 'arm64'
    } else {
        $Architecture = 'x64'
    }
}
Write-Host "Target Architecture: $Architecture" -ForegroundColor Yellow

function Need($what, $test, $hint) {
    if (-not (& $test)) {
        Write-Error "$what is needed and was not found.`n  $hint"
    }
}

Need 'cargo' { Get-Command cargo -ErrorAction SilentlyContinue } `
     'Install Rust from https://rustup.rs'
Need 'PyInstaller' { python -m PyInstaller --version 2>$null } `
     'pip install pyinstaller'

$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 7\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
    Write-Error "Inno Setup is needed and was not found.`n  https://jrsoftware.org/isdl.php"
}

# --- 1. the emulator -------------------------------------------------------
if ($Architecture -eq 'arm64') {
    $targetFlag = @('--target', 'aarch64-pc-windows-msvc')
    $targetExePath = 'target\aarch64-pc-windows-msvc\release\vbnote.exe'
} else {
    $targetFlag = @()
    $targetExePath = 'target\release\vbnote.exe'
}

if (-not $SkipEmulator) {
    Write-Host 'Building the emulator...' -ForegroundColor Cyan
    cargo build --release @targetFlag
    if ($LASTEXITCODE -ne 0) { Write-Error 'the emulator did not build' }
}

if (-not (Test-Path $targetExePath)) {
    Write-Error "$targetExePath is missing"
}

# --- 2. the wizard ---------------------------------------------------------
Write-Host 'Freezing the setup wizard...' -ForegroundColor Cyan
if (Test-Path 'dist\wizard') { Remove-Item -Recurse -Force 'dist\wizard' }

python -m PyInstaller `
    --noconfirm --clean --windowed `
    --name 'VBNote Setup' `
    --distpath 'dist\pyinstaller' `
    --workpath 'build\pyinstaller' `
    --specpath 'build' `
    --paths . `
    --hidden-import wizard.flashdisk `
    --hidden-import wizard.provision `
    --hidden-import wizard.wizard `
    'vbnote_setup.py'

if ($LASTEXITCODE -ne 0) { Write-Error 'the wizard did not freeze' }

New-Item -ItemType Directory -Force -Path 'dist' | Out-Null
Move-Item 'dist\pyinstaller\VBNote Setup' 'dist\wizard'
Remove-Item -Recurse -Force 'dist\pyinstaller'

Write-Host 'Checking the frozen wizard starts...' -ForegroundColor Cyan
$wizardExe = 'dist\wizard\VBNote Setup.exe'
if (-not (Test-Path $wizardExe)) { Write-Error "$wizardExe was not built" }
$check = Start-Process -FilePath $wizardExe -ArgumentList '--selftest' -Wait -PassThru -NoNewWindow
if ($check.ExitCode -ne 0) {
    Write-Error "the frozen wizard did not start (exit $($check.ExitCode))"
}

# --- 3. NVDA's controller client -------------------------------------------
$nvdaVersion = '2024.4.2'
$nvdaDll     = 'nvdaControllerClient.dll'
$nvdaLicence = 'installer\nvda-controllerclient-license.txt'

if ($Architecture -eq 'arm64') {
    $nvdaSubdir = 'arm64'
    $nvdaSha    = '3387d977006fe4fff07780bf8e8eff1ef23f98316f469853c7639727ec9d5481'
} else {
    $nvdaSubdir = 'x64'
    $nvdaSha    = '0853530a19746f8748994f234ed33589ac255badee41daf82aba47934b5235fb'
}

# Check if DLL exists and matches target architecture hash; if not, re-fetch
$needsFetch = $false
if (-not (Test-Path $nvdaDll) -or -not (Test-Path $nvdaLicence)) {
    $needsFetch = $true
} else {
    $currentHash = (Get-FileHash $nvdaDll -Algorithm SHA256).Hash.ToLower()
    if ($currentHash -ne $nvdaSha) { $needsFetch = $true }
}

if ($needsFetch) {
    Write-Host "Fetching NVDA's controller client ($Architecture) $nvdaVersion..." -ForegroundColor Cyan
    $url = "https://download.nvaccess.org/releases/$nvdaVersion/nvda_${nvdaVersion}_controllerClient.zip"
    $zip = Join-Path $env:TEMP "nvda-controllerclient-$nvdaVersion.zip"
    $out = Join-Path $env:TEMP "nvda-controllerclient-$nvdaVersion"
    if (-not (Test-Path $zip)) { Invoke-WebRequest -Uri $url -OutFile $zip }
    if (Test-Path $out) { Remove-Item -Recurse -Force $out }
    Expand-Archive $zip -DestinationPath $out
    Copy-Item (Join-Path $out "$nvdaSubdir\nvdaControllerClient.dll") $nvdaDll -Force
    Copy-Item (Join-Path $out 'license.txt') $nvdaLicence -Force
}

$got = (Get-FileHash $nvdaDll -Algorithm SHA256).Hash.ToLower()
if ($got -ne $nvdaSha) {
    Write-Error ("$nvdaDll hash mismatch for $Architecture.`n" +
                 "  expected $nvdaSha`n" +
                 "  found    $got`n" +
                 "  Delete $nvdaDll and build again.")
}
Write-Host "  $nvdaDll $((Get-Item $nvdaDll).Length) bytes, hash as expected for $Architecture"

# --- 4. the installer ------------------------------------------------------
Write-Host 'Building the installer...' -ForegroundColor Cyan
$log = & $iscc "/DTargetArch=$Architecture" 'installer\VBNote.iss'
$log | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { Write-Error 'the installer did not build' }

foreach ($needed in @('vbnote.exe', 'VBNote Setup.exe', $nvdaDll)) {
    if (-not ($log -match [regex]::Escape($needed))) {
        Write-Error "the installer was built without $needed"
    }
}

Get-ChildItem 'dist\*setup.exe' | ForEach-Object {
    Write-Host ("`nReady: {0} ({1:N1} MB)" -f $_.FullName, ($_.Length / 1MB)) -ForegroundColor Green
}
