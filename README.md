# 🧠 Agnostic Agent Router

> **The "Operating System" for your AI Agents.** A portable, platform-agnostic environment that turns generic chatbots into high-agency autonomous engineers.

[![Sync](https://img.shields.io/badge/Sync-Dropbox-blue.svg)](#)
[![Supported Agents](https://img.shields.io/badge/Agents-Antigravity%20%7C%20Gemini%20%7C%20Claude-success.svg)](#)

## The Problem
As AI agents scale, context windows get bloated. If you install 1,500+ skills directly into an agent, it hallucinates. If you don't install them, the agent is useless. Worse, managing MCP (Model Context Protocol) servers across different CLIs and GUI apps is a manual, fragmented nightmare.

## The Solution
The **Agnostic Agent Router** is a "Library Bootloader." It separates your **Knowledge** (The Vault) from your **Compute** (The Agent). 

By running the bootloader, you instantly inject a **Master Skill Router** (The Librarian) into your agent. The Librarian dynamically searches, proposes, and loads capabilities *Just-In-Time* (JIT), keeping context lean while offering unlimited scale.

### 🌟 Core Capabilities

* 🧩 **Agnostic Symlinking:** Connects `~/.gemini`, `~/.claude`, and `~/.agy` to your central cloud-synced brain. Switch clients without losing a single skill.
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
