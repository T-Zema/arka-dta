# Mod: frakcja Terran (piąta strona w skirmishu), etap 0

Grywalna frakcja „Terran” w skirmishu Deathmatch. Technicznie to przejęty dom pomocniczy `GDI1` (indeks 6) ze stroną `TerranSide`. Na etapie 0 jest klonem Aliantów. Stan: **zainstalowany 2026-10-24, (niezweryfikowane w grze)**.

Źródła: [[plans/new-faction]] (wariant A′, uzasadnienie), [[engine/sides-and-houses]], szkic etapu 0 (dawniej `Modding/drafts/new-faction-poc/`, dziś tylko w historii gita, commit `c650a9b`; jego treść żyje w `INI/Map Code/SC Factions/000 Terran faction.ini`).

## Pliki

| Plik | Zmiana | Kopia |
|---|---|---|
| `INI/Map Code/SC Factions/000 Terran faction.ini` (do 2026-10-28 `INI/Map Code/Terran Faction.ini`, dziś to tylko punkt wejścia z `BasedOn`, [[engine/map-code-layers]]) | nowy: `[Sides] TerranSide=GDI1`, `[TerranSide]`, `[GDI1]` (`Name=Terran`, `ActsLike=6`, `Multiplay=yes`, `Side=TerranSide`), 113× `Owner=…,GDI1` (typy Aliantów), 4× zdjęty `GDI1` (`TDPROC`, `TDPROC_AI`, `DEPCARR`, `GHPAD`) | `Terran Faction.ini.bak` (stan etapu 0) |
| `Resources/GameOptions.ini` | `Sides=GDI,Nod,Allies,Soviet,Neutral,Special,Terran` + komentarz z oryginałem | `GameOptions.ini.bak` |
| `INI/MPMaps.ini` | `[Default]`: `MapCodeININame=Terran Faction.ini`, `DisallowedPlayerSides=4,5`. `[Tournament]`, `[Empowerment]`, `[Survivor]`, `[Scavenger]`, `[Co-Op *]`, `[King of the Hill]`, `[Maps/Default/SEABOUND_HIGHWAY]`: `DisallowedPlayerSides=4,5,6`. Razem 23 wstawione linie, każda pod komentarzem `; Terran faction`. | `MPMaps.ini.bak` |
| `MIX/SideC07.mix`, `MIX/sidenc07.mix`, `MIX/Speech07.mix` | kopie `…03` (sidebar, ekran wyniku i EVA Aliantów) | — |
| `Resources/terranicon.png` | kopia `alliesicon.png` | — |
| `Resources/l600s6{1,2}.pcx`, `Resources/l480s6{1,2}.pcx` | kopie ekranów ładowania Aliantów (`…s2{1,2}`) | — |

**Jednostka startowa (2026-10-24, sesja budynków Terran):** w `000 Terran faction.ini` blok „Terran start unit”:
`[General] BaseUnit=SCMCVT,GMCV,NMCV,AMCV,SMCV`, `[VehicleTypes] TER01=SCMCVT` i zaślepka `[SCMCVT]` z `Owner=Special`.
Pełny `SCMCVT` (Terran Construction Tank, `DeploysInto=SCCC`, `Owner=GDI1`, `TechLevel=-1`) jest w `StarCraft.ini`.
Kolejność w `spawnmap.ini` (zaobserwowana): plik frakcji (Map Code) → `Advanced AI.ini` → `StarCraft.ini`, więc przy zaznaczonym
STARCRAFT wygrywa `Owner=GDI1` i Terran startuje czołgiem. Bez STARCRAFT zaślepka nie pasuje do nikogo i Terran dostaje `AMCV`.
`BaseUnit` jest celowo w pliku frakcji, nie w `StarCraft.ini`: tam nadpisałby `BaseUnit=MHQ` trybu Survivor. Wszystkie budynki
Terran i `SCMCV` mają teraz `GDI1` w `Owner=` ([[mods/starcraft-terran-buildings]]). Marine'y jeszcze nie (to sekcje sesji Marines).

`Rules.ini`, `Enhance.ini`, mapy i pliki innych sesji (`StarCraft.ini`, `SkirmishLobby.ini`, `Art.ini`) są nietknięte.

Poprawka po pierwszym teście: w `MPMaps.ini` dodana sekcja `[Custom Map]` (`MapCodeININame=Terran Faction.ini`,
`DisallowedPlayerSides=4,5`) przed `[GameModeAliases]`. To tryb map z `Maps/Custom` (`GameMode=standard` w mapie,
alias `standard=Custom Map`).

## Test 1 (2026-10-24): crash, przyczyna znaleziona

