# Mod: AI frakcji Protoss (skirmish z Advanced AI + moduł misji)

Komputer grający Protossami (dom `GDI2`) stawia bazę z budynków SC wokół Nexusa i Pylonów, robi badania, buduje Probe'y i armię SC i atakuje według taktyk w stylu AI StarCrafta. Do misji (ARKA 6) jest osobny moduł triggerów. Stan: **zainstalowany 2026-10-30, (niezweryfikowane w grze)**. Skirmish wymaga checkboxów STARCRAFT i Advanced AI (domyślny).

Źródła: [[plans/protoss-ai]] (inżynieria wsteczna AI SC i silnika), [[engine/advanced-ai]] (mechanika Advanced AI, sesja AI Terran), [[engine/skirmish-ai]] (klasyczne AI), [[mods/terran-ai]] (wzorzec generatora), skrypty AI SC z CASC (`PMCx` melee, `PLOx`/`PMEx`/`PHIx` kampania), disasemblacja `Vinifera.dll` 16.2.3 z `Vinifera.pdb` (`AdvancedAI_AI_Unit` 0x100BBF0F, `HouseClassExtension::AI_Unit`, `_Find_Build_Location`), `game.exe` (`BuildingTypeClass::Read_INI` 0x440B7A, `HouseClass::AI` 0x4BD0BC–0x4BD1A1).

## Pliki

| Plik | Co |
|---|---|
| `Modding/tools/build-scprotossai.ps1` | generator; `-WhatIf` wypisuje blok, `-Report` pokazuje, które jednostki AI może cenić |
| `INI/Game Options/StarCraft.ini` | blok `; >>> Protoss AI` na końcu, za `; >>> Terran AI` |
| `Modding/tools/patch-vinifera-navalai.ps1` | łatka `Vinifera.dll` (sekcja `.scai`), w łańcuchu `patch-vinifera.ps1` |
| `Modding/tools/ProtossAI.ps1` | moduł misji `Add-ProtossAI` (na bazie `Add-ZergAI` z `ZergAI.ps1`) |

Oba generatory AI czytają `StarCraft.ini` bez **własnego** bloku, więc listy `[AI]` każdego z nich zawierają wpisy drugiego. Po zmianach typów SC uruchom ponownie oba, w dowolnej kolejności.

## Co robi blok w `StarCraft.ini`

1. **Czysto SC:** `GDI2` znika z `Owner=` typów spoza SC (dziś tylko `TDHARV`). Bez tego wyszukiwania Advanced AI „pierwszy wpis, który dom posiada” zwracały zbieracz DTA zamiast Probe'a, a AI nie liczyło swoich Assimilatorów i Probe'ów.
2. **`AIBuildThis=yes`** dla 15 budynków (Pylon, Assimilator, Gateway, Forge, Photon Cannon, Cybernetics Core, Robotics Facility, Shield Battery, Stargate, Citadel, Robotics Support Bay, Observatory, Templar Archives, Fleet Beacon, Arbiter Tribunal) i 17 badań `SCQ*` ([[mods/starcraft-research]]). Ostatni krok kolejki Advanced AI stawia jedną sztukę każdego, jak wątki `upgrade` w `PMCx`. Nexus zostaje `AIBuildThis=no`: stracony wraca jako `SCPDNEX`. `SCPCAN` dostaje `IsBaseDefense=yes`, jeśli go nie ma.
3. **Listy `[AI]`** (wpisy Protossów na końcu):
   - `BuildPower=…,SCPPYL`: Pylon jest jednocześnie elektrownią podstawową i zaawansowaną, więc przy niskiej nadwyżce prądu AI stawia kolejne Pylony, jak zapas w SC;
   - `BuildRefinery=…,SCPASM`, `BuildBarracks=…,SCPGAT`;
   - `BuildWeapons=…,SCPROB`: warunki `HAS_WAR_FACTORY`;
   - `BuildDefense`, `BuildPDefense`, `BuildAA` `=…,SCPCAN`;
   - `BuildNavalYard=…,SCPROB,SCPSTG`: jednostki Robotics i Stargate to pojazdy `Naval=yes`, a Advanced AI buduje je tylko dla drużyn morskich, które wymagają takiej „stoczni”.
