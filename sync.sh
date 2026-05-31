#!/usr/bin/env bash
# Agnostic AI Agent Sync - macOS & Linux
# https://github.com/cliffordp/agnostic-ai-agent-sync

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

CONFIG_FILE="$HOME/.agnostic-ai-agent-sync"
VERSION="1.0.0"

# ─── Agent mapping ───────────────────────────────────────────────
# Format: LOCAL_PATH|HUB_SUBFOLDER
# HUB_SUBFOLDER is relative to the Hub path
build_agent_map() {
    AGENT_MAP=()
    REMOTE_URL="https://raw.githubusercontent.com/cliffordp/agnostic-ai-agent-sync/main/agents.map"
    MAP_CONTENT=""

    if command -v curl &> /dev/null; then
        MAP_CONTENT=$(curl -sfL --max-time 2 "$REMOTE_URL" 2>/dev/null || echo "")
    fi

    # Fallback if curl failed or machine is offline
    if [ -z "$MAP_CONTENT" ]; then
        MAP_CONTENT=$(cat << 'EOF'
UNIX|$HOME/.claude/skills|skills
UNIX|$HOME/.claude/config|config
UNIX|$HOME/.codex/skills|skills
UNIX|$HOME/.codex/config|config
UNIX|$HOME/.cursor/skills|skills
UNIX|$HOME/.cursorrules|config/AGENTS.md
UNIX|$HOME/.gemini/antigravity/skills|skills
UNIX|$HOME/.gemini/antigravity/config|config
UNIX|$HOME/.gemini/skills|skills
UNIX|$HOME/.gemini/config|config
UNIX|$HOME/.antigravity/skills|skills
UNIX|$HOME/.antigravity/config|config
UNIX|$HOME/.antigravity-ide/skills|skills
UNIX|$HOME/.antigravity-ide/config|config
UNIX|$HOME/.antigravitycli/skills|skills
UNIX|$HOME/.antigravitycli/config|config
UNIX|$HOME/.agents/skills|skills
UNIX|$HOME/.codeium/windsurf/skills|skills
UNIX|$HOME/.qoder/skills|skills
EOF
)
    fi

    while IFS= read -r line; do
        # Strip trailing carriage returns cross-platform
        line="${line%$'\r'}"
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        if [[ "$line" == UNIX\|* ]]; then
            PATTERN="${line#UNIX|}"
            PATTERN="${PATTERN/\$HOME/$HOME}"
            AGENT_MAP+=("$PATTERN")
        fi
    done <<< "$MAP_CONTENT"
}

# ─── Not supported (intentionally excluded) ──────────────────────
# These AI tools store config in ways that can't be safely symlinked:
#
# Cline        — VS Code extension. Global config lives in VS Code
#                settings.json, not a standalone directory.
#                Per-project rules go in .cline/ within the repo.
#
# Roo Code     — VS Code extension. Same architecture as Cline.
#                Per-project rules go in .roo/ within the repo.
#
# Aider        — Config is a single YAML file (~/.aider.conf.yml),
#                not a directory of skills. Per-project .aider/.
#
# Continue.dev — Config is ~/.continue/config.json (a JSON blob with
#                API keys, model settings, etc). Not skill-based.
#
# GitHub Copilot — Config embedded in VS Code/JetBrains settings.
#                  Per-repo instructions in .github/copilot-instructions.md.

# ─── Helpers ─────────────────────────────────────────────────────
save_config() {
    echo "HUB_PATH=$HUB_PATH" > "$CONFIG_FILE"
    echo -e "  ${DIM}(Saved Hub path to $CONFIG_FILE)${RESET}"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        if [ -n "${HUB_PATH:-}" ] && [ -d "$HUB_PATH" ]; then
            return 0
        fi
    fi
    return 1
}

resolve_target() {
    local hub_sub="$1"
    echo "$HUB_PATH/$hub_sub"
}

apply_lock() {
    local path="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        chflags -h uchg "$path" 2>/dev/null || true
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo chattr +i "$path" 2>/dev/null || true
    fi
}

remove_lock() {
    local path="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        chflags -h nouchg "$path" 2>/dev/null || true
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo chattr -i "$path" 2>/dev/null || true
    fi
}

