# AI skirmisha w TS + Vinifera: plan bazy, produkcja, AI-triggery

Jak komputer w skirmishu (i w misji z AI-triggerami) decyduje, co budować, gdzie stawia budynki, jakie jednostki szkoli i kiedy atakuje. Strona powstała przy projekcie [[plans/protoss-ai]] (inżynieria wsteczna 2026-10-30) i dotyczy też frakcji Terran i Zerg.

Źródła: `game.exe` + `Game.pdb` (deasemblacja capstone `HouseClass::Make_Base_Nodes` 0x4C5BB0, `Can_Build_Here` 0x4CB9C0, wywołujący `DisplayClass::Passes_Proximity_Check` 0x4761A0), `Vinifera.pdb` (układ `RulesClass`, `BuildingTypeClass`), kod Vinifery (`src/extensions/house/houseext.cpp` `AI_Unit`/`AI_Naval_Unit`, `houseext_hooks.cpp` `_AI_Building`, `_Expert_AI`, `_Find_Build_Location`, `_Production_Check`, `aitriggertype/aitriggertypeext_hooks.cpp`), `INI/AI.ini`, `INI/Map Code/Naval Only AI.ini`, `INI/Rules.ini` `[AI]`, `[Houses]`, `[GSYRD_AI]`, `Maps/Missions/se09.map`.

## Plan bazy (`Make_Base_Nodes`, raz na początku gry)

1. **Kandydaci:** wszystkie `BuildingTypes` z domem w `Owner=`, `AIBuildThis=yes` i `TechLevel` ≤ poziomu domu (`Weeder` tylko przy chwaście na mapie). Kolejność = kolejność `[BuildingTypes]`.
2. **Początek planu:** pierwszy typ z `[AI] BuildConst`, który dom może posiadać (hak Vinifery 0x4C5E20), potem pierwszy posiadalny z `BuildPower`. Ten drugi wchodzi **nawet bez `AIBuildThis`**.
3. Pierwszy posiadalny z `BuildBarracks` i pierwszy z `BuildWeapons` idą na czoło listy kandydatów.
4. **Przebiegi:** każdy kandydat, którego wymagania (`AI_Has_Prerequisites`, wersja Vinifery) spełniają budynki już w planie, dopisuje się na koniec. Lądowiska (`Helipad`) dostają 1–3 kopie. Przebiegi trwają, aż wejdą wszyscy. `GAPLUG` jest odkładany na koniec.
5. **Dodatkowe rafinerie:** kopie pierwszej posiadalnej z `BuildRefinery` w losowych miejscach za pierwszą. Liczba to 2 − pole domu `+0x58` (prawdopodobnie poziom trudności; **niezweryfikowane**).
6. **Obrona:** od 4. węzła wplatane są węzły „obrona” (`-1`) i mury (`-3`). Liczba zależy od wartości bazy i `NodBaseDefenseCoefficient`/`GDIBaseDefenseCoefficient`. GDI dostaje też `WallTower`. Konkretny typ obrony wybiera dopiero `AI_Build_Defense` w trakcie gry (listy `BuildDefense`, `BuildAA`, `BuildPDefense`).

**Wniosek:** typ, który ma budować AI, potrzebuje `AIBuildThis=yes`, `Owner` z domem i własnej pozycji na listach `[AI]`. Lista jest **jedna dla wszystkich domów**. „Pierwszy posiadalny” wybiera się po `Owner`, więc żaden typ DTA wcześniej na liście nie może mieć domu SC w `Owner`.

## Budowa w trakcie gry (`AI_Building`, Vinifera)

- Bierze kolejny niezbudowany węzeł. Jeśli w skirmishu `Drain` węzła + zużycie > produkcja − `PowerSurplus` (250), **przed nim wstawia elektrownię strony**: `PowerTurbine`, potem `AdvancedPowerPlant` (gdy spełnione wymagania), na koniec `RegularPowerPlant` z sekcji strony (`[ProtossSide] RegularPowerPlant=SCPPYL`). Pylony rosną więc same razem z bazą, prawie jak zapas w SC.
- **Miejsce:** `Find_Build_Location` od środka bazy, odstęp `AIBaseSpacing` (`Can_Build_Here`). **Zasięg budowania (`Adjacent`/`BaseNormal`) sprawdza tylko kursor gracza**: `Passes_Proximity_Check` wołają wyłącznie `DisplayClass::Set_Cursor_Pos` i `Mouse_Left_Release`. AI Protossów nie potrzebuje więc zasięgu Pylonów (stawia budynki obok siebie wokół środka bazy).
- **Pułapka „stoczni”:** Vinifera stawia każdy budynek z `Naval=yes` **na wodzie** (`Nearby_Location` z `SPEED_FLOAT`, do `AINavalYardAdjacency` od ConYardu). Fabryki SC z wyjściem stoczni (`SCPROB`, `SCPSTG`, `Naval=yes` bez `WaterBound`) AI postawiłoby tylko na wodzie. Na lądzie budynek czeka w nieskończoność i blokuje kolejkę budowy. **(wniosek z kodu, niezweryfikowane w grze)**
- `UseMPAIBaseNodes=yes` w `[Basic]` mapy: AI skirmisha buduje węzły bazy z mapy (`NodeCount`) zamiast planu i wyłącza wstawianie elektrowni oraz „raise money”.

## Produkcja jednostek

