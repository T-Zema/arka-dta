# Kasa, szybkość budowania i mnożniki domów

Ustawienia ekonomii i globalnych mnożników na poziomie mapy i domu.

Źródła: `INI/Rules.ini` (komentarze nad `[Houses]` linia ~2788, `[General] BuildSpeed`, `TiberiumStorage`), `Maps/Missions/FRSTBITE.MAP` (`[Allies]`), log Debug (HouseTypes przetwarzane ze scenariusza), deasemblacja `game.exe` (`Game.pdb`: `HouseClass::Harvested` `0x4BD590`, `Spend_Money` `0x4BD770`, `Tracking_Active_Add` `0x4C45D0`, `Tracking_Active_Remove` `0x4C4450`, `Recalc_Power_Drain` `0x4C93F0`), Vinifera `houseext_hooks.cpp` `HouseClassExt::_Harvested`.

## Kredyty na start (misja)

- Sekcja domu w mapie, np. `[Allies] Credits=80`. **Wartość jest mnożona ×100**: 80 = 8 000 $, 10000 = 1 000 000 $.
- Licznik to 32-bitowy int: powyżej ok. 21 mln $ (`Credits` > ~21 000) **przekręca się na ujemną kwotę**.
- W skirmishu kasę ustawia dropdown *Starting Credits* w lobby.

## Mnożniki domu (country)

Klucze w sekcji domu, np. `[Allies]` w mapie (silnik przetwarza HouseTypes ze scenariusza):
`Firepower`, `Armor` (większe = mocniejszy), `Groundspeed`, `Airspeed`, `Cost`, `ROF` (większe = wolniej),
`BuildTime` (mniejsze = szybciej; `0.5` = 2× szybciej). **(niezweryfikowane w grze)**: działanie w misji jest wnioskiem z logu.

## Globalna szybkość budowania

`[General] BuildSpeed=.8` w Rules (minuty na obiekt kosztujący 1000 $). `BuildSpeed=.4` = 2× szybciej
**dla wszystkich**, łącznie z AI. Tak robi [[mods/super-mod-v1]].

## Silosy: jak naprawdę działa `Storage=`

Dom ma dwie kasy: `Credits` (`House+0x1A4`, bez limitu) i **Tyberium w magazynach** (`StorageClass` pod `House+0x194`, limit
`Capacity` pod `House+0x1A8`). `Available_Money` = obie razem.

- **`Capacity`** zmienia tylko `HouseClass::Tracking_Active_Add/Remove` (`0x4C45D0` / `0x4C4450`), w gałęzi **budynku**:
  `Capacity ± Class->Storage`. Gałęzie jednostki, piechoty i samolotu tylko liczą sztuki (`UQuantity` itd.).
- `Storage=` to pole **`TechnoTypeClass`** (`+0x3EC`), a każda techno ma własny magazyn (`TechnoClass+0x168`). U zbieraczy to
  ich ładunek (`SCZWORK Storage=13`), więc jednostka z `Storage=` **nie** powiększa silosów domu.
- **Urobek** (`Harvested`, w DTA podmieniony przez Viniferę na `HouseClassExt::_Harvested`) przycina ładunek do
  `Capacity − zapas` i rozkłada go **bal po balu do budynków** domu z `Class->Storage > 0` (pętla po `Buildings`).
  Co się nie mieści, przepada (EVA „Silos needed”).
- **Wydatki** (`Spend_Money`, `game.exe`, Vinifera go nie rusza): najpierw `Credits`, potem zdejmuje Tyberium z budynków.
- Zniszczony budynek z `Storage=`: `Capacity` spada, a jego zawartość ginie. Przy przejęciu lub sprzedaży (flaga `true`)
  przelewa się do innych silosów.
- **AI w skirmishu** (`Session.Type != GAME_NORMAL && !IsHuman`) i opcja lobby „No Silos” (`[General] TiberiumStorage=no`,
  `INI/Game Options/No Silos.ini`): urobek idzie prosto do `Credits` i silosy nie mają znaczenia.
- **Prąd** (`Recalc_Power_Drain` `0x4C93F0`) też sumuje wyłącznie budynki (`Power_Output`/`Drain` z `BuildingTypeClass`).

Jednostka-silos (Overlord Zergów) wymaga więc łatek: [[plans/overlord-storage]], zainstalowane jako [[mods/overlord-storage]]
(od tej pory pojazd z `Storage=` bez `Harvester=yes` podnosi `Capacity`).

## Poziomy trudności

Sekcje `[Easy]`, `[Normal]`, `[PlayerNormal]`, `[Difficult]` (i rozszerzenia Vinifery `[VeryEasy]`…`[UltimatelyEasy]`
dla AI) mają własne `BuildTime`, `Cost`, `Armor`, `ROF`. Czyta je tylko `Rules.ini`, **mapa ich nie nadpisuje**, a w kampanii
mnożniki kraju z sekcji domu (`Armor=` itd.) są ignorowane (Vinifera `HouseClassExt::_Assign_Handicap`, gałąź `GAME_NORMAL`).
W skirmishu oba mnożniki się mnożą. `spawn.ini`: `DifficultyModeHuman` / `DifficultyModeComputer`. Szczegóły i trudność
misji ARKA: [[engine/triggers-and-dialogue]] („Poziom trudności”).
