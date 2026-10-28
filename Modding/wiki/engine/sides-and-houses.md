# Strony (`[Sides]`) i domy (`[Houses]`): jak silnik i klient wiążą frakcję z indeksem

Grywalna frakcja to dom (HouseType) przypisany do strony (Side). Klient wybiera dom **po indeksie**. Od strony zależą pliki MIX sidebara, EVA i AI. Ta strona zbiera fakty potrzebne do dodania nowej frakcji (zob. [[plans/new-faction]]).

Źródła: `INI/Rules.ini` (`[Sides]`, `[Houses]`, `[GDISide]`…`[SovietSide]`, `[General]`, `[AI]`, `[PrerequisiteGroups]`), `INI/Enhance.ini`, `INI/AI.ini` (`[AITriggerTypes]`), `Resources/GameOptions.ini`, `Resources/ClientDefinitions.ini`, `INI/MPMaps.ini`, `INI/Game Options/Advanced AI.ini`, `spawn.ini`, `Debug/DEBUG_23-10-2026_17-23-32.LOG`, `MIX/SideC0*.mix`, `MIX/sidenc0*.mix`, `MIX/Speech0*.mix`, napisy w `Resources/clientdx.exe` i `Vinifera.dll`, skan `[Houses]` we wszystkich `Maps/**/*.map`.

## Strony

```ini
[Sides]                     ; indeks = kolejność wpisów
GDISide=GDI,GDI1,GDI2       ; 0
NodSide=Nod,Nod1,Nod2       ; 1
AlliesSide=Allies,Allies1,Allies2   ; 2
SovietSide=Soviet,Soviet1,Soviet2   ; 3
CivilianSide=Neutral        ; 4
SpecialSide=Special         ; 5
```
Sekcja strony (Vinifera `SideClassExtension`): `UIColor`, `OptionsMenuTextColor`, `ScreenTextColor`, `ToolTipColor`,
`HoverHighlightColor`, `RegularPowerPlant`, `AdvancedPowerPlant`, `Crew`, `Disguise`, `Engineer`, `Technician`,
`SurvivorDivisor`, `HunterSeeker`. Wzorzec: `[AlliesSide]`.

### Pliki zależne od strony (indeks strony + 1)

Vinifera ładuje `SIDEC%02d.MIX`, `SIDENC%02d.MIX` i `SPEECH%02d.MIX`. W logu: `Preparing Mixfiles for Side 02` →
`SIDEC03.MIX`, `SIDENC03.MIX`, a potem `Prep_Speech_For_Side()` → `SPEECH03.MIX`. Gdy pliku brak, Vinifera pisze
`Prep_For_Side({}) failed! Trying with side 0...` i bierze pliki GDI zamiast się wywalić.

| MIX | Zawartość (lister `Modding/tools/mixlist.ps1`, nazwy z „local mix database.dat”) |
|---|---|
| `SideC0x.mix` | sidebar (`side1-3.shp`, `tabs.shp`, `tab-*.shp`, `radar.shp`, `power/repair/sell/wayp.shp`, `addon.shp`, **`sidebar.pal`**), okna dialogowe (`*.pcx`), ekran wyniku (`score.pcx`, `score.aud`, `briefing.pcx`) oraz **grafiki typów wspólnych dla stron**: `harv.shp`, `horv.shp`, `proc*.shp` i cameo `e6icon`, `harvicon`, `hpadicon`, `mcvicon`, `procicon`, `raswicon` |
| `sidenc0x.mix` | czcionki, `compass.shp`, `globe.shp`, mapy regionów kampanii `rg*/rn*.shp`, dźwięki ekranu wyniku |
| `Speech0x.mix` | EVA: `00-iNNN.aud` (te same nazwy dla każdej strony, AUD). Który plik jest którym zdarzeniem: DTA nie ma `EVA.INI`, więc Vinifera bierze listę `EvaNames` (kolejność = indeks `VoxType`) i nazwy z tabeli `Speech[]` w `game.exe` (tablica wskaźników od offsetu pliku 0x311D14). Pełna mapa najważniejszych zdarzeń i przykład przemalowanego sidebara: [[mods/terran-faction]] („Sidebar i EVA”). |

MIX-y strony ładują się **dwa razy**. Najpierw w `Start_Game`, przed mapą: indeksem strony jest wtedy surowe `Side=`
ze `spawn.ini`, czyli numer domu (log: `Side=6` → `Preparing Mixfiles for Side 06` → `SIDEC07.MIX`). Potem po wczytaniu
scenariusza: według strony domu gracza (`Calling Prep_For_Side()`). Potwierdzone w `DEBUG_24-10-2026_19-17-57.LOG`.
Po podmianie MIX-ów silnik pisze `Reloaded side-dependent type graphics`. Dlatego harvester i rafineria wyglądają inaczej u każdej strony.

