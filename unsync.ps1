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
            cmd /c rmdir "$localPath"
            Write-Host " [UNLINKED] $localPath" -ForegroundColor Green
            $unlocked++
        }
    }
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
