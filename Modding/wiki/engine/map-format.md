# Format pliku mapy (.map) i kafle teatru

Jak zbudowany jest plik mapy TS/DTA od strony terenu i overlay: geometria, pakowanie, kafle TMP, LAT, mury, mapy własne.

Źródła: `Maps/**/*.map` (korpus 270 map Temperate, statystyki z 2026-10-24), `INI/Temperat.ini`, `MIX/IsoTemp.mix`,
renderer `Map Editor/Map Renderer/CNCMaps.Renderer.exe`, `INI/MPMaps.ini` (`[GameModeAliases]`), `Resources/ClientDefinitions.ini`,
kod `Modding/tools/TsMap.cs` (dekodery i enkodery sprawdzone round-tripem).

## Geometria

- `[Map] Size=0,0,W,H`: W kolumn po 48 px, H wierszy po 24 px ekranu. Komórka `(x,y)`: `dx = x − y + W − 1`, `dy = x + y − W − 1`,
  lewy górny róg rombu na ekranie `(dx·24, dy·12)`. `+x` = w prawo-dół, `+y` = w lewo-dół, `−y` (N) = w prawo-górę.
- Ważne komórki: `dx ∈ [0, 2W−2]`, `dy ∈ [0, 2H−1]`, parzystość `dx+dy` parzysta. Edytory zapisują **pełny prostokąt**,
  czyli `(2W−1)·H` rekordów (sprawdzone na tiber, alpine_assault, red_mountain, hardpoints).
- `LocalSize=X,Y,w,h` to widoczny obszar w tych samych jednostkach (48 × 24 px). Mapy DTA mają zwykle Y = 4–6.
  Renderer CNCMaps dokleja na dole 3 wiersze (`MapLocalSizeBottomCropValue` w `modconfig.xml`).
- Numer komórki w `[Waypoints]` i jako klucz `[Terrain]` = **`y*1000 + x`** (sprawdzone na drzewach w Crossroads).
  `[Structures]`: `Dom,TYP,HP,X,Y,kierunek,...` (17 pól).
- Teren DTA jest **płaski**: `Temperat.ini [General]` ma `CliffSet=1`, `HeightBase=1`, `RampBase=1` (wyłączone).
  Wszystkie komórki w mapach mają `Level=0`. Klify to zwykłe kafle z nieprzejezdnymi komórkami w stylu RA1
  (zob. [[engine/connected-tiles]]).

## Pakowanie sekcji

- Sekcje `[IsoMapPack5]`, `[OverlayPack]`, `[OverlayDataPack]`: base64 w liniach `1=`, `2=`… (po 70 znaków), po zdekodowaniu
  ciąg porcji `[uint16 skompresowane][uint16 rozpakowane][dane]`.
- **IsoMapPack5** = porcje **LZO1X**; rekord 11 B: `uint16 x, uint16 y, int32 tile, byte subtile, byte level, byte ice`.
  Gra przyjmuje też strumień LZO z samych literałów (`TsMap.cs Lzo.CompressLiteral`, poprawne LZO1X bez kompresji).
- **OverlayPack / OverlayDataPack** = porcje **Format80 (LCW)**, każda tablica ma 512×512 bajtów, indeks **`y*512 + x`**,
  `0xFF` = brak overlay. Enkoder `Format80.Compress` (wypełnienia `0xFE` + bloki literałów).
- Mapy z `Maps/Default` często nie mają `[PreviewPack]`, bo podgląd to PNG obok mapy.
- **Mapy z `Maps/Custom` muszą mieć `[PreviewPack]`.** Klient DTA (stara wersja XNA) czyta PNG obok mapy tylko dla map z
  `MPMaps.ini`. Dla map własnych od razu woła `MapPreviewExtractor`, a bez sekcji podgląd jest **czarny**
  (`client.log`: `no [PreviewPack] exists, unable to extract preview`; zgłoszenie użytkownika 2026-10-25).
  Format: `[Preview] Size=0,0,W,H` + `[PreviewPack]` = porcje **LZO** (jak IsoMapPack5) z pikselami **RGB** 24-bit, W×H×3 bajtów.
  Zapis: `Pack.PackData(rgb, true, 8192)` + `Pack.ToIniLines` z `TsMap.cs`. 400×410 daje ok. 660 KB base64.
  Gotowe funkcje: `MapPreview.Set(ini, obraz, 400)` (skalowanie, BGR → RGB, pakowanie) i `MapPreview.Get(ini)` (odczyt do kontroli),
  używane przez `convert-scmap.ps1 -Preview`.

