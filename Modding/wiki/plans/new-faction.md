# Plan: piąta grywalna frakcja (np. Terranie) obok GDI/Nod/Allies/Soviet

Da się to zrobić bez ruszania `Rules.ini` i bez psucia kampanii. Najlepiej w skirmishu **przejąć dom pomocniczy `GDI1` (indeks 6)**, nieużywany na 200 z 201 map skirmisha, i zrobić z niego frakcję. Dokument: architektura, etap 0 (PoC gotowy do instalacji), dalsze etapy, ryzyka.

Źródła: [[engine/sides-and-houses]] (wszystkie fakty o indeksach, MIX-ach, kliencie i AI), [[engine/ini-layering]],
[[engine/client-lobby-options]], [[plans/starcraft-factions]], szkic `Modding/drafts/new-faction-poc/`, rozmowa
z 2026-10-24 (użytkownik: „dodać kompletnie nową frakcję obok tych, co są”; równolegle sesja „Marines” robi jednostki SC).

## Kluczowy problem i decyzja

Klient zapisuje `Side=<pozycja w dropdownie>`, a silnik czyta to jako indeks w `[Houses]`. Pozycja 4 to dziś **Neutral**.

| Wariant | Jak | Plusy | Minusy |
|---|---|---|---|
| **A′: przejęty dom pomocniczy** (zalecany) | Plik doklejany tylko do skirmisha (`MapCodeININame` trybu Deathmatch) przerabia dom `GDI1` (indeks 6) na frakcję: `Name=Terran`, `Side=TerranSide`, `Multiplay=yes`, `ActsLike=6`, oraz poprawia `Owner=`. Lista `Sides=` w kliencie ma 7 pozycji, z czego 4 (Neutral) i 5 (Special) są zablokowane. | `Rules.ini` nietknięty, kampanie i co-op działają. Dom istnieje od startu silnika, więc **nie ma ryzyka R1**. Tylko 2 wyszarzone pozycje. Kolejne frakcje mogą przejąć `Nod1` (7), `GDI2` (8)… i nadal będą tylko 2 wyszarzone pozycje. | W INI-ach frakcja nazywa się `GDI1` (np. `Owner=…,GDI1`), a tylko w grze i lobby wyświetla się „Terran”. Mapa `seabound_highway` definiuje domy pomocnicze, trzeba ją zablokować dla tej frakcji. |
| A: nowy dom tylko w skirmishu | Nowy dom `Terran` w pliku doklejanym do skirmisha, w skirmishu dostaje indeks **14**. `Sides=` ma 15 pozycji, 4–13 zablokowane. | czysta nazwa `Terran` w INI | 10 wyszarzonych pozycji, ryzyko R1 (dom powstaje dopiero z pliku mapy) |
| B: dom w `Rules.ini` | Dopisać dom (i stronę) do Rules | Dom istnieje od startu | Psuje triggery **122 map** (misje/co-op mają własne domy od indeksu 14). Trzeba by przełączać „profil frakcji” przed kampanią. |

Dlaczego `GDI1`: domy pomocnicze 6–13 są w Rules+Enhance właścicielami tylko 3–6 typów (`GDI1`: `TDPROC`, `TDPROC_AI`,
`TDHARV`, `DEPCARR`, `TRAN`, a w trybie Enhanced także `GHPAD` i `TRANV`). `AI.ini` w ogóle ich nie używa (TeamTypes mają tylko
`House=GDI/Nod/Allies/Soviet`), a na mapach skirmisha występują tylko w `seabound_highway`. `Special` (indeks 5) odpada,
bo używa go 35 map skirmisha. `GDI1` ma najniższy wolny indeks, więc wyszarzonych pozycji jest najmniej.

## Z czego składa się „kompletna” frakcja

