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

- **Numery folderów Terran ≠ numery misji w grze** (sprawdzone 2026-10-27 po `SPRP`): `Terran06` Norad II, `Terran07` „Biting the Bullet” (niewydana, Antiga), `Terran08` The Trump Card, `Terran09` The Big Push (platform, Tarsonis), `Terran10` „Operation Silent Scream” (jungle, Tarsonis: 3 psi-nadajniki na `Beacon 1–3`, miasta Delta/Nova/Omega z cywilami, użyta w [[missions/arka-05-tarsonis]]), `Terran11` New Gettysburg, `Terran12` The Hammer Falls (platform). `Terran13` nie istnieje. Nazwę i opis mapy daje `SPRP` (nr napisu w `STR `), lokacje `MRGN` (20 bajtów: prostokąt + nr napisu).
- Folder `Maps\campaign` instalacji ma tylko Enslavers. Mapy kampanii leżą w **CASC**: `SD/campaign/<Terran|Zerg|Protoss|EXPTerran…>/<Terran01…>/staredit/scenario.chk` (sam CHK, bez MPQ: `New-Object Chk (, $casc.ReadFile(ścieżka))`). Obok są `staredit/wav/*` (głosy odpraw). Kopie `locales/<język>/Assets/campaign/...` nie są zainstalowane lokalnie (`ekey not in index`).
- `MRGN` (20 B na lokację: lewo, góra, prawo, dół w pikselach, uint16 nazwa) daje nazwane lokacje autora, np. w T2: „Abandoned Settlement”, „Infested Building”, „first creep location”. Dobre podpowiedzi, gdzie stawiać obiekty misji.
- Obejrzane (2026-10-26): **T1 Wasteland** 64×64 badlands (Raynor, mała placówka, 23 Zerglingi), **T2 Backwater Station** 64×64 badlands (baza SW, opuszczona osada Terran NW, zainfekowane CC + 5 Creep Colonies NE, 47 Zerglingów, 8 Hydralisków; użyta w [[missions/arka-01-marsara]]), **T3 Desperate Alliance** 96×96 badlands (obrona 30 min, pełna baza Zergów, Mutaliski i Guardiany, kandydat na mapę misji 2 „Ewakuacja”).

## Brzegi i przesmyki w konwerterze (ScToDta, poprawka 2026-10-30)

Zgłoszenie użytkownika (zrzuty z misji 3, 6 i 7): w jeziorach stały brukowane krzyże i gołe kwadraty ziemi, a łańcuch klifów brzegowych urywał się na nich.

