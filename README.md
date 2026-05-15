# Tiqdo

A minimal, native macOS menu bar task manager built around the **Now / Nxt / Ltr** prioritization system.

![Tiqdo Screenshot](screenshot.png)

## Philosophy

Most to-do apps fail because of poor structure, not lack of discipline. Tiqdo fixes this with three simple lanes:

- **NOW** — What needs your attention today. Keep it to 3-5 tasks.
- **NXT** — Tomorrow's priorities, captured today. Your next move is already waiting.
- **LTR** — Parked, not forgotten. Ideas and future plans for when the time comes.

Drag between lanes as priorities shift. That's it.

## Features

- **Menu bar native** — One click to open, one click to close. No dock icon, no window clutter.
- **Three-lane system** — NOW / NXT / LTR with drag & drop between lanes and reordering within.
- **Multiple tabs** — Up to 4 separate contexts (Work, Personal, Home, ...), each with its own lanes.
- **Global shortcut** — `Ctrl+Q` summons Tiqdo from any app, including fullscreen.
- **Tab switching** — `Ctrl+Tab` cycles through tabs instantly.
- **Dark UI** — Purpose-built dark interface with colored lane badges.
- **Resizable** — Drag the edge to resize. Size is remembered between sessions.
- **Completed task cleanup** — Trash button clears done tasks. Tasks completed over 24h ago are auto-removed.
- **Task completion history** — Browse completed tasks grouped by day. Configurable retention up to 10,000 records.
- **100% private** — No accounts, no cloud, no analytics. All data stays on your Mac in Application Support.
- **Launch at login** — Optional, configurable in settings.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+Q` | Toggle Tiqdo (global, works from any app) |
| `Ctrl+Tab` | Switch to next tab |
| `Enter` | Confirm new task / save edit |
| `Escape` | Cancel edit / close panel |

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Install

```bash
git clone https://github.com/petrfilip/Tiqdo.git
cd Tiqdo
./build.sh
```

The script compiles the project with `swiftc` and creates an app bundle at `.build/Tiqdo.app`.

To install a symlink to `/Applications/Tiqdo.app`:

```bash
./build.sh --install
```

To launch:

```bash
./build.sh --launch
```

On first launch, macOS may block the app. Go to **System Settings > Privacy & Security > Open Anyway**.

## License

MIT
