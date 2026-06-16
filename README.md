# 🧠 Agnostic Agent Router

> **A unified capability router for your AI Agents.** A portable, platform-agnostic environment that turns generic coding assistants into high-agency autonomous engineers.

[![Sync](https://img.shields.io/badge/Sync-Dropbox-blue.svg)](#)
[![Supported Agents](https://img.shields.io/badge/Agents-Antigravity%20%7C%20Gemini%20%7C%20Claude%20%7C%20OpenAI-success.svg)](#)

## The Problem
As AI agents scale, context windows get bloated. If you install 1,500+ skills directly into an agent, it hallucinates. If you don't install them, the agent is useless. Worse, managing MCP (Model Context Protocol) servers across different CLIs and GUI apps is a manual, fragmented nightmare.

## The Solution
The **Agnostic Agent Router** is a "Library Bootloader." It separates your **Knowledge** (The Vault) from your **Compute** (The Agent). 

By running the bootloader, you instantly inject a **Master Skill Router** (The Librarian) into your agent. The Librarian dynamically searches, proposes, and loads capabilities *Just-In-Time* (JIT), keeping context lean while offering unlimited scale.

### 🌟 Core Capabilities

* 🧩 **Agnostic Symlinking:** Connects `~/.gemini`, `~/.claude`, `~/.agy`, and OpenAI clients to your central cloud-synced brain. Switch vendors without losing a single skill.
* 🤖 **The Librarian-Operator:** An advanced JIT router that doesn't just read markdown—it executes frameworks, clones repos, and runs CLI tools autonomously.
* 🔌 **Centralized MCP Registry:** Hard-links a single `mcp_config.json` across all your agent platforms. When the Librarian installs a new MCP tool, it's instantly available everywhere.
* 🕵️ **Zero-Metadata Discovery:** Drop any GitHub repo into your vault. The Librarian infers its purpose from `README.md` or `package.json`—no manual tagging required.
* 🛡️ **Automated Trust Policies:** Injects your Vault into agent trust files (`trustedFolders.json`) so your Librarian never gets blocked by security prompts when accessing its own tools.

## Architecture

* **The Bootloader (`sync.sh`)**: The script that configures the local machine.
* **The Brain (`vault/`)**: Your cloud-hosted directory of 1,500+ skills, frameworks, and MCP servers.
* **The Registrar (`config/mcp_config.json`)**: The single source of truth for active software tools.
* **The Librarian (`skill-router/SKILL.md`)**: The autonomous persona that navigates the vault.

## Quick Start

```bash
# Clone the bootloader
git clone https://github.com/cliffordp/agnostic-agent-router.git
cd agnostic-agent-router

# Boot the environment
./sync.sh
```
*Note: Ensure your `AGENTS_DIR` variables in `sync.sh` map to your actual cloud storage location.*

## Windows (PowerShell) Support

The bootloader fully supports Windows via the included `sync.ps1` script. It uses Windows native Directory Junctions to achieve the same agnostic symlinking capability.

```powershell
powershell -ExecutionPolicy Bypass -File .\sync.ps1
```

If you need to uninstall the bootloader, use the included unsync script:

```powershell
powershell -ExecutionPolicy Bypass -File .\unsync.ps1
```

## Example Screenshots

Ran on Cliff's macOS after he already manually created symlinks (what this script would automatically do for you), indicating that it gracefully works even if you've partially implemented what this script does.

<img width="364" height="116" alt="2026-04-15 sync status" src="https://github.com/user-attachments/assets/8a9c75d9-4098-4b17-a2a8-7a0e35163b80" />

* * *

<img width="762" height="382" alt="2026-04-15 sync 1 of 2" src="https://github.com/user-attachments/assets/3cb8f345-7269-4390-b210-b209a9c46eac" />
<img width="866" height="314" alt="2026-04-15 sync 2 of 2" src="https://github.com/user-attachments/assets/0c7ef861-82e3-4aa6-add2-3cedff3c3f32" />

* * *

<img width="778" height="312" alt="2026-04-15 sync status after syncing" src="https://github.com/user-attachments/assets/c1557cf8-ce4f-4ae9-8b5f-331778d4675e" />

* * *

<img width="538" height="376" alt="2026-04-15 easily choose your Hub&#39;s location" src="https://github.com/user-attachments/assets/c88d25b9-fa66-4a04-b9cb-f6e6d2463c44" />

## Unlocking / Undoing

Need to modify or remove the symlinks? Run the unlock script first:

#### Mac / Linux
```bash
chmod +x unsync.sh
./unsync.sh
```

This script safely reverses the sync process without losing your new skills:
1. Removes the immutable OS locks from all symlinks
2. Deletes the symlinks to disconnect the local tools from your Hub
3. Everything in your Hub is left untouched and safe
4. Your `.backup_*` folders are left untouched

## FAQ

**Q: Will this delete my existing skills?**
No. Any existing folders or files are renamed to `.backup_TIMESTAMP` before a symlink is created. You can always find them right next to the original path.

**Q: Do I have to answer the Hub wizard every time?**
No. After the first run, your Hub path is saved to `~/.agnostic-ai-agent-sync`. Future runs remember it automatically and skip straight to the analysis.

**Q: What if I install a new AI coding tool later?**
Just re-run `./sync.sh`. It auto-detects newly installed agents and offers to wire them up. Already-synced agents are left untouched.

**Q: Can I sync skills across multiple computers?**
Yes — that's a big reason this tool exists. Put your Hub folder in Dropbox, iCloud Drive, OneDrive, or any cloud-synced directory. Run `./sync.sh` on each machine. They'll all point to the same shared Hub.

**Q: What about per-project rules like `.cursorrules` in a repo?**
This tool only manages **global** (user-level) config. Per-project files inside your repositories (`.cursorrules`, `.claude/`, `.windsurf/rules/`) are untouched and work as normal alongside these global symlinks.

## License & Disclaimer

[MIT License](LICENSE) — use it, star it, fork it, embed it in your workflows. 

This tool modifies symlinks and file system permissions on your machine. While it is designed with safety guardrails (dry-run analysis, confirmation prompts, automatic backups), **you use it at your own risk**. Always review the analysis output before confirming.