4. **Taktyki `House=8`**. Wybiera się pierwsza pasująca. W drużynach lądowych jest piechota z Gatewaya, w „morskich” armia z Robotics i Stargate.

| Taktyka | Typ | Kiedy | Wzór w SC |
|---|---|---|---|
| `PROTOSS_EARLY_ZEALOT_RUSH` | rush piechotą | slot 0 < 4, < 2500 klatek, wróg nie Soviet | rush Zealotów |
| `PROTOSS_EARLY_SCOUT` | zwiad | slot 0 < 11 (50%: ustaw 11) | DTA |
| `PROTOSS_EARLY_DEFEND` | obrona do 1700 | slot 0 > 10, < 2000 klatek | `PHIx`: 2 Zealoty + Dragoon w bazie |
| `PROTOSS_ZEALOT_WAVE` | rush do 4800 | 2000–7000 klatek, bez przewagi wroga, 60% | `PMCx`, atak 1: 12 Zealotów |
| `PROTOSS_DARK_TEMPLAR_RAID` | samobójczy rajd na zbieracze do 2600 | > 6000 klatek, wróg bez sensorów, ma > 1 rafinerię, co 6000 klatek, 40% | DT w linii robotników (maskowanie liczy się ×2) |
| `PROTOSS_FLANK_ATTACK` | atak na rafinerie | słabo bronione rafinerie, co 6000 klatek, 75% | DTA |
| `PROTOSS_HOLD_THE_LINE` | straż domowa do 3000, najwyżej 1 | przewaga wroga ×2, > 4000 klatek, 50% | `defensebuild`/`defenseuse` |
| `PROTOSS_GATEWAY_ARMY` | atak (Zealoty, Dragoony, Templarzy), rośnie z czasem | > 6000 klatek, 50% | `PMCx`, atak 2 |
| `PROTOSS_DIRECT_ATTACK` / `PROTOSS_FAST_ATTACK` | atak mieszany / zapas | 50% / zawsze | DTA |
| `PROTOSS_ROBOTICS_PUSH` (morska) | Reavery, Archony do 6000 | > 5000 klatek, 40% | `PHIx`: fala z Reaverem |
| `PROTOSS_FLEET_HARASS` (morska) | do 4500 | 40% | `PMCx`, atak 3: Scouty |
| `PROTOSS_FLEET_ATTACK` (morska) | flota rosnąca z czasem | zawsze | pętla `PMCx`: Scouty i Carriery |

**Jednostek, których AI nie zbuduje** (raport `-Report`: broń główna bez pocisku `AG=yes` albo brak broni): Corsair (czysto przeciwlotniczy, `InvisibleAA`), Shuttle, Observer, Probe do walki. Pocisk `Invisible` nie ma klucza `AG`, więc obowiązuje domyślne `AG=yes` (tak samo jak przy karabinach piechoty DTA).

## Łatka `patch-vinifera-navalai.ps1`

Advanced AI (i klasyczne AI) wrzuca **zastępczego zbieracza** i **zastępcze MCV** do lądowej kolejki `House->BuildUnit`. Probe i `SCPDNEX` mają `Naval=yes` (wyjście „stoczni” przy Robotics), więc żadna fabryka lądowa ich nie weźmie i kolejka zostaje pełna na zawsze. Wtedy `HouseClass::AI` pomija `AI_Infantry` i `AI_Aircraft` (hak Vinifery 0x4BD0BC: „buduje zbieracza”), a `_Production_Check` przestaje wołać `AI_Building`. AI Protossów zastygłoby po pierwszej utracie Probe'a.

| Miejsce | Co zmienia |
|---|---|
| A `0x100BC0F9` (`AdvancedAI_AI_Unit`) | jednostka `Naval=yes` trafia do `HouseClassExtension::BuildNavalUnit` (+0x34), skąd biorą ją Robotics i Stargate |
| B `0x100BB028` (`HouseClassExtension::AI_Unit`, klasyczne) | to samo dla zastępczego zbieracza |
| C `0x100C6976` (`_Find_Build_Location`, klasyczne) | budynek `Naval=yes` szuka miejsca na wodzie tylko przy `WaterBound=yes` (`Speed`=`SPEED_FLOAT`, +0x358). Robotics i Stargate stają na lądzie, a stocznie DTA dalej na wodzie |

