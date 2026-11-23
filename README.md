![VendorScout — Find the nearest vendor](media/cover.png)

# VendorScout for WoW Forever

Search items and find the nearest known vendor, in a standalone window or the world map. Includes a complete vendor extract from a pinned NorgannonDB snapshot: 3,940 items, 1,151 vendors, 18,010 relationships. No runtime dependencies. Interface 16001; version 1.0.0.

Version 1.0.0 is the first stable release for WoW Forever 1.60.1. The database is rebuilt from NorgannonDB's 2026-11-22 snapshot, adding 19 vendor-item relationships and incorporating corrected vendor data.

The map search is a separate movable window with saved placement. Both search windows share their query, filters, selection and Clear actions. The nearest match is selected after a search. Small original coin icons mark results; the toggle sits inside the upper-right map edge. Each login/reload starts without selected vendors or vendor pins.

The installable addon is in `VendorScout/`. See `VendorScout/LES-MEG.txt` for Norwegian installation instructions and commands. Start with `/vs`, `/vs 159`, or `/vs map`. The separate install ZIP contains only the addon folder.

Results sort by straight-line world distance from the player's current position, using the nearest known spawn of each vendor. Search refreshes every two seconds while visible. Different continents and unknown distances follow measurable distances; unknown locations follow mapped locations. Coordinates are not walking routes or live NPC tracking. Reputation, seasonal access and stock are not guaranteed. The community snapshot may omit new Forever content.

The design follows the existing Whats Next? dark panels, green highlights, bordered buttons and compact result cards. English/Norwegian controls, source-provided item/NPC translations, item-link/ID lookup, faction and category filters, map scope, pulsing selection and per-character observations are included.

## Development

Python 3.11+ and `lupa==2.8` provide an actual Lua 5.1 interpreter for tests. Pillow is needed only for the schematic layout previews.

```powershell
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
python tools/build_database.py
python tools/preview.py preview
python tools/package.py dist
```

The source ZIP includes `source-data/NorgannonDB/`: all consumed source files, their original notices and the pinned snapshot marker. `tools/build_database.py` verifies the hashes in `database-manifest.json` before executing this trusted snapshot. Database output is deterministic. An external git checkout can also be passed as the first argument. Updating the snapshot requires reviewing the schema, changing `SOURCE_COMMIT`, updating expected coverage and revalidating both factions.

The source audit tests use the bundled snapshot, or `../NorgannonDB` when working with a checkout. They compare every relationship and generated coordinate to the upstream data, not only a few sample items. Tests use an explicit WoW API/UI simulation; they do not establish in-game compatibility.

The current build passed 57 tests. Lua syntax, missing item-cache behavior, exact IDs/links, faction-specific spawns, pagination, map scope, pin limits, combat restrictions, vendor observations, movement-based reordering, and absent/secret coordinates are covered. The UI simulation models multiple anchors, strata, frame levels, pointer targeting, focus, typing and the caret. A regression test reproduces the old input interception by the HIGH map border. Floating-window tests check placement outside the map, unchanged canvas anchors, dragging, saved positions, scale, screen clamping and close/reopen behavior. Additional tests exercise both search fields and both Clear actions, shared selection, automatic native map search and minimap navigation. A local inspection also checked the relevant APIs against Blizzard UI source from Gethe/wow-ui-source's `forever` branch at `734f065329cff4992835b01a84f210a297db91b6`. When that checkout is present at `../wow-ui-source`, integration tests exercise its MapCanvas data-provider base; otherwise they use the included explicit API simulation.

## In-game verification checklist

The beta UI was tested in game by the project owner. Automated checks below use simulated APIs; repeat this checklist when client or map behavior changes.

1. Install in Forever, enable Lua errors, log in as Alliance and Horde.
2. Search `159` from two different positions; verify the first vendor changes appropriately and distances change while moving.
3. Open the world map, search in the map panel, click a result and verify the pulsing pin aligns with the NPC's known location. Test zone/continent changes, zooming and minimized/maximized maps.
4. Test a vendor without coordinates, an item requiring reputation, and a limited-stock item. Unknown data must stay unknown.
5. Open a merchant with a previously unrecorded item, reload, and verify the timestamped observation remains searchable.
6. Verify combat blocks map opening without Lua errors; verify Escape, minimap dragging and the EN/NO controls.

Preview PNGs generated by the tool are schematic renders of the actual Lua frame tree using substitute fonts and simulated distances. They are not in-game screenshots.

## Source layout

- `VendorScout/Data.lua`, `Locales.lua`: generated data, ready for offline use.
- `Search.lua`: search, filters, coordinate conversion and ranking.
- `UI.lua`: standalone window, details, language and minimap control.
- `Map.lua`, `Pins.xml`: map search, data provider and owned map pins.
- `Merchant.lua`: positive observations; never deletes inventory based on a filtered merchant window.
- `Core.lua`: lifecycle, debouncing, refresh and slash commands.
- `tools/`, `tests/`, `database-manifest.json`: reproducible build and validation.

GPL-3.0. Full license and upstream notices are included with the addon and source snapshot. No network calls, purchases, automatic movement or public publishing occur in the addon.
