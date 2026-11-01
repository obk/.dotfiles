<#
.SYNOPSIS
    Windows dotfiles installer: copies configs into place and installs packages with scoop.

.DESCRIPTION
    Every file listed in $Files is copied to its target location. Targets that
    already match the repo are left alone; anything else at the target is moved
    to ~\.dotfiles-backup\<timestamp>\ first.

    Shared configs (git, oh-my-posh, zed) live in .config\ and are used by
    macOS too; Windows-only configs and package lists live in windows\.
    Shared Claude Code settings in .claude\settings.json are merged into
    ~\.claude\settings.json, keeping keys only this machine has.

    When started from Windows PowerShell 5.1 it installs scoop and
    PowerShell 7 if missing and re-runs itself with pwsh.

.EXAMPLE
    ./windows.ps1 -DryRun          # show what would happen
    ./windows.ps1                  # copy configs + install packages
    ./windows.ps1 -SkipPackages    # only copy configs
    ./windows.ps1 -Export          # copy live configs + package lists back into the repo
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipPackages,
    [switch]$Export
)

# Kept compatible with Windows PowerShell 5.1 up to the pwsh re-run, since
# that's what a fresh Windows install has.
$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "    $msg" }
function Write-Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

function Update-Path {
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'User') + ';' +
                [Environment]::GetEnvironmentVariable('PATH', 'Machine')
}

function Install-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) { return }
    Write-Step 'Installing scoop'
    if ((Get-ExecutionPolicy) -in 'Restricted', 'Undefined') {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }
    Invoke-RestMethod https://get.scoop.sh | Invoke-Expression
    Update-Path
}

function Install-ScoopApp($name, $command) {
    if (Get-Command $command -ErrorAction SilentlyContinue) { return }
    Write-Step "Installing $name"
    scoop install $name
    Update-Path
}

# --- powershell 7 ------------------------------------------------------------

$Root = $PSScriptRoot

# Re-run under PowerShell 7 when started from the stock Windows PowerShell 5.1
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $forward = @()
    if ($DryRun) { $forward += '-DryRun' }
    if ($SkipPackages) { $forward += '-SkipPackages' }
    if ($Export) { $forward += '-Export' }
    Install-Scoop
    Install-ScoopApp pwsh pwsh
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'windows.ps1') @forward
    return
}

# --- configs -----------------------------------------------------------------

$BackupDir = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# repo path -> target path
$Files = [ordered]@{
    '.config\git\config'                                  = "$HOME\.config\git\config"
    '.config\git\ignore'                                  = "$HOME\.config\git\ignore"
    '.config\oh-my-posh\obk.toml'                         = "$HOME\.config\oh-my-posh\obk.toml"
    '.ssh\config'                                         = "$HOME\.ssh\config"
    'windows\powershell\Microsoft.PowerShell_profile.ps1' = $PROFILE.CurrentUserCurrentHost
    '.config\zed\settings.json'                           = "$env:APPDATA\Zed\settings.json"
    '.config\gh\config.yml'                               = "$env:APPDATA\GitHub CLI\config.yml"
    '.config\herdr\config.toml'                           = "$HOME\.config\herdr\config.toml"
    '.config\herdr\config-gpui.local.toml'                = "$HOME\.config\herdr\config-gpui.local.toml"
    'windows\windows-terminal\settings.json'              = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
}

function Test-SameContent($a, $b) {
    # links (e.g. from an older link-based install) always count as different,
    # so they get replaced with a real copy
    if ((Get-Item -LiteralPath $b -Force).LinkType) { return $false }
    return (Get-FileHash -LiteralPath $a).Hash -eq (Get-FileHash -LiteralPath $b).Hash
}

function Install-File($source, $target) {
    if (Test-Path -LiteralPath $target) {
        if (Test-SameContent $source $target) {
            Write-Info "ok      $target"
            return
        }
        $backup = Join-Path $BackupDir ($target -replace '^[A-Za-z]:\\', '')
        Write-Info "backup  $target -> $backup"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force (Split-Path $backup) | Out-Null
            Move-Item -LiteralPath $target -Destination $backup
        }
    }

    Write-Info "copy    $source -> $target"
    if ($DryRun) { return }

    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target
}

function Read-List($path) {
    Get-Content $path | ForEach-Object Trim | Where-Object { $_ -and -not $_.StartsWith('#') }
}

# Claude Code keeps one ~/.claude/settings.json that mixes shared preferences
# with machine-only keys (hooks, auto mode). The repo's keys are merged into it
# instead of replacing the file, so this machine's own keys are kept.
$ClaudeSettings = "$HOME\.claude\settings.json"

function Read-Json($path) {
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
}

