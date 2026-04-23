# Agnostic AI Agent Sync - Windows
# https://github.com/cliffordp/agnostic-ai-agent-sync

$Version = "1.0.0"
$ConfigFile = "$env:USERPROFILE\.agnostic-ai-agent-sync"
$userProfile = $env:USERPROFILE

# ─── Agent mapping ───────────────────────────────────────────────
function Get-AgentMap {
    $remoteUrl = "https://raw.githubusercontent.com/cliffordp/agnostic-ai-agent-sync/main/agents.map"
    $mapContent = ""
    
    try {
        $mapContent = Invoke-RestMethod -Uri $remoteUrl -TimeoutSec 2 -ErrorAction Stop
    } catch {
        $mapContent = @"
WIN|`$userProfile\.claude\skills|skills
WIN|`$userProfile\.claude\config|config
WIN|`$userProfile\.codex\skills|skills
WIN|`$userProfile\.codex\config|config
WIN|`$userProfile\.cursor\skills|skills
WIN|`$userProfile\.cursorrules|config\AGENTS.md
WIN|`$userProfile\.gemini\antigravity\skills|skills
WIN|`$userProfile\.gemini\antigravity\config|config
WIN|`$userProfile\.gemini\skills|skills
WIN|`$userProfile\.gemini\config|config
WIN|`$userProfile\.agents\skills|skills
WIN|`$userProfile\.codeium\windsurf\skills|skills
WIN|`$userProfile\.qoder\skills|skills
"@
    }

    $agentMap = @()
    $lines = $mapContent -split "`n"
    foreach ($line in $lines) {
        $line = $line.Trim() -replace "`r", ""
        if ([string]::IsNullOrEmpty($line) -or $line.StartsWith("#")) { continue }
        
        if ($line.StartsWith("WIN|")) {
            $pattern = $line.Substring(4)
            $pattern = $pattern -replace '\$userProfile', $userProfile
            $agentMap += $pattern
        }
    }
    
    return $agentMap
}

# ─── Not supported (intentionally excluded) ──────────────────────
# Cline        — VS Code extension. Global config in VS Code settings.json.
# Roo Code     — VS Code extension. Same architecture as Cline.
# Aider        — Config is a single YAML file (~/.aider.conf.yml).
# Continue.dev — Config is ~/.continue/config.json (JSON with API keys).
# GitHub Copilot — Config in VS Code/JetBrains settings. Per-repo .github/.

# ─── Helpers ─────────────────────────────────────────────────────
function Save-Config {
    "HUB_PATH=$script:hubPath" | Out-File -FilePath $ConfigFile -Encoding utf8
    Write-Host "  (Saved Hub path to $ConfigFile)" -ForegroundColor DarkGray
}

function Load-Config {
    if (Test-Path $ConfigFile) {
        $content = Get-Content $ConfigFile -Raw
        if ($content -match 'HUB_PATH=(.+)') {
            $path = $Matches[1].Trim()
            if (Test-Path $path) {
                $script:hubPath = $path
                return $true
            }
        }
    }
    return $false
}

# ─── STATUS command ──────────────────────────────────────────────
function Invoke-Status {
    Write-Host ""
    Write-Host "==============================================="
    Write-Host "  Agnostic AI Agent Sync - Status"
    Write-Host "==============================================="
    Write-Host ""

    if (-Not (Load-Config)) {
        Write-Host "No saved configuration found." -ForegroundColor Yellow
        Write-Host "Run .\sync.ps1 first to set up your Hub."
        return
    }

    Write-Host "Hub: $script:hubPath" -ForegroundColor White
    Write-Host ""

    $agentMap = Get-AgentMap
    $healthy = 0; $broken = 0; $unlinked = 0; $locked = 0; $unlocked = 0

    foreach ($entry in $agentMap) {
        $parts = $entry -split "\|", 2
        $localPath = $parts[0]
        $hubSub = $parts[1]
        $target = "$($script:hubPath)\$hubSub"
        $parentDir = Split-Path $localPath -Parent

        if (-Not (Test-Path $parentDir)) { continue }

        $item = Get-Item -LiteralPath $localPath -Force -ErrorAction SilentlyContinue

        if ($null -ne $item) {
            $isLink = ($item.Attributes -match "ReparsePoint")

            if ($isLink) {
                $existingTarget = ""
                try { $existingTarget = $item.Target } catch {}

                if ($existingTarget -eq $target) {
                    if (-Not (Test-Path $target)) {
                        Write-Host "  x $localPath -> $target [dangling - Target Hub missing]" -ForegroundColor Red
                        $broken++
                    } else {
                        Write-Host "  v $localPath -> $target [locked]" -ForegroundColor Green
                        $healthy++
                        $locked++
                    }
                } else {
                    Write-Host "  x $localPath -> $existingTarget [wrong target]" -ForegroundColor Red
                    Write-Host "    Expected: $target" -ForegroundColor DarkGray
                    $broken++
                }
            } else {
                Write-Host "  o $localPath [not synced - real file/dir exists]" -ForegroundColor Yellow
                $unlinked++
            }
        } else {
            Write-Host "  - $localPath [empty - ready to sync]" -ForegroundColor DarkGray
            $unlinked++
        }
    }

    Write-Host ""
    Write-Host "─────────────────────────────────────"
    Write-Host "  Synced: $healthy  Broken: $broken  Not synced: $unlinked"
    Write-Host ""

    if ($broken -gt 0 -or $unlinked -gt 0) {
        Write-Host "Run .\sync.ps1 to fix issues."
    } else {
        Write-Host "Everything looks good!" -ForegroundColor Green
    }
}

# ─── Hub selection (guided) ──────────────────────────────────────
function Select-Hub {
    if (Load-Config) {
        Write-Host "Found saved Hub: $($script:hubPath)" -ForegroundColor White
        $useSaved = Read-Host "[?] Use this Hub? (Y/n)"
        if ($useSaved -notmatch "^[Nn]$") { return }
        Write-Host ""
    }

    $currentDir = (Get-Location).Path

    Write-Host "Your Hub is the single folder where all your AI agent skills and"
    Write-Host "config will live. Every AI coding tool gets symlinked to it."
    Write-Host ""
    Write-Host "Current directory: $currentDir" -ForegroundColor White
    Write-Host ""
    $usePwd = Read-Host "[?] Is the current directory your Hub? (y/N)"

    if ($usePwd -match "^[Yy]$") {
        $script:hubPath = $currentDir
    } else {
        Write-Host ""
        $hubExists = Read-Host "[?] Do you already have a Hub folder somewhere? (y/N)"

        if ($hubExists -match "^[Yy]$") {
            $script:hubPath = Read-Host "Enter the path to your existing Hub"
            $script:hubPath = $script:hubPath.TrimEnd("\")

            if (-Not $script:hubPath) {
                Write-Host "Error: Path cannot be empty. Aborting." -ForegroundColor Red
                exit
            }
            if (-Not (Test-Path $script:hubPath)) {
                Write-Host "Error: '$($script:hubPath)' does not exist. Aborting." -ForegroundColor Red
                exit
            }
        } else {
            Write-Host ""
            Write-Host "Let's create one. Pick a parent location:"
            Write-Host ""
            Write-Host "  1) Documents"
            Write-Host "  2) Dropbox"
            Write-Host "  3) OneDrive"
            Write-Host "  4) Enter a custom path"
            Write-Host ""
            $parentChoice = Read-Host "Choose 1-4"

            switch ($parentChoice) {
                "1" { $parentDir = "$userProfile\Documents" }
                "2" { $parentDir = "$userProfile\Dropbox" }
                "3" {
                    $oneDrive = $env:OneDrive
                    if ($oneDrive -and (Test-Path $oneDrive)) { $parentDir = $oneDrive }
                    else { $parentDir = "$userProfile\OneDrive" }
                }
                "4" { $parentDir = Read-Host "Enter the full parent path" }
                default {
                    Write-Host "Invalid choice. Aborting." -ForegroundColor Red
                    exit
                }
            }

            $parentDir = $parentDir.TrimEnd("\")
            if (-Not (Test-Path $parentDir)) {
                Write-Host "Error: '$parentDir' does not exist. Aborting." -ForegroundColor Red
                exit
            }

            $folderName = Read-Host "Folder name to create inside $parentDir (default: agents)"
            if (-Not $folderName) { $folderName = "agents" }

            $script:hubPath = "$parentDir\$folderName"

            if (Test-Path $script:hubPath) {
                Write-Host "Note: '$($script:hubPath)' already exists. Using it as your Hub." -ForegroundColor Yellow
            } else {
                New-Item -ItemType Directory -Force -Path $script:hubPath | Out-Null
                Write-Host "  [Created] $($script:hubPath)" -ForegroundColor Green
            }
        }
    }

    Write-Host ""
    Write-Host "Hub: $($script:hubPath)" -ForegroundColor White
}

# ─── Auto-detect and merge existing skills ───────────────────────
function Merge-ExistingSkills {
    $agentMap = Get-AgentMap
    $sourcesWithContent = @()

    foreach ($entry in $agentMap) {
        $parts = $entry -split "\|", 2
        $localPath = $parts[0]
        $hubSub = $parts[1]

        if ($hubSub -ne "skills") { continue }
        if (-Not (Test-Path $localPath)) { continue }

        $item = Get-Item $localPath -Force
        if ($item.Attributes -match "ReparsePoint") { continue }

        $fileCount = (Get-ChildItem -Path $localPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($fileCount -gt 0) {
            $sourcesWithContent += "$localPath ($fileCount files)"
        }
    }

    if ($sourcesWithContent.Count -eq 0) { return }

    Write-Host ""
    Write-Host "Found existing skill files on your system:" -ForegroundColor Cyan
    foreach ($src in $sourcesWithContent) {
        Write-Host "  * $src"
    }
    Write-Host ""
    $doMerge = Read-Host "[?] Copy these into your Hub ($($script:hubPath)\skills\) before syncing? (y/N)"

    if ($doMerge -notmatch "^[Yy]$") {
        Write-Host "  Skipped. (They'll be backed up during sync anyway.)" -ForegroundColor DarkGray
        return
    }

    foreach ($entry in $agentMap) {
        $parts = $entry -split "\|", 2
        $localPath = $parts[0]
        $hubSub = $parts[1]

        if ($hubSub -ne "skills") { continue }
        if (-Not (Test-Path $localPath)) { continue }

        $item = Get-Item $localPath -Force
        if ($item.Attributes -match "ReparsePoint") { continue }

        $fileCount = (Get-ChildItem -Path $localPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($fileCount -gt 0) {
            Copy-Item -Path "$localPath\*" -Destination "$($script:hubPath)\skills\" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  [Merged] $localPath -> $($script:hubPath)\skills\" -ForegroundColor Green
        }
    }
    Write-Host ""
}

# ─── Ensure Hub subdirectories ───────────────────────────────────
function Ensure-HubDirs {
    $agentMap = Get-AgentMap

    # Always ensure the root directories exist
    if (-not (Test-Path "$($script:hubPath)\skills")) { New-Item -ItemType Directory -Force -Path "$($script:hubPath)\skills" | Out-Null }
    if (-not (Test-Path "$($script:hubPath)\config")) { New-Item -ItemType Directory -Force -Path "$($script:hubPath)\config" | Out-Null }

    # Ensure any dynamically nested subdirectories map correctly
    foreach ($entry in $agentMap) {
        $parts = $entry -split '\|', 2
        $localPath = $parts[0]
        $hubSub = $parts[1]
        $target = Resolve-Target $hubSub

        # If the local path is a known file (not a dir), or the target looks like a file (has an extension),
        # we only need to ensure the parent folder exists to hold it. Otherwise, create the full target.
        $targetBasename = Split-Path -Path $target -Leaf
        $isFileTarget = ($targetBasename -match "\.")
        $isLocalFile = (Test-Path -Path $localPath -PathType Leaf)

        if ($isFileTarget -or $isLocalFile) {
            $parentDir = Split-Path -Path $target -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
                Write-Host "  [Created] $parentDir" -ForegroundColor Green
            }
        } else {
            if (-not (Test-Path $target)) {
                New-Item -ItemType Directory -Force -Path $target | Out-Null
                Write-Host "  [Created] $target" -ForegroundColor Green
            }
        }
    }

    # Standardize on AGENTS.md for unified context
    $configPath = "$($script:hubPath)\config"
    if (Test-Path $configPath) {
        Push-Location $configPath
        $agentsMd = "AGENTS.md"
        
        if (-not (Test-Path $agentsMd)) {
            if ((Test-Path "CLAUDE.md") -and -not ((Get-Item "CLAUDE.md" -Force).Attributes -match "ReparsePoint")) {
                Rename-Item "CLAUDE.md" "AGENTS.md"
            } elseif ((Test-Path "GEMINI.md") -and -not ((Get-Item "GEMINI.md" -Force).Attributes -match "ReparsePoint")) {
                Rename-Item "GEMINI.md" "AGENTS.md"
            } else {
                New-Item -ItemType File -Name "AGENTS.md" -Force | Out-Null
            }
        }

        # Create symlinks for legacy file expectations within the config dir
        foreach ($alias in @("CLAUDE.md", "GEMINI.md")) {
            if (-not (Test-Path $alias)) {
                cmd /c mklink $alias AGENTS.md > $null 2>&1
            }
        }
        Pop-Location
    }
}

# ─── Configure Global Agents (Optional) ───────────────────────────
function Invoke-ConfigureGlobalAgents {
    Write-Host ""
    Write-Host "=== Global Agent Configuration ===" -ForegroundColor Cyan
    $configAgents = Read-Host "[?] Set AGENTS.md as the default context for Gemini CLI and Aider? (y/N)"
    
    if ($configAgents -match "^[Yy]$") {
        # 1. Configure Gemini CLI
        $geminiDir = "$userProfile\.gemini"
        $geminiSettings = "$geminiDir\settings.json"
        
        if (-Not (Test-Path $geminiDir)) {
            New-Item -ItemType Directory -Force -Path $geminiDir | Out-Null
        }
        if (-Not (Test-Path $geminiSettings)) {
            "{}" | Out-File -FilePath $geminiSettings -Encoding utf8
        }
        
        try {
            $content = Get-Content $geminiSettings -Raw
            if ([string]::IsNullOrWhiteSpace($content)) { $content = "{}" }
            $obj = $content | ConvertFrom-Json
            
            $hasContext = [bool](Get-Member -InputObject $obj -Name "context" -ErrorAction SilentlyContinue)
            $hasFileName = $false
            if ($hasContext -and $null -ne $obj.context) {
                $hasFileName = [bool](Get-Member -InputObject $obj.context -Name "fileName" -ErrorAction SilentlyContinue)
            }
            
            if (-not $hasContext) {
                $obj | Add-Member -MemberType NoteProperty -Name "context" -Value @{ "fileName" = "AGENTS.md" }
                $obj | ConvertTo-Json -Depth 10 | Out-File -FilePath $geminiSettings -Encoding utf8
                Write-Host "  [Configured] Gemini CLI to use AGENTS.md" -ForegroundColor Green
            } elseif (-not $hasFileName) {
                $obj.context | Add-Member -MemberType NoteProperty -Name "fileName" -Value "AGENTS.md"
                $obj | ConvertTo-Json -Depth 10 | Out-File -FilePath $geminiSettings -Encoding utf8
                Write-Host "  [Configured] Gemini CLI to use AGENTS.md" -ForegroundColor Green
            } else {
                Write-Host "  Gemini CLI already has a context file configured. Skipped." -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "  [Warning] Could not parse $geminiSettings. Skipping Gemini CLI configuration." -ForegroundColor Yellow
        }

        # 2. Configure Aider
        $aiderConfig = "$userProfile\.aider.conf.yml"
        $hasAiderConfig = $false
        if (Test-Path $aiderConfig) {
            $hasAiderConfig = (Select-String -Path $aiderConfig -Pattern "^read:" -Quiet)
        }
        
        if ($hasAiderConfig) {
            Write-Host "  Aider already has a 'read:' directive configured. Skipped." -ForegroundColor DarkGray
        } else {
            "`nread: AGENTS.md" | Out-File -FilePath $aiderConfig -Append -Encoding utf8
            Write-Host "  [Configured] Aider to use AGENTS.md" -ForegroundColor Green
        }
    } else {
        Write-Host "  Skipped agent configuration." -ForegroundColor DarkGray
    }
}

# ─── SYNC command (main) ────────────────────────────────────────
function Invoke-Sync {
    Write-Host ""
    Write-Host "==============================================="
    Write-Host "  Agnostic AI Agent Sync (Windows)"
    Write-Host "==============================================="
    Write-Host ""

    Select-Hub
    Ensure-HubDirs
    Merge-ExistingSkills
    Save-Config

    $agentMap = Get-AgentMap

    # ── PHASE 1: ANALYSIS ──
    Write-Host ""
    Write-Host "=== PHASE 1: ANALYSIS (Dry-Run) ===" -ForegroundColor Cyan
    Write-Host "Scanning your system for installed AI agents..."
    Write-Host ""

    $planActions = @()
    $planDisplay = @()
    $errors = 0
    $skipped = 0
    $alreadyOk = 0

    foreach ($entry in $agentMap) {
        $parts = $entry -split "\|", 2
        $localPath = $parts[0]
        $hubSub = $parts[1]
        $target = "$($script:hubPath)\$hubSub"
        $parentDir = Split-Path $localPath -Parent

        if (-Not (Test-Path $parentDir)) { $skipped++; continue }
        if (-Not (Test-Path $target)) {
            Write-Host "  [SKIP] Hub target '$target' does not exist. Skipping $localPath." -ForegroundColor Yellow
            $skipped++; continue
        }

        if (Test-Path $localPath) {
            $item = Get-Item $localPath -Force
            $isLink = ($item.Attributes -match "ReparsePoint")

            if ($isLink) {
                $existingTarget = ""
                try { $existingTarget = $item.Target } catch {}

                if ($existingTarget -eq $target) {
                    $planActions += "relock|$localPath|$target"
                    $planDisplay += "  [OK]      $localPath - already correct. Will verify lock."
                    $alreadyOk++
                } else {
                    Write-Host "  [WARN]    $localPath points to unexpected location:" -ForegroundColor Yellow
                    Write-Host "            Current:  $existingTarget"
                    Write-Host "            Expected: $target"
                    $planActions += "replace|$localPath|$target"
                    $planDisplay += "  [REPLACE] $localPath - will redirect to Hub."
                }
            } else {
                $planActions += "backup|$localPath|$target"
                $planDisplay += "  [BACKUP]  $localPath - will be backed up, then linked."
            }
        } else {
            $planActions += "fresh|$localPath|$target"
            $planDisplay += "  [NEW]     $localPath -> $target"
        }
    }

    if ($planDisplay.Length -eq 0) {
        Write-Host "No supported AI agent directories found on this machine."
        Write-Host "($skipped paths skipped - those IDEs are not installed.)"
        return
    }

    Write-Host "Planned Actions:" -ForegroundColor White
    foreach ($line in $planDisplay) { Write-Host $line }

    if ($skipped -gt 0) {
        Write-Host ""
        Write-Host "  ($skipped agent paths skipped - those IDEs are not installed.)" -ForegroundColor DarkGray
    }

    if ($errors -gt 0) {
        Write-Host ""
        Write-Host "$errors critical issue(s) detected. Aborting for safety." -ForegroundColor Red
        return
    }

    if ($planActions.Count -eq $alreadyOk -and $alreadyOk -gt 0) {
        Write-Host ""
        Write-Host "All $alreadyOk agent(s) already synced and locked. Nothing to do!" -ForegroundColor Green
        
        Invoke-ConfigureGlobalAgents
        
        return
    }

    # ── PHASE 2: CONFIRMATION ──
    Write-Host ""
    Write-Host "=== PHASE 2: CONFIRMATION ===" -ForegroundColor Cyan
    $confirm = Read-Host "[?] Does this plan look correct? Type 'y' to implement, or anything else to abort"

    if ($confirm -notmatch "^[Yy]$") {
        Write-Host ""
        Write-Host "Safely aborted. Zero files were touched." -ForegroundColor Yellow
        return
    }

    # ── PHASE 3: IMPLEMENTATION ──
    Write-Host ""
    Write-Host "=== PHASE 3: IMPLEMENTATION ===" -ForegroundColor Cyan

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $walFile = "$env:USERPROFILE\.agnostic-ai-agent-sync.wal"
    Out-File -FilePath $walFile -InputObject "" -Force

    try {

        foreach ($actionEntry in $planActions) {
            $parts = $actionEntry -split "\|", 3
            $actionType = $parts[0]
            $actionPath = $parts[1]
            $actionTarget = $parts[2]
            $basename = Split-Path $actionPath -Leaf
            $isFile = ($basename -eq ".cursorrules")

            switch ($actionType) {
                "relock" {
                    icacls $actionPath /remove:d Everyone > $null 2>&1
                    icacls $actionPath /deny Everyone:`(DE`) > $null 2>&1
                    "LOCKED|$actionPath" | Out-File -FilePath $walFile -Append
                    Write-Host " [OK] Verified lock: $actionPath" -ForegroundColor Green
                }
                "replace" {
                    icacls $actionPath /remove:d Everyone > $null 2>&1
                    $item = Get-Item $actionPath -Force
                    if ($item.PSIsContainer) { cmd /c rmdir $actionPath }
                    else { Remove-Item -Path $actionPath -Force }

                    if ($isFile) { cmd /c mklink "$actionPath" "$actionTarget" > $null 2>&1 }
                    else { New-Item -ItemType Junction -Path $actionPath -Value $actionTarget | Out-Null }
                    "LINKED|$actionPath" | Out-File -FilePath $walFile -Append
                    
                    icacls $actionPath /deny Everyone:`(DE`) > $null 2>&1
                    "LOCKED|$actionPath" | Out-File -FilePath $walFile -Append
                    Write-Host " [OK] Replaced and locked: $actionPath -> $actionTarget" -ForegroundColor Green
                }
                "backup" {
                    $backupPath = "$actionPath.backup_$timestamp"
                    Rename-Item -Path $actionPath -NewName (Split-Path $backupPath -Leaf)
                    "BACKED_UP|$actionPath|$backupPath" | Out-File -FilePath $walFile -Append
                    Write-Host " [BACKED UP] $actionPath -> $backupPath" -ForegroundColor Yellow

                    if ($isFile) { cmd /c mklink "$actionPath" "$actionTarget" > $null 2>&1 }
                    else { New-Item -ItemType Junction -Path $actionPath -Value $actionTarget | Out-Null }
                    "LINKED|$actionPath" | Out-File -FilePath $walFile -Append
                    
                    icacls $actionPath /deny Everyone:`(DE`) > $null 2>&1
                    "LOCKED|$actionPath" | Out-File -FilePath $walFile -Append
                    Write-Host " [OK] Linked and locked: $actionPath -> $actionTarget" -ForegroundColor Green
                }
                "fresh" {
                    if ($isFile) { cmd /c mklink "$actionPath" "$actionTarget" > $null 2>&1 }
                    else { New-Item -ItemType Junction -Path $actionPath -Value $actionTarget | Out-Null }
                    "LINKED|$actionPath" | Out-File -FilePath $walFile -Append
                    
                    icacls $actionPath /deny Everyone:`(DE`) > $null 2>&1
                    "LOCKED|$actionPath" | Out-File -FilePath $walFile -Append
                    Write-Host " [OK] Created and locked: $actionPath -> $actionTarget" -ForegroundColor Green
                }
            }
        }
    } catch {
        Write-Host ""
        Write-Host "⨯ Interrupt caught or error occurred! Rolling back changes..." -ForegroundColor Red
        
        if (Test-Path $walFile) {
            $walLines = Get-Content $walFile
            [array]::Reverse($walLines)
            
            foreach ($line in $walLines) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $parts = $line -split "\|", 3
                $op = $parts[0]
                $path1 = $parts[1]
                $path2 = $parts[2]
                
                if ($op -eq "LOCKED") {
                    icacls $path1 /remove:d Everyone > $null 2>&1
                } elseif ($op -eq "LINKED") {
                    $item = Get-Item -LiteralPath $path1 -Force -ErrorAction SilentlyContinue
                    if ($item.PSIsContainer) { cmd /c rmdir $path1 }
                    else { Remove-Item -Path $path1 -Force -ErrorAction SilentlyContinue }
                } elseif ($op -eq "BACKED_UP") {
                    Rename-Item -Path $path2 -NewName (Split-Path $path1 -Leaf) -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Host "Rollback complete. Your filesystem was restored to its pre-sync state."
        }
        
        Remove-Item -Path $walFile -Force -ErrorAction SilentlyContinue
        exit
    }

    Remove-Item -Path $walFile -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "==============================================="
    Write-Host "  Success! All agents are securely synced." -ForegroundColor Green
    Write-Host "==============================================="

    Invoke-OfferCleanup

    Invoke-ConfigureGlobalAgents

    Write-Host ""
    Write-Host "Useful commands:"
    Write-Host "  .\sync.ps1 status   - Check health of all symlinks"
    Write-Host "  .\sync.ps1 cleanup  - Remove old backup files"
    Write-Host "  .\unsync.ps1        - Unlock all symlinks for manual editing"
}

# ─── CLEANUP command ─────────────────────────────────────────────
function Invoke-OfferCleanup {
    $agentMap = Get-AgentMap
    $backups = @()

    foreach ($entry in $agentMap) {
        $parts = $entry -split "\|", 2
        $localPath = $parts[0]
        $parentDir = Split-Path $localPath -Parent
        $basename = Split-Path $localPath -Leaf

        if (-Not (Test-Path $parentDir)) { continue }

        $found = Get-ChildItem -Path $parentDir -Filter "${basename}.backup_*" -ErrorAction SilentlyContinue
        if ($found) { $backups += $found }
    }

    if ($backups.Count -eq 0) { return }

    Write-Host ""
    Write-Host "Found $($backups.Count) backup(s) from previous sync runs:" -ForegroundColor Cyan
    foreach ($b in $backups) {
        if ($b.PSIsContainer) {
            $size = "{0:N2} MB" -f ((Get-ChildItem $b.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        } else {
            $size = "{0:N2} KB" -f ($b.Length / 1KB)
        }
        Write-Host "  $($b.FullName) ($size)" -ForegroundColor DarkGray
    }

    Write-Host ""
    $doCleanup = Read-Host "[?] Delete these backups? They are no longer needed. (y/N)"

    if ($doCleanup -notmatch "^[Yy]$") {
        Write-Host "  Kept. Run .\sync.ps1 cleanup anytime to remove them later." -ForegroundColor DarkGray
        return
    }

    foreach ($b in $backups) {
        Remove-Item -Path $b.FullName -Recurse -Force
        Write-Host "  [Deleted] $($b.FullName)" -ForegroundColor Green
    }
    Write-Host "Cleanup complete." -ForegroundColor Green
}

function Invoke-Cleanup {
    Write-Host ""
    Write-Host "==============================================="
    Write-Host "  Agnostic AI Agent Sync — Cleanup Backups"
    Write-Host "==============================================="
    Write-Host ""

    Invoke-OfferCleanup

    # Check if any remain
    $agentMap = Get-AgentMap
    $remaining = @()
    foreach ($entry in $agentMap) {
        $parts = $entry -split "\|", 2
        $localPath = $parts[0]
        $parentDir = Split-Path $localPath -Parent
        $basename = Split-Path $localPath -Leaf
        if (-Not (Test-Path $parentDir)) { continue }
        $found = Get-ChildItem -Path $parentDir -Filter "${basename}.backup_*" -ErrorAction SilentlyContinue
        if ($found) { $remaining += $found }
    }
    if ($remaining.Count -eq 0) {
        Write-Host "No backup files found. Nothing to clean up."
    }
}

# ─── CLI router ──────────────────────────────────────────────────
$command = if ($args.Count -gt 0) { $args[0] } else { "" }

switch ($command) {
    "status" { Invoke-Status }
    "cleanup" { Invoke-Cleanup }
    "version" { Write-Host "Agnostic AI Agent Sync v$Version" }
    "help" {
        Write-Host "Usage: .\sync.ps1 [command]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  (none)     Run the interactive sync wizard"
        Write-Host "  status     Check health of all symlinks"
        Write-Host "  cleanup    Remove old .backup_ files from previous syncs"
        Write-Host "  version    Show version number"
        Write-Host "  help       Show this help message"
    }
    "" { Invoke-Sync }
    default {
        Write-Host "Unknown command: $command" -ForegroundColor Red
        Write-Host "Run .\sync.ps1 help for usage."
    }
}