## Indeks kafla i pliki TMP

- `tile` = suma `TilesInSet` wszystkich wcześniejszych `[TileSetNNNN]` w `Temperat.ini` + numer w zestawie.
  Liczy się `TilesInSet`, nawet gdy plików brak (np. `Water` ma `TilesInSet=40`, a istnieje tylko `w01.tem`).
- Plik kafla: `FileName` + numer `01…` + `.tem` (Temperate, w `IsoTemp.mix`). Klasa `Theater` w `TsMap.cs`.
- TMP: nagłówek `int32 szer, wys (w komórkach), 48, 24`, tabela offsetów komórek (0 = brak), nagłówek komórki 52 B:
  `x, y, extraOff, zOff, extraZOff, extraX, extraY, extraW, extraH, flagi, byte height, byte terrain, byte ramp, RGB radar ×2, pad`.
  Romb 48×24 to 576 bajtów, wiersze o szerokości 4, 8, … 48, 44, … 4.
- **Kod terenu komórki**: `0` przejezdne, `7`/`8` skała (nieprzejezdne), `9` woda, `1`/`2`/`A` plaże i przejścia (przejezdne).
- Przydatne indeksy w Temperate: Clear `0`, Dirt LAT `1007` (+ Clear/Dirt LAT `1008`), Tall Grass `1032` (+ LAT `1047`),
  Pavement LAT `1955` (+ `1956`), Water `334` (1×1), Animated Water `374–387` (2×2 … 10×10; w mapach dominuje 10×10 = `383`),
  Small Rocks `1076–1081` (1×1 skała: `1076`, `1079`), Cliffs `1183+`, Shores `1282+`, Water Cliffs `1777+`.

## LAT (automatyczne przejścia podłoża)

Gra nie liczy LAT sama, robi to edytor przy zapisie. Reguła potwierdzona na 270 mapach (Clear/Dirt i Tall/Short Grass):
dla komórki podłoża G maska `bit0 = N (x,y−1)`, `bit1 = E (x+1,y)`, `bit2 = S (x,y+1)`, `bit3 = W (x−1,y)` ustawia bit,
gdy sąsiad **nie** jest G. Maska 0 → kafel bazowy (np. `1007`), inaczej `latStart + maska` (np. `1008 + maska`).

## Overlay

- Ważne ID z `[OverlayTypes]`: `2` BRIK (mur betonowy), `8`/`9` JGRASS/JFERN, `27–30` GRNGEM, `31–34` BLUGEM, `35–38` MIXGEM,
  `102–113` RTIB (zielone tyberium), `127–138` QTIB (niebieskie), `147–150` ZORE (ruda), `180` IMOV (niewidzialna przeszkoda).
- Surowce: `OverlayData` = etap 0–11 (mapy używają zwykle 3–11). Gems: `Value=60`, bez wzrostu (`[Gems]`, `[BlueGems]`).
- **Mury**: `OverlayData` = maska sąsiadów tego samego muru `N=1, E=2, S=4, W=8` (kierunki komórkowe jak wyżej);
  `+16` i `+32` to klatki uszkodzone. Potwierdzone na 10 119 komórkach BRIK w 371 mapach.

## Mapy własne w kliencie

- Plik `.map` do `Maps/Custom/`, w kliencie tryb **Custom Map**. `[Basic] GameMode=standard` mapuje się na „Custom Map”
  przez `MPMaps.ini [GameModeAliases]`. Potrzebne: `Name`, `Author`, `MaxPlayer`, `MinPlayer`, `MultiplayerOnly=1`, `[Waypoints] 0..n`.
- Od 2026-10-24 tryb „Custom Map” ma w `MPMaps.ini` własną sekcję `[Custom Map]` (kod mapy frakcji Terran,
  `DisallowedPlayerSides`), zob. [[mods/terran-faction]]. Dotyczy wszystkich map z `Maps/Custom`.
- Podgląd: PNG o tej samej nazwie obok mapy. Mapy DTA mają 800 px szerokości, **bez znaczników startu** (rysuje je klient),
  obszar = `LocalSize` jak w rendererze CNCMaps.
- Renderer: `CNCMaps.Renderer.exe -i mapa.map -o nazwa -d katalog -p -T -m "..\..\MIX" -M modconfig.xml [--mark-start-pos -s]`
  (uruchamiać z katalogu renderera). Opcja `-r` (podbicie rudy) **wywala się** na typach surowców DTA. `-z` (miniatura)
  nic nie zapisała, więc miniaturę skaluje się samemu.
