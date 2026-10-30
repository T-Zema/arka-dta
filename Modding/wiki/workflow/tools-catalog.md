# Katalog skryptów `Modding/tools/`

Ponad 90 plików w jednym folderze, pogrupowanych według celu: co każdy skrypt robi, co zapisuje i w jakiej kolejności je uruchamiać. Szczegóły są w nagłówku każdego skryptu (pierwsze linie komentarza) i na stronie modu.

Źródła: nagłówki skryptów w `Modding/tools/` (stan 2026-10-28), `Modding/dta/sync.json`, [[engine/shp-graphics]] (rejestr numerów MIX).

Skrypty liczą folder gry jako `$PSScriptRoot\..\..`, więc działają tylko z `Modding/tools/` (albo z kopii gry o tym samym układzie, np. piaskownicy testowej). Generatory bez `-Install` budują tylko MIX i podglądy; z `-Install` piszą też pliki INI gry. Przed `-Install` zamknij grę ([[workflow/tooling]]).

## Wspólne biblioteki (dot-source / `Add-Type`)

| Plik | Do czego |
|---|---|
| `MapCode.ps1` | łańcuch warstw kodu mapy frakcji (`Get-MapCodeLayer`, `Read-MapCodeText`, `Set-MapCodeBlock`, `New-MapCodeLayer`), [[engine/map-code-layers]] |
| `MissionKit.ps1` | pomocniki misji ARKA: tempo dialogów, skrzynki, `Add-ZergBuilder`, `Add-ScAirArmor`, przypominajki celów i postęp „k z n” (`Add-ObjectiveReminder`, `Add-CountProgress`), [[engine/triggers-and-dialogue]] |
| `ZergAI.ps1` | `Add-ZergAI`: ogólne AI gniazda Zergów w misji (produkcja w Niecce, ataki, alarm i obrona, kontratak, pomoc dla innego miejsca, rozbudowa dronami); po `MissionKit.ps1`, wołać **po** `Add-Difficulty`. [[engine/zerg-ai]] |
| `dta-common.ps1` | wspólne funkcje `dta-capture`/`dta-restore`/`dta-precheck` |
| `ModTools.cs` | MIX, SHP, GRP, AUD, palety, PCX, arkusze podglądu ([[workflow/tooling]]) |
| `Casc.cs` | odczyt CASC StarCraft: Remastered ([[engine/starcraft-assets]]) |
| `ScBuild.cs`, `ScBuildings.cs`, `ScInfantry.cs`, `ScUnits.cs`, `ScZerg.cs`, `ScProtoss.cs`, `ScIscript.cs` | konwersja grafik i dźwięków SC → SHP/AUD (pojazdy, budynki, piechota, iscript) |
| `ScMap.cs`, `TsMap.cs`, `ScToDta.cs`, `DesignToDta.cs`, `GeoData.cs` | mapy: SC → DTA, projekt/zrzut → DTA, dane OSM i DEM ([[engine/map-format]], [[workflow/mission-maps]]) |
| `ScModSetup.cs` | program instalatora ([[workflow/installer]]) |

## Generatory modów StarCraft

Kolumna „INI”: gdzie piszą z `-Install` (bloki `; >>> X` … `; <<< X`, każdy generator podmienia tylko swój). „Warstwa” = plik w `INI/Map Code/SC Factions/` ([[engine/map-code-layers]]).

