# Warstwy INI: skąd silnik bierze ustawienia

Silnik czyta `Rules.ini`, a potem nadpisuje go sekcjami z mapy (i z opcji gry doklejonych przez klienta). Dzięki temu można modować bez ruszania Rules.ini.

Źródła: `Debug/DEBUG_23-10-2026_08-59-14.LOG` (linie ~270–412), `Maps/Missions/FRSTBITE.MAP`, `spawn.ini`, `Resources/SkirmishLobby.ini`.

## Kolejność

1. `INI/Rules.ini` (+ Art.ini, AI.ini itd.): baza.
2. **Mapa / scenariusz.** Klient kopiuje wybraną mapę do `spawnmap.ini` (w głównym katalogu gry),
   doklejając zawartość zaznaczonych opcji gry (`CustomIniPath=` z lobby, zob. [[engine/client-lobby-options]]).
3. W logu: `Calling Rule->Addition() with scenario overrides`, a potem ponowne
   `Rules: Processing HouseTypes / SuperWeaponTypes / BuildingTypes / AircraftTypes / UnitTypes /
   InfantryTypes / WeaponTypes / BulletTypes / WarheadTypes / ...`.
   Oznacza to, że **mapa może nadpisać dowolny klucz dowolnego typu**, w tym domy (`[Allies]`) i `[General]`.

## Zasady nadpisywania

- Sekcja w mapie o tej samej nazwie co w Rules (np. `[2TNK]`) **nadpisuje tylko podane klucze**,
  reszta zostaje z Rules.
- `spawnmap.ini` jest **generowany od nowa przy każdym starcie**. Edytujemy źródło
  (`Maps/Missions/*.map` albo plik opcji gry), nigdy `spawnmap.ini`.
- Mapa może dołączać wspólne pliki: `[INISystem] BasedOn=../../INI/Map Code/AI Discounts Enhanced.ini`
  (te pliki mogą mieć własne `BasedOn`, np. `AI Discounts Classic.ini`).
- **`[INISystem] BasedOn=<plik>` łączy pliki w łańcuch** w każdym pliku, który klient czyta przez `IniFile` (mapy, Map Code):
  najpierw wczytuje plik bazowy, potem kładzie na niego bieżący (późniejszy klucz wygrywa); działa rekurencyjnie, ścieżka
  jest względna wobec folderu bieżącego pliku. Tak zbudowany jest kod mapy frakcji SC, zob. [[engine/map-code-layers]].
- `$Inherits=` (Vinifera) działa **tylko w obrębie jednego pliku INI**. Nowy typ zdefiniowany w mapie
  nie odziedziczy sekcji z Rules.ini: trzeba wypisać wszystkie klucze (zob. [[engine/adding-new-types]]).
- **Powtórzone sekcje w plikach doklejanych przez klienta są scalane, późniejszy klucz wygrywa.** Sprawdzone 2026-10-25 na
  bibliotece klienta `Resources/Binaries/Rampastring.Tools.dll` (`IniFile`, załadowana w PowerShell przez `Assembly.Load(bytes)`):
  `[A] X=1 Y=1` + `[A] Y=2 W=3` → `[A] X=1 Y=2 W=3`. `spawnmap.ini` ma wtedy jedną sekcję (np. jedno `[BuildingTypes]`, choć
  warstwy kodu mapy frakcji w `INI/Map Code/SC Factions/` mają ich kilka). Dzięki temu blok jednego generatora może dopisać klucze do sekcji z bloku innego generatora
  (wzorzec w [[mods/zerg-research]]). Dotyczy plików, które przechodzą przez klienta (mapa, Map Code, Game Options), **nie** `Art.ini`/`Rules.ini`,
  które czyta sama gra.
- Zapisy gry (`Saved Games/`) mają stan sprzed zmiany. Po każdej modyfikacji misję trzeba **zacząć od nowa**.

## Gdzie co edytować

| Cel | Plik |
|---|---|
| Jedna misja | `Maps/Missions/<MAPA>.MAP` (ścieżka z `INI/Battle.ini` → `Scenario=`) |
| Każda mapa skirmisha, włączane checkboxem | `INI/Game Options/<nazwa>.ini` + wpis w `Resources/SkirmishLobby.ini` |
| Cała gra na stałe | `INI/Rules.ini` (unikać, psuje grę online) |

Aktualnie grana misja: `spawn.ini` → `MissionInternalName=` i `Side=`.