- **Przyczyna:** `FindBridges` uznawał za most każde pole lądu, które w oknie 7×7 widzi dwa kawałki wody. Tak samo wygląda zatoczka z zakrzywionym brzegiem. Takie pola były brukowane (`Pave`) i wyłączone z brzegów (`Shores` zwraca dla nich klasę 0), więc ląd stykał się z wodą gołą krawędzią rombu. To samo działo się na prawdziwych wąskich przesmykach i na sztucznych groblach z 3–4 kafli.
- **`PruneBridges`** (koniec `FindBridges`): grupa pól-mostów, której końce lądu łączą się po lądzie w promieniu 12 pól, to zatoczka, więc znacznik mostu znika. Przesmyk, który naprawdę łączy dwa lądy, zostaje **poszerzony** o `WidenBridges` pól (domyślnie 2, woda → nizina) i dostaje brzegi jak każdy ląd. W środku zostaje przejezdny. `WidenBridges = 0` (przed `Classify()`) przywraca stare brukowane mosty.
- **`RepairCoast`** (koniec `SettleWater`, bez nowego wywołania): drugi przebieg łańcuchów brzegu tym samym zestawem co ostatnie `Shores` (bez predykatu `land`), na całym wybrzeżu bez elementów: łuki krótsze niż 4 pola, końce łuków przy klifach płaskowyżów, nieudane łańcuchy. Potem pojedyncze cyple (ląd z 3 stronami surowej wody) i zatoczki (woda z 3 stronami lądu) są przestawiane i drugi przebieg idzie jeszcze raz. W logu: `coast repair: raw coast edges A -> B`. `RawCoast()` liczy krawędzie ląd/woda bez elementu.
- **Końce jezior** (zgłoszenie sesji misji 7, ten sam dzień): łańcuchy obu brzegów wąskiego jeziora kończą się obok siebie i zostaje szczelina, czyli goły ląd przy zwykłej wodzie albo przy wodnej części elementu. `TipSeams()` znajduje takie miejsca. `RepairCoast` próbuje każde osobno: zdejmuje elementy brzegu w promieniu 3 pól, zasypuje wąski koniec wody (woda z 3 stronami lądu → nizina) i układa brzeg od nowa. Zmiana zostaje tylko wtedy, gdy szwów i surowych krawędzi w promieniu 8 pól jest mniej; w przeciwnym razie stan mapy wraca w całości. Pierwsza wersja bez cofania pogarszała wynik (szwy 7 → 20), bo nowy łańcuch nie zawsze trafia w gniazda sąsiadów. W logu: `chain-end seams A -> B (n fixed, m tried and put back …)`. ARKA 3: 7 → 3.
- **Runda 3 (zrzuty użytkownika z ARKA 3: stawy i koniec ramienia jeziora przy bazie):**
  - **Małe i wąskie wody znikają.** Zamknięta woda (nie przy krawędzi mapy) mniejsza niż `MinWaterBody` (domyślnie 60 pól) staje się lądem. To samo dotyczy wąskiej zamkniętej wody do 300 pól, która nie ma ani jednego pola z wodą dookoła w promieniu 2 (np. ramię jeziora o szerokości 3–4 pól). Ich brzeg jest za krótki albo za ciasny na zamknięty łańcuch klifów, więc w grze z jednej strony był klif, a z drugiej goła prosta krawędź. Działa w `Classify` i jeszcze raz w `RepairCoast`: stawy często odcinają się dopiero po ułożeniu brzegów.
  - **Elementy brzegu na suchym lądzie** (część wodna elementu leżała na polu lądu, więc po zasypaniu stawu zostawała skała z kałużą) są usuwane.
  - **Szew ma 8 prób:** zasypać koniec wody, zatopić język lądu, przesunąć brzeg o 2 rzędy w stronę wody albo lądu. Każda próba najpierw ze zdjęciem elementów w promieniu 3, potem 6. Łańcuchy naprawcze próbują też korytarza 3 pól.
  - `MinWaterWidth` (woda węższa niż N pól → ląd) istnieje, ale jest **wyłączony**: na ARKA 3 przy wartości 3 szwy wzrosły z 2 do 6.
  - **Czego konwerter nie domyka:** ostry wklęsły narożnik wody (90°) i pojedyncze przerwy 1–2 pól na prostym brzegu. Ostry narożnik od grobli ARKA 3 jest ścięty skosem w skrypcie mapy.
  - **Kontrola w skrypcie mapy** (`build-arka03-antiga.ps1`): po renderze `coast.png` to kadry wokół każdego szwu, który został, z numerem komórki. Oglądać przed oddaniem mapy.
- Wynik na ARKA 3: krawędzi bez brzegu było 135, potem 4, po rundzie 3 zostały 1 krawędź i 1 szew. Brukowanych mostów nie ma, a wszystkie waypointy są osiągalne. Groble ARKA 3 mają teraz 9 kafli szerokości: węższe i tak zostałyby poszerzone.
- **Co zostaje:** pas niziny o szerokości ok. 1 komórki między klifem płaskowyżu SC a wodą jest za wąski na element brzegu, więc dalej ma ząbki (ARKA 6: krawędzi bez brzegu 29 → 22). Sesja ARKA 6 obchodzi to w swoim skrypcie: przed konwersją woda w promieniu 8 minikafli od wysokiego terenu SC staje się niziną (plaża). Kandydat na ogólną opcję konwertera.
- Mapy zbudowane przed poprawką mają stary wygląd do czasu przebudowy skryptem terenu. Mosty kamienne Fighting Spirit po przebudowie byłyby grubszymi przesmykami **(niesprawdzone)**.

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