| Skrypt | MIX | INI | Strona |
|---|---|---|---|
| `build-scmarine.ps1` | `ECACHE77` | `StarCraft.ini` (Marine) | [[mods/starcraft-marine]] |
| `build-scterran.ps1` | `ECACHE98` | `StarCraft.ini` (budynki Terran) | [[mods/starcraft-terran-buildings]] |
| `build-scliftoff.ps1` | `ECACHE89` | latające wersje budynków Terran | [[mods/starcraft-terran-buildings]] |
| `build-scuberdepot.ps1` | `ECACHE96` | Uber Supply Depot | [[mods/starcraft-terran-buildings]] |
| `build-scunits.ps1` | `ECACHE97` | `StarCraft.ini` (jednostki Terran) | [[mods/starcraft-terran-units]] |
| `build-scflyers.ps1` | `ECACHE90` | okręty Terran jako pojazdy Fly (eksperyment, w użyciu) | [[engine/fly-locomotor]] |
| `build-scsfx.ps1` | `ECACHE88` | brakujące dźwięki broni SC | [[mods/terran-faction]] |
| `build-scterranside.ps1` | `SideC07`, `Speech07` | sidebar i EVA Terran | [[mods/terran-faction]] |
| `build-scresearch.ps1` | `ECACHE87` | `StarCraft.ini` (badania Terran) | [[mods/starcraft-research]] |
| `build-sczerg.ps1` | `ECACHE80` | `StarCraft.ini`, `Art.ini`, `Sound.ini` (Zergi z checkboxa) | [[mods/starcraft-zerg]] |
| `build-sczergbase.ps1` | `ECACHE86` | warstwa `010 Zerg faction` + `[General]` warstwy `000`, `Art.ini`, `Sound.ini`, lobby | [[mods/zerg-faction]] |
| `build-sczergheroes.ps1` | `ECACHE82` | warstwa `030 Zerg heroes`, `Art.ini`, `Sound.ini`, `Rules.ini` (supermoc) | [[mods/zerg-heroes]] |
| `build-sczergresearch.ps1` | `ECACHE84` | warstwa `040 Zerg research`, `Art.ini`, `StarCraft.ini` `[AI] BuildConst` | [[mods/zerg-research]] |
| `build-sczergside.ps1 -Install` | `Speech08`, `SideC08` | EVA i sidebar Zergów | [[mods/zerg-side]] |
| `build-sczergcreep.ps1` | – | warstwa `080 Zerg creep`, `Art.ini` | [[mods/zerg-creep]] |
| `build-sczergdeath.ps1` | – | warstwa `090 Zerg death sounds`, `Art.ini` | [[mods/zerg-faction]] |
| `build-scprotoss.ps1` | `ECACHE85` | warstwa `020 Protoss faction` + `[General]`/`Owner=` warstwy `000`, `Art.ini`, `Sound.ini`, lobby | [[mods/protoss-faction]] |
| `build-scprotossresearch.ps1` | `ECACHE83` | warstwa `070 Protoss research`, `Art.ini` | [[mods/protoss-faction]] |
| `build-scworkers.ps1` | `ECACHE78` | warstwa `060 SC workers`, `StarCraft.ini`, `Art.ini`; uruchamia `patch-vinifera-workers` i `patch-freescv` | [[mods/sc-workers]] |
| `build-scbldgsounds.ps1` | `ECACHE79` | warstwa `050 SC building select sounds`, `StarCraft.ini`, `Sound.ini` | [[mods/sc-building-sounds]] |
| `build-scinfstim.ps1` | `ECACHE81` | `StarCraft.ini`, `Art.ini`, `Sound.ini` | [[mods/sc-infantry-stim]] |
| `build-scairarmor.ps1` | – | warstwa `100 SC air armor`, `StarCraft.ini` | [[engine/air-armor]] |
| `build-scterranai.ps1` | – | `StarCraft.ini` (blok `Terran AI`: `Owner=` bez `GDI1`, `AIBuildThis`, listy `[AI]`, taktyki `House=6`); `-WhatIf` = podgląd | [[mods/terran-ai]] |
| `build-scprotossai.ps1` | – | `StarCraft.ini` (blok `Protoss AI` za `Terran AI`: `Owner=` bez `GDI2`, `AIBuildThis`, listy `[AI]`, taktyki `House=8`); `-WhatIf` = podgląd, `-Report` = jednostki, które AI może cenić | [[mods/protoss-ai]] |
| `ProtossAI.ps1` | – | moduł misji `Add-ProtossAI` (na `Add-ZergAI`): drużyny i fale `PHIx`, przywołanie przy Pylonach | [[mods/protoss-ai]] |
| `build-scmusic.ps1` | luźne `MUSIC\SC*.AUD` | `Theme.ini` (`[Themes]` + sekcje utworów) | [[mods/sc-music]] |
| `build-gun100t.ps1` | `ECACHE76` | `Art.ini` (działo misji ARKA 0) | [[missions/arka-00-triggers]] |

**Kolejność ponownego uruchamiania** (późniejsze czytają wynik wcześniejszych): `build-sczergbase` → `build-scprotoss` → `build-sczergheroes` → `build-sczergresearch` → `build-scprotossresearch` → `build-scbldgsounds`, `build-scworkers` → `build-sczergcreep` → `build-sczergdeath` → `build-scairarmor` → `build-scterranai`, `build-scprotossai` (czytają scalone reguły i nawzajem swoje bloki, więc na końcu, w dowolnej kolejności). Po zmianie typów SC przebuduj też misje ARKA (kopiują typy do map).

## Łatki binarne (`game.exe`, `Vinifera.dll`)

