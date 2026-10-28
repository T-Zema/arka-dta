# Mod: robotnicy SC (SCV, Dron, Probe) jak w StarCrafcie

Robotnicy trzech ras SC mają animację wydobycia z SC. Wożą surowce tylko do rafinerii swojej rasy (Refinery, Extractor,
Assimilator), a Refinery daje 2 SCV zamiast harvestera DTA. Stan: animacje **działają w grze** (test użytkownika 2026-10-26);
2 SCV **(niezweryfikowane w grze)**. Doki w głównych budynkach (CC, Nexus, Hatchery) były zainstalowane 2026-10-26 i na prośbę
użytkownika zostały wycofane tego samego dnia.

Źródła: dane SC z CASC (`scripts/iscript.bin` przez `tools/ScIscript.cs`, `arr/images.dat` (funkcja rysowania), `unit/terran/scv.grp`,
`unit/zerg/drone.grp`, `unit/protoss/probe.grp`, `unit/bullet/scvspark.grp`, `unit/bullet/ephFire.grp`, `TileSet/jungle/bfire.pcx`),
kod Vinifery (lokalna kopia `Vinifera-develop`: `houseext.cpp` `HouseClassExtension::Place_Object`, `objecttypeext.cpp`
`Who_Can_Build_Me`, `buildingext_hooks.cpp` `_Receive_Message`, `unitext_hooks.cpp` `_UnitClass_Draw_Shape_IdleRate_Patch`,
`footext_hooks.cpp` `_FootClass_AI_IdleRate_Patch`), deasemblacja `Vinifera.dll` i `game.exe` (capstone przez `pixi`),
`Vinifera.pdb` (`llvm-pdbutil dump -types/-publics`), `INI/Rules.ini` (`[General] UnloadingHarvester=HORV`), plik `version` klienta (MD5).

## Co było nie tak

| Objaw | Przyczyna |
|---|---|
| Robotnik zbiera bez żadnej animacji | SHP miały tylko klatki stania/chodu. Pojazd SHP nie ma w TS klatek „zbierania”. |
| Przy rafinerii robotnik zmienia się w harvester GDI | Vinifera rysuje rozładowujący się harvester jako `UnloadingClass`, a bez niej jako `[General] UnloadingHarvester=HORV`. |
| Bez rafinerii robotnicy nie zarabiają | W TS harvester oddaje surowce tylko do budynków z `Dock=`. W SC minerały idą do CC/Nexusa/Hatchery. |

## Animacja wydobycia (z iscriptu SC, animacja 15 obrazka jednostki)

| Robotnik | SC | DTA (klatki idle) | `IdleRate` |
|---|---|---|---|
| SCV `SCSCV` | `w1 f34 ATTACK w1 f17` (zestawy 2/1 na zmianę) + iskry `scvspark` (10 klatek) | 10 na kierunek, od 32 | 2 |
| Dron `SCZWORK` | `f85 w2 f102 w2 f119 w2 f136 w2` (zestawy 5–8) | 4 na kierunek, od 256 | 4 |
| Probe `SCPPROBE` | `ATTACK w1` (ciało stoi) + wiązka `ephFire` (12 klatek, rysowana przez `bfire.pcx`) | 12 na kierunek, od 128 | 2 |

- Iskra/wiązka leży w SC na minerale. Tu jest wpieczona przed robotnikiem (promień 16 px, płaszczyzna 2:1), a przy kierunkach
  „od widza” rysowana za ciałem.
- Odtwarzanie przez animację bezczynności Vinifery: Art `IdleRate`, `StartIdleFrame`, `IdleFrames` (zob. [[engine/shp-graphics]]).
  Licznik to `TotalFramesWalked`, rośnie co `IdleRate` ticków, gdy pojazd stoi (ok. 45 ticków/s; tick SC = 42 ms).
- Sama Vinifera grałaby ją przy każdym postoju. Łatka DLL (niżej, C) zawęża to do harvesterów, które **właśnie zbierają**
  (`UnitClass::IsHarvesting`, `+0x36E`; `game.exe` ustawia je w `Mission_Harvest`, `0x654C47`). Stojący robotnik ma zwykłą klatkę.
- Nowe SHP pod nowymi nazwami (`SCSCVW`, `SCZWORKW`, `SCPPROBEW`) w `MIX/ECACHE78.MIX`, podpięte przez Rules `Image=`.
  Dlatego generatory frakcji i ich MIX-y zostają nietknięte. Cameo bez zmian (`SCSCVI`, `SCZWORKI`, `SCPPROBEI`).
- `UnloadingClass=<sam typ>`: przy rozładunku robotnik zostaje sobą.

## Oddawanie do głównego budynku (wycofane)

