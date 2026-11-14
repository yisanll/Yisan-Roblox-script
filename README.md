# Evade Script (Roblox)

A client-side Luau script for the Roblox game **Evade**, written for **Potassium** (also works on executors that support `loadstring`, `getgc`, `hookfunction` and HTTP requests).

Two versions are included:

| File | Language |
| --- | --- |
| `Evade.luau` | English UI |
| `躲避.luau` | Chinese UI |

Run **only one** of them at a time — they do the same thing and would conflict if loaded together.

## Features

- **ESP** — player boxes, monster boxes, optional self box, max-distance slider, downed indicator, HP and distance labels.
- **Movement** — move speed slider (applies while walking, sprinting, crouching, sliding and using emotes), auto jump, jump-height multiplier (level 1 = the game's original default height, +25% per level).
- **Revive** — auto revive (revives yourself when downed) and auto rescue (flies to a downed teammate and revives them with the normal hold-E flow, then instantly returns to the sky platform if it is enabled).
- **Farm** — sky platform (keeps you fixed on one point, you cannot be knocked off or fall), auto collect event items (tickets), pickup interval slider.
- **Boombox** — equips a client-side boombox with a built-in song list, volume, play/pause, stop, and custom song ID.
- **UI** — WindUI (Aero theme), all settings in one window.

## Hotkeys

| Key | Action |
| --- | --- |
| `Insert` / `F2` | Show / hide the whole UI |
| `Home` / `F3` | Toggle auto jump |

## Requirements

- An executor with `loadstring`, `getgc`, `hookfunction` and `request`/`HttpGet` support (tested with **Potassium**).
- HTTP requests must be allowed — the script downloads the UI library and icon pack from GitHub on startup.
- The game must be loaded before executing the script.

## Usage

1. Join an **Evade** server and wait until your character has spawned.
2. Copy the content of `Evade.luau` (or `躲避.luau`) into your executor.
3. Execute the script; the menu opens automatically.
4. Every feature is a toggle or slider in the menu.

## Notes

- The platform + auto rescue combo is designed so that auto rescue has priority: the platform stops holding you while rescuing, then places you back on the platform as soon as the revive finishes.
- If a rescue target disappears mid-flight, you are returned to the platform automatically.
- The script is intentionally comment-free; every option is labelled in the UI.

## Disclaimer

This project is shared for educational and personal use only. Using scripts like this may violate the Roblox Terms of Service and the rules of the game, and can result in a ban. Use it at your own risk; the author takes no responsibility for any consequences.