## Domy

```ini
[Houses]   ; 0=GDI 1=Nod 2=Allies 3=Soviet 4=Neutral 5=Special 6..13=GDI1,Nod1,GDI2,Nod2,Allies1,Allies2,Soviet1,Soviet2
[Allies]
Name=Allies
Suffix=ALI
Prefix=G
Color=AlliedBlue
Multiplay=yes          ; dom do wyboru w grze wieloosobowej/skirmishu
Side=AlliesSide        ; nazwa strony z [Sides]
```
Domy pomocnicze (`Allies1`…) mają `ActsLike=<indeks>` i własny kolor. `Neutral`/`Special` mają `MultiplayPassive=true`.

### Indeks domu jest „twardy”

- **Klient → `spawn.ini`:** `Side=<pozycja na liście Sides= z GameOptions.ini>`, a AI: `[HouseCountries] MultiN=<pozycja>`.
  Spawner Vinifery traktuje tę liczbę jako **indeks w `[Houses]`**. Lista klienta `Sides=GDI,Nod,Allies,Soviet`
  pokrywa się z domami 0–3. Piąta pozycja dałaby `Side=4`, czyli **Neutral**.
- **Mapy:** typy domów powstają przez find-or-make po nazwie: najpierw lista z Rules, potem `[Houses]` mapy.
  **122 ze 158 map** z sekcją `[Houses]` (62 misje, 57 co-op, 3 skirmishowe: `dueling_islands`, `dueling_deadlands`,
  `seabound_highway`) dopisuje własne domy od indeksu **14** (np. `14=TLAllies`). Triggery odwołują się do nich numerem
  (`cr01.map`: zdarzenie `1,1,0,14`). Mapy co-op dopychają nawet `Fake14…Fake49`, żeby trafić w konkretne indeksy.
- **Wniosek:** dopisanie albo przestawienie domu w `Rules.ini` przesuwa indeksy domów z misji i psuje ich triggery.
  Nowy dom wolno dodawać tylko tam, gdzie misje go nie widzą: w INI doklejanym do mapy skirmisha (zob. [[engine/ini-layering]]).
- **Lepsze obejście: przejęcie domu pomocniczego.** Domy 6–13 (`GDI1`…`Soviet2`) służą misjom. Na mapach skirmisha
  występują tylko w `seabound_highway`, `AI.ini` ich nie używa (TeamTypes mają tylko `House=GDI/Nod/Allies/Soviet`),
  a w `Owner=` (Rules+Enhance) mają po 3–6 typów (`GDI1`: `TDPROC`, `TDPROC_AI`, `TDHARV`, `DEPCARR`, `TRAN`, w Enhanced
  także `GHPAD`, `TRANV`). Plik doklejany do skirmisha może więc zmienić `[GDI1]` w grywalną frakcję
  (`Name=`, `Side=`, `Multiplay=yes`, `ActsLike=6`) bez nowego indeksu. W kliencie wyszarzone są wtedy tylko pozycje 4–5.
  `Special` się nie nadaje: używa go 35 map skirmisha. Plan: [[plans/new-faction]].
  Zajęte (2026-10-25): `GDI1` = Terran (strona 6, [[mods/terran-faction]]), `Nod1` = Zerg (strona 7, [[mods/zerg-faction]]),
  `GDI2` = Protoss (strona 8, `SIDEC09`, [[mods/protoss-faction]]). `GDI2` miał w `Owner=` `TDHARV`, `TDPROC`, `TDPROC_AI`,
  `DEPCARR`, `ASTRP`, `AIA10` (Rules+Enhance); kod mapy frakcji zdejmuje go ze wszystkich oprócz `TDHARV`.
  Wolne pomocnicze: `Nod2`, `Allies1`, `Allies2`, `Soviet1`, `Soviet2`.
- **`Enhance.ini`** (plik Firestorma, `game.exe` go czyta, tryb Enhanced / `Firestorm=True` w `spawn.ini`) nakłada się
  na Rules: zmienia `Owner=` 18 typów oraz `[General] PrerequisiteTech`, `[AI] BuildTech/BuildHelipad/BuildRadar`,
  `PowerSurplus`. Analizy `Owner=` trzeba robić na Rules+Enhance. Czy w trybie Classic jest pomijany: **(niezweryfikowane)**.

## Klient (XNA, `clientdx.exe`)

