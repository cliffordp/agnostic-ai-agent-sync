# Agnostic AI Agent Sync — Unsync / Unlock utility
# Removes the immutable lock from all synced junctions so you can modify them manually.

Write-Host ""
Write-Host "==============================================="
Write-Host "  Agnostic AI Agent Sync — Unlock / Unsync"
Write-Host "==============================================="
Write-Host ""

$userProfile = $env:USERPROFILE
$knownPaths = @(
    "$userProfile\.claude\skills",
    "$userProfile\.claude\config",
    "$userProfile\.codex\skills",
    "$userProfile\.codex\config",
    "$userProfile\.cursor\skills",
    "$userProfile\.gemini\antigravity\skills",
    "$userProfile\.codeium\windsurf\skills",
    "$userProfile\.qoder\skills",
    "$userProfile\.cursorrules"
)

$unlocked = 0

foreach ($localPath in $knownPaths) {
    if (Test-Path -Path $localPath) {
        $item = Get-Item $localPath -Force
        $isLink = ($item.Attributes -match "ReparsePoint")
        if ($isLink) {
            icacls $localPath /remove:d Everyone > $null 2>&1
            Write-Host " [UNLOCKED] $localPath" -ForegroundColor Green
            $unlocked++
        }
    }
}

if ($unlocked -eq 0) {
    Write-Host "No locked junctions found. Nothing to do."
} else {
    Write-Host ""
    Write-Host "Unlocked $unlocked junction(s)." -ForegroundColor Green
    Write-Host "You can now safely delete or modify them manually."
    Write-Host "To re-lock, just run sync.ps1 again."
}