| # | Element | Gdzie | Kto |
|---|---|---|---|
| 1 | Dom `GDI1` → „Terran” + strona `TerranSide` (kolory UI, `Crew`, elektrownie) | `INI/Map Code/Terran Faction.ini` | ta sesja |
| 2 | Pozycja w dropdownie, ikona `terranicon.png`, ekrany ładowania `l600s6{1,2}.pcx` / `l480s6{1,2}.pcx` | `Resources/GameOptions.ini`, `Resources/` | ta sesja |
| 3 | Blokada pozycji 4–5 (wszędzie) i 6 (tryby bez pliku frakcji, co-op, mapa `seabound_highway`) | `INI/MPMaps.ini` | ta sesja |
| 4 | Sidebar, paleta, ekran wyniku, grafiki harv/proc + cameo wspólne | `MIX/SideC07.mix`, `MIX/sidenc07.mix` (strona 6 → plik 07) | ta sesja; writer `[Mix]::Write` z `Modding/tools/ModTools.cs` (sesja Marines), lister `Modding/tools/mixlist.ps1` |
| 5 | EVA | `MIX/Speech07.mix` (`00-iNNN.aud`) | ta sesja; WAV→AUD `[Aud]::Encode` z `ModTools.cs` |
| 6 | Drzewko technologii: ConYard, MCV, elektrownia, rafineria + zbieracz, koszary, fabryka, radar, tech, obrona, supermoc | plik frakcji (`[General] BaseUnit/HarvesterUnit`, `[AI] Build*`, własna grupa w `[PrerequisiteGroups]`) | ta sesja |
| 7 | Jednostki SC (Marine itd.): grafika, dźwięk, Art.ini | `Art.ini`, `Sound.ini`, `Game Options/StarCraft.ini` (checkbox `chkStarCraft`), `MIX/ECACHE77.MIX` (dawniej 99) | **sesja Marines** (zob. [[mods/starcraft-marine]]). Frakcja tylko dopisuje się do `Owner=` typów `SCMARINE*` (jako `GDI1`, robi to sesja Marines w swoim pliku). Marine to technicznie `UnitType` (deploy = `TransformsInto`), więc buduje się w War Factory. |
| 8 | AI | Advanced AI (domyślnie włączone) powinno grać samo z list `[AI]`. Klasyczne AI wymaga własnych `[AITriggerTypes]` z polem Side = **7**. | ta sesja |
| 9 | Muzyka, ekran wyniku, nazwy | opcjonalnie | później |

## Etap 0: PoC (zainstalowany 2026-10-24 jako [[mods/terran-faction]], czeka na test)

Cel: sprawdzić samą „hydraulikę” na frakcji będącej klonem Aliantów, zanim dojdą grafiki SC.

Szkic (wariant A′): `Modding/drafts/new-faction-poc/INI/Map Code/Terran Faction.ini`. Zawiera
`[Sides] TerranSide=GDI1`, `[TerranSide]` (jak Allies), `[GDI1]` (`Name=Terran`, `ActsLike=6`, `Multiplay=yes`,
`Side=TerranSide`, `Color=AlliedBlue`), `Owner=<oryginał>,GDI1` dla **113 typów** z `Allies` w `Owner=` oraz zdjęty
`GDI1` z `TDPROC`, `TDPROC_AI`, `DEPCARR` i `GHPAD` (`TDHARV` zostaje, bo to harvester rafinerii `SCREFI`). Plik jest
wygenerowany z **Rules.ini + Enhance.ini** (zob. [[engine/sides-and-houses]]). Dzięki temu `AMCV` (z `BaseUnit`),
`RAHARV` i budynki z list `[AI]` działają bez dalszych zmian.

Instalacja (kopie `.bak` przed edycją):
1. Skopiować szkic do `INI/Map Code/Terran Faction.ini`.
2. `Resources/GameOptions.ini`: `Sides=GDI,Nod,Allies,Soviet,Neutral,Special,Terran`.
3. `INI/MPMaps.ini`: w `[Default]` dodać `MapCodeININame=Terran Faction.ini` i `DisallowedPlayerSides=4,5`.
   To samo w nowej sekcji `[Custom Map]` (tryb map z `Maps/Custom`; brak tej sekcji spowodował crash w teście 1, zob. [[mods/terran-faction]]).
   W pozostałych trybach `DisallowedPlayerSides=4,5,6`, a dla mapy `seabound_highway` `DisallowedPlayerSides=4,5,6`.
