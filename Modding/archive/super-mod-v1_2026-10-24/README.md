# Super Mod v1 + Frostbite cheats — archive (2026-10-24)

Snapshot of every file changed by the first modding session for Dawn of the Tiberium Age
(engine: Tiberian Sun + Vinifera). Full write-up: `Modding/wiki/mods/super-mod-v1.md`
and `Modding/wiki/mods/frostbite-cheats.md`.

## Contents

| Path (relative to game root) | `modified/` | `original/` |
|---|---|---|
| `INI/Game Options/Super Mod.ini` | new file | — (did not exist) |
| `Resources/SkirmishLobby.ini` | adds `chkSuperMod`, hides `chkIngameAllying` | stock |
| `Maps/Missions/FRSTBITE.MAP` | Frostbite cheats (credits, MCV, 40+ units, Ion Cannon…) | stock |

## Install

Copy everything from `modified/` over the game root (keep the folder structure).

## Uninstall

1. Copy everything from `original/` over the game root.
2. Delete `INI/Game Options/Super Mod.ini`.

The DTA client updater may silently restore stock `SkirmishLobby.ini` / `FRSTBITE.MAP`;
re-run *Install* if the SUPER MOD checkbox or the Frostbite cheats disappear.
