# Mapy misji z prawdziwego terenu: narzędzia

Jak zbudować mapę DTA (teatr Temperate) ze zrzutu Google Maps, danych OpenStreetMap i wysokości terenu, z klifami, plażami, drogami z kafli, budynkami i waypointami. Pierwsze użycie: Gibraltar ([[missions/arka-00-gibraltar]]). Strona dla sesji, które robią kolejne mapy misji.

Źródła: `Modding/tools/DesignToDta.cs`, `GeoData.cs`, `ScToDta.cs`, `fetch-geodata.ps1`, `build-arka-gibraltar.ps1`, `Map Editor/Editor/Config/ConnectedTileDrawer.ini`, `INI/Art.ini`, sesja 2026-10-26.

## Pliki

| Plik | Co robi |
|---|---|
| `tools/fetch-geodata.ps1` | pobiera OSM (`api.openstreetmap.org/api/0.6/map`, sam dzieli obszar przy limicie 50 tys. węzłów) i kafle DEM Terrarium z15 (S3) do `<Out>\osm\`, `<Out>\dem15\` |
| `tools/GeoData.cs` | `GeoRef` (Web Mercator ↔ piksele zrzutu, dopasowanie do punktów i do linii brzegu), `Osm` (XML, wyszukiwanie po nazwie i tagu, wypełnianie obszarów, łączenie dróg między skrzyżowaniami), `Dem` (wysokość w metrach) |
| `tools/DesignToDta.cs` | `Layer` (raster etykiet w pikselach zrzutu: kolor, wielokąty, linie, koła, głosowanie, odległość od etykiety, krawędź poziomu) i `DesignToDta : ScToDta` (komórki, 2 poziomy płaskowyżu, rampy, plaże, drogi z kafli, budynki, drzewa, mury, ruda, waypointy, kontrole) |
| `tools/ScToDta.cs` | wspólne z konwerterem map SC: łańcuchy klifów A*, klify wodne, woda, LAT, kontrole przejezdności |
| `tools/build-arka-gibraltar.ps1` | **wzór skryptu mapy**: cała geometria jako dane; skopiuj i podmień współrzędne |
| `raw/maps/<miejsce>-google.png`, `raw/maps/<miejsce>-geo/` | surowe dane (tylko do odczytu) |

## Przepis na nową mapę

1. **Zrzut** Google Maps (widok mapy, północ u góry) → `raw/maps/<miejsce>-google.png`. Woda ma jednolity kolor (144, 217, 237), więc z niego bierzemy linię brzegu.
2. **Dane:** `tools\fetch-geodata.ps1 -South … -North … -West … -East … -Out Modding\raw\maps\<miejsce>-geo` (współrzędne z zapasem wokół zrzutu).
3. **Skrypt mapy:** kopia `build-arka-gibraltar.ps1`. Ustaw:
   - punkty kontrolne georeferencji: 4–6 nazw z OSM i piksele ich ikon na zrzucie. Potem `RefineToEdge` dociąga projekcję do linii brzegu (Gibraltar: z 15,7 px do 1,1 px średnio);
   - prostokąt widoczny (`$du0..$dv1`) i rozmiar mapy (`$localW`, `$localH`): jedna komórka ≈ 48 / `ScaleX` px zrzutu;
   - progi wysokości poziomów (`$elev1`, `$elev2`) albo wielokąt ręczny, jeśli terenu nie ma w DEM;
   - poprawki wody (napisy i falochrony na wodzie, wąskie mola), plaże, rampy, rezerwacje, waypointy.
4. `-DesignOnly` → obejrzyj `design_kind/ground/zone/buildings.png` w `%TEMP%\<work>\` (siatka co 20 px z opisem co 100).
5. Pełna budowa (~5–8 min z renderem) → przejrzyj `log.txt`, `waypoints.png`, `rawcoast.png` (czerwone kółka = brzeg bez kawałka brzegu) i wycinki `*_full.png` w natywnej rozdzielczości.
6. Strona wiki mapy (tabela waypointów, trasy, pułapki) + wpis w `log.md`.

## Wariant: teren z mapy kampanii StarCrafta (świat fikcyjny)

Dla miejsc bez prawdziwej geografii (Mar Sara, Antiga, Char…) teren bierze się z mapy kampanii SC. Wzór: `tools/build-arka01-marsara.ps1` ([[missions/arka-01-marsara]]).

1. CHK z CASC: `SD/campaign/Terran/TerranNN/staredit/scenario.chk` ([[engine/starcraft-maps]]). Siatkę kafli z jednostkami i lokacjami `MRGN` wyrysować i wybrać miejsca.
2. Usunąć z `Chk.Units` to, czego konwerter nie powinien zamienić (gejzery = drzewa Tyberium), dopisać minerały tam, gdzie mają być klejnoty.
3. **Zoom:** mapa 64×64 SC to tylko 32×64 komórek. Powiększyć `ScTerrain` (Flags, Rgb, W, H), `Chk.Width/Height` i pozycje jednostek/sprite'ów przed `new ScToDta`.
4. **Teatr:** `Theater "INI\Desert.ini","des"` + `DesertCliffSet`/`DesertWaterCliffSet`, podłoża pustyni podane do `ApplyGround`, po `WriteMap` podmienić `Theater=`. Pustynne zestawy LAT mają ten sam układ co Temperate (kafel bazowy + 16 przejść).
5. Waypointy w kaflach SC → `CellAt(px·zoom)` → najbliższa wolna komórka; dekoracje dopiero po waypointach (z dala od nich), potem `WallFrames`, `WriteMap`.
6. Usunąć „świątynię” konwertera (`DBTMPL` w `Structures`), jeśli coś stało pośrodku mapy.

## Kolejność etapów (ważna)

`Classify` → `Cliffs` (wyższy poziom pierwszy) → `Shores` (klify wodne poza plażami) → `Beaches` → `SettleWater` → `DrownSpecks(40)` → `MarkCoastPieces` → `FillWater` → `DrownRawCoast` → rezerwacje (+ mur do `RoadAvoid`) → `RoadLat` + `FinishRoads` (drogi OSM) → mur, ruda, budynki, drzewa → `SmoothGround` → `ApplyGroundRoads` (LAT z drogami) → `WallFrames` → waypointy → kontrole → `FlushBuildings` → `WriteMap`.

## Pułapki (z Gibraltaru)

**Sieć i PowerShell**
- Overpass API (i lustra) **odrzucają TLS z tego komputera**. API OSM i S3 działają. W PS 5.1 trzeba włączyć TLS 1.2.
- Liczba ujemna jako argument pozycyjny (`F 36.1 -5.35`) trafia do funkcji jako **tekst**. Używaj nazwanych parametrów albo nawiasów `(-5.35)`.
- `@( (P 1,2) <nowa linia> (P 3,4) )` spłaszcza tablice. Każdy element zaczynaj przecinkiem: `,(P 1,2)`.
- `[ordered]@{ 10 = … }`: `$d[10]` to pozycja, nie klucz. Klucze tekstowe.
- Każdy skrypt z `Add-Type` w osobnym `powershell -NoProfile` (inaczej „type already exists”).

**Teren**
- **Plaże:** woda w szablonach Shores ma kod `9` **albo `1`** (płytka, przejezdna). Bez tego łańcuch plaży ucieka w ląd albo się odwraca ([[engine/connected-tiles]]). Plaże są potrzebne do desantu poduszkowców i `LST`, bo klify wodne mają skalne komórki.
- Wąski cypel (< 6 komórek) nie mieści klifów wodnych z obu stron. Wykrywanie grobli (`FindBridges`) jest w mapach projektowanych wyłączone, bo przecinało cypel kanałem.
- Pas lądu między klifem płaskowyżu a morzem: klif (~2 komórki) + brzeg (1–2) + droga = **co najmniej 6 komórek**. Na Gibraltarze ląd w odległości 48 px od wschodniego brzegu zostaje niziną. Ogranicz ten zabieg tylko odległością, nie stałym `x`, bo granica wychodzi prosta jak od linijki.
- Drugi poziom płaskowyżu potrzebuje ok. 2–3 komórek pierwszego poziomu wokół (dwie linie klifów). Odsunięcie 24 px zjadło grań prawie całą, 18 px działa.
- Rampy: punkt z grubsza przy prawdziwej drodze w górę, `NearestEdge` dosuwa go do krawędzi poziomu, a `Disc` (r 13 px ≈ 4 komórki) oznacza komórki bez klifu. Poziom bez rampy jest nieosiągalny i służy jako ozdoba.

**Drogi (Paved Road LAT, od 2026-10-27)**
- **DTA rysuje drogi jako `Paved Road LAT`**, nie kaflami: ciemny asfalt z miękką krawędzią, prosto w osiach izometrii albo pod kątem 45°. Zbadane na se03, se04, reclamation i crc12 (2000–5700 komórek `Clear/Paved Road LAT` na mapę). **Każda droga gdzieś prowadzi:** do innej drogi, za krawędź mapy, na plac lub parking (bruk), do bazy albo na most. Ślepych końców w trawie nie ma.
- Kafle `TemperatePavedRoadASet` (2 komórki, A*) dawały na Gibraltarze rozsypane odcinki. A* nie układał wielu ciągów, a główne drogi OSM urywają się tam, gdzie dochodziła pominięta mniejsza ulica. Recenzja: „drogi do nikąd”.
- Konwerter: `RoadLat(polilinia)` zbiera odcinki (2 komórki szerokości, pędzel 2×2). `FinishRoads(10, 30)` zamyka końce: koniec **stykający się bokiem** z drogą na tym samym poziomie jest OK (styk po skosie wygląda jak przerwa); tak samo koniec przy krawędzi mapy. Pozostałe końce dostają prosty łącznik do najbliższej drogi w promieniu 10. Jeśli się nie da, koniec ląduje na placu (12+ komórek bruku w promieniu 3) albo zostaje przycięty do ostatniego skrzyżowania. Odcinek bez żadnego styku wypada. W logu `free ends` musi wynosić 0; arkusz waypointów zaznacza końce na placach (pomarańczowe kwadraty) i wolne końce (czerwone koła).
- Komórka drogi na klifie, brzegu albo działce przesuwa się do najbliższej dozwolonej w promieniu 2 (`SnapRoad`). Bez tego `Sir Herbert Road` pod Skałą rozpadała się na okruchy, a pas wschodni nie miał drogi.
- LAT: grunt `RoadG = 4`; kafle `Paved Road LAT & addons`, przejścia `Clear/Paved Road LAT`, a przy bruku `Pavement/Paved Road LAT`. Bruk liczy sąsiednią drogę jako swój grunt (`ApplyGroundRoads`). Kod terenu 11, jak bruk: przejezdny i budowlany. Skrypt misji stawia budynki obok.
- Drogi LAT nie są `Used`, więc `Free` wprost wyklucza drogi: budynki, drzewa i ruda ich nie zasłaniają. `SmoothGround` ich nie wygładza.
- Mur (linia nakładki) wpisz do `RoadAvoid` przed drogami. Droga przechodzi tylko przez bramy.
- Z OSM tylko `trunk/primary/secondary` (+ `_link`). Wszystko naraz zapchałoby miasto równoległymi pasami.
**Obiekty**
- Budynki z pokrycia OSM (`FillAreas` → `PlaceOnCover`): w komórce musi być ≥ 40% obrysów, a wokół każdego budynku zostaje pierścień 1 komórki (ulice). Strefę bazy gracza wyłącz (`ReserveZone`).
- Neutralne obiekty z grafiką w Temperate (fundament z Art.ini): wioska `V01–V11` 1×1, `V03` 2×2, `CITY09` magazyn 1×1, `CITY10` 2×2, `NV17` silos, `NV18` szopa, `CA0011` zbiornik 1×2, `CA0008` „jaskinia” 2×2, `CRANE` 1×1, `HANGAR` 2×3, `RUS02A` wieża 1×1, ruiny wież `DBTWR`/`DBATWR` 1×1, `AMMOCRAT`, `STEELCRATE`, `WOODCRATE`, `RABARL` 1×1, `LHUS` latarnia, `WDML` wiatrak, `HOSP` 2×2. `RUS02B` i `BARLO5` nie mają sekcji w Art.ini, nie używać.
- Dom budynków cywilnych: `Neutral` (musi zostać w `[Houses]` misji).

**Misja a teren**
- Skrypt terenu **nadpisuje mapę w całości**. Triggery robi osobna warstwa, która czyta mapę terenu (wzór: `build-arka00-mission.ps1`, [[missions/arka-00-triggers]]).
- **Każda misja ARKA** dołącza `tools/MissionKit.ps1` (`. "$tools\MissionKit.ps1"` po definicji `Trigger`) i ma:
  - `Add-RevealCrate x y`: skrzynkę z odkryciem mapy obok bazy gracza (życzenie użytkownika). Komórkę trzeba zająć (`Find-Spot` + `Occupy`) **przed** rozstawieniem jednostek;
  - `Split-MultiText; Set-DialoguePacing` przed zapisem triggerów i `Test-TextTimeline` z wynikiem 0 WARN ([[engine/triggers-and-dialogue]], „Tempo dialogów”);
  - złoża, łupy (`Add-MoneyCrate`) i powtarzane rajdy na gospodarkę według [[workflow/mission-design]] (recenzja 2026-10-27).
- Złoża w skrypcie terenu: wielokąt albo koło w `Layer` + `CellsIn(layer, wartość, poziom)` (ruda na płaskowyżu nie spływa po klifie do miasta), kopalnia `OREMINE` jako obiekt `[Terrain]` na pierwszej wolnej komórce (`Free`).
- Numery waypointów to kontrakt między warstwami. Pozycje mogą się przesunąć o 1–2 komórki po przebudowie, numery nigdy.
- `HomeCell` to numer waypointu (konwerter wpisuje 98, ustaw w misji).
