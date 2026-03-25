<p align="center">
  <img src="Screenshots/AppIcon.png" width="128" alt="HarbourMaster icon">
</p>

<h1 align="center">HarbourMaster</h1>
<p align="center">Know what's running on your ports.</p>

<p align="center">
  <a href="https://github.com/jalonsogo/harbourmaster/releases/latest">
    <img src="https://img.shields.io/github/v/release/jalonsogo/harbourmaster?style=flat-square&color=34d058&label=Download" alt="Download">
  </a>
  <img src="https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square" alt="macOS 13+">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square" alt="MIT">
</p>

<br>

<p align="center">
  <img src="Screenshots/Screen 1.png" width="280">
  <img src="Screenshots/Screen 2.png" width="280">
  <img src="Screenshots/Screen 3.png" width="280">
</p>

---

HarbourMaster lives in your menu bar and shows every TCP port currently in use — instantly, without opening a terminal. It detects dev servers, Docker containers, and macOS system services, and tells you exactly what's running and where.

## Features

**Port monitoring**
- Background scan every 5 seconds — notified the moment a port opens or closes via a HUD toast (no permissions required)
- Automatically recognises dev runtimes (node, python, bun, go, ruby, deno, rust, java…) regardless of port number
- Configurable dev port list with individual ports and ranges (e.g. `3000–3400`), with overlap warnings

**Per-port actions**
- Open in browser · Copy URL · Open in Finder · Open in Terminal · Copy path · Kill process

**Docker**
- Ports resolved to real container names and images via `docker ps`
- Grouped by Compose project — one line per stack, hover to expand services
- Per-container: Restart · Pause/Unpause · Stop · View Logs · View Project Logs · Open Shell
- Opens containers in Docker Desktop or OrbStack (auto-detected)
- Real CPU/memory stats from `docker stats`, not host proxy RSS

**Color legend**

| | Meaning |
|--|---------|
| 🟢 circle | Dev port — known runtime or configured port |
| 🔵 circle | Other user process |
| 🟢 box | Docker container — running |
| ⚪ box | Docker container — paused |
| 🟠 shield | macOS system service (AirPlay, Handoff…) |

## Settings

Four-tab window (`⌘,`) — launch at login, preferred browser, preferred terminal, Docker container manager (Docker Desktop / OrbStack), configurable dev ports and ranges.

<p align="center">
  <img src="Screenshots/settings 1.png" width="380">
  <img src="Screenshots/settings 2.png" width="380">
</p>

## Requirements

- macOS 13 Ventura or later
- Docker CLI (optional — required for Docker features)
