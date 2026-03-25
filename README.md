# HarbourMaster ⚓

A native macOS menu bar app that shows every TCP port currently in use on your machine — with deep integrations for Docker, process management, and developer tooling.

## Features

### Port monitoring
- Scans all TCP ports in LISTEN state **concurrently** (lsof + Docker + ps run in parallel)
- **Background polling every 5 seconds** — detects port changes without opening the menu
- Groups ports into **Dev Ports**, **Docker**, and **Other** sections
- **Dev Ports** includes any port run by a known runtime (node, python, bun, go, ruby, deno, rust, java, …) regardless of port number, plus a configurable list of port numbers

### Notifications
- **Floating HUD toast** appears in the top-right corner when a port opens or closes — no system notification permissions required
- Toggle on/off in Settings

### Color legend
| Icon | Meaning |
|------|---------|
| 🟢 `circle.fill` green | Dev port — known runtime or configured dev port number |
| 🔵 `circle.fill` blue | Other user process |
| 🟢 `shippingbox.fill` green | Docker container — running |
| ⚪ `shippingbox.fill` gray | Docker container — paused |
| 🟠 `shield.fill` orange | macOS system service (AirPlay, Handoff, …) |

### Per-port submenu
Every port shows:
- **Open in Browser** — always first; uses your preferred browser (configurable)
- **Copy URL** — copies `http://localhost:<port>` to clipboard
- **CPU %** and **RAM** usage (container-level stats for Docker ports)
- **Open in Finder** — reveals the process working directory
- **Open in Terminal** — opens the working directory in your preferred terminal
- **Copy Path**
- **Kill Process** (with a safety confirmation for macOS system services)

### Docker integration
- Ports mapped from Docker containers are detected and grouped by **Compose project** — one line per stack, hover to expand services
- Each container row shows container name, image, project, and port mapping — **click any row to copy its value**
- **Open in Docker Desktop / OrbStack** — dedicated action per container
- **Restart**, **Pause/Unpause**, **Stop** the container directly from the menu
- **View Container Logs** — opens `docker logs -f <name>` in your terminal
- **View Project Logs** — opens `docker compose logs -f` for the whole stack
- **Open Shell** — opens `docker exec -it <name> /bin/sh` in your terminal
- Container **CPU %** and **memory** from `docker stats` (not host process RSS)

### Settings (`⌘,`)
Four-tab toolbar window (System Settings style):

**General**
- Launch at login via `SMAppService`
- Browser — Default, Safari, Chrome, Firefox, Arc, Brave, Edge (shows only installed)
- Terminal — Default, iTerm2, Ghostty, Kitty, Warp, Alacritty, Hyper (shows only installed)
- Notifications toggle

**Docker**
- Show/hide Docker section in menu
- Container manager — Auto-detect / Docker Desktop / OrbStack (affects deep-link behaviour)

**Dev Ports**
- Add/remove individual port numbers
- Add port **ranges** (e.g. `3000-3400`) — warns if an existing port falls inside the range
- Range overlap detection

**Legend**
- Icon and colour reference

## Requirements
- macOS 13 Ventura or later
- Docker CLI (optional — required for Docker features)

## Build & run

```bash
git clone https://github.com/jalonsogo/harbourmaster.git
cd harbourmaster
./build.sh        # builds, assembles .app bundle, ad-hoc signs
open HarbourMaster.app
```

### Install to /Applications

```bash
./install.sh
```

> **Note:** The app is ad-hoc signed (not notarized). On first launch macOS may block it. Run:
> ```bash
> xattr -cr /Applications/HarbourMaster.app
> ```

## Project structure

```
Sources/HarbourMaster/
├── main.swift                     # NSApplication entry point
├── AppDelegate.swift              # NSStatusItem, menu building, all actions
├── PortInfo.swift                 # Port data model + dev runtime detection
├── PortScanner.swift              # Concurrent lsof + ps + Docker scanning
├── DockerScanner.swift            # docker ps parsing, stats, container actions
├── AppSettings.swift              # UserDefaults-backed settings + routing helpers
├── SettingsWindowController.swift # NSToolbar-based settings window
├── SettingsView.swift             # SwiftUI tab content (General/Docker/Dev Ports/Legend)
└── HUDNotification.swift          # Floating toast notification panel
```
