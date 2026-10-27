# Dawn of the Tiberium Age — modding workspace

This folder is a working install of **Dawn of the Tiberium Age** (DTA): a C&C mod running on the
Tiberian Sun engine + the **Vinifera** extension DLL, launched through the CnCNet/XNA client (`DTA.exe`).
The user mods it for personal use and talks in Polish — reply in Polish.

## Knowledge base (read first)

All modding knowledge lives in an LLM-maintained wiki, following Karpathy's "LLM wiki" pattern
(see `Modding/raw/sources/karpathy-llm-wiki.md`):

| Layer | Path | Rule |
|---|---|---|
| Raw sources | game files (`INI/`, `Maps/`, `Resources/`, `Debug/`) + `Modding/raw/` | read-only references; never edit `Modding/raw/` |
| Wiki | `Modding/wiki/**.md` | owned by the LLM: create, update, cross-link |
| Schema | this file | co-evolved with the user |
| Catalog | `Modding/index.md` | read **first** when answering any modding question |
| Log | `Modding/log.md` | append-only, one line per event |
| Archives | `Modding/archive/` | frozen snapshots of finished mods (folder + zip) |

## Workflows

- **Ingest** (new source: a game file studied, a forum post, a crash log, user-provided assets):
  read it → write/update the relevant wiki pages (often several) → update `index.md` → append to `log.md`.
- **Query**: read `index.md` → open the linked pages → answer citing them as `[[page]]`.
  If the answer is a reusable insight, file it back into the wiki.
- **Mod work**: before editing a game file, back it up (`<file>.bak` next to it, only if no `.bak` exists).
  When a mod is finished, snapshot it into `Modding/archive/<name>_<YYYY-MM-DD>/` (`modified/`, `original/`,
  `README.md` with install/uninstall) + a zip, and write `Modding/wiki/mods/<name>.md`.
- **Git** (repo = the game folder, see `Modding/wiki/workflow/repo-and-updates.md`): after mod work run
  `Modding/tools/dta-capture.ps1` (records our new/changed game files, checks the binary patches are reproducible) and
  commit; commit/push only when the user asks. A new binary patch script must be added to `patch-game.ps1` /
  `patch-vinifera.ps1`, otherwise it is lost on the next DTA update. Before a DTA update: `dta-precheck.ps1`; after it:
  `dta-restore.ps1` — never `git checkout`/`reset --hard` over DTA files (that drops DTA's new version without a merge).
- **Lint** (when asked, or after large changes): look for contradictions between pages, stale claims
  (e.g. a file the client updater reverted), orphan pages not in `index.md`, missing cross-links,
  and claims still marked *niezweryfikowane* that the user has since tested.

## Page conventions

- Polish prose, English game keys/IDs verbatim (`TechLevel=-1`, `[2TNK]`).
- Obsidian-style links: `[[engine/ini-layering]]` (path relative to `Modding/wiki/`, no `.md`).
- Every page starts with a one-line summary, then `Źródła:` listing the raw files it was derived from.
- Mark anything not yet confirmed in-game with **(niezweryfikowane w grze)**.
- Log line format: `YYYY-MM-DD | ingest|query|mod|lint|archive | short description`.

## Tooling quirks (this machine)

- Windows; prefer the PowerShell tool for INI parsing scripts. Bash commands here are often
  backgrounded by the user, and the `rtk` hook rewrites `grep` output — use the Grep tool instead.
- `Rules.ini` is ~750 KB / 31k lines: never read it whole; grep for `^\[SECTION\]` and read with `-A`.