is_locked() {
    local path="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ls -lO "$path" 2>/dev/null | grep -q "uchg" && return 0
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        lsattr "$path" 2>/dev/null | grep -q "i" && return 0
    fi
    return 1
}

# ─── STATUS command ──────────────────────────────────────────────
cmd_status() {
    echo ""
    echo "==============================================="
    echo "  Agnostic AI Agent Sync — Status"
    echo "==============================================="
    echo ""

    if ! load_config; then
        echo -e "${YELLOW}No saved configuration found.${RESET}"
        echo "Run ./sync.sh first to set up your Hub."
        exit 0
    fi

    echo -e "Hub: ${BOLD}$HUB_PATH${RESET}"
    echo ""

    build_agent_map

    HEALTHY=0
    BROKEN=0
    UNLINKED=0
    LOCKED_COUNT=0
    UNLOCKED_COUNT=0

    for ENTRY in "${AGENT_MAP[@]}"; do
        LOCAL_PATH="${ENTRY%%|*}"
        HUB_SUB="${ENTRY##*|}"
        TARGET=$(resolve_target "$HUB_SUB")
        PARENT_DIR=$(dirname "$LOCAL_PATH")
        BASENAME=$(basename "$LOCAL_PATH")

        # Skip if tool not installed
        if [ ! -d "$PARENT_DIR" ]; then
            continue
        fi

        if [ -L "$LOCAL_PATH" ]; then
            ACTUAL=$(readlink "$LOCAL_PATH" 2>/dev/null || echo "UNREADABLE")
            if [ "$ACTUAL" = "$TARGET" ]; then
                if [ ! -e "$LOCAL_PATH" ]; then
                    echo -e "  ${RED}✗${RESET} $LOCAL_PATH → $TARGET ${RED}[dangling - Target Hub missing]${RESET}"
                    BROKEN=$((BROKEN + 1))
                elif is_locked "$LOCAL_PATH" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${RESET} $LOCAL_PATH → $TARGET ${GREEN}[locked]${RESET}"
                    LOCKED_COUNT=$((LOCKED_COUNT + 1))
                    HEALTHY=$((HEALTHY + 1))
                else
                    echo -e "  ${YELLOW}⚠${RESET} $LOCAL_PATH → $TARGET ${YELLOW}[unlocked]${RESET}"
                    UNLOCKED_COUNT=$((UNLOCKED_COUNT + 1))
                    HEALTHY=$((HEALTHY + 1))
                fi
            else
                echo -e "  ${RED}✗${RESET} $LOCAL_PATH → $ACTUAL ${RED}[wrong target]${RESET}"
                echo -e "    ${DIM}Expected: $TARGET${RESET}"
                BROKEN=$((BROKEN + 1))
            fi
        elif [ -e "$LOCAL_PATH" ]; then
            echo -e "  ${YELLOW}○${RESET} $LOCAL_PATH ${YELLOW}[not synced — real file/dir exists]${RESET}"
            UNLINKED=$((UNLINKED + 1))
        else
            echo -e "  ${DIM}–${RESET} $LOCAL_PATH ${DIM}[empty — ready to sync]${RESET}"
            UNLINKED=$((UNLINKED + 1))
        fi
    done

    echo ""
    echo "─────────────────────────────────────"
    echo -e "  Synced: ${GREEN}$HEALTHY${RESET}  (${GREEN}$LOCKED_COUNT locked${RESET}, ${YELLOW}$UNLOCKED_COUNT unlocked${RESET})"
    [ $BROKEN -gt 0 ] && echo -e "  Broken: ${RED}$BROKEN${RESET}"
    [ $UNLINKED -gt 0 ] && echo -e "  Not synced: ${YELLOW}$UNLINKED${RESET}"
    echo ""

    if [ $BROKEN -gt 0 ] || [ $UNLOCKED_COUNT -gt 0 ] || [ $UNLINKED -gt 0 ]; then
        echo -e "Run ${BOLD}./sync.sh${RESET} to fix issues."
    else
        echo -e "${GREEN}Everything looks good!${RESET}"
    fi
}

