#!/usr/bin/env bash
# Agnostic AI Agent Sync — Unsync / Unlock utility
# Removes the immutable lock from all synced symlinks so you can modify them manually.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo "==============================================="
echo "  Agnostic AI Agent Sync — Unlock / Unsync"
echo "==============================================="
echo ""

declare -a KNOWN_PATHS=(
    "$HOME/.claude/skills"
    "$HOME/.claude/config"
    "$HOME/.codex/skills"
    "$HOME/.codex/config"
    "$HOME/.cursor/skills"
    "$HOME/.cursorrules"
    "$HOME/.gemini/antigravity/skills"
    "$HOME/.codeium/windsurf/skills"
    "$HOME/.qoder/skills"
)

UNLOCKED=0

for LOCAL_PATH in "${KNOWN_PATHS[@]}"; do
    if [ -L "$LOCAL_PATH" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            chflags -h nouchg "$LOCAL_PATH" 2>/dev/null || true
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo chattr -i "$LOCAL_PATH" 2>/dev/null || true
        fi
        rm "$LOCAL_PATH"
        echo -e " ${GREEN}[UNLINKED]${RESET} $LOCAL_PATH"
        UNLOCKED=$((UNLOCKED + 1))
    fi
done

if [ $UNLOCKED -eq 0 ]; then
    echo "No locked symlinks found. Nothing to do."
else
    echo ""
    echo -e "${GREEN}${BOLD}✓ Unlinked $UNLOCKED IDE(s).${RESET}"
    echo "Your IDEs are now disconnected and will use their own default skill folders."
    echo ""
    echo "Your skills are safe! They were left exactly as they are in your Hub."
    echo "If you want to manually move them back to a specific IDE, copy them from the Hub."
fi