- **Zbieracz** (`AI_Unit`): `Get_First_ActLike(HarvesterUnit)` i `Get_First_ActLike(BuildRefinery)`. **Gdy którejś listy nie da się posiadać, Vinifera kończy grę błędem krytycznym** („House %s has no valid refinery building defined”). Dla `GDI2` (Protoss) `BuildRefinery=TDPROC,RAPROC` nie ma nic, więc komputer-Protoss dziś wywraca grę. Zastępczy zbieracz trafia do kolejki **lądowej** (`BuildUnit`), a Probe ma `Naval=yes`, więc nie wyprodukuje go żadna fabryka i kolejka stoi. Pełna kolejka blokuje więcej: hak Vinifery 0x4BD0BC („buduje zbieracza”) pomija wtedy `AI_Infantry`/`AI_Aircraft`, a `_Production_Check` nie woła `AI_Building`. Naprawa: łatka `patch-vinifera-navalai.ps1` ([[mods/protoss-ai]]) kieruje jednostkę `Naval=yes` do `BuildNavalUnit`.
- **Reszta jednostek powstaje tylko dla drużyn:** licznik = członkowie drużyn, które czekają na posiłki (`Reinforce=yes` i niepełne albo jeszcze nie wystartowały), minus jednostki domu, które da się zwerbować. Wybór: najbardziej brakujący typ albo (z prawdopodobieństwem `FillEarliestTeamProbability`) typ najstarszej drużyny. Osobne kolejki: piechota, pojazdy lądowe, pojazdy `Naval` (`AI_Naval_Unit`), samoloty.
- `Raise_Money` i `Fire_Sale` (sprzedaż przy bankructwie) działają tylko w skirmishu bez `UseMPAIBaseNodes`.

## AI-triggery (`[AITriggerTypes]`)

Format (pola po `=`): nazwa, drużyna 1, właściciel (`<all>` albo dom), poziom techniki, warunek (−1 brak, 0 wróg posiada, 1 dom posiada, 2/3 wróg na żółtym/czerwonym prądzie, 4 wróg ma kasę…), obiekt warunku, 32 bajty hex (ilość LE, operator: 0 `<`, 1 `<=`, 2 `==`, 3 `>=`, 4 `>`, 5 `!=`), waga startowa/min/max, skirmish (1), 0, **strona**, obrona bazy, drużyna 2, Easy, Medium, Hard.

- **Strona = `ActLike` domu + 1** (hak Vinifery 0x4109EF). `ActLike` to indeks z `[Houses]` z `ActsLike=`. W `AI.ini` DTA strony 1–4 = GDI/Nod/Allies/Soviet (925 triggerów). `GDI2` (Protoss) ma `ActsLike=8`, więc jego triggery mają stronę **9**. Terran `GDI1` i Zerg `Nod1`: 7 i 8, o ile ich `ActsLike` to własny indeks (**do sprawdzenia**).
- **MCV też rozstawia AI-trigger**: `MCV <strona> Deploy` (warunek: dom nie ma ConYardu, drużyna `MCV_*_DEP`, skrypt `MCV_DEPLOY` = obroty + `11,14` Hunt, „deploy aż się uda”). Strona bez takiego triggera nigdy nie rozstawi bazy.
- Kod mapy (warstwy `INI/Map Code`, scalane przez klienta do mapy) może mieć **własne** `[AITriggerTypes]`, `[TeamTypes]`, `[TaskForces]`, `[ScriptTypes]` i `[Basic] IgnoreGlobalAITriggers=yes|no`. Przykład: `Naval Only AI.ini`.
- **Misje:** 44 mapy DTA mają lokalne AI-triggery, np. `se09.map`: 165 sztuk, właściciel = konkretny dom, warunek −1 (zawsze), wersje E/M/H, drużyny `IsBaseDefense=yes` (`11,10` Area Guard) do obrony i drużyny ataku. Dom ma `IQ=4`, `NodeCount` z węzłami bazy, `IgnoreGlobalAITriggers=yes`.
- **Budynki „tylko dla AI”** w DTA: kopie `X_AI` (`$Inherits=X`, `AIBuildThis=yes`, `BuildLimit=0`, inne wymagania), np. `TWR_AI`, `GSYRD_AI` (komentarz: `AIBuildThis=no` przy stoczni daje crash `0041F57F`).

## Co z tego wynika dla frakcji SC

| Frakcja | Blokada AI w skirmishu |
|---|---|
| Protoss (`GDI2`) | brak rafinerii na `BuildRefinery` (crash), `AIBuildThis=no`, brak AI-triggerów strony 9 (MCV, drużyny), Robotics/Stargate na wodzie, Probe w kolejce lądowej. Zrobione dla Advanced AI w [[mods/protoss-ai]] (listy, `AIBuildThis`, taktyki `House=8`, łatka `patch-vinifera-navalai.ps1`: Probe/MCV do kolejki morskiej, woda tylko dla `WaterBound`); AITriggerów strony 9 brak |
| Zerg (`Nod1`) | budynki z dronów (bez ConYardu) wymagałyby łatki planowania, zob. [[engine/zerg-ai]] |
| Terran (`GDI1`) | zrobione dla Advanced AI: [[mods/terran-ai]] (listy `[AI]`, `AIBuildThis`, taktyki `House=6`); AITriggerów strony 7 brak |

## Uwaga: przy Advanced AI (domyślny checkbox) działa inna ścieżka

Opis wyżej to klasyczne AI. Z Advanced AI (2026-10-30, [[engine/advanced-ai]]): AITriggery są wyłączone dla wszystkich domów komputera, armia powstaje tylko z taktyk z `House=` = indeks domu w `[Houses]` (DTA ma 0–3), bazę planuje `AdvAI_Evaluate_Get_Best_Building` (nie `Make_Base_Nodes`), budynki poza ulepszeniami stawia `BuildingClass_Exit_Object_Custom_Position` (pułapka „`Naval=yes` → woda” dotyczy tylko klasycznego AI), a MCV rozstawia `UnitClass::Mission_Guard` (hak Vinifery: `DeploysInto` na liście `[AI] BuildConst`), bez AITriggera. **(niezweryfikowane w grze)**
