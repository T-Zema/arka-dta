# Plan: frakcja Zerg z budową „dron zamienia się w budynek”

Szósta grywalna frakcja (przejęty dom `Nod1`, indeks 7), w której budynki powstają jak w SC: dron podjeżdża w wybrane miejsce, gracz daje deploy, dron znika, a w jego miejscu rośnie budynek. Stan: **etap 0 zainstalowany 2026-10-25** jako [[mods/zerg-faction]] (niezweryfikowane w grze). Zmiany względem projektu poniżej:
Hatchery jest „stocznią” Vinifery (`Naval=yes`, drony z `BuiltAt=SCZHAT` pojawiają się obok, wzorzec Starportu), a w etapie 0 jest
Evolution Chamber i Sunken Colony (bez Hydralisk Den, bo Hydralisk wymaga tylko `BARRACKS`).

Źródła: rozmowa z 2026-10-25 (użytkownik: „przenieść sposób budowania Zergów… może da się to sprytnie obejść”, „testujemy na NOWEJ frakcji”),
[[engine/transform-deploy]], [[engine/sides-and-houses]], [[plans/new-faction]], [[mods/terran-faction]], [[mods/starcraft-zerg]],
`INI/Rules.ini` (`DeploysInto=` w `[GMCV]`, `[DBFRT]`→`BFRT`, `Owner=` z `Nod1`: tylko `TDHARV`, `TDPROC`, przestarzały `AFLD_AI`).

## Sztuczka: osobny dron na każdy budynek

Silnik umie dokładnie jedną rzecz w stylu Zergów: **pojazd z `DeploysInto=<budynek>` znika i zamienia się w budynek** (MCV → ConYard,
w DTA też `DBFRT` → `BFRT`, czyli działa nie tylko dla ConYardu). Jeden typ ma tylko jeden cel deployu, więc:

- Hatchery (`SCZHATCH`) to **fabryka pojazdów** („larwy”), a nie ConYard.
- Buduje się w niej „Drone → Spawning Pool”, „Drone → Extractor” itd.: **osobny pojazd na każdy budynek**, z grafiką drona,
  z cameo budynku z małym dronem i z `DeploysInto=<budynek>`. Koszt = dron + budynek, `BuildTime` = czas budynku.
- Gracz wysyła drona na miejsce, daje deploy, dron znika, a budynek rośnie z animacją `Buildup=` (kokon z SC).
- Start gry: `BaseUnit` = „Drone → Hatchery” (zamiast MCV) i to wszystko. Frakcja nie ma ConYardu, a zakładka budynków jest pusta.

Odrzucone warianty:
- **Cykl `TransformsInto`** (deploy przełącza tryb drona: Pool → Evo → …). Jeden typ ma albo `TransformsInto`, albo `DeploysInto`
  (oba pod klawiszem deploy), więc z cyklu nie da się wyjść w budynek.
- **Dron jako piechota** (obecny `SCDRONE`). Piechota w TS nie ma deployu.

## Role budynków (kompromisy silnika)

| Budynek SC | W DTA | Uwagi |
|---|---|---|
| Hatchery | `Factory=UnitType`, `WeaponsFactory=yes` (larwy → drony i Zergi-pojazdy) | Budynek ma jedną `Factory=`, więc piechota idzie gdzie indziej. Nie jest rafinerią: fabryka pojazdów też używa jedynego kanału radiowego (jak ConYard, zob. [[engine/transform-deploy]]) **(niezweryfikowane)**. |
| Spawning Pool | `Factory=InfantryType` (Zergling, Hydralisk, Ultralisk… = obecna piechota z [[mods/starcraft-zerg]]) | W SC wszystko wychodzi z larw. Tu Pool jest „koszarami”. |
| Extractor | `Refinery=yes`, `FreeUnit=` dron-robotnik | Dron stawia go obok Tiberium (gejzerów nie ma). |
| Dron-robotnik | `Harvester=yes`, grafika drona (pojazd SHP) | Zbieracz w TS musi być pojazdem. Osobny od dronów budowlanych. Czy zbieracz z `DeploysInto` w ogóle reaguje na deploy: test opcjonalny. |
| Lair, Hive | osobne budynki z drona, wymagają Hatchery (i Lair), same też są fabrykami larw | W SC to mutacja Hatchery. Ulepszenie Vinifery (`PowersUpBuilding`) kupuje się w zakładce budynków, a ta wymaga `Factory=BuildingType`, czyli ConYardu, którego Zergi nie mają. |
| Creep Colony → Sunken / Spore | Sunken i Spore jako osobne drony, z wymaganiem Creep Colony | Prawdziwa mutacja kolonii odpada z tego samego powodu co Lair. |
| Evolution Chamber, Hydralisk Den, Spire, Queen's Nest, Ultralisk Cavern, Defiler Mound | budynki tech (wymagania jednostek) | |
| Overlord / zasilanie | Zergi bez prądu: `Power=0` w budynkach albo Hatchery z dużym `Power=` | |