# ─── Hub path selection (guided) ─────────────────────────────────
select_hub() {
    # Check for saved config first
    if load_config; then
        echo -e "Found saved Hub: ${BOLD}$HUB_PATH${RESET}"
        read -rp "[?] Use this Hub? (Y/n): " USE_SAVED
        if [[ ! "$USE_SAVED" =~ ^[Nn]$ ]]; then
            return
        fi
        echo ""
    fi

    CURRENT_DIR=$(pwd)

    echo "Your Hub is the single folder where all your AI agent skills and"
    echo "config will live. Every AI coding tool gets symlinked to it."
    echo ""
    echo -e "Current directory: ${BOLD}$CURRENT_DIR${RESET}"
    echo ""
    read -rp "[?] Is the current directory your Hub? (y/N): " USE_PWD

    if [[ "$USE_PWD" =~ ^[Yy]$ ]]; then
        HUB_PATH="$CURRENT_DIR"
    else
        echo ""
        read -rp "[?] Do you already have a Hub folder somewhere? (y/N): " HUB_EXISTS

        if [[ "$HUB_EXISTS" =~ ^[Yy]$ ]]; then
            read -rp "Enter the path to your existing Hub (e.g. ~/Dropbox/agents): " HUB_PATH
            HUB_PATH="${HUB_PATH/#\~/$HOME}"
            HUB_PATH="${HUB_PATH%/}"

            if [ -z "$HUB_PATH" ]; then
                echo -e "${RED}Error: Path cannot be empty. Aborting.${RESET}"
                exit 1
            fi

            if [ ! -d "$HUB_PATH" ]; then
                echo -e "${RED}Error: '$HUB_PATH' does not exist. Aborting.${RESET}"
                exit 1
            fi
        else
            echo ""
            echo "Let's create one. Pick a parent location:"
            echo ""
            echo "  1) ~/Documents"
            echo "  2) ~/Dropbox"
            echo "  3) ~/Library/CloudStorage  (iCloud, OneDrive, etc.)"
            echo "  4) Enter a custom path"
            echo ""
            read -rp "Choose 1-4: " PARENT_CHOICE

            case "$PARENT_CHOICE" in
                1) PARENT_DIR="$HOME/Documents" ;;
                2) PARENT_DIR="$HOME/Dropbox" ;;
                3)
                    echo ""
                    echo "Available cloud storage folders:"
                    if [ -d "$HOME/Library/CloudStorage" ]; then
                        ls -1 "$HOME/Library/CloudStorage" 2>/dev/null | while read -r dir; do
                            echo "    $dir"
                        done
                    else
                        echo "    (none found)"
                    fi
                    echo ""
                    read -rp "Enter the full path under CloudStorage (e.g. ~/Library/CloudStorage/Dropbox): " PARENT_DIR
                    PARENT_DIR="${PARENT_DIR/#\~/$HOME}"
                    ;;
                4)
                    read -rp "Enter the full parent path: " PARENT_DIR
                    PARENT_DIR="${PARENT_DIR/#\~/$HOME}"
                    ;;
                *)
                    echo -e "${RED}Invalid choice. Aborting.${RESET}"
                    exit 1
                    ;;
            esac

            PARENT_DIR="${PARENT_DIR%/}"

            if [ ! -d "$PARENT_DIR" ]; then
                echo -e "${RED}Error: '$PARENT_DIR' does not exist. Aborting.${RESET}"
                exit 1
            fi

            read -rp "Folder name to create inside $PARENT_DIR (default: agents): " FOLDER_NAME
            FOLDER_NAME="${FOLDER_NAME:-agents}"

            HUB_PATH="$PARENT_DIR/$FOLDER_NAME"

            if [ -d "$HUB_PATH" ]; then
                echo -e "${YELLOW}Note: '$HUB_PATH' already exists. Using it as your Hub.${RESET}"
            else
                mkdir -p "$HUB_PATH"
                echo -e "${GREEN}[Created]${RESET} $HUB_PATH"
            fi
        fi
    fi

    echo ""
    echo -e "Hub: ${BOLD}$HUB_PATH${RESET}"
}

