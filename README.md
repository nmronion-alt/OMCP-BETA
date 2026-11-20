# 🧅 OMCP — Onion Minecraft Control Panel

<p align="center">
  <strong>A self-hosted Minecraft server control panel.</strong><br>
  Manage your Minecraft servers, files, worlds, plugins, backups and network access from one clean dashboard.
</p>

<p align="center">
  <a href="https://discord.gg/kRGg2HjRKn">💬 Join our Discord</a>
  &nbsp;•&nbsp;
  <a href="https://www.youtube.com/@not_mr_onion1">▶️ YouTube — not Mr Onion</a>
</p>

<p align="center">
  <strong>Created by not Mr Onion</strong>
</p>

---

## ⚡ Install OMCP

Run this command on a fresh Ubuntu/Debian Linux host with root or `sudo` access:

```bash
curl -fsSL https://raw.githubusercontent.com/nmronion-alt/OMCP-BETA/fix/beta-cloudshell-create/install-omcp.sh -o /tmp/omcp.sh && if [ "$(id -u)" -eq 0 ]; then bash /tmp/omcp.sh; else sudo bash /tmp/omcp.sh; fi
```

The installer detects whether the host provides a platform `PORT` (for example, Railway). If it does, OMCP binds to `0.0.0.0:$PORT` and skips the outbound tunnl.gg dependency; open the HTTPS domain assigned by that platform. On a normal VPS without `PORT`, OMCP stays on localhost and uses tunnl.gg for the browser panel link.

> **Compatibility:** The installer currently targets Debian/Ubuntu with `apt-get` and root access. It supports hosts without systemd, but a host must allow long-running processes, provide persistent storage for `/var/lib/omcp`, and permit the required outbound downloads. A platform's generated web domain exposes only the panel's HTTP(S) traffic; Minecraft player connections still need a separate TCP relay. Temporary or sleep-prone free tiers may stop the panel or server.

## ✨ What is OMCP?

OMCP is a self-hosted control panel for managing Minecraft Java servers on your own Linux host. It includes a web dashboard and a local agent that controls the Minecraft server process and its files.

**How it works**

```text
Your Browser
    │
    ▼
OMCP Web Panel (HTTPS)
    │
    ▼
OMCP Agent on your VPS
    │
    ├── Minecraft Server
    ├── Server Files & Worlds
    ├── Plugins & Configuration
    └── Backups & Network Routing
```

The management API listens on `127.0.0.1:8765` by default on ordinary VPS installs. On platforms that provide `PORT`, it binds to `0.0.0.0:$PORT` so the platform's HTTP ingress can reach it.

## 🚀 Features

| Area | What you can do |
|---|---|
| 🖥️ **Server Console** | Start, stop and restart servers, send console commands, and view live/recent logs |
| 📦 **Server Software** | Create and manage supported Minecraft server types and choose available versions |
| 📁 **File Manager** | Browse, upload, edit, rename, delete, download and archive server files; extract ZIP archives |
| 🌍 **World Manager** | View server worlds, import worlds from ZIP or folder, and manage eligible worlds |
| ⚙️ **Options** | Configure common server properties, gameplay settings and MOTD with a formatted preview |
| 🧩 **Plugins** | Browse compatible plugin catalogues, choose versions and install plugins on supported Bukkit-based servers |
| 🧵 **Fabric Mods** | Browse Modrinth Fabric mods and modpacks, select compatible releases and install them |
| 👥 **Players** | Read live status samples and manage ban, unban and operator records without sending console commands |
| 💾 **Backups** | Create ZIP backups and schedule local VPS or Google Drive backups |
| 🔐 **SFTP** | Generate SFTP credentials and create a dedicated Pinggy TCP host for remote file clients |
| 🌐 **Network Routing** | Use the currently implemented Pinggy, Bore and Minekube Connect routes; provider availability depends on host/network setup |
| 📊 **Resource Information** | View host memory and CPU-thread information |
| 👤 **Accounts** | Set up an admin account and sign in with protected password storage |

Feature availability depends on the selected Minecraft software, version, host environment and configured providers. Some plugin or server-software combinations may need a manual restart or additional compatibility checks.

## 🧰 Requirements

- Debian or Ubuntu Linux host/container (`apt-get`)
- Root or `sudo` access
- A platform-provided `PORT` for direct platform ingress, or outbound SSH access for the optional tunnl.gg panel tunnel
- Internet connection for installation and downloads
- A persistent host for long-running use

The installer installs the runtime components it needs, including Java 21 where required.

## 🔒 Security & networking

- On a normal VPS, the OMCP management API binds to localhost (`127.0.0.1:8765`) and is published through its HTTPS tunnel.
- On a platform with an assigned `PORT`, OMCP binds to `0.0.0.0:$PORT`; protect the platform domain with the application's login and the platform's access controls.
- Keep your admin credentials private and use a trusted HTTPS access method.
- Minecraft Java player traffic uses a separate TCP route/relay; a web HTTPS tunnel alone does not carry Minecraft TCP connections.
- Local backups stay on the VPS. They are not off-site and can be lost if the host is lost.
- Google Drive backups require your own Google OAuth configuration.

## 🧑‍💻 Project files

- `agent/omcp_agent.py` — local API and Minecraft process manager
- `index.html` — OMCP web dashboard
- `install-omcp.sh` — installer
- `docs/ARCHITECTURE.md` — architecture and security notes

## 💬 Community & updates

Questions, feedback or ideas? Join the community:

- **Discord:** https://discord.gg/kRGg2HjRKn
- **YouTube:** https://www.youtube.com/@not_mr_onion1

---

<p align="center">
  Made with 🧅 by <strong>not Mr Onion</strong>
</p>