- `patch-game.ps1`: wszystkie łatki `game.exe` naraz (po aktualizacji DTA): `patch-spawnreturn`, `patch-flyhover`, `patch-flyertarget`, `patch-buildup`, `patch-freescv`, `patch-airboard`, `patch-infdeploy`, `patch-veins`, `patch-zergbuild`, `patch-overlordstorage`. Źródła jaskiń w `*.asm` (nasm przez pixi). [[engine/game-exe-patching]]
- `patch-vinifera.ps1`: wszystkie łatki `Vinifera.dll`: `patch-vinifera-workers`, `patch-vinifera-veins`, `patch-vinifera-overlord`, `patch-vinifera-navalai` (tabela `$builds` na wersje DTA). [[workflow/repo-and-updates]]
- Nowa łatka musi trafić do `patch-game.ps1` albo `patch-vinifera.ps1`, inaczej zginie przy aktualizacji DTA (`CLAUDE.md`).

## Misje ARKA

| Skrypt | Wynik |
|---|---|
| `build-arka-gibraltar.ps1` | teren ARKA 0 (`Maps/Custom/arka00_gibraltar.map`), [[missions/arka-00-gibraltar]] |
| `build-arka00-mission.ps1` | misja ARKA 0, [[missions/arka-00-triggers]] |
| `build-arka01-marsara.ps1`, `build-arka01-mission.ps1` | ARKA 1, [[missions/arka-01-marsara]] |
| `build-arka02-marsara.ps1`, `build-arka02-mission.ps1` | ARKA 2, [[missions/arka-02-ewakuacja]] |
| `build-arka04-antiga.ps1`, `build-arka04-mission.ps1` | ARKA 4, [[missions/arka-04-zielony-krysztal]] |
| `build-arka05-tarsonis.ps1`, `build-arka05-mission.ps1` (+ `arka05-protoss.ps1`, `arka05-zerg.ps1`) | ARKA 5, [[missions/arka-05-tarsonis]] |
| `build-arka07-antiga.ps1`, `build-arka07-mission.ps1` | ARKA 7 (etap 1: teren + obiekty, bez triggerów), [[missions/arka-07-zdrada]] |
| `build-arka-previews.ps1` | podglądy misji 300×200 dla klienta |
| `build-briefing.ps1` | film briefingu z JSON w `Modding/briefings/`, [[engine/briefing-movies]] |
| `build-campaign-html.ps1` | `Modding/exports/campaign-arka.html` z [[plans/campaign-arka]] |
| `build-bldg-sheet.ps1` | arkusz wyglądu budynków na mapie, [[catalog/city-buildings]] |
| `dump-triggers.ps1` | dekompilacja triggerów mapy do tekstu |
| `.claude/skills/pokaz-render/show-render.ps1` | skill „pokaż mi render”: mapa po tytule albo pliku, render CNCMaps tylko gdy PNG starszy od mapy, otwiera w Paincie, mała kopia 1400 px do Read |
| `fetch-geodata.ps1` | pobieranie OSM i DEM do projektu mapy |

Misje nie ładują `StarCraft.ini` ani kodu mapy frakcji: skrypty misji kopiują typy SC (z domknięciem zależności) do mapy, czytając `StarCraft.ini` i wszystkie warstwy (`Get-MapCodeLayers`).

## Mapy SC jako skirmish

- `port-scmap.ps1 -Map "<nazwa>"`: całość jednym poleceniem, [[workflow/scmap-pipeline]].
- `convert-scmap.ps1`: konwersja jednej mapy (używa go `port-scmap`).

## Repo, aktualizacje DTA, instalator

- `dta-capture.ps1`: po każdej zmianie modu (lista naszych plików, `.gitignore`, `state.json`), `dta-precheck.ps1` przed aktualizacją DTA, `dta-restore.ps1` po niej. [[workflow/repo-and-updates]]
- `build-installer.ps1`: `Modding/dist/DTA-SCMod-Setup.exe` ze `state.json`; budować po `dta-capture`. [[workflow/installer]]

## Diagnostyka (działająca gra, tylko odczyt pamięci)

Analiza offline: `vdis.py` (disasembler PE przez capstone/pixi, [[workflow/tooling]]), `sc-aiscript.ps1` (skrypty AI StarCrafta z CASC do tekstu, [[engine/starcraft-assets]]).

`spawnprobe.ps1` (pozycja i stan jednostek), `morphprobe.ps1` (deploy dronów, stan piechoty Zergów), `veinprobe.ps1` (Veinhole Monstery), `nukeprobe.ps1` (stan supermocy), `mixlist.ps1` (zawartość MIX). Logi `*.log` git ignoruje. [[engine/debugging]]
