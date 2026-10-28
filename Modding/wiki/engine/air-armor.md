# Pancerze lotników SC: AA Aliantów tylko na rozkaz, Dragoon nie trafia Overlorda

Zasada ogólna użytkownika (2026-10-28): AA Aliantów samo nie strzela do lotników Terran, Zergów i Protossów, a gdy gracz ręcznie wskaże cel, trafia. Dragoony w ogóle nie mogą zestrzelić Overlorda. Całość jest w INI przez typy pancerza Vinifery, bez łatki `game.exe`.

Źródła: `INI/Rules.ini` (`[ArmorTypes]`, opis kluczy nad sekcją, `[ZeroWH]`/`[DummyWH]`), dokumentacja i źródła Vinifery na GitHubie (`docs/New-Features-and-Enhancements.md`, `src/new/verses/verses.h`, `src/new/armortype/armortype.cpp`, `src/extensions/rules/rulesext.cpp`), log `Debug/DEBUG_28-10-2026_16-29-56.LOG`, generator `Modding/tools/build-scairarmor.ps1`.

## Mechanizm Vinifery
- `[ArmorTypes]` dodaje pancerze po nazwie (małe litery, wielkość liter ma znaczenie). Sekcja pancerza: `Modifier=`, `ForceFire=`, `Retaliate=`, `PassiveAcquire=`, `BaseArmor=`.
- Głowica: `Modifier.<pancerz>=`, `ForceFire.<pancerz>=` (atak na rozkaz), `Retaliate.<pancerz>=` (odwet), `PassiveAcquire.<pancerz>=` (samodzielne wybieranie celu w Guard).
- **Wartość jest szukana przy każdym trafieniu** (`Verses::Get_Value`): ustawiona w głowicy → jeśli nie, ta sama głowica dla `BaseArmor` (rekurencyjnie) → wartość domyślna pancerza. Dlatego nowy pancerz z `BaseArmor=light` dostaje od każdej głowicy dokładnie to, co `light`, także flagi.
- Nieznana nazwa w `Armor=` daje `none` (`ArmorTypeClass::From_Name`), bez crasha.
- `RulesClassExtension::Process` (z `Armors()`) działa w **każdym** przebiegu reguł: Rules, opcje gry, kod mapy, mapa (w logu 4× „Rules: Processing ArmorTypes”). Pancerz można więc dodać w pliku frakcji albo w mapie misji, bez zmiany `Rules.ini`.

## Co robi `build-scairarmor.ps1`
Blok `; >>> SC air armor` na końcu `INI/Map Code/Terran Faction.ini` i `INI/Game Options/StarCraft.ini` (w każdym tylko typy SC zdefiniowane w tym pliku; późniejsze klucze wygrywają):
- **Pancerze**: `sc_air_wood`, `sc_air_light`, `sc_air_medium`, `sc_air_heavy` (`BaseArmor` = stary pancerz) i `sc_overlord` (`BaseArmor=sc_air_heavy`).
- **50 lotników SC** (ID `SC*` z lokomotorem Fly albo Jumpjet, czyli też latające budynki Terran): `Armor=sc_air_<stary>`. Overlord, Upgraded Overlord i Yggdrasill (`SCZOVL`, `SCZOVL2`, `SCZHYG`): `sc_overlord`. Obrażenia od wszystkich innych broni bez zmian.
- **AA Aliantów** = typy, których `Owner` to tylko `Allies`/`GDI1`, z bronią o pocisku `AA=yes`: `RAAGUN` (+`RAAGUN_AI`), `MFLAK`/`AIMFLAK`, `CTNK`/`AICTNK`, `PTNK`, `TTNKMSL`, `FLAKCORV`, `DDFLAK`, `FRIGATE`/`AIFRIGATE`, `HVCT`. Ich głowice dostają kopie `AL_FlakWH`, `AL_BazAPRA`, `AL_ChronoAP`, `AL_MslHEAA` z `PassiveAcquire.sc_air_*=no`, `Retaliate.sc_air_*=no`, `ForceFire.sc_air_*=yes`. Broń używana tylko przez Aliantów dostaje nową głowicę w miejscu (`ZSU-23`, `Flak`, `NavalFlak`, `APTuskAA`, `FrigateMissileAA`); broń wspólna z innymi właścicielami jest kopiowana (`ChronoTuskAA` → `AL_ChronoTuskAA` tylko dla `TTNKMSL`, bo `2TNKMSL` jest wspólny).
- **Trafia na rozkaz**: gdzie głowica dawała 0% (np. `FlakWH`: `wood` 0%, a `light` → `BaseArmor=wood`), kopia ma wartość dla `medium` (`AL_FlakWH` 770% na Mutaliska i latające budynki, `AL_MslHEAA` 580%). To ta sama pułapka co w ARKA 4, zob. [[workflow/known-mistakes]].
- **Dragoon**: `SCPPhase` i `SCPPhaseU` strzelają `SCPDragWH` (kopia `SCPPhaseWH`, który zostaje dla Arbitera) z `Modifier/ForceFire/Retaliate/PassiveAcquire.sc_overlord` wyłączonymi. Kursor ataku na Overlordzie nie działa, Dragoon też sam go nie wybierze.
- Wspólne AA (`E3` Rocket Soldier, `GTNK`, `HVR`, `JEEPPTNK`, `MWAVEMSAM`, `2TNKMSL`, AA Sowietów, Marines, Goliath, Missile Turret…) działa jak dotąd, czyli samo celuje w lotników (łatka [[engine/fly-locomotor]] „Automatyczne celowanie”).
- Skutek uboczny: komputerowi Alianci też nie bronią się AA przed lotnikami SC (AI nie wydaje rozkazów ataku wieżyczkom).

## Misje ARKA
Misje kopiują typy SC do mapy (domknięcie zależności), więc `Armor=` lotników i sekcje pancerzy przechodzą same. Resztę (`[ArmorTypes]`, głowice i bronie Aliantów z Rules, głowica Dragoona) dopisuje `Add-ScAirArmor` z `tools/MissionKit.ps1`, czytając blok z pliku frakcji. Wywołanie jest w `build-arka01/02/04/05-mission.ps1` (zaraz po wczytaniu MissionKit). Wszystkie 4 mapy przebudowane 2026-10-28 (CHECKS PASS). Kopia lotnika zrobiona w generatorze misji (np. `ARKOVLC` w ARKA 5, Overlord siejący creep) musi powstać **przed** `Add-ScAirArmor` i skopiować `Armor=` z oryginału, inaczej zostanie ze starym pancerzem. ARKA 0 (1953) nie ma lotników SC.

## Kolejność generatorów
Uruchomić `build-scairarmor.ps1` ponownie po każdym generatorze SC, który dodaje lotników albo zmienia ich `Armor=` (Zerg, Protoss, badania, bohaterowie), potem przebudować misje ARKA. Blok czyta pliki bez własnego bloku, więc ponowne uruchomienie nie nawarstwia `sc_air_sc_air_*` (skrypt odmawia, gdy zobaczy `Armor=sc_*` spoza bloku).

**(niezweryfikowane w grze)**: brak samodzielnego ognia AA Aliantów, trafienie na rozkaz, brak odwetu, zakaz ataku Dragoona na Overlorda.
