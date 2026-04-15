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

$linksToRemove = @()

foreach ($localPath in $knownPaths) {
    if (Test-Path -Path $localPath) {
        $item = Get-Item $localPath -Force
        $isLink = ($item.Attributes -match "ReparsePoint")
        if ($isLink) {
            $linksToRemove += $item
        }
    }
}

if ($linksToRemove.Count -eq 0) {
    Write-Host "No locked junctions found. Nothing to do."
    exit
}

Write-Host "The following IDE config paths will be disconnected from the Hub:" -ForegroundColor Cyan
foreach ($link in $linksToRemove) {
    $target = $link.Target
    Write-Host "  - $($link.FullName) -> $target"
}

Write-Host ""
Write-Host "Warning: This will delete these junctions and break the connection to your Hub." -ForegroundColor Yellow
Write-Host "Your skills inside the Hub will be completely untouched."
Write-Host ""
$confirm = Read-Host "Are you sure you want to unsync these IDEs? (y/N)"

if ($confirm -notmatch "^[Yy]$") {
    Write-Host "Aborted. Nothing was changed."
    exit
}

Write-Host ""
$unlocked = 0

foreach ($link in $linksToRemove) {
    $localPath = $link.FullName
    icacls $localPath /remove:d Everyone > $null 2>&1
    cmd /c rmdir "$localPath"
    Write-Host " [UNLINKED] $localPath" -ForegroundColor Green
    $unlocked++
}

if ($unlocked -eq 0) {
    Write-Host "No locked junctions found. Nothing to do."
} else {
    Write-Host ""
    Write-Host "`u{2713} Unlinked $unlocked IDE(s)." -ForegroundColor Green
    Write-Host "Your IDEs are now disconnected and will use their own default skill folders."
    Write-Host ""
    Write-Host "Your skills are safe! They were left exactly as they are in your Hub."
    Write-Host "If you want to manually move them back to a specific IDE, copy them from the Hub."
}