Mapa *The Lost Temple (StarCraft)* z `Maps/Custom`, tryb **Custom Map**, gracz `Side=6`. Crash
`EXCEPTION_ACCESS_VIOLATION` w `HouseClass::Tracking_Add()` ← `UnitClass::UnitClass()` ← `Last_Minute_Multiplayer_Fixups()`
(`Debug/EXCEPT_24-10-2026_19-17-57.TXT`). Log: `Generating units for house 0 (Name: GDI1 …)` i od razu wyjątek.
- **Przyczyna:** plik frakcji był podpięty tylko do trybu Deathmatch (`[Default]`), a tryb „Custom Map” nie miał ani pliku
  frakcji, ani blokady pozycji 6. Gracz dostał więc surowy dom pomocniczy `GDI1` (`GDISide`, bez `Multiplay`, bez MCV
  w `BaseUnit`). Spawner próbował utworzyć jednostkę startową bez typu i się wywalił.
- **Zasada:** w **każdym** trybie, w którym da się wybrać Terran, musi być doklejony plik frakcji. W pozostałych trybach
  pozycja 6 musi być zablokowana.
- **Fakt z logu:** pierwsze `Prep_For_Side()` (przed mapą) bierze surowe `Side=` ze `spawn.ini` jako indeks strony
  (`Preparing Mixfiles for Side 06` → `SIDEC07.MIX`). Drugie (po mapie) bierze stronę domu gracza (tu `Side 00`, bo
  plik frakcji się nie doczepił). Przy `GDI1` = dom 6 i `TerranSide` = strona 6 oba wywołania trafią w `SIDEC07`.

## Test (do zrobienia przez użytkownika)

Skirmish, tryb **Deathmatch** (mapa z listy) albo **Custom Map** (np. Lost Temple), gracz = Terran, AI = Allies, Advanced AI włączone. Po grze w `Debug/` (najnowszy log):
1. `Side 6: TerranSide` z `GDI1` pod spodem (plik frakcji doklejony do mapy).
2. `Initializing SIDEC07.MIX` przy drugim `Prep_For_Side()`. Jeśli sidebar zostaje GDI, wpisać tu wynik.
3. Gracz dostaje MCV Aliantów (`AMCV`), rozkłada go i buduje drzewko Aliantów. Kolor i ikona w lobby są OK.
4. W lobby pozycje Neutral i Special są wyszarzone, a „Random” ich nie losuje.
5. AI = Terran: buduje bazę i atakuje.
6. Kontrola: GDI vs AI GDI dalej buduje helipad (zdjęcie `GDI1` z `GHPAD`).
7. Kontrola: misja kampanii (np. Frostbite) działa jak wcześniej.

Jeśli w trybie innym niż Deathmatch da się wybrać Terran, znaczy to, że `DisallowedPlayerSides` per tryb nie działa (ryzyko R2 z planu).

## Współdzielony plik: frakcja Zerg (2026-10-25)

Kod mapy frakcji niesie też frakcję Zerg (dom `Nod1`, strona 7), bo `MapCodeININame` przyjmuje jedną nazwę pliku (od 2026-10-28 ten plik łączy warstwy przez `BasedOn`, Zergi mają własną warstwę `010 Zerg faction.ini`). Dopisane:
`ZergSide=Nod1` w `[Sides]`, `SCZDHAT` w `BaseUnit`, `HarvesterUnit=…,SCZWORK`, `ZRG01–06` w `[VehicleTypes]` i blok „Zerg faction”
na końcu. W `MPMaps.ini` blokady `4,5,6` są teraz `4,5,6,7`, a w `GameOptions.ini` `Sides=…,Terran,Zerg`. Przy przegenerowaniu
tego pliku trzeba potem puścić `Modding/tools/build-sczergbase.ps1 -Install`. Szczegóły: [[mods/zerg-faction]].

## Sidebar i EVA (2026-10-25, prośba użytkownika: „sidebar i EVA adiutanta Terran jak w SC”)

Generator: `Modding/tools/build-scterranside.ps1` (StarCraft + ffmpeg ze scratchpada innej sesji albo `-FFmpeg <ścieżka>`).
Buduje od nowa `MIX/SideC07.mix` i `MIX/Speech07.mix` ze źródeł Aliantów (`SideC03`, `Speech03`). `sidenc07.mix` zostaje kopią.
Podglądy w `%TEMP%\scterranside`. **(niezweryfikowane w grze)**

- **Sidebar:** te same SHP co u Aliantów, ale przemalowana paleta `sidebar.pal` (jest osobna dla każdej strony):
  neutralne szarości zamienione na ciemny bordowo-brązowy metal konsoli Terran (`SD/game/tconsole.DDS`, BGRA 640×188), złoto na turkus,
  a kolory funkcjonalne (pasek prądu, siatka radaru, lampki) bez zmian. Tak samo przemalowane palety 29 kawałków PCX (okna, suwaki).
  `briefing.pcx` i `score.pcx` zostają.