**Wycofane 2026-10-26 na prośbę użytkownika: najpierw CC, potem Hatchery/Lair/Hive i Nexus.** Robotnicy mają znowu `Dock=` z bloków
frakcji (SCV `SCREFI,PROC,…`, Dron `SCZEXT`, Probe `SCPASM`), a w blokach `SC workers` nie ma `Refinery=` dla głównych budynków.
Łatka A/B w `Vinifera.dll` zostaje. Działa tylko, gdy budowniczy jest rafinerią, więc teraz nic nie zmienia. Opis niżej
pokazuje, jak to działało, gdyby wrócić do tego pomysłu.

- `Refinery=yes`, `DockUnload=yes`, `Bib=yes` w `SCCC`, `SCPNEX`, `SCZHAT`, `SCZHTS`, `SCZLAI`, `SCZHIV` (wszystkie 4x3 jak
  rafinerie; dok = pole `+2,+1` budynku, `buildingext_hooks.cpp`).
- `Dock=`: SCV `SCCC,SCREFI,…`, Dron `SCZHAT,SCZHTS,SCZLAI,SCZHIV,SCZEXT`, Probe `SCPNEX,SCPASM`. Harvestery DTA (`HARV`, `TDHARV`,
  `RAHARV`) też mogą oddawać do CC. Vinifera wybiera najbliższy wolny dok (`_UnitClass_Mission_Harvest_FINDHOME_…`).
- CC i Nexus to construction yardy. Wcześniej CC jako rafineria nie działało (test 2026-10-25, zob. [[engine/transform-deploy]]).
  Przyczyna jest w `HouseClassExtension::Place_Object`: przy każdym postawionym budynku fabryka budynków
  (`Who_Can_Build_Me`) robi `builder->Transmit_Message(RADIO_HELLO, tech)`, a potem dostaje `RADIO_COMPLETE`. To zabiera
  jedyny kanał radiowy zadokowanemu robotnikowi. **Łatka A/B pomija obie wiadomości, gdy budowniczy ma `IsRefinery`.**
  Jedyna strata: animacja „budowania” construction yardu (budynki SC jej nie mają). Klasyczne ConYardy bez zmian.
- Hatchery nie buduje budynków (to „stocznia” larw), więc konfliktu nie ma. Wyjście jednostek z niej (`Unlimbo_Naval_Helper`)
  nie zmienia misji, gdy budynek jest w kontakcie radiowym **(niezweryfikowane w grze: produkcja przy zadokowanym dronie)**.

## Refinery daje 2 SCV (`tools/patch-freescv.ps1`, `game.exe`)

- `[SCREFI] FreeUnit=SCSCV` (było `TDHARV`) i nowy `Description` w bloku `SC workers` w `StarCraft.ini`.
- Silnik daje jedną `FreeUnit`. `BuildingClass::Grand_Opening` tworzy ją w jednym bloku (`0x42E56F`–`0x42E8E0`): nowa jednostka,
  `Unlimbo` na polu doku albo na wolnym polu obok, `Assign_Mission(HARVEST)`, `Commence`. Każde wyjście idzie przez `0x42E909`.
- Łatka: po udanym postawieniu (`0x42E8D6`) blok rusza drugi raz, gdy `FreeUnit` ma `IniName` = `SCSCV` (`AbstractTypeClass+0x14`,
  `BuildingTypeClass::FreeUnit` `+0x4FC`). Drugi SCV trafia na wolne pole obok doku. Flaga drugiego przebiegu leży w `.p_data`
  (`0x86E400`) i jest czyszczona na wspólnym wyjściu `0x42E909`. Jaskinie `0x86C300` (65 B) i `0x86C350` (12 B) w `.p_text`.
- Test na kopii: łatka, „already patched”, deasemblacja, `-Revert` daje plik identyczny. Łatka jest w `tools/patch-game.ps1`.
- Dotyczy też AI. Extractor i Assimilator dają nadal po jednym robotniku.

## Łatka `Vinifera.dll` (`tools/patch-vinifera-workers.ps1`)

Nowa sekcja `.scdock` (RVA `0x6DB000`, 0x200 B; w `.text` nie ma wolnego miejsca dłuższego niż 18 B). Skoki są tylko względne.

| | Adres | Oryginał | Warunek w jaskini |
|---|---|---|---|
| A | `0x100BCA54` | `builder->Transmit_Message(RADIO_HELLO=2, tech)` | pomiń, gdy `[builder+0x220]` (Class) `+0x81B` (`IsRefinery`) ≠ 0 |
| B | `0x100BCB02` | `tech->Transmit_Message(RADIO_COMPLETE=0xC, builder)` | jw. (budowniczy w `[ebp+0Ch]`) |
| C | `0x101153D6` | `IdleRate > 0` → klatka idle | dodatkowo: `UnitTypeClass+0x48E` (`IsToHarvest`) → wymagaj `UnitClass+0x36E` (`IsHarvesting`) **i** misji Harvest (`+0x4C` = 9) |

