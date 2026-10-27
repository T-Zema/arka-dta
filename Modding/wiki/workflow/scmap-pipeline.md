# Pipeline: mapa StarCrafta → mapa skirmisha DTA

Jedno polecenie od nazwy mapy SC do zainstalowanej mapy DTA, z kontrolami i arkuszem do oceny. Ok. 8 s na mapę 128×128.

Źródła: `Modding/tools/port-scmap.ps1` (pipeline), `convert-scmap.ps1` (konwersja), `ScToDta.cs`; przebiegi na Lost Temple
i Fighting Spirit (2026-10-24); logi gry `Debug/DEBUG_24-10-2026_19-*.LOG`.

## Polecenia

```powershell
Modding\tools\port-scmap.ps1 -List [-Filter "temple"]      # unikalne mapy SC: rozmiar, tileset, liczba startów, folder
Modding\tools\port-scmap.ps1 -Map "Fighting Spirit"         # znajdź, skonwertuj, sprawdź, zainstaluj (gdy nie FAIL)
Modding\tools\port-scmap.ps1 -Map "Python" -NoInstall       # tylko zbuduj i pokaż arkusz
Modding\tools\port-scmap.ps1 -Map "Lost Temple" -Archive    # + archive/sc-<nazwa>_<data>/ i .zip
```

- `-Map` przyjmuje fragment nazwy pliku (spacje = podkreślenia) albo pełną ścieżkę. Te same mapy z wielu folderów sezonów
  ladderu są scalane po hashu. Przy kilku różnych wersjach pipeline wypisuje listę, a `-Pick n` wybiera wersję.
- Wynik: `Maps/Custom/sc_<nazwa>.map` (ok. 1 MB, w środku `[PreviewPack]` 400 px, bo z niego klient bierze podgląd map
  własnych) + `.png` 800 px (do arkusza i dla porządku). Klient: Skirmish → tryb **Custom Map**.
- Folder roboczy `%TEMP%\scmap\<nazwa>\`: `review.png`, `summary.json`, `log.txt` (łuki, łańcuchy, kontrole), `cells.png`,
  `reach.png`, `compare_sc.png`, `sc.png` (oryginał), `*_full.png` (pełny render).
- Instalacja nie nadpisze mapy w `Maps/Custom`, której nie zrobiło to narzędzie (sprawdza `Author=... port: Claude`), chyba że `-Force`.
  Po instalacji pipeline sam dopisuje linię `mod` do `log.md`. Stronę wiki mapy trzeba napisać samemu.

## Werdykt i co oglądać

- **FAIL**: mniej niż 2 starty albo starty niepołączone po ziemi. Nie instaluje (chyba że `-Force`).
- **WARN**: nieudane łańcuchy klifów/brzegów, ponad 15 komórek „odciętych” (w SC przejezdne, tu nie), ponad 150 „przecieków”
  albo klejnoty nieosiągalne z ziemi. Klejnoty na wyspach (Lost Temple) to wierność oryginałowi, a nie błąd.
- `review.png`: oryginał | podgląd DTA | przejezdność względem SC (czerwone = dostępne tu, w SC nie; pomarańczowe = odwrotnie).
  Zawsze obejrzeć. Liczby nie wyłapią np. dziwnych ząbków wody czy murów w złym miejscu.
- Szczegóły obejrzeć na wycinkach `*_full.png` (pełna rozdzielczość, 3072 px na mapę 128×128).

## Co konwerter robi sam (stan po Fighting Spirit)

- Woda = duże nieprzejezdne niziny z udziałem niebieskich minikafli ≥ 0,12 (średni kolor zawodzi przy wąskich kanałach
  o brązowych brzegach). Brzegi = Water Cliffs.
- Mosty i groble SC: komórka lądu, wokół której w oknie 7×7 są dwa osobne kawałki wody. Nie dostają klifów wodnych, są brukowane.
- Płaskowyże per poziom (SC średni i wysoki), wyższe najpierw. Rampy tylko tam, gdzie SC ma przejście po minikaflach.
- Mury (dekoracje blisko środka mapy): szkielet Zhang-Suen + uzupełnienie ukosów, więc zachowują kształty X, L i T.
  Wydłużone przeszkody dalej od środka = linie małych skał, drobne = drzewa. Sprite'y SC = drzewa.
- Pętla naprawcza: drzewo, skała albo mur, które odcinają teren przejezdny w SC, są usuwane.
- Łańcuch klifów nie może nachodzić na żaden swój wcześniejszy element (w wąskim kanale wracał tym samym brzegiem).

## Ograniczenia

- Zawsze teatr Temperate. Kolory podłoża dobrane pod jungle (inne tilesety SC: poprawny układ, słabsze podobieństwo wyglądu).
- Mosty SC stają się przejściem lądem (brukiem), a nie kaflem mostu DTA.
- Brak neutralnych budynków SC i jednostek innych niż minerały, gejzery i starty.
- Płaskowyż zamknięty w pętlę (bez rampy, krawędzi mapy i wody) dostaje dwa zakończenia obok siebie, co może zostawić
  przejście **(niezweryfikowane: dotąd żadna mapa takiego nie miała)**.
