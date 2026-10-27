# Plan: Overlord jako silos (kredyty) albo elektrownia

**Wdrożone 2026-10-27 jako [[mods/overlord-storage]] (wariant A, `Storage=100`).** Studium wykonalności: czy Overlord Zergów (`SCZOVL`, `SCZOVL2`, bohater `SCZHYG`) może
przechowywać kredyty jak Supply Depot/Pylon/Creep Colony (`Storage=100`) albo dawać prąd. Użytkownik woli kredyty.

Źródła: [[engine/houses-economy]] (sekcja o silosach: deasemblacja `game.exe`, Vinifera `HouseClassExt::_Harvested`),
`INI/Map Code/Terran Faction.ini` (`[SCZOVL]`, wartości `Storage`/`Power` typów `SCZ*`), [[mods/zerg-faction]].

## Wniosek

- **Samo INI nie wystarczy.** `Storage=100` na Overlordzie da się wpisać (pole `TechnoTypeClass`), ale silnik dolicza pojemność
  domu tylko z budynków i tylko budynki napełnia urobkiem ([[engine/houses-economy]]).
- **Prąd jest Zergom zbędny**: wszystkie budynki `SCZ*` mają `Power=0`, a Hatchery/Lair/Hive dają `Power=50`. Prąd z jednostki
  wymagałby łatki `Recalc_Power_Drain` i nowego klucza (jednostki nie czytają `Power=`), więc odpada.
- **Kredyty da się zrobić dwiema łatkami**, w stylu poprzednich ([[engine/game-exe-patching]]).

## Projekt (do zatwierdzenia przez użytkownika)

1. **`game.exe`, `Tracking_Active_Add/Remove`, gałąź jednostki**: jednostka z `Storage > 0`, która nie jest zbieraczem
   (`Harvester`/`Weeder` = no; robotnicy SC mają `Storage=` jako ładunek), zmienia `Capacity` o swoje `Storage`.
   Wtedy EVA „Silos needed” i paski liczą się poprawnie.
2. **Urobek, `Vinifera.dll`** (`HouseClassExt::_Harvested`; łatka w `game.exe` nie zadziała, bo Vinifera przeskakuje
   `0x4BD590`). Dwa warianty:
   - **A (prostszy, zalecany):** Overlord tylko podnosi limit. Nadwyżka, która nie mieści się w budynkach, trafia do pierwszego
     budynku-silosu domu ponad jego `Storage` (Hatchery/Extractor). `Spend_Money` działa bez zmian. Śmierć Overlorda obniża limit,
     ale **nie zabiera kasy**. Ryzyko kosmetyczne: paski `PipScale` przepełnionego budynku.
   - **B (wierny):** kredyty leżą **w Overlordzie** (`TechnoClass+0x168`). Dodatkowa pętla po `Units` w `_Harvested` i w
     `Spend_Money` (`game.exe`), a przy śmierci zawartość ginie. Wymaga trzech łatek.
3. INI: `Storage=100` (jak Supply Depot, Pylon, Creep Colony) w `[SCZOVL]`, `[SCZOVL2]`, ewentualnie `[SCZHYG]`, w bloku generatora
   `build-sczergbase.ps1` / `build-sczergresearch.ps1` / `build-sczergheroes.ps1` albo w bloku `; >>> SC balance (user)`.

Dotyczy tylko gracza: AI w skirmishu dostaje urobek prosto do `Credits`, a opcja lobby „No Silos” wyłącza silosy w ogóle.