4. Kopie: `MIX/SideC03.mix` → `SideC07.mix`, `sidenc03.mix` → `sidenc07.mix`, `Speech03.mix` → `Speech07.mix`,
   `alliesicon.png` → `terranicon.png`, `l600s2{1,2}.pcx` → `l600s6{1,2}.pcx`, `l480s2{1,2}.pcx` → `l480s6{1,2}.pcx`.

Test w grze (Deathmatch, skirmish, Advanced AI włączone):
- **T1** gracz = Terran, AI = Allies. W `Debug/*.LOG` widać `Side 6: TerranSide` z domem `GDI1` pod spodem oraz
  `Initializing SIDEC07.MIX` przy drugim `Prep_For_Side()` (pierwsze, przed mapą, może jeszcze załadować `SIDEC01` GDI).
  Jeśli zostaje sidebar GDI, Vinifera nie przeładowuje MIX-ów po zmianie strony domu w mapie i trzeba to obejść.
- **T2** MCV się rozkłada, pasek budowy pokazuje drzewko Aliantów, kolor i sidebar są OK.
- **T3** AI = Terran: buduje bazę i atakuje.
- **T4** dropdown: pozycje Neutral i Special wyszarzone, „Random” ich nie wylosuje (inaczej trzeba dodać `[RandomSelectors]`).
- **T5** misja z kampanii (np. Frostbite) działa jak dawniej. To formalność, bo Rules się nie zmienia.
- **T6** zwykła gra GDI vs AI GDI w Deathmatchu: GDI dalej buduje helipad i transportowce (zdjęcie `GDI1` z `GHPAD` nie szkodzi domowi `GDI`).

Odinstalowanie: przywrócić `GameOptions.ini.bak` i `MPMaps.ini.bak`, usunąć skopiowane pliki.

## Etapy dalsze

1. **Tożsamość:** nazwa, kolor domu (nowy wpis w color schemes albo istniejący), kolory UI strony, ikona, ekrany ładowania.
2. **Własne budynki bazowe** z prefiksem `SC` (np. `SCCC` Command Center = ConYard, `SCSCV` = MCV/zbieracz,
   `SCSUPPLY` = elektrownia, `SCREF` = rafineria, `SCBARR`, `SCFACT`…). Najpierw na grafikach pożyczonych przez
   `Image=`, potem na grafikach ze StarCrafta od sesji Marines. Przepis: [[engine/adding-new-types]].
   Uwaga: `$Inherits` z Rules nie działa w pliku mapy, trzeba wypisać pełne sekcje. Każdy nowy typ potrzebuje
   `ScrapExplosion=` obok `Explosion=`, bo przy opcji „Scrap Debris” (domyślnie włączonej) Vinifera podmienia jedno na drugie.
   Nowe animacje trzeba też zarejestrować w `Rules.ini [Animations]` (zob. [[engine/adding-new-types]], [[engine/shp-graphics]]).
   **Stan 2026-10-24:** 14 budynków Terran z grafiką SC już jest (sesja budynków Terran, [[mods/starcraft-terran-buildings]]):
   `SCCC` (ConYard), `SCDEPO`, `SCREFI`, `SCBARR`, `SCEBAY`, `SCMTUR`, `SCACAD`, `SCBUNK`, `SCFACT`, `SCSTAR`, `SCSCIF`,
   `SCARMO`, `SCCOMS`, `SCNUKE` w bloku na końcu `Game Options/StarCraft.ini`, grafiki w `MIX/ECACHE98.MIX`.
   Dla frakcji wystarczy: dopisać `GDI1` (w wariancie A′; w wariancie A `Terran`) do `Owner=` tych 14 sekcji (wszystkie mają tę samą listę),
   MCV z `DeploysInto=SCCC`, `[General] BaseUnit`/`HarvesterUnit` i `[AI] BuildConst=…,SCCC` itd. w pliku frakcji.
   Uwaga na kolejność doklejania: blok budynków nadpisuje `[General] Prerequisite{Barracks,Factory,Radar,Tech}`.
