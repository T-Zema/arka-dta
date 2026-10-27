# Mapy StarCrafta: MPQ, CHK, tilesety, przejezdność

Jak odczytać mapę `.scm/.scx` ze StarCraft: Remastered i jej teren (poziomy, przejezdność, kolory) bez narzędzi zewnętrznych.

Źródła: `C:\Program Files (x86)\StarCraft\Maps` (ok. 300 map, m.in. `Maps\ladder\(4)Lost Temple.scm`),
pliki tilesetów z CASC (`TileSet/*.cv5|vf4|vx4ex|vr4|wpe`), kod `Modding/tools/ScMap.cs`. CASC opisuje [[engine/starcraft-assets]].

## Plik mapy

- `.scm`/`.scx` = archiwum **MPQ** (format 0/1). Teren i obiekty są w pliku `staredit\scenario.chk`.
- Tablice hash i block są szyfrowane kluczami `Hash("(hash table)",3)` i `Hash("(block table)",3)`. Pliki są dzielone na sektory
  `512 << shift`. Kompresja w mapach Blizzarda: **PKWARE DCL implode** (maska `0x08`) i zlib (`0x02`). Implementacja:
  `Mpq` + `Explode` (port `blast.c`) w `ScMap.cs`.

## Sekcje CHK (używane)

| Sekcja | Zawartość |
|---|---|
| `DIM ` | szerokość, wysokość w kaflach 32×32 px (Lost Temple 128×128) |
| `ERA ` | tileset: 0 badlands, 1 platform, 2 install, 3 ashworld, 4 jungle, 5 Desert, 6 Ice, 7 Twilight |
| `MTXM` | uint16 na kafel: `grupa = v >> 4`, `podkafel = v & 15` (późniejsze wystąpienia sekcji nadpisują wcześniejsze) |
| `UNIT` | 36 B na obiekt: x, y (piksele, środek), ID, właściciel, surowce. **176–178 minerały** (64×32 px), **188 gejzer** (128×64), **214 start location** |
| `THG2` | sprite'y dekoracji (drzewa, krzaki): ID, x, y, właściciel, flagi |
| `STR `, `SPRP` | napisy; `SPRP` = indeksy nazwy i opisu scenariusza |

## Teren z tilesetu

- `cv5`: 52 B na grupę, od bajtu 20 tablica 16 × uint16 megakafli. `megakafel = cv5[grupa].mega[podkafel]`.
- `vf4`: na megakafel 16 × uint16 flag minikafli 8×8 px: `1` przejezdny, `2` średni poziom, `4` wysoki, `8` zasłania widok.
- `vx4ex` (Remastered): na megakafel 16 × uint32 = `indeks_vr4 << 1 | odbicie`. `vr4`: 64 B pikseli na minikafel. `wpe`: paleta 256 × RGBA.
- Przejezdność SC liczy się na minikaflach (8 px). Flood fill po 8-sąsiedztwie pokazuje, które obszary są połączone po ziemi.

## Folder Maps i nazwy

- Te same mapy leżą w wielu folderach sezonów ladderu (`Maps\ladder\Season 5…11`, `2018Season1`…), np. Fighting Spirit 10×.
  Pipeline scala je po hashu MD5.
- Nazwa w `SPRP` bywa ozdobiona (`| iCCup | Fighting Spirit 1.3`) albo koreańska (CP949, w Windows-1252 wychodzą krzaki),
  więc nazwę mapy DTA lepiej brać z nazwy pliku bez prefiksu `(4)`.

## Mapy kampanii (w CASC)

- Folder `Maps\campaign` instalacji ma tylko Enslavers. Mapy kampanii leżą w **CASC**: `SD/campaign/<Terran|Zerg|Protoss|EXPTerran…>/<Terran01…>/staredit/scenario.chk` (sam CHK, bez MPQ: `New-Object Chk (, $casc.ReadFile(ścieżka))`). Obok są `staredit/wav/*` (głosy odpraw). Kopie `locales/<język>/Assets/campaign/...` nie są zainstalowane lokalnie (`ekey not in index`).
- `MRGN` (20 B na lokację: lewo, góra, prawo, dół w pikselach, uint16 nazwa) daje nazwane lokacje autora, np. w T2: „Abandoned Settlement”, „Infested Building”, „first creep location”. Dobre podpowiedzi, gdzie stawiać obiekty misji.
- Obejrzane (2026-10-26): **T1 Wasteland** 64×64 badlands (Raynor, mała placówka, 23 Zerglingi), **T2 Backwater Station** 64×64 badlands (baza SW, opuszczona osada Terran NW, zainfekowane CC + 5 Creep Colonies NE, 47 Zerglingów, 8 Hydralisków; użyta w [[missions/arka-01-marsara]]), **T3 Desperate Alliance** 96×96 badlands (obrona 30 min, pełna baza Zergów, Mutaliski i Guardiany, kandydat na mapę misji 2 „Ewakuacja”).

## Fighting Spirit (spostrzeżenia)

- 128×128 jungle, dwa poziomy, 4 bazy w rogach, 108 pól minerałów, 14 gejzerów, 84 sprite'y dekoracji, brak neutralnych budynków.
- 4 wąskie, kręte kanały wodne (3–4 kafle) z kamiennymi mostami. Most to przejezdne minikafle nad wodą. W SC wszystko jest
  połączone z ziemi, nie ma wysp.
- Środek: dwie kolumny murów złożonych z kształtów X (nieprzejezdne doodady) i dwie ekspansje między nimi.
- Woda w kanałach ma brązowe brzegi: średni kolor komponentu nie jest „niebieski”, liczy się udział niebieskich minikafli (0,37–0,55).

## Lost Temple (spostrzeżenia)

- Tylko dwa poziomy: nizina i płaskowyże (`2`), brak `4`. Bazy startowe stoją na płaskowyżach z jedną rampą.
- Z ziemi **nie da się dojść** do wysp w rogach (lewy górny, prawy dolny) ani do trzech płaskowyżów nad wodą (lewy środkowy,
  prawy środkowy, dolny środkowy) i małego płaskowyżu w prawym górnym rogu. Wynika to z flood filla po danych `vf4`.
- Krawędzie wody to skaliste urwiska, a nie plaże. Narożne wyspy otacza linia małych skał.
- Środek: ruiny świątyni (nieprzejezdne doodady) i cztery mury w kształcie litery L.
