# HarbourMaster ⚓

A native macOS menu bar app that shows every TCP port currently in use on your machine — with deep integrations for Docker, process management, and developer tooling.

## Features

### Port monitoring
- Lists all TCP ports in LISTEN state, refreshed automatically every time you open the menu
- Groups ports into **Dev Ports**, **Docker**, and **Other** sections
- One-click **Open in Browser** for any port (`http://localhost:<port>`)

### Color legend
| Icon | Meaning |
|------|---------|
| 🟢 `circle.fill` green | Dev port — well-known dev server port (3000, 8080, 5173, …) |
| 🔵 `circle.fill` blue | Other user process |
| 🟢 `shippingbox.fill` green | Docker container — running |
| ⚪ `shippingbox.fill` gray | Docker container — paused |
| 🟠 `shield.fill` orange | macOS system service (AirPlay, Handoff, …) |

### Per-port submenu
Every port shows:
- **CPU %** and **RAM** usage
- **Open in Browser** — uses your preferred browser (configurable)
- **Open in Finder** — reveals the process working directory
- **Open in Terminal** — opens the working directory in your preferred terminal
- **Copy Path**
- **Kill Process** (with a safety confirmation for macOS system services)

### Docker integration
When a port is mapped from a Docker container, HarbourMaster queries the Docker CLI and shows:
- **Container name**, **image**, **compose project**, and **port mapping**
- Containers grouped by **Docker Compose project/stack** within the Docker section
- Click container name or image to **open in Docker Desktop or OrbStack**
- **Restart**, **Pause/Unpause**, **Stop** the container directly from the menu
- **View Container Logs** — opens `docker logs -f <name>` in your terminal
- **View Project Logs** — opens `docker compose logs -f` for the whole stack

### Settings (`⌘,`)
- **Launch at login** via `SMAppService`
- **Browser** — Default, Safari, Chrome, Firefox, Arc, Brave, Edge (shows only installed browsers)
- **Terminal** — Default, iTerm2, Ghostty, Kitty, Warp, Alacritty, Hyper (shows only installed terminals)
- **Docker section** — toggle visibility, choose container manager (Auto-detect / Docker Desktop / OrbStack)
- **Legend** — color and icon reference

## Requirements
- macOS 13 Ventura or later
- Docker CLI (optional — required for Docker features)

## Build & run

```bash
git clone https://github.com/jalonsogo/harbourmaster.git
cd harbourmaster
./build.sh
open HarbourMaster.app
```

### Install to /Applications

```bash
./install.sh
```

## Project structure

```
Sources/HarbourMaster/
├── main.swift                   # NSApplication entry point
├── AppDelegate.swift            # NSStatusItem, menu building, all actions
├── PortInfo.swift               # Port data model
├── PortScanner.swift            # lsof + ps parsing
├── DockerScanner.swift          # docker ps parsing + container actions
├── AppSettings.swift            # UserDefaults-backed settings, browser/terminal routing
├── SettingsView.swift           # SwiftUI settings form
└── SettingsWindowController.swift
```