## Problemy i obejścia

- **Czas budowy:** płaci się go w Hatchery przy produkcji drona. Potem jest tylko `Buildup` (kilka sekund). Silnik nie umie budynku
  „dojrzewającego” z czasem.
- **Anulowanie morfu (opcja):** budynek z `UndeploysInto=<dron→budynek>` cofa się do drona (jak latające budynki Terran).
  Efekt uboczny: budynek łapie się w zaznaczenie ramką. Wymaga opcji „Re-Deployable MCV”.
- **Creep:** brak. Deploy nie sprawdza `Adjacent=`, więc Zergi stawiają budynki gdziekolwiek dojedzie dron (mocniejsze niż w SC).
- **Zatłoczona zakładka pojazdów:** ok. 14 dronów budowlanych plus jednostki. Rozwiązanie: wymagania (dron → Spire pojawia się dopiero po Lair).
- **AI:** Advanced AI nie rozstawia dronów, więc AI-Zerg nie zbuduje bazy. Etap 0 przewiduje Zerga tylko dla gracza. Później ewentualnie
  osobny ConYard tylko dla AI (`Owner=Nod1`, `TechLevel=-1`, w `[AI] BuildConst`).
- **Miejsce deployu:** budynek staje fundamentem wokół komórki drona, a zajęty teren daje kursor „nie można” (jak MCV) **(niezweryfikowane dla dużych fundamentów)**.

## Nowa frakcja (wymóg użytkownika: testy na nowej frakcji)

Wzorzec 1:1 z [[mods/terran-faction]]:
- Dom **`Nod1` (indeks 7)** → `Name=Zerg`, `Side=ZergSide`, `Multiplay=yes`, `ActsLike=7`. Strona `ZergSide` = 8. wpis w `[Sides]`
  (indeks 7), więc MIX-y strony to `SideC08.mix`, `sidenc08.mix`, `Speech08.mix`. `Nod1` jest właścicielem tylko `TDHARV`/`TDPROC`
  (wymóg misji, w pliku frakcji zdjąć) i przestarzałego `AFLD_AI`.
- `Resources/GameOptions.ini`: `Sides=…,Terran,Zerg`, ikona `zergicon.png`, ekrany `l600s7{1,2}.pcx`, `l480s7{1,2}.pcx`.
- `INI/MPMaps.ini`: w trybach bez pliku frakcji `DisallowedPlayerSides=4,5,6,7`.
- **`MapCodeININame` przyjmuje jeden plik** (dziś `Terran Faction.ini` w `[Default]` i `[Custom Map]`). Blok Zergów trzeba więc dopisać
  do tego samego pliku (jako oznaczony blok) albo zmienić nazwę na wspólny plik frakcji SC. Czy klient przyjmie listę po przecinku: **(niezweryfikowane)**.
- Typy Zergów: `Owner=Nod1` (budynki i drony tylko dla Zergów). Piechota z [[mods/starcraft-zerg]] dostaje `Nod1` w `Owner=`.

## Etapy

0. **PoC:** frakcja `Nod1`/Zerg, Hatchery, „Drone → Hatchery” (start), dron-robotnik, Extractor, Spawning Pool i 2–3 drony budowlane.
   Grafiki z SC (`unit/zerg/*.grp` tym samym konwerterem co budynki Terran, `ScBuildings.cs`), osobny MIX. Test: start, deploy drona,
   produkcja w Hatchery i Pool, zbieranie.
1. Wszystkie budynki, Lair/Hive, obrona, latające Zergi z Hatchery (wzorzec Fly z [[engine/fly-locomotor]]).
2. Sidebar i EVA Zergów, AI.