function Merge-ClaudeSettings {
    $shared = Read-Json "$Root\.claude\settings.json"
    $exists = Test-Path -LiteralPath $ClaudeSettings
    try { $live = if ($exists) { Read-Json $ClaudeSettings } else { [ordered]@{} } } catch { $live = $null }
    if ($live -isnot [System.Collections.IDictionary]) { # empty, broken or not an object: skip, like mac/linux
        Write-Warn "skip    $ClaudeSettings (couldn't read it as JSON)"
        return
    }
    $before = $live | ConvertTo-Json -Depth 32
    foreach ($key in $shared.Keys) {
        if ($shared[$key] -is [System.Collections.IDictionary] -and $live[$key] -is [System.Collections.IDictionary]) {
            foreach ($sub in $shared[$key].Keys) { $live[$key][$sub] = $shared[$key][$sub] }
        } else {
            $live[$key] = $shared[$key]
        }
    }
    $after = $live | ConvertTo-Json -Depth 32
    if ($exists -and $after -eq $before) {
        Write-Info "ok      $ClaudeSettings"
        return
    }
    if ($exists) {
        $backup = Join-Path $BackupDir '.claude\settings.json'
        Write-Info "backup  $ClaudeSettings -> $backup"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force (Split-Path $backup) | Out-Null
            Copy-Item -LiteralPath $ClaudeSettings -Destination $backup
        }
    }
    Write-Info "merge   .claude\settings.json -> $ClaudeSettings"
    if ($DryRun) { return }
    New-Item -ItemType Directory -Force (Split-Path $ClaudeSettings) | Out-Null
    Set-Content -LiteralPath $ClaudeSettings -Value $after
}

# Copy the current values of the repo's keys from the live settings back into the repo.
function Export-ClaudeSettings {
    if (-not (Test-Path -LiteralPath $ClaudeSettings)) {
        Write-Info "missing $ClaudeSettings"
        return
    }
    $repoFile = "$Root\.claude\settings.json"
    $shared = Read-Json $repoFile
    try { $live = Read-Json $ClaudeSettings } catch { $live = $null }
    if ($live -isnot [System.Collections.IDictionary]) {
        Write-Warn "skip    .claude\settings.json ($ClaudeSettings isn't valid JSON)"
        return
    }
    $new = [ordered]@{}
    foreach ($key in $shared.Keys) { if ($live.Contains($key)) { $new[$key] = $live[$key] } }
    $json = $new | ConvertTo-Json -Depth 32
    if ($json -eq ($shared | ConvertTo-Json -Depth 32)) { return }
    Write-Info 'updated .claude\settings.json'
    if (-not $DryRun) { Set-Content -LiteralPath $repoFile -Value $json }
}

# Fonts ship with the repo (fonts\), installed for this user only (no admin needed).
function Install-Fonts {
    $dir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $changed = $false
    foreach ($font in Get-ChildItem "$Root\fonts\*\*.ttf") {
        $target = Join-Path $dir $font.Name
        if ((Test-Path -LiteralPath $target) -and
            (Get-FileHash -LiteralPath $target).Hash -eq (Get-FileHash -LiteralPath $font.FullName).Hash) { continue }
        $changed = $true
        Write-Info "font    $($font.Name)"
        if ($DryRun) { continue }
        try {
            New-Item -ItemType Directory -Force $dir | Out-Null
            Copy-Item -LiteralPath $font.FullName -Destination $target -Force
            New-ItemProperty -Path $reg -Name "$($font.BaseName) (TrueType)" -Value $target -PropertyType String -Force | Out-Null
        } catch {
            Write-Warn "skip    $($font.Name) (in use? close apps using it and re-run)"
        }
    }
    if (-not $changed) { Write-Info "ok      $dir" }
}

# Commits are signed with user.signingKey (.config\git\config). git verifies
# signatures against gpg.ssh.allowedSignersFile, so list that key there.
# Other entries in the file are kept.
function Add-AllowedSigner {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warn 'skip    allowed_signers (git not installed yet)'
        return
    }
    $config = "$Root\.config\git\config"
    $key = git config -f $config --path user.signingKey
    $file = git config -f $config --path gpg.ssh.allowedSignersFile
    $email = git config -f $config user.email
    if (-not (Test-Path -LiteralPath $key)) {
        Write-Info "skip    $file (no $key on this machine yet)"
        return
    }
    $line = "$email " + ((Get-Content -LiteralPath $key -TotalCount 1).Split(' ')[0..1] -join ' ')
    if ((Test-Path -LiteralPath $file) -and ((Get-Content -LiteralPath $file) -contains $line)) {
        Write-Info "ok      $file"
        return
    }
    Write-Info "signer  $email -> $file"
    if ($DryRun) { return }
    # LF only: ssh-keygen reads this file and a trailing CR would break the key
    [IO.File]::AppendAllText($file, "$line`n")
}