- `Resources/GameOptions.ini` `[General] Sides=`: lista nazw w dropdownie. Ikona: `Resources/<nazwa małymi>icon.png`
  (14–15 px, np. `alliesicon.png`).
- Obsługiwane: `[RandomSelectors]` (grupy losowania), `DisallowedPlayerSides=` (lista indeksów, w `MPMaps.ini`
  per mapa i prawdopodobnie per tryb gry) oraz `DisallowedSideIndex=` w checkboxie (jeden indeks; ta sama polaryzacja
  co `CustomIniPath`, więc jeden checkbox nie może jednocześnie doklejać pliku i blokować strony, gdy jest odznaczony).
  Zablokowane strony są w dropdownie **wyszarzone, ale widoczne** (`XNADropDownItem.Selectable`, brak `Visible`).
- **Brak `InternalSideIndices`** (nowsze wersje klienta mają to mapowanie). Indeks w dropdownie = indeks domu.
- Ekrany ładowania: `CustomLoadScreen=Resources/l600s21.pcx` dla `Side=2`, czyli
  `l600s<indeks><1..LoadingScreenCount>.pcx` (800×600) i `l480s…` (640×480). `LoadingScreenCount=2` w `ClientDefinitions.ini`.
  Format dla dwucyfrowego indeksu (np. `l600s141.pcx`) **(niezweryfikowane)**.
- `SidebarHack=yes` (`ClientDefinitions.ini` + `[ForcedSpawnIniOptions]`): unikalne sidebary dla ponad 2 stron.
- Tryby gry w `MPMaps.ini`: `[Default]` (Deathmatch), `[Empowerment]`, `[Scavenger]`, `[Survivor]`, `[Tournament]`,
  `[King of the Hill]`, `[Co-Op *]`. Do tego **„Custom Map”**: tryb map z `Maps/Custom` (`GameMode=standard` w mapie,
  `[GameModeAliases] standard=Custom Map`). Domyślnie nie ma swojej sekcji, ale można ją dodać. Klucz `MapCodeININame=`
  dokleja plik z `INI/Map Code/` (co-op: `Difficulty *.ini`). Wartość to jedna nazwa pliku (string, lista po przecinku nie działa),
  ale ten plik może łączyć kolejne przez `[INISystem] BasedOn=`; tak zbudowany jest kod frakcji SC ([[engine/map-code-layers]]). Pliki `Map Code/Empowerment.ini`, `Scavenger.ini` itd. noszą
  nazwy trybów, więc klient prawdopodobnie domyślnie szuka `<tryb>.ini` **(niezweryfikowane)**. Jawne `MapCodeININame` w tych
  trybach zastąpiłoby ich własny plik.

## Budowa bazy i AI

- `[General] BaseUnit=GMCV,NMCV,AMCV,SMCV` (MCV na start: pierwszy z listy, którego `Owner=` obejmuje dom),
  `HarvesterUnit=TDHARV,RAHARV`, `PadAircraft=`.
- `[AI] BuildConst/BuildPower/BuildRefinery/BuildBarracks/BuildTech/BuildWeapons/BuildDefense/BuildPDefense/BuildAA/
  BuildHelipad/BuildRadar/BuildNavalYard`: AI bierze z listy to, co może zbudować. Komentarz w Rules: misje wymagają,
  by każdy dom posiadał przynajmniej jeden `HarvesterUnit` i jeden budynek z `BuildRefinery`.
- `[AITriggerTypes]` w `AI.ini`: 925 wpisów, każdy z polem **Side = indeks strony + 1** (1=GDI…4=Soviet, 0=każda),
  po ok. 230 na stronę. Nowa strona bez własnych triggerów nie dostanie drużyn z klasycznego AI.
- **Advanced AI** (checkbox `chkExtremeAI`, domyślnie zaznaczony, `INI/Game Options/Advanced AI.ini`):
  `AdvancedAIBaseBuilding=yes`, `AdvancedAIUnitProduction=yes`. Buduje bazę i dobiera jednostki według oceny wartości,
  więc nowa strona powinna grać bez pisania TeamTypes **(niezweryfikowane w grze)**. Uwaga: plik nadpisuje
  `[AI] BuildTech=`, więc inny plik z tym kluczem może przegrać zależnie od kolejności doklejania.
- Grupy wymagań: `PrerequisitePower` ma już **122 znaki** (komentarz DTA: dłuższa wartość przekracza limit, ok. 128).
  Nowych budynków nie dopisujemy tam, tylko do własnej grupy `[PrerequisiteGroups]` albo do bezpośredniego `Prerequisite=`.
  Inne klucze (np. `Owner=`) mają w Rules wartości do 351 znaków.