3. **Odpięcie od Aliantów:** usunąć generowane `Owner=…,GDI1`, zostawić tylko typy SC i wspólne (mury, cywilne).
4. **Sidebar i EVA:** `[Mix]::Write` (ModTools.cs) → `SideC07.mix` z własnymi `side1-3.shp`, `tabs.shp`, `radar.shp`, `sidebar.pal` itd.,
   `Speech07.mix` z głosem adiutanta SC (konwersja do AUD).
5. **AI:** sprawdzić Advanced AI. Ewentualnie dopisać `[AITriggerTypes]` (Side=7) i TeamTypes w pliku frakcji.
6. **Archiwum** jak [[mods/super-mod-v1]].

## Ryzyka

- **R7 (A′):** DTA używa domów pomocniczych jako obejścia dla AI (komentarz w `Enhance.ini`: „the AI won't build it if it
  doesn't have GDI1 specified as an additional owner”, plus `GHPAD`/`TRANV` z `GDI1`). W skirmishu AI to dom `GDI`, nie `GDI1`,
  więc zdjęcie `GDI1` nie powinno szkodzić **(niezweryfikowane, test T6)**.
- **R1 (dotyczy tylko wariantu A):** spawner ładuje MIX-y strony **przed** wczytaniem mapy (`[Spawner] Start_Game: Failed to load side MIXes!`
  istnieje w Vinifera.dll), czyli zanim dom 14 powstanie z pliku frakcji. Jeśli sięga wtedy do `HouseTypes[14]`,
  gra może się wywalić **(niezweryfikowane w grze)**. Po wczytaniu scenariusza Vinifera robi `Prep_For_Side()` drugi raz.
  Analogia potwierdzona w grze: animacje dodane tylko w opcji gry nie mają SHP, bo obrazy ładują się w `Initializing Theater`,
  przed `Rule->Addition()` (zob. [[engine/shp-graphics]]). To, co powstaje z pliku doklejanego do mapy, omija wczesną inicjalizację.
- **R6:** budynki Terran od sesji budynków mają `AIBuildThis=no`. Żeby AI-Terran budowało bazę SC, plik frakcji musi
  nadpisać ten klucz i dopisać budynki do list `[AI] Build*`.
- **R2:** `DisallowedPlayerSides` per tryb gry. W `MPMaps.ini` udokumentowane tylko per mapa **(niezweryfikowane)**.
  Jeśli nie działa: blokada per mapa (dużo wpisów) albo pogodzić się z możliwością wyboru złej pozycji.
- **R3:** aktualizacja klienta może nadpisać `GameOptions.ini` i `MPMaps.ini`, trzeba wtedy ponowić instalację (stąd archiwum).
- **R4:** gra online z innymi jest wykluczona (inne pliki klienta). Użytkownik gra prywatnie.
- **R5:** opcje gry doklejane później (np. `Advanced AI.ini` nadpisuje `[AI] BuildTech=`) mogą wyzerować listy frakcji.
  Listy w pliku frakcji powinny zawierać też wartości z Advanced AI.

## Pytania do użytkownika

1. Jaka frakcja i nazwa: Terranie (pasuje do marines z sesji Marines), Protossi, Zergowie, a może coś własnego?
2. Czy jednostki SC mają być **wyłącznie** dla nowej frakcji, czy też dla czterech starych (jak robi to teraz sesja Marines)?
3. Czy zgoda na instalację PoC (zmiana `GameOptions.ini` i `MPMaps.ini` z kopiami `.bak`) i test T1–T5 w grze?