**Poprawka 2026-10-27 (test użytkownika: „wygląda, jakby worker zbierał przy postoju”).** `game.exe` ustawia `IsHarvesting`
w `Do_MISSION_HARVEST`, ale zeruje je tylko w `Do_MISSION_MOVE`, `Do_MISSION_PATROL`, `Do_MISSION_REPAIR` i w `UnitClass::AI`
(adresy z `Game.pdb`). Po rozkazie Stop albo przy postoju w Guard flaga zostawała ustawiona. Jaskinia C sprawdza teraz także
misję. Skrypt na starszej łatce przepisuje same jaskinie: wynik jest identyczny ze świeżą łatką, `-Revert` daje oryginał.
**(niezweryfikowane w grze)** Możliwy drobny efekt: robotnik w misji Harvest, który czeka w kolejce do rafinerii, może nadal „kopać”.

**Poprawka 2 (2026-10-27, test użytkownika: bezczynne drony Zergów „żują”).** Bez Extractora `Do_MISSION_HARVEST` od razu
przełącza drona na Guard, bo nie ma doku. Dron w kółko wraca do misji Harvest, a w tych tickach stara flaga `IsHarvesting`
włączała animację. Jaskinia C wymaga teraz również stanu misji `HARVESTING` (`MissionClass::Status` `+0x58` = 1).
Stany misji Harvest w `game.exe` (tablica skoków `0x65525C`): 0 LOOKING `0x654B54` (szuka Tiberium, zeruje flagę, przy
powodzeniu ustawia flagę i stan 1), 1 HARVESTING `0x654CE7` (zbiera; gdy przestaje, zeruje flagę), 2 FINDHOME `0x654EE2`,
3 `0x655151`, 4 `0x65516A`. Wada, która może zostać: dron, który w stanie 1 utknął w drodze do złoża, „żuje” w miejscu
**(niezweryfikowane w grze)**.

- Sprawdza bajty oryginału, więc inną wersję Vinifery odrzuci. `-Revert` cofa każdy bajt sam (test: wynik ma MD5 z pliku
  `version` klienta). Kopia `Vinifera.dll.bak` = oryginał. Plik `version` trzyma **MD5** plików jako ciąg bajtów w zapisie dziesiętnym.
- Aktualizacja klienta DTA może podmienić `Vinifera.dll` (jak `game.exe`). Wtedy uruchom łatkę ponownie.
- Uwaga dla skryptów: w PowerShellu `$dll` i `$Dll` to ta sama zmienna. Pierwsza wersja nie zrobiła przez to kopii `.bak`,
  oryginał odtworzono przez `-Revert` (zob. [[workflow/tooling]]).

## Pliki

| Plik | Zmiana | Kopia |
|---|---|---|
| `MIX/ECACHE78.MIX` | `SCSCVW.SHP`, `SCZWORKW.SHP`, `SCPPROBEW.SHP` | nowy plik |
| `INI/Art.ini` | blok `; >>> SC workers` (`[SCSCVW]`, `[SCZWORKW]`, `[SCPPROBEW]`) | `.bak` (stary) |
| `INI/Game Options/StarCraft.ini` | blok `SC workers`: `[SCSCV]` `Image`/`UnloadingClass`, `[SCREFI]` `FreeUnit=SCSCV` + opis | `.bak` (stary) |
| `game.exe` | łatka `patch-freescv.ps1` (2 SCV z Refinery) | `game.exe.bak` |
| `INI/Map Code/SC Factions/060 SC workers.ini` | blok `SC workers`: `[SCZWORK]`, `[SCPPROBE]` (`Image`, `UnloadingClass`) | `.bak` warstwy |
| `Vinifera.dll` | łatka A/B/C | `Vinifera.dll.bak` |

Generator: `tools/build-scworkers.ps1 [-Install]` (podglądy PNG w `-PreviewDir`). Bloki są na końcu plików (w kodzie mapy: własna warstwa nad warstwami
frakcji, [[engine/map-code-layers]]), a klient scala powtórzone sekcje, więc wygrywają z blokami generatorów frakcji ([[engine/ini-layering]]). Gdy generator frakcji zmieni
`Dock=` robotnika albo harvesterów DTA, popraw też ten blok.

## Do sprawdzenia w grze

1. ~~Animacja wydobycia~~: działa (test 2026-10-26).
2. Po postawieniu Refinery obok pojawiają się 2 SCV i od razu zbierają.
3. Rozładunek: robotnik zostaje sobą (nie harvester GDI).
4. ~~Doki w głównych budynkach~~: wycofane.