# ─── Auto-detect and merge existing skills ───────────────────────
merge_existing_skills() {
    build_agent_map

    FOUND_FILES=0
    declare -a SOURCES_WITH_CONTENT=()

    for ENTRY in "${AGENT_MAP[@]}"; do
        LOCAL_PATH="${ENTRY%%|*}"
        HUB_SUB="${ENTRY##*|}"

        # Only look at skills directories, skip config and file mappings
        if [[ "$HUB_SUB" != "skills" ]]; then
            continue
        fi

        # Skip if it's already a symlink (already managed)
        if [ -L "$LOCAL_PATH" ]; then
            continue
        fi

        # Skip if it doesn't exist or is empty
        if [ -d "$LOCAL_PATH" ]; then
            FILE_COUNT=$(find "$LOCAL_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
            if [ "$FILE_COUNT" -gt 0 ]; then
                FOUND_FILES=$((FOUND_FILES + FILE_COUNT))
                SOURCES_WITH_CONTENT+=("$LOCAL_PATH ($FILE_COUNT files)")
            fi
        fi
    done

    if [ $FOUND_FILES -eq 0 ]; then
        return
    fi

    echo ""
    echo -e "${CYAN}${BOLD}Found existing skill files on your system:${RESET}"
    for src in "${SOURCES_WITH_CONTENT[@]}"; do
        echo -e "  • $src"
    done
    echo ""
    read -rp "[?] Copy these into your Hub ($HUB_PATH/skills/) before syncing? (y/N): " DO_MERGE

    if [[ ! "$DO_MERGE" =~ ^[Yy]$ ]]; then
        echo -e "  ${DIM}Skipped. (They'll be backed up during sync anyway.)${RESET}"
        return
    fi

    for ENTRY in "${AGENT_MAP[@]}"; do
        LOCAL_PATH="${ENTRY%%|*}"
        HUB_SUB="${ENTRY##*|}"

        if [[ "$HUB_SUB" != "skills" ]]; then continue; fi
        if [ -L "$LOCAL_PATH" ]; then continue; fi
        if [ ! -d "$LOCAL_PATH" ]; then continue; fi

        FILE_COUNT=$(find "$LOCAL_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [ "$FILE_COUNT" -gt 0 ]; then
            # Copy files, don't overwrite existing
            cp -rn "$LOCAL_PATH"/* "$HUB_PATH/skills/" 2>/dev/null || true
            echo -e "  ${GREEN}[Merged]${RESET} $LOCAL_PATH → $HUB_PATH/skills/"
        fi
    done
    echo ""
}

# ─── Ensure Hub subdirectories ───────────────────────────────────
ensure_hub_dirs() {
    build_agent_map
    
    # Always ensure the root directories exist
    mkdir -p "$HUB_PATH/skills" "$HUB_PATH/config"
    
    # Ensure any dynamically nested subdirectories map correctly
    for ENTRY in "${AGENT_MAP[@]}"; do
        LOCAL_PATH="${ENTRY%%|*}"
        HUB_SUB="${ENTRY##*|}"
        TARGET=$(resolve_target "$HUB_SUB")
        
        # If the local path is a known file (not a dir), or the target looks like a file (has an extension),
        # we only need to ensure the parent folder exists to hold it. Otherwise, create the full target.
        if [ -f "$LOCAL_PATH" ] || [[ "$(basename "$TARGET")" == *.* ]]; then
            PARENT_DIR=$(dirname "$TARGET")
            if [ ! -d "$PARENT_DIR" ]; then
                mkdir -p "$PARENT_DIR"
                echo -e "  ${GREEN}[Created]${RESET} $PARENT_DIR"
            fi
        else
            if [ ! -d "$TARGET" ]; then
                mkdir -p "$TARGET"
                echo -e "  ${GREEN}[Created]${RESET} $TARGET"
            fi
        fi
    done

    # Standardize on AGENTS.md for unified context
    if [ -d "$HUB_PATH/config" ]; then
        (
            cd "$HUB_PATH/config" || true
            if [ ! -f "AGENTS.md" ]; then
                if [ -f "CLAUDE.md" ] && [ ! -L "CLAUDE.md" ]; then
                    mv "CLAUDE.md" "AGENTS.md"
                elif [ -f "GEMINI.md" ] && [ ! -L "GEMINI.md" ]; then
                    mv "GEMINI.md" "AGENTS.md"
                else
                    touch "AGENTS.md"
                fi
            fi

            # Create symlinks for legacy file expectations within the config dir
            for alias in "CLAUDE.md" "GEMINI.md"; do
                if [ ! -e "$alias" ]; then
                    ln -s "AGENTS.md" "$alias" 2>/dev/null || true
                fi
            done
        )
    fi
}

# ─── Configure Global Agents (Optional) ───────────────────────────
configure_global_agents() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Global Agent Configuration ===${RESET}"
    read -rp "[?] Set AGENTS.md as the default context for Gemini CLI and Aider? (y/N): " CONFIG_AGENTS
    
    if [[ "$CONFIG_AGENTS" =~ ^[Yy]$ ]]; then
        # 1. Configure Gemini CLI
        if command -v jq >/dev/null 2>&1; then
            mkdir -p ~/.gemini
            if [ ! -f ~/.gemini/settings.json ]; then
                echo "{}" > ~/.gemini/settings.json
            fi
            
            # Check if context.fileName already exists
            if ! jq -e '.context.fileName' ~/.gemini/settings.json > /dev/null 2>&1; then
                jq '.context.fileName = "AGENTS.md"' ~/.gemini/settings.json > ~/.gemini/settings_tmp.json && mv ~/.gemini/settings_tmp.json ~/.gemini/settings.json
                echo -e "  ${GREEN}[Configured]${RESET} Gemini CLI to use AGENTS.md"
            else
                echo -e "  ${DIM}Gemini CLI already has a context file configured. Skipped.${RESET}"
            fi
        else
            mkdir -p ~/.gemini
            if [ ! -f ~/.gemini/settings.json ] || [ "$(cat ~/.gemini/settings.json | tr -d ' \n\r\t')" = "{}" ]; then
                echo '{"context":{"fileName":"AGENTS.md"}}' > ~/.gemini/settings.json
                echo -e "  ${GREEN}[Configured]${RESET} Gemini CLI to use AGENTS.md (no jq needed)"
            else
                echo -e "  ${YELLOW}[Warning]${RESET} 'jq' is not installed and settings.json is not empty. Skipping Gemini CLI configuration."
            fi
        fi

        # 2. Configure Aider
        if [ -f ~/.aider.conf.yml ] && grep -q "^read: " ~/.aider.conf.yml; then
            echo -e "  ${DIM}Aider already has a 'read:' directive configured. Skipped.${RESET}"
        else
            echo -e "\nread: AGENTS.md" >> ~/.aider.conf.yml
            echo -e "  ${GREEN}[Configured]${RESET} Aider to use AGENTS.md"
        fi
    else
        echo -e "  ${DIM}Skipped agent configuration.${RESET}"
    fi
}

# ─── SYNC command (main) ────────────────────────────────────────
cmd_sync() {
    echo ""
    echo "==============================================="
    echo "  Agnostic AI Agent Sync (macOS & Linux)"
    echo "==============================================="
    echo ""

    select_hub
    ensure_hub_dirs
    merge_existing_skills
    save_config

    build_agent_map

    # ── PHASE 1: ANALYSIS ──
    echo ""
    echo -e "${CYAN}${BOLD}=== PHASE 1: ANALYSIS (Dry-Run) ===${RESET}"
    echo "Scanning your system for installed AI agents..."
    echo ""

    declare -a PLAN_ACTION=()
    declare -a PLAN_DISPLAY=()
    ERRORS=0
    SKIPPED=0
    ALREADY_OK=0

    for ENTRY in "${AGENT_MAP[@]}"; do
        LOCAL_PATH="${ENTRY%%|*}"
        HUB_SUB="${ENTRY##*|}"
        TARGET=$(resolve_target "$HUB_SUB")
        PARENT_DIR=$(dirname "$LOCAL_PATH")

        # Skip if the parent tool directory doesn't exist (agent not installed)
        if [ ! -d "$PARENT_DIR" ]; then
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        # Verify Hub target exists
        if [ ! -e "$TARGET" ]; then
            echo -e "  ${YELLOW}[SKIP]${RESET} Hub target '$TARGET' does not exist yet. Skipping $LOCAL_PATH."
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        # ── Classify what currently lives at LOCAL_PATH ──
        if [ -L "$LOCAL_PATH" ]; then
            EXISTING_TARGET=$(readlink "$LOCAL_PATH" 2>/dev/null || echo "UNREADABLE")
            if [ "$EXISTING_TARGET" = "$TARGET" ]; then
                PLAN_ACTION+=("relock|$LOCAL_PATH")
                PLAN_DISPLAY+=("  ${GREEN}[OK]${RESET}      $LOCAL_PATH — already correct. Will verify lock.")
                ALREADY_OK=$((ALREADY_OK + 1))
            elif [ "$EXISTING_TARGET" = "UNREADABLE" ]; then
                echo -e "  ${RED}[ERROR]${RESET}   Cannot read symlink at $LOCAL_PATH. Please inspect manually."
                ERRORS=$((ERRORS + 1))
            else
                echo -e "  ${YELLOW}[WARN]${RESET}    $LOCAL_PATH points to unexpected location:"
                echo -e "            Current:  $EXISTING_TARGET"
                echo -e "            Expected: $TARGET"
                PLAN_ACTION+=("replace_symlink|$LOCAL_PATH|$TARGET")
                PLAN_DISPLAY+=("  ${YELLOW}[REPLACE]${RESET} $LOCAL_PATH — will redirect to Hub.")
            fi
        elif [ -d "$LOCAL_PATH" ]; then
            PLAN_ACTION+=("backup_dir|$LOCAL_PATH|$TARGET")
            PLAN_DISPLAY+=("  ${YELLOW}[BACKUP]${RESET}  $LOCAL_PATH — directory will be backed up, then linked.")
        elif [ -f "$LOCAL_PATH" ]; then
            PLAN_ACTION+=("backup_file|$LOCAL_PATH|$TARGET")
            PLAN_DISPLAY+=("  ${YELLOW}[BACKUP]${RESET}  $LOCAL_PATH — file will be backed up, then linked.")
        else
            PLAN_ACTION+=("fresh_link|$LOCAL_PATH|$TARGET")
            PLAN_DISPLAY+=("  ${GREEN}[NEW]${RESET}     $LOCAL_PATH → $TARGET")
        fi
    done

    # ── Print the plan ──
    if [ ${#PLAN_DISPLAY[@]} -eq 0 ]; then
        echo ""
        echo "No supported AI agent directories were found on this machine."
        echo "(Skipped $SKIPPED paths where the parent tool is not installed.)"
        exit 0
    fi

    echo -e "${BOLD}Planned Actions:${RESET}"
    for line in "${PLAN_DISPLAY[@]}"; do
        echo -e "$line"
    done

    if [ $SKIPPED -gt 0 ]; then
        echo ""
        echo -e "  ${DIM}($SKIPPED agent paths skipped — those tools are not installed.)${RESET}"
    fi

    if [ $ERRORS -gt 0 ]; then
        echo ""
        echo -e "${RED}${BOLD}✗ $ERRORS critical issue(s) detected. Aborting for safety.${RESET}"
        echo "  Please resolve the errors above and re-run."
        exit 1
    fi

    # If everything is already correctly synced, just confirm and exit
    if [ ${#PLAN_ACTION[@]} -eq $ALREADY_OK ] && [ $ALREADY_OK -gt 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}✓ All $ALREADY_OK agent(s) already synced and locked. Nothing to do!${RESET}"
        
        # Offer global configuration of agents even if synced
        configure_global_agents
        
        exit 0
    fi

    # ── PHASE 2: CONFIRMATION ──
    echo ""
    echo -e "${CYAN}${BOLD}=== PHASE 2: CONFIRMATION ===${RESET}"
    read -rp "[?] Does this plan look correct? Type 'y' to implement, or anything else to abort: " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Safely aborted. Zero files were touched."
        exit 0
    fi

    # ── PHASE 3: IMPLEMENTATION ──
    echo ""
    echo -e "${CYAN}${BOLD}=== PHASE 3: IMPLEMENTATION ===${RESET}"

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    WAL_FILE="$HOME/.agnostic-ai-agent-sync.wal"
    : > "$WAL_FILE" # Create/truncate the WAL file

    rollback_wal() {
        echo ""
        echo -e "${RED}${BOLD}⨯ Interrupt caught or error occurred! Rolling back changes...${RESET}"
        if [ ! -s "$WAL_FILE" ]; then
            echo "Nothing to roll back."
            exit 1
        fi
        
        # Read WAL into array to process in reverse
        mapfile -t WAL_LINES < "$WAL_FILE"
        for (( idx=${#WAL_LINES[@]}-1 ; idx>=0 ; idx-- )) ; do
            IFS='|' read -r OP PATH1 PATH2 <<< "${WAL_LINES[idx]}"
            if [ "$OP" = "LOCKED" ]; then
                remove_lock "$PATH1"
            elif [ "$OP" = "LINKED" ]; then
                rm -f "$PATH1"
            elif [ "$OP" = "BACKED_UP" ]; then
                mv "$PATH2" "$PATH1" 2>/dev/null || true
            fi
        done
        echo "Rollback complete. Your filesystem was restored to its pre-sync state."
        rm -f "$WAL_FILE"
        exit 1
    }

    # Trap interrupts and errors
    trap 'rollback_wal' INT TERM ERR

    for ACTION_ENTRY in "${PLAN_ACTION[@]}"; do
        IFS='|' read -r ACTION_TYPE ACTION_PATH ACTION_TARGET <<< "$ACTION_ENTRY"

        case "$ACTION_TYPE" in
            relock)
                remove_lock "$ACTION_PATH"
                apply_lock "$ACTION_PATH"
                echo "LOCKED|$ACTION_PATH" >> "$WAL_FILE"
                echo -e " ${GREEN}[OK]${RESET} Verified lock: $ACTION_PATH"
                ;;

            replace_symlink)
                remove_lock "$ACTION_PATH"
                rm "$ACTION_PATH"
                ln -s "$ACTION_TARGET" "$ACTION_PATH"
                echo "LINKED|$ACTION_PATH" >> "$WAL_FILE"
                apply_lock "$ACTION_PATH"
                echo "LOCKED|$ACTION_PATH" >> "$WAL_FILE"
                echo -e " ${GREEN}[OK]${RESET} Replaced and locked: $ACTION_PATH → $ACTION_TARGET"
                ;;

            backup_dir|backup_file)
                BACKUP_PATH="${ACTION_PATH}.backup_${TIMESTAMP}"
                echo "BACKED_UP|$ACTION_PATH|$BACKUP_PATH" >> "$WAL_FILE"
                mv "$ACTION_PATH" "$BACKUP_PATH"
                echo -e " ${YELLOW}[BACKED UP]${RESET} $ACTION_PATH → $BACKUP_PATH"
                ln -s "$ACTION_TARGET" "$ACTION_PATH"
                echo "LINKED|$ACTION_PATH" >> "$WAL_FILE"
                apply_lock "$ACTION_PATH"
                echo "LOCKED|$ACTION_PATH" >> "$WAL_FILE"
                echo -e " ${GREEN}[OK]${RESET} Linked and locked: $ACTION_PATH → $ACTION_TARGET"
                ;;

            fresh_link)
                ln -s "$ACTION_TARGET" "$ACTION_PATH"
                echo "LINKED|$ACTION_PATH" >> "$WAL_FILE"
                apply_lock "$ACTION_PATH"
                echo "LOCKED|$ACTION_PATH" >> "$WAL_FILE"
                echo -e " ${GREEN}[OK]${RESET} Created and locked: $ACTION_PATH → $ACTION_TARGET"
                ;;
        esac
    done

    # Clear WAL and traps on success
    trap - INT TERM ERR
    rm -f "$WAL_FILE"

    echo ""
    echo "==============================================="
    echo -e "${GREEN}${BOLD}  ✓ Success! All agents are securely synced.${RESET}"
    echo "==============================================="

    # Offer cleanup of backup files
    offer_cleanup

    # Offer global configuration of agents
    configure_global_agents

    echo ""
    echo "Useful commands:"
    echo "  ./sync.sh status   — Check health of all symlinks"
    echo "  ./sync.sh cleanup  — Remove old backup files"
    echo "  ./unsync.sh        — Unlock all symlinks for manual editing"
}

# ─── CLEANUP command ─────────────────────────────────────────────
find_backups() {
    build_agent_map
    declare -a BACKUP_PATHS=()

    for ENTRY in "${AGENT_MAP[@]}"; do
        LOCAL_PATH="${ENTRY%%|*}"
        PARENT_DIR=$(dirname "$LOCAL_PATH")
        BASENAME=$(basename "$LOCAL_PATH")

        if [ ! -d "$PARENT_DIR" ]; then continue; fi

        # Find .backup_ files/dirs matching this path
        while IFS= read -r -d '' backup; do
            BACKUP_PATHS+=("$backup")
        done < <(find "$PARENT_DIR" -maxdepth 1 -name "${BASENAME}.backup_*" -print0 2>/dev/null)
    done

    echo "${BACKUP_PATHS[@]}"
}

offer_cleanup() {
    build_agent_map
    declare -a BACKUP_PATHS=()

    for ENTRY in "${AGENT_MAP[@]}"; do
        LOCAL_PATH="${ENTRY%%|*}"
        PARENT_DIR=$(dirname "$LOCAL_PATH")
        BASENAME=$(basename "$LOCAL_PATH")

        if [ ! -d "$PARENT_DIR" ]; then continue; fi

        while IFS= read -r -d '' backup; do
            BACKUP_PATHS+=("$backup")
        done < <(find "$PARENT_DIR" -maxdepth 1 -name "${BASENAME}.backup_*" -print0 2>/dev/null)
    done

    if [ ${#BACKUP_PATHS[@]} -eq 0 ]; then
        return
    fi

    echo ""
    echo -e "${CYAN}${BOLD}Found ${#BACKUP_PATHS[@]} backup(s) from previous sync runs:${RESET}"
    TOTAL_SIZE=0
    for backup in "${BACKUP_PATHS[@]}"; do
        if [ -d "$backup" ]; then
            SIZE=$(du -sh "$backup" 2>/dev/null | cut -f1)
        else
            SIZE=$(ls -lh "$backup" 2>/dev/null | awk '{print $5}')
        fi
        echo -e "  ${DIM}$backup ($SIZE)${RESET}"
    done

    echo ""
    read -rp "[?] Delete these backups? They are no longer needed. (y/N): " DO_CLEANUP

    if [[ ! "$DO_CLEANUP" =~ ^[Yy]$ ]]; then
        echo -e "  ${DIM}Kept. Run ./sync.sh cleanup anytime to remove them later.${RESET}"
        return
    fi

    for backup in "${BACKUP_PATHS[@]}"; do
        rm -rf "$backup"
        echo -e "  ${GREEN}[Deleted]${RESET} $backup"
    done
    echo -e "${GREEN}Cleanup complete.${RESET}"
}

cmd_cleanup() {
    echo ""
    echo "==============================================="
    echo "  Agnostic AI Agent Sync — Cleanup Backups"
    echo "==============================================="
    echo ""

    offer_cleanup

    build_agent_map
    declare -a CHECK_BACKUPS=()
    for ENTRY in "${AGENT_MAP[@]}"; do
        LOCAL_PATH="${ENTRY%%|*}"
        PARENT_DIR=$(dirname "$LOCAL_PATH")
        BASENAME=$(basename "$LOCAL_PATH")
        if [ ! -d "$PARENT_DIR" ]; then continue; fi
        while IFS= read -r -d '' backup; do
            CHECK_BACKUPS+=("$backup")
        done < <(find "$PARENT_DIR" -maxdepth 1 -name "${BASENAME}.backup_*" -print0 2>/dev/null)
    done

    if [ ${#CHECK_BACKUPS[@]} -eq 0 ]; then
        echo "No backup files found. Nothing to clean up."
    fi
}

# ─── CLI router ──────────────────────────────────────────────────
case "${1:-}" in
    status)
        cmd_status
        ;;
    cleanup)
        cmd_cleanup
        ;;
    version|--version|-v)
        echo "Agnostic AI Agent Sync v$VERSION"
        ;;
    help|--help|-h)
        echo "Usage: ./sync.sh [command]"
        echo ""
        echo "Commands:"
        echo "  (none)     Run the interactive sync wizard"
        echo "  status     Check health of all symlinks"
        echo "  cleanup    Remove old .backup_ files from previous syncs"
        echo "  version    Show version number"
        echo "  help       Show this help message"
        ;;
    "")
        cmd_sync
        ;;
    *)
        echo -e "${RED}Unknown command: $1${RESET}"
        echo "Run ./sync.sh help for usage."
        exit 1
        ;;
esac
