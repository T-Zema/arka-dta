# Mapa: The Lost Temple (StarCraft) w DTA

Mapa StarCrafta **(4)Lost Temple** przeniesiona automatycznie na silnik DTA jako mapa skirmisha dla 2–4 graczy.
Stan: zainstalowana, zarchiwizowana, **działa w grze** (test użytkownika 2026-10-24 19:22: wczytanie, ok. 3 min gry
vs AI, normalne wyjście, 42 FPS; `Debug/DEBUG_24-10-2026_19-22-12.LOG`). Wcześniejszy crash o 19:17 to wina moda
frakcji Terran (zob. [[mods/terran-faction]]), a nie mapy: mapa wczytała się, a gra padła przy jednostkach startowych domu `GDI1`.
O 19:28 mapę wygenerowano ponownie ulepszonym konwerterem (cienkie mury ze szkieletu, poprawki wody). Tej wersji nie testowano,
ale format pliku jest ten sam.

Źródła: `C:\Program Files (x86)\StarCraft\Maps\ladder\(4)Lost Temple.scm`, tileset jungle z CASC, `INI/Temperat.ini`,
`Map Editor/Editor/Config/ConnectedTileDrawer.ini`, korpus map DTA. Narzędzia: `Modding/tools/convert-scmap.ps1`, `ScToDta.cs`.

## Pliki

- `Maps/Custom/sc_lost_temple.map` (300 KB) i `Maps/Custom/sc_lost_temple.png` (podgląd 800×819).
- **Poprawka 2026-10-25 (podgląd w lobby był czarny):** klient nie czyta PNG dla map z `Maps/Custom`, tylko `[PreviewPack]`
  z mapy (zob. [[engine/map-format]]). Do `sc_lost_temple.map` i `sc_fighting_spirit.map` dopisane `[Preview]` + `[PreviewPack]`
  (PNG zmniejszony do 400×410). Kopie: `*.map.bak`. Od 2026-10-25 `convert-scmap.ps1` (więc i `port-scmap.ps1`) dopisuje
  `[Preview]`/`[PreviewPack]` sam (`MapPreview.Set` w `TsMap.cs`, 400 px). Archiwa obu map zawierają już wersje z podglądem.
- W kliencie: Skirmish → tryb **Custom Map** → „The Lost Temple (StarCraft)”. Gra nie wymaga żadnej zmiany Rules/Art.
- Odinstalowanie: usunąć oba pliki. Archiwum: `archive/sc-lost-temple_2026-10-24/`.

## Jak przeniesiono teren

| StarCraft | DTA |
|---|---|
| mapa 128×128 kafli (4096 px) | `Size=0,0,68,137`, `LocalSize=2,5,64,128`; 1 px SC = 0,75 px DTA, więc 1 kafel SC ≈ 1 komórka i izometryczne ukosy SC zostają ukosami |
| płaskowyż (poziom 2) | ziemia (Dirt LAT), zielone łaty → trawa; ogrodzony klifami `Cliffs` (teren DTA jest płaski) |
| nizina | trawa (Clear), łaty dżungli → Tall Grass LAT |
| rampa | przerwa w klifie; rampę uznaje się tylko tam, gdzie w SC da się przejść po minikaflach między dwiema komórkami |
| woda | animowana woda (szablony do 10×10) + **Water Cliffs** wzdłuż brzegu (w SC brzegi to skaliste urwiska) |
| minerały (104 pola) | **niebieskie klejnoty** `BLUGEM01–04`, etap 9–11, ok. 3,7 komórki na pole (385 komórek) |
| gejzery (10) | `TIBTREE` + plama zielonego tyberium (`RTIB`) wokół |
| start locations (4) | `[Waypoints] 0–3` |
| ruiny świątyni w środku | `DBTMPL` (Ruined Temple of Nod, Neutral, 2×2, 10 000 HP) |
| mury świątyni (4 × L) | mur betonowy `BRIK`, linia grubości 1, klatki wg maski sąsiadów |
| linie skał wokół wysp | kafle `Small Rocks` 1×1 |
| drobne doodady i sprite'y drzew | drzewa `T01–T17`, krzaki `JBR01–05` |

Szczegóły formatu: [[engine/map-format]]. Układanie klifów: [[engine/connected-tiles]]. Odczyt SC: [[engine/starcraft-maps]].

## Kontrole (2026-10-24)

- Wszystkie 4 starty połączone po ziemi. Klejnoty osiągalne: 323/385, a brakujące 62 leżą na wyspach w rogach (jak w SC).
- Porównanie z przejezdnością SC (flood fill z pierwszego startu): ok. 40 komórek „przecieku” i 9 „zamknięcia”,
  pojedyncze komórki na krawędziach klifów. Płaskowyże niedostępne w SC są niedostępne także tu.
- Zestaw komórek IsoMapPack5 = pełny prostokąt, jak w mapach z edytora.
- Niezweryfikowane w grze: działanie AI na dłuższą metę, ekonomia klejnotów.

## Regeneracja

`Modding\tools\port-scmap.ps1 -Map "Lost Temple"` (zob. [[workflow/scmap-pipeline]]: kontrole, arkusz `review.png`,
ograniczenia konwertera).
