# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DontLoseMe is a lightweight World of Warcraft addon (Retail 12.0+) that displays a configurable crosshair overlay on the player's character. It uses no external libraries and provides customizable shapes, colors, and display conditions.

## API Reference

**Official WoW API Documentation**: https://warcraft.wiki.gg/

Use this wiki when working with WoW API functions, widgets, events, or UI elements. All WoW API calls in this codebase (e.g., `CreateFrame`, `UIDropDownMenu_*`, `ColorPickerFrame`, etc.) are documented there.

**WoW UI Source Code**: https://github.com/Gethe/wow-ui-source

Reference implementation of Blizzard's UI code. Useful for seeing real-world examples of widget usage, frame templates, and UI patterns.

## Architecture

### File Structure
- **Core.lua**: Main addon logic, event handling, crosshair rendering, and database initialization
- **Options.lua**: Settings UI panel with controls and live preview
- **DontLoseMe.toc**: Addon metadata and load order (Core.lua loads before Options.lua)

### Shared Namespace Pattern
Both files share state via the `ns` (namespace) table:
```lua
local ADDON, ns = ...
```

Critical initialization order:
1. Both files load when addon loads
2. `ADDON_LOADED` event fires → Core.lua's `InitDB()` sets `ns.db`
3. Options.lua's DB() function relies on `ns.db` being set by Core.lua
4. Never attempt to access database before `ns.db` is initialized

### Database Architecture
- **Saved Variable**: `DontLoseMeDB` (global table, per-character)
- **Storage Key**: `"CharacterName-RealmName"` for per-character settings
- **Accessor**: `ns.db` points to current character's settings (set by Core.lua)
- **Migrations**: Handled in `PerformMigrations()` during `PLAYER_LOGIN`

### Key Components

#### Core.lua
- Creates crosshair frame (`Root`) with texture manipulation
- Handles visibility conditions (always/party/raid/combat)
- Event-driven: ADDON_LOADED, PLAYER_LOGIN, GROUP_ROSTER_UPDATE, combat events
- `ns.RefreshAll()`: Reapplies layout and visibility (called from Options.lua)

#### Options.lua
- Settings panel registered with WoW's modern Settings UI
- Forward declarations needed: `RefreshPreview` and `UpdateControlState`
- Preview rendering mirrors Core.lua's rendering logic
- Controls sync with database via getter/setter pattern
- **CRITICAL**: Never render preview before database is initialized (avoid early timers)

### Shape Rendering
Four supported shapes: PLUS (default), X, CHEVRON_DN, CHEVRON_UP
- Each shape uses multiple textures (main + outline layers)
- Textures positioned/rotated via `PlaceBar()` and `PlaceOutlined()`
- Outline system: optional background textures with configurable thickness

## Testing & Development

### In-Game Testing
Since this is a WoW addon, there is no traditional build/test process:
1. Edit files directly in the addon directory
2. In-game: `/reload` to reload all addons
3. Open settings: `/dontloseme` or `/dlm`

### Manual Testing Checklist
- Enable/disable crosshair
- Test each shape (PLUS, X, CHEVRON_DN, CHEVRON_UP)
- Verify outline toggle and colors
- Test conditions (always/party/raid/combat)
- Verify preview matches in-game crosshair
- Test with multiple characters (per-character settings)

### Common Issues
- **Preview not showing**: Database not initialized when preview renders
- **Settings not persisting**: Check per-character storage key format
- **Desync between preview and crosshair**: Ensure both use same rendering logic

## Release Process

Releases are automated via GitHub Actions (`.github/workflows/release-zip.yml`):
1. Create and publish a GitHub release with tag (e.g., `v1.0.1`)
2. Workflow bundles Core.lua, Options.lua, DLMIcon.tga, DontLoseMe.toc
3. Creates `DontLoseMe+<tag>.zip` with proper folder structure
4. Uploads zip to the release

## Slash Commands
- `/dontloseme` or `/dlm` - Opens settings panel

## Commit Message Format

- Use single-line messages for single logical changes (e.g., `[fix] Corrected preview rendering timing`)
- Focus on WHAT was changed, not why or how
- Start descriptions with past tense verbs (e.g., "Added", "Fixed", "Removed", "Updated")
- Never include "Generated with Claude Code" or "Co-Authored-By: Claude" attributions

## Critical Rules
1. **Never use C_Timer.After for initial preview render** - Database may not be ready
2. **Maintain rendering parity** - Preview in Options.lua must match Core.lua exactly
3. **Respect load order** - Core.lua initializes database, Options.lua depends on it
4. **Boolean storage** - Always store `outlineEnabled` as proper boolean (not truthy values)
5. **Per-character isolation** - All settings are per-character, never account-wide
