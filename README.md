# Agnostic AI Agent Sync

Maintain a single unified folder of AI agent skills and instructions, making it seamless to switch between Antigravity, Claude, Codex, Cursor, Qoder, Windsurf, and others.

Dependency-free, with OS-level immutable symlinks — protected from being accidentally deleted or overwritten by aggressive IDE updates.

## The Problem

Using multiple AI coding tools means your custom instructions end up scattered across `~/.cursorrules`, `~/.claude/skills/`, `~/.codex/config/`, etc. Updating one meant manually copy-pasting to all the others — and inevitably forgetting one.

Worse, existing sync approaches create regular symlinks that are **easily overwritten** by IDE software updates, `git checkout` resets, or environment re-initialization. One bad update and your entire symlinked skill library vanishes.

## The Solution

**Agnostic AI Agent Sync** creates symlinks from each IDE's config location to a single "Hub" folder you control, then **locks them at the OS level** so nothing can silently delete them (like a new `git clone` command for that slick new Skill).

### Why This Is Different

| Feature | Generic symlinks / npm tools | Agnostic AI Agent Sync |
|---|---|---|
| Survives IDE updates | ❌ Silently deleted | ✅ OS-level immutable lock |
| Maps `.cursorrules` ↔ `CLAUDE.md` | ❌ Manual | ✅ Automatic |
| Dry-run before changes | ❌ YOLO | ✅ Full analysis + confirmation |
| Clean skill repos | ❌ Cloned repos pollute each other’s git state | ✅ Each repo is an independent sibling |
| Dependencies | Node.js / npm | **Zero** — native bash & PowerShell |
| Undo / unlock | Manual googling | ✅ Built-in `unsync` script removes locks and unlinks IDEs |

### How It Works

1. **Analyze** — Scans your system for installed AI agents, classifies what exists at each path (real folder, existing symlink, nothing), and prints a clear plan.
2. **Confirm** — Asks for your explicit `y` approval. If you say no, zero files are touched.
3. **Implement** — Backs up real folders, creates symlinks, and locks them with OS-level immutability (`chflags` on macOS, `chattr` on Linux, `icacls` on Windows).

## Setup Guide

### Option A: One-liner (Mac / Linux)

Copy and paste this into your terminal — it downloads and runs the script directly:

```bash
curl -fsSL https://raw.githubusercontent.com/cliffordp/agnostic-ai-agent-sync/main/sync.sh -o sync.sh && chmod +x sync.sh && ./sync.sh
```

### Option B: Clone the repo

Open your terminal (Mac/Linux) or PowerShell (Windows). Navigate to wherever you keep projects (e.g. `cd ~/Documents`), then run:

```bash
git clone https://github.com/cliffordp/agnostic-ai-agent-sync.git
cd agnostic-ai-agent-sync
```

> **Don't have `git`?** Click the green **Code** button on this page → **Download ZIP** → unzip it somewhere you'll remember → open your terminal inside that folder.

### Step 2: Run the sync

The script will walk you through everything — including creating your Hub folder if you don't have one yet.

#### Mac / Linux

```bash
chmod +x sync.sh
./sync.sh
```

#### Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\sync.ps1
```

The script will:
1. Ask where your Hub is (or help you create one)
2. Auto-detect and offer to merge any existing skill files scattered across your IDEs
3. Scan your system for installed AI agents
4. Show you exactly what it plans to do
5. Wait for you to type `y` before touching anything

> **Re-running is safe.** The script remembers your Hub path (saved to `~/.agnostic-ai-agent-sync`). Subsequent runs skip the wizard and go straight to analysis.

### Step 3: Check status (anytime)
Run this from wherever you downloaded or cloned the script:
```bash
./sync.sh status
```

Shows a dashboard of all your synced agents — whether each link is healthy, locked, broken, or not yet synced.

## Supported Agents

The script currently maps these paths to your Hub:

| Agent | Local Path | Hub Target |
|---|---|---|
| Claude | `~/.claude/skills/` | `Hub/skills/` |
| Claude | `~/.claude/config/` | `Hub/config/` |
| Codex | `~/.codex/skills/` | `Hub/skills/` |
| Codex | `~/.codex/config/` | `Hub/config/` |
| Cursor | `~/.cursor/skills/` | `Hub/skills/` |
| Cursor | `~/.cursorrules` | `Hub/config/CLAUDE.md` |
| Antigravity | `~/.gemini/antigravity/skills/` | `Hub/skills/` |
| Windsurf | `~/.codeium/windsurf/skills/` | `Hub/skills/` |
| Qoder | `~/.qoder/skills/` | `Hub/skills/` |

> If an agent isn't installed on your machine, it's automatically skipped.

### Not Currently Supported

These tools store their config in ways that aren't compatible with directory-level symlinking:

| Tool | Why |
|---|---|
| **Cline** | VS Code extension — global config lives inside VS Code's `settings.json`, not a standalone directory |
| **Roo Code** | VS Code extension — same architecture as Cline; per-project rules only (`.roo/`) |
| **Aider** | Config is a single YAML file (`~/.aider.conf.yml`), not a directory of skills |
| **Continue.dev** | Config is `~/.continue/config.json` — a JSON blob mixing API keys with settings |
| **GitHub Copilot** | Config embedded in VS Code/JetBrains settings; per-repo via `.github/copilot-instructions.md` |

## Unlocking / Undoing

Need to modify or remove the symlinks? Run the unlock script first:

#### Mac / Linux
```bash
chmod +x unsync.sh
./unsync.sh
```

#### Windows
```powershell
powershell -ExecutionPolicy Bypass -File .\unsync.ps1
```

This script safely reverses the sync process without losing your new skills:
1. Removes the immutable OS locks from all symlinks
2. Deletes the symlinks to disconnect the IDEs from your Hub
3. Everything in your Hub is left untouched and safe
4. Your `.backup_*` folders are left untouched

Your IDEs will now generate clean, empty folders. If you want to keep the skills you installed while synced, simply copy them from your Hub back into the IDE's local folder.

To re-link everything to the Hub later, just run `sync.sh` / `sync.ps1` again.

## FAQ

**Q: Will this delete my existing skills?**
No. Any existing folders or files are renamed to `.backup_TIMESTAMP` before a symlink is created. You can always find them right next to the original path. The script also offers to merge your scattered skills into the Hub before syncing. After a successful sync, you'll be asked if you want to clean up old backups.

**Q: How do I remove old backup files?**
The script offers to clean them up automatically after each sync. If you skipped that prompt, run `./sync.sh cleanup` (or `.\sync.ps1 cleanup` on Windows) anytime. It lists every backup with its size and asks before deleting anything.

**Q: Do I have to answer the Hub wizard every time?**
No. After the first run, your Hub path is saved to `~/.agnostic-ai-agent-sync`. Future runs remember it automatically and skip straight to the analysis.

**Q: What if I install a new IDE later?**
Just re-run `./sync.sh`. It auto-detects newly installed agents and offers to wire them up. Already-synced agents are left untouched.

**Q: How do I install new skills after syncing?**
Navigate to your Hub's `skills/` folder (or any synced path like `~/.claude/skills/` — they all point to the same place) and install normally. For example:

```bash
cd ~/.claude/skills/
git clone https://github.com/cliffordp/claude-skills
```

The new skill instantly appears in every synced IDE. The immutable lock protects the symlink itself from being deleted — but writing inside the directory works normally.

**Q: What if a symlink already points to the right place?**
The script detects this, skips re-creation, and just verifies the lock is applied. It's safe to run repeatedly.

**Q: What if a symlink points somewhere unexpected?**
The script flags it with a `[WARN]` in the analysis phase. You'll see exactly where it currently points and where it *should* point. If you confirm, it replaces it. If you abort, nothing changes.

**Q: Do I need admin/root access?**
On macOS, no. On Linux, `chattr` requires `sudo` (it will prompt). On Windows, Directory Junctions don't require admin — symlinks for `.cursorrules` may require Developer Mode enabled in Windows Settings.

**Q: Can I sync skills across multiple computers?**
Yes — that's a big reason this tool exists. Put your Hub folder in Dropbox, iCloud Drive, OneDrive, or any cloud-synced directory. Run `./sync.sh` on each machine. They'll all point to the same shared Hub.

**Q: Can I use iCloud Drive / Dropbox / OneDrive as my Hub?**
Absolutely. The script's guided setup even offers these as default choices. Cloud storage is the recommended location for your Hub.

**Q: What actually goes in the Hub?**
Two folders: `skills/` (your reusable SKILL.md files, prompt libraries, etc.) and `config/` (your CLAUDE.md or other global agent instructions). The script creates both automatically.

**Q: What about per-project rules like `.cursorrules` in a repo?**
This tool only manages **global** (user-level) config. Per-project files inside your repositories (`.cursorrules`, `.claude/`, `.windsurf/rules/`) are untouched and work as normal alongside these global symlinks.

**Q: Can I have different skills for different IDEs?**
Not with this tool — the whole point is a single shared set. If you need IDE-specific skills, manage those manually in per-project directories instead.

**Q: My IDE just updated and something seems broken. What do I do?**
Run `./sync.sh status` to check if the symlinks are still intact. If the lock held (which it should), you'll see all green. If something got overwritten, re-run `./sync.sh` to repair it.

**Q: How do I add support for a new AI agent?**
Open `sync.sh` (or `sync.ps1`), find the `AGENT_MAP` array, and add a new line following the `LOCAL_PATH|HUB_SUBFOLDER` pattern. PRs welcome!

**Q: Does running the sync script require an internet connection?**
No. Once you have the script files on your machine, everything runs locally. No web requests, no telemetry, no dependencies.

**Q: Can I install this via Homebrew?**
Not currently. Because this tool relies on local script execution to detect your home directory (`~/.claude`, etc.) and manages state via a saved `~/.agnostic-ai-agent-sync` config, dropping it into the `/usr/local/bin` / `/opt/homebrew` `$PATH` as a global executable isn't supported yet. The recommended approach is to keep the script in a dedicated directory (like `~/Documents/scripts/` or `~/GitHub/agent-sync/`).

**Q: Why is a Hub better than cloning skill repos directly into `~/.claude/skills/`?**
Without a Hub, cloning multiple skill repos into a single IDE directory (like `~/.claude/skills/`) mixes them together on disk. Running `git status` inside one repo shows the others as untracked files, requiring constant `.gitignore` maintenance. With a Hub, each skill repo is cloned as an independent sibling directory — clean `git status`, no `.gitignore` games, and every repo can be updated or removed without touching the others. See [claude-skills](https://github.com/cliffordp/claude-skills) for a curated collection that follows this pattern.

## License

[MIT License](LICENSE) — use it, star it, fork it, embed it in your workflows. 

## Disclaimer

This tool modifies symlinks and file system permissions on your machine. While it is designed with safety guardrails (dry-run analysis, confirmation prompts, automatic backups), **you use it at your own risk**. Always review the analysis output before confirming. The authors are not responsible for any data loss or misconfiguration resulting from use of this tool.

## Disclosure

This codebase was generated with the assistance of AI coding tools. The human author reviewed the code and tested the tool on macOS but not on Linux or Windows.