# --- export ------------------------------------------------------------------

if ($Export) {
    Write-Step 'Copying live configs back into the repo'
    if ($DryRun) { Write-Warn 'dry run, nothing will be changed' }
    foreach ($entry in $Files.GetEnumerator()) {
        $repoFile = Join-Path $Root $entry.Key
        $live = $entry.Value
        if (-not (Test-Path -LiteralPath $live)) {
            Write-Info "missing $live"
            continue
        }
        if ((Get-FileHash -LiteralPath $live).Hash -eq (Get-FileHash -LiteralPath $repoFile).Hash) { continue }
        Write-Info "updated $($entry.Key)"
        if (-not $DryRun) { Copy-Item -LiteralPath $live -Destination $repoFile }
    }
    Export-ClaudeSettings

    Write-Step 'Updating package lists'
    if ($DryRun) { return }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop bucket list | ForEach-Object Name | Set-Content "$Root\windows\packages\scoop-buckets.txt"
        scoop list 6>$null | ForEach-Object Name | Where-Object { $_ -ne 'scoop' } |
            Set-Content "$Root\windows\packages\scoop-apps.txt"
        Write-Info 'windows\packages\scoop-buckets.txt, scoop-apps.txt'
    }

    Write-Step 'Changes in the repo (review with git diff, then commit)'
    git -C $Root status --short
    return
}

Write-Step 'Copying dotfiles'
if ($DryRun) { Write-Warn 'dry run, nothing will be changed' }
foreach ($entry in $Files.GetEnumerator()) {
    $source = Join-Path $Root $entry.Key
    $target = $entry.Value
    if ($entry.Key -like 'windows\windows-terminal\*' -and -not (Test-Path (Split-Path (Split-Path $target)))) {
        Write-Info "skip    $target (Windows Terminal not installed)"
        continue
    }
    Install-File $source $target
}
Merge-ClaudeSettings
Install-Fonts
Add-AllowedSigner
if (Test-Path $BackupDir) { Write-Info "replaced files were backed up to $BackupDir" }

if ($SkipPackages) { return }

# --- scoop -------------------------------------------------------------------

Write-Step 'Scoop'
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Info 'installing scoop'
    if (-not $DryRun) { Install-Scoop }
}

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    # git is needed before buckets can be added
    if (-not $DryRun -and -not (scoop list git 6>$null)) { scoop install git }

    $haveBuckets = @(scoop bucket list | ForEach-Object Name)
    foreach ($bucket in Read-List "$Root\windows\packages\scoop-buckets.txt") {
        if ($bucket -in $haveBuckets) { continue }
        Write-Info "bucket  $bucket"
        if (-not $DryRun) { scoop bucket add $bucket }
    }

    $haveApps = @(scoop list 6>$null | ForEach-Object Name)
    foreach ($app in Read-List "$Root\windows\packages\scoop-apps.txt") {
        if ($app -in $haveApps) { continue }
        Write-Info "app     $app"
        if (-not $DryRun) { scoop install $app }
    }
}

# --- claude code -------------------------------------------------------------

# Official installer (verifies the download, sets up the claude command). It runs
# in its own pwsh because it sets strict mode and calls exit, which would leak
# into this script if run with irm | iex here.
Write-Step 'Claude Code'
if (-not (Get-Command claude -ErrorAction SilentlyContinue) -and -not (Test-Path "$HOME\.local\bin\claude.exe")) {
    Write-Info 'install via https://claude.ai/install.ps1'
    if (-not $DryRun) {
        & pwsh -NoProfile -ExecutionPolicy Bypass -Command 'irm https://claude.ai/install.ps1 | iex'
        if ($LASTEXITCODE -ne 0) { Write-Warn 'Claude Code install failed, skipping' }
        Update-Path
    }
} else {
    Write-Info 'ok      already installed'
}

# --- zed ---------------------------------------------------------------------

# Installed with winget, not scoop: scoop's zed warns that its auto-updater
# can install into unintended locations. Extensions come from
# auto_install_extensions in .config\zed\settings.json; zed installs them itself.
Write-Step 'Zed'
if (-not (Get-Command zed -ErrorAction SilentlyContinue)) {
    Write-Info 'install ZedIndustries.Zed (winget)'
    if (-not $DryRun) {
        winget install --id ZedIndustries.Zed --exact --source winget `
            --accept-package-agreements --accept-source-agreements
        Update-Path
    }
}

Write-Step 'Done'