- **Radar:** klatki 0–9 `radar.shp` (gasnące logo strony) pokazują teraz Marine'a z lobby SC Remastered
  (`webui/dist/lib/images/terran.webm`, VP9 770×848, kadr 2,5 s, białe tło usunięte) na przyciemnionej siatce radaru, kwantyzowanego do nowej palety.
  SC nie ma osobnego godła Terran w danych.
- **Teksty strony** (`[TerranSide]` w `000 Terran faction.ini`): `OptionsMenuTextColor`/`ScreenTextColor=0,210,230`, `ToolTipColor=LightCyan`,
  `HoverHighlightColor=Cyan`.
- **EVA:** kolejność zdarzeń EVA (Vinifera `EvaNames`, bez `EVA.INI` w DTA) odpowiada tabeli `Speech[]` w `game.exe`
  (wskaźniki od pliku 0x311D14; np. 3 ConstructionComplete = `00-I018`, 8 InsufficientFunds = `00-I022`, 14 BaseUnderAttack = `00-I082`,
  43 MissileLaunchDetected = `00-I150`, 67/68 YouAreVictorious/YouHaveLost = `00-I284/286`). Kwestie adiutanta (`SD/sound/terran/advisor`)
  rozpoznane rozpoznawaczem mowy Windows (en-US, `System.Speech`, gramatyka ze zdań SC + dyktowanie, wejście przepróbkowane do 16 kHz):

  | Plik SC | Kwestia | Pewność | Zdarzenie EVA (plik TS) |
  |---|---|---|---|
  | `taderr00` | Not enough minerals | pewne | Insufficient funds (`00-i022`) |
  | `taderr01` | Insufficient vespene gas | pewne | (nieużyte) |
  | `taderr02` | Additional supply depots required | pewne | Low power (`00-i024`) |
  | `taderr03` | Landing sequence interrupted? | słabe | (nieużyte) |
  | `taderr04` | Unacceptable landing zone | 0,42 | Cannot deploy here (`00-i016`) |
  | `taderr06` | Not enough energy? | średnie | (nieużyte) |
  | `tadupd00` | Your base is under attack | średnie | Base under attack (`00-i082`) |
  | `tadupd01` | Your forces are under attack | pewne | Harvester / ally under attack (`00-i090`, `00-i308`) |
  | `tadupd02` | Research complete? | słabe | New construction options (`00-i032`) |
  | `tadupd03` | Add-on complete | pewne | (nieużyte) |
  | `tadupd04` | Nuclear launch detected | średnie | Missile launch detected (`00-i150`) |
  | `tadupd05` | ? | brak | (nieużyte) |
  | `tadupd06` | Upgrade complete? | słabe | Unit armor/firepower/speed upgraded (`00-i068/070/080`) |
  | `tadupd07` | Nuclear missile ready | pewne | Chemical/Cluster missile ready (`00-i152/154`; Nuclear Silo = `MultiSpecial`) |

  Do tego `terran/scv/tscupd00` („Job's finished”) jako Construction complete (`00-i018`) oraz `misc/youwin` i `misc/youlose`
  (`00-i026/284`, `00-i028/286`). Pozostałe zdarzenia (Unit ready, Building, Training, On hold itd.) mówi dalej EVA Aliantów,
  bo w SC adiutant ich nie mówi. `00-i080`, `00-i152` i `00-i308` nie było w `Speech03`, więc zadziałają tylko wtedy, gdy MIX strony
  ma pierwszeństwo przed wspólnym `SPEECH.MIX` **(niezweryfikowane)**.

## Odinstalowanie

```powershell
Copy-Item Resources\GameOptions.ini.bak Resources\GameOptions.ini -Force
Copy-Item INI\MPMaps.ini.bak INI\MPMaps.ini -Force
Remove-Item 'INI\Map Code\Terran Faction.ini', MIX\SideC07.mix, MIX\sidenc07.mix, MIX\Speech07.mix, Resources\terranicon.png, Resources\l600s61.pcx, Resources\l600s62.pcx, Resources\l480s61.pcx, Resources\l480s62.pcx
```

Od 2026-10-28 `Terran Faction.ini` to punkt wejścia całego łańcucha warstw, więc jego usunięcie wyłącza też Zergów i Protossów. Warstwy zostają w `INI/Map Code/SC Factions/` (do usunięcia razem z folderem, jeśli znikają wszystkie frakcje SC).

## Dalej

Po udanym teście: budynki Terran z [[mods/starcraft-terran-buildings]] i jednostki z [[mods/starcraft-marine]] dostają
`GDI1` w `Owner=` (ich sesje robią to w `StarCraft.ini`); zrobione 2026-10-24/25. Sidebar i EVA Terran: zrobione (sekcja wyżej).
Zostaje odpięcie od Aliantów i archiwum.
Kroki opisuje [[plans/new-faction]].