Innych frakcji to nie zmienia: ich zbieracze i MCV nie są `Naval`, a stocznie DTA mają `WaterBound=yes`. Tylko kompilacja 16.2.3 (`6AD94075`). Instalacja przy zamkniętej grze: `tools/patch-vinifera.ps1`. Cofnięcie: `patch-vinifera.ps1 -Revert` (cofa wszystkie, w odwrotnej kolejności).

## Misje: `Add-ProtossAI` (`ProtossAI.ps1`)

W misjach Advanced AI nie działa sensownie (bierze wszystkie domy komputera, AITriggery są martwe, [[engine/advanced-ai]]). Baza Protossów w misji to więc triggery, jak gniazdo Zergów ([[engine/zerg-ai]]): `Add-ZergAI` z etykietami Protossów i:
- **`Get-ProtossSquads -Target <wp> -Base <wp>`:** drużyny z kampanii SC (`PHIx`):
  - fala 1: 3 Zealoty;
  - fala 2: 4 Zealoty + 2 Dragoony;
  - fala 3: 6 Zealotów + 4 Dragoony;
  - fala 4: to samo + Reaver;
  - templariusze;
  - 2 Dark Templar na zbieracze (`0,3`);
  - obrona: 2 Zealoty + Dragoon, Area Guard;
  - kontratak.
- **`Get-ProtossOrders`:** oś czasu `PHIx` Difficult. Pierwsza fala po 189 s, potem co 126 s. Fala 4 powtarza się co 252 s, DT i templariusze co 378 s. Easy i Medium zmniejszają drużyny przez `$DiffLevels`.
- **Przywołanie:** drużyna, której produkcja nie zdążyła w `Watchdog` s, pojawia się posiłkami przy Pylonie (`Rally`).
- **Pylony:** zniszczenie **wszystkich** Pylonów z `Pylons=` (tagi) kończy zamówienia i przywołania. `LostTags` (np. Nexus) kończą je od razu.
- **`Test-ProtossBuildable`:** loguje typy z drużyn, których dom nie zbuduje w mapie (`TechLevel`, `Owner`).

Mapa misji 6 ma na razie tylko teren i obiekty ([[missions/arka-06-ogien-z-nieba]]). Moduł podłączy skrypt misji, gdy dostanie domy i triggery. Dom Fenixa potrzebuje `IQ=5`, Nexusa, Gatewaya i Robotics (dla Reavera) oraz typów SC z `TechLevel` ≥ 0 i `Owner=` z tym domem.

## Test (do zrobienia przez użytkownika)

Skirmish, STARCRAFT + Advanced AI, AI = Protoss (najlepiej trudne) na mapie DTA i na mapie SC:
1. AI przenosi `SCPDNEX` w Nexus i stawia kolejno Pylon, Assimilator, Gateway, Robotics. Buduje Probe'y w Robotics i nie sprzedaje Assimilatora.
2. Pierwsza drużyna (zwiad albo rush Zealotów) w ciągu ok. 2–4 min, potem fala Zealotów, później Dragoony i Templarzy.
3. Po zabiciu Probe'a AI buduje nowego (łatka A), a baza dalej rośnie (Forge, Photon Cannony, Stargate, badania).
4. Robotics/Stargate: ataki Reaverów i Archonów, później Scouty i Carriery.
5. Bez checkboxa Advanced AI: Protoss nie ma AITriggerów strony 9 (nie zrobione), więc tylko buduje i się broni.
6. Przy crashu: `EXCEPT_*.TXT` i log z `Debug/`, najpierw szukać „Unknown AdvAI”.

## Odinstalowanie

Usunąć blok `; >>> Protoss AI` … `; <<< Protoss AI` z `INI/Game Options/StarCraft.ini` i cofnąć łatkę (`patch-vinifera-navalai.ps1 -Revert`, gdy jest ostatnią sekcją, albo `patch-vinifera.ps1 -Revert` dla wszystkich).
