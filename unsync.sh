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

declare -a LINKS_TO_REMOVE=()

for LOCAL_PATH in "${KNOWN_PATHS[@]}"; do
    if [ -L "$LOCAL_PATH" ]; then
        LINKS_TO_REMOVE+=("$LOCAL_PATH")
    fi
done

if [ ${#LINKS_TO_REMOVE[@]} -eq 0 ]; then
    echo "No locked symlinks found. Nothing to do."
    exit 0
fi

echo -e "${CYAN}${BOLD}The following IDE config paths will be disconnected from the Hub:${RESET}"
for link in "${LINKS_TO_REMOVE[@]}"; do
    TARGET=$(readlink "$link" || echo "unknown")
    echo "  - $link -> $TARGET"
done

echo ""
echo -e "${YELLOW}Warning: This will delete these symlinks and break the connection to your Hub.${RESET}"
echo "Your skills inside the Hub will be completely untouched."
echo ""
read -p "Are you sure you want to unsync these IDEs? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted. Nothing was changed."
    exit 0
fi

echo ""
UNLOCKED=0

for LOCAL_PATH in "${LINKS_TO_REMOVE[@]}"; do
    if [[ "$OSTYPE" == "darwin"* ]]; then
        chflags -h nouchg "$LOCAL_PATH" 2>/dev/null || true
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo chattr -i "$LOCAL_PATH" 2>/dev/null || true
    fi
    rm "$LOCAL_PATH"
    echo -e " ${GREEN}[UNLINKED]${RESET} $LOCAL_PATH"
    UNLOCKED=$((UNLOCKED + 1))
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
