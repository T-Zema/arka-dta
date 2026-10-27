# Misja ARKA 0: „Ostatnia brama” — mapa Gibraltaru (1953)

Teren preludium kampanii [[plans/campaign-arka]]: Gibraltar z Hiszpanią na północy, zbudowany skryptem ze zrzutu Google Maps. Strona dla agentów, którzy dokładają triggery, domy i jednostki: co jest na mapie, gdzie są waypointy i na co uważać.

Źródła: `Modding/raw/maps/gibraltar-google.png` (zrzut 620×930 od użytkownika, 2026-10-26), `Modding/tools/build-arka-gibraltar.ps1`, `Modding/tools/DesignToDta.cs`, `Modding/tools/ScToDta.cs`, `Maps/Missions/SE01.MAP` (wzór misji DTA), `INI/Battle.ini`, `INI/Rules.ini` (`[OBLI]`, `LaserFire`, `[RAPDOX]`, jednostki pływające), `INI/Art.ini` (fundamenty).

## Stan

- **Gotowe:** teren, brzegi, Skała z rampami, drogi, mur, budynki cywilne, drzewa, ruda, 36 waypointów misji. Kontrole przejezdności w skrypcie przechodzą.
- **Nie ma:** domów misji, triggerów, jednostek, bazy gracza, ARKI, briefingu, wpisu w `Battle.ini`. To zadanie następnego agenta (lista niżej).
- Mapa jest dziś mapą **skirmishową** do obejrzenia: `Maps/Custom/arka00_gibraltar.map`, w kliencie Skirmish → tryb **Custom Map**, 2 graczy (start 0 na działce ARKI, start 1 w Hiszpanii). **(niezweryfikowane w grze)**

Podgląd z numerami waypointów: `missions/img/arka-00-gibraltar-waypoints.jpg` (żółte = ląd, niebieskie = morze, pomarańczowe S0/S1 = starty skirmisha; skrypt zapisuje go jako `%TEMP%\arka-gibraltar\waypoints.png`, po przebudowie skopiuj). Projekt warstw na siatce zrzutu: `missions/img/arka-00-gibraltar-design.png`.

**Podział pracy (2026-10-26):** teren należy do `tools/build-arka-gibraltar.ps1` (ta strona). Triggery, dialogi i kluczowe budynki robi sesja `dawn-of-the-tiberium-7b` jako osobną warstwę `tools/build-arka00-mission.ps1`. Ten skrypt czyta `Maps/Custom/arka00_gibraltar.map` tylko do odczytu i zapisuje `Maps/Missions/arka00.map`. Po przebudowie terenu wystarczy uruchomić skrypt misji ponownie. **Numery waypointów 10–45 to kontrakt między warstwami:** nie przenumerowywać. Każde przesunięcie waypointu wpisać do `log.md` i do tabeli niżej.

## Pliki i przebudowa

| Plik | Rola |
|---|---|
| `Maps/Custom/arka00_gibraltar.map` (+ `.png`) | wynik; nadpisywany przy każdej przebudowie |
| `Modding/tools/build-arka-gibraltar.ps1` | cała geometria jako dane (wielokąty, drogi, plaże, waypointy, obiekty) |
| `Modding/tools/DesignToDta.cs` | klasy `Layer` (rastry projektu) i `DesignToDta` (próbkowanie, plaże, budynki, drzewa, waypointy) |
| `Modding/tools/ScToDta.cs` | wspólne etapy z konwertera SC: klify A*, klify wodne, woda, LAT, kontrole |

```powershell
Modding\tools\build-arka-gibraltar.ps1               # ok. 3 min z renderem; log i obrazy w %TEMP%\arka-gibraltar\
Modding\tools\build-arka-gibraltar.ps1 -DesignOnly   # tylko warstwy projektu (design_kind/ground/zone.png) do strojenia
```

- Współrzędne w skrypcie to **piksele zrzutu** (x 0–620, y 0–930; y < 0 to Hiszpania dopisana nad zrzutem). Widoczny prostokąt: x 115–590, y −60…930. Jedna komórka ≈ 7,8 × 4,5 px zrzutu.
- Wynik jest deterministyczny (`Random(1998)`), więc ta sama wersja skryptu daje ten sam plik.
- Uruchamiaj w osobnym `powershell -NoProfile` (dwa `Add-Type` w jednym procesie kończą się błędem „type already exists”).

## Geometria

- `Size=0,0,64,229`, `LocalSize=2,5,60,220`, teatr TEMPERATE, ok. 11,5 tys. komórek przejezdnych. Komórka w INI = `y*1000+x`.
- Północ mapy = północ ekranu. Z góry na dół: Hiszpania (La Línea) → granica → zatoka i pas startowy → mur północny → miasto i baza → Skała → miasto południowe → Europa Point.

## Strefy i trasy

| Strefa | Co tam jest | Waypointy |
|---|---|---|
| Baza gracza (North District, stare miasto) | wolna trawa na zachód od Skały, działka ARKI 9×9 i 4 działki elektrowni 5×5 **zarezerwowane** (bez drzew i budynków) | 10–14 |
| Mur północny (Northern Defences) | betonowy mur `BRIK` (overlay 2) w poprzek przesmyku, dwie bramy | 15 (Landport, droga z lotniska), 16 (Waterport, zachód) |
| Lotnisko | pas startowy (bruk) w poprzek przesmyku; między granicą a pasem sporne pole rudy | 20, 21, 39 |
| Hiszpania (La Línea) | pola, wioska, park z drzewami; dwie zarezerwowane strefy zbiórki Sowietów | 17 (Tanya), 18, 19 |
| Skała | płaskowyż z klifami dookoła, trzy rampy: NW (Willis's Road), SW (Queen's Road, przy jaskini św. Michała), S (Windmill Hill) | 28–35 |
| Pas wschodni (Sir Herbert Miles Road) | wąski ląd pod klifem Skały, od Eastern Beach do Europa Point; **druga droga z Hiszpanii na południe, omija mur** | 22–25 |
| Doki | brukowany nabrzeże, 3 dźwigi `CRANE`, 3 magazyny `CITY09` | 37 |
| Południe | miasteczko (V01–V11, `V03`, szpital `HOSP`), wiatrak `WDML`, ruda Windmill Hill, latarnia `LHUS` | 26, 36, 38 |
| Morze | zatoka na zachodzie, Morze Śródziemne na wschodzie i południu (jeden akwen dookoła cypla) | 40–45 |

Plaże (zestaw Shores, przejezdne): Playa de Levante (Hiszpania, wschód), Eastern Beach (23), Catalan Bay (24), Sandy Bay, Camp Bay (26, zachód, blisko miasta), Europa Point (27). Reszta brzegu to klify wodne (skała).

Trasy wroga, które teren wymusza:
1. **Sowieci z północy:** zbiórka 18/19 → granica 20 → pas 21 → bramy 15/16 → baza. Najkrótsza.
2. **Obejście wschodem:** 19 → 22 → pas wschodni (24, 25) → południe (33/36) → miasto od południa. Długa, idealna dla Stealth Tanków Nod.
3. **Z morza (Nod):** łodzie z 40–45; desant tylko na plażach 23, 24, 26, 27. Camp Bay (26) to najkrótsza droga do ARKI od strony wody, dobra dla szpiega z ostatnich 3 minut.
4. **Skała:** kto zajmie płaskowyż (rampy 29→28, 31→30, 33→32), ten ma osłoniętą pozycję nad bazą i pasem wschodnim.

## Waypointy

Numery 10–45 są dla misji. 0 i 1 to starty skirmisha (do usunięcia albo zignorowania w misji). Litery = zapis waypointu w polu akcji triggera (A = 0, Z = 25, AA = 26), **(niezweryfikowane: sprawdzić w edytorze na jednym triggerze)**.

| Nr | Lit. | Komórka | Opis |
|---|---|---|---|
| 10 | K | 131118 | ARKA: środek działki 9×9 (Chronosfera `RAPDOX` ma 2×2, jest zapas na większą ARKĘ) |
| 11 | L | 128106 | Elektrownia 1 (NW), działka 5×5 |
| 12 | M | 119115 | Elektrownia 2 (NE) |
| 13 | N | 146123 | Elektrownia 3 (SW) |
| 14 | O | 137133 | Elektrownia 4 (SE), tuż pod klifem Skały |
| 15 | P | 107104 | Brama Landport (mur, droga z lotniska) |
| 16 | Q | 119093 | Brama Waterport (mur, zachód) |
| 17 | R | 47069 | Tanya: park w La Línea, za liniami wroga |
| 18 | S | 52036 | Sowieci: zbiórka NW |
| 19 | T | 28057 | Sowieci: zbiórka NE |
| 20 | U | 70077 | Przejście graniczne (Winston Churchill Ave) |
| 21 | V | 84091 | Pas startowy, skrzyżowanie z drogą |
| 22 | W | 83113 | Devil's Tower Rd pod północną ścianą Skały (wejście na pas wschodni) |
| 23 | X | 71111 | Lądowisko: Eastern Beach |
| 24 | Y | 107147 | Lądowisko: Catalan Bay |
| 25 | Z | 187220 | Pas wschodni, odcinek tunelu Dudley Ward |
| 26 | AA | 211207 | Lądowisko: Camp Bay (zachód, południe miasta) |
| 27 | AB | 244255 | Lądowisko: Europa Point |
| 28 | AC | 122132 | Skała: góra rampy NW |
| 29 | AD | 121119 | Skała: dół rampy NW |
| 30 | AE | 179192 | Skała: góra rampy SW |
| 31 | AF | 187185 | Skała: dół rampy SW |
| 32 | AG | 217233 | Skała: góra rampy S |
| 33 | AH | 227244 | Skała: dół rampy S |
| 34 | AI | 97120 | Skała: szczyt północny (miejsce na baterie nad lotniskiem) |
| 35 | AJ | 146164 | Skała: Middle Hill |
| 36 | AK | 236255 | Latarnia Europa Point |
| 37 | AL | 167147 | Doki |
| 38 | AM | 218223 | Ruda: Windmill Hill (bezpieczna, południe) |
| 39 | AN | 67090 | Ruda: lotnisko (sporna) |
| 40 | AO | 67015 | Morze: zatoka, wejście od północnego zachodu |
| 41 | AP | 158120 | Morze: zatoka przy dokach |
| 42 | AQ | 123177 | Morze Śródziemne, wschód |
| 43 | AR | 260247 | Morze: południe (Cieśnina) |
| 44 | AS | 110062 | Morze: zatoka przy pasie startowym |
| 45 | AT | 63117 | Morze: wschód, przy Eastern Beach |

Kontrole w skrypcie (przejazd po ziemi, z obiektami): Hiszpania → ARKA, Eastern Beach → ARKA, Catalan Bay → Europa Point, Camp Bay → ARKA, wszystkie trzy rampy, ARKA → szczyt Skały, Tanya → zbiórka sowiecka, ARKA → ruda Windmill Hill. Wszystkie OK (2026-10-26).

## Co zostało do zrobienia (dla agenta od triggerów)

1. **Skopiować** mapę do `Maps/Missions/ARKA00.MAP` i pracować na kopii (zob. pułapka 1).
2. `[Basic]` jak w misji: `MultiplayerOnly=no`, `Player=<dom gracza>`, `HomeCell=10` (pułapka 3), nazwa, `EndOfGame` itd. Wzór: `Maps/Missions/SE01.MAP`.
3. `[Houses]` + sekcje domów: Alianci (gracz), Sowieci, Nod, `Neutral` (budynki cywilne już na mapie są `Neutral`), `Special`. Ewentualnie osobny dom dla Tanyi albo von Eslinga.
4. Wpis w `INI/Battle.ini` (`[Battles]` + `[M_ARKA00]` z `Scenario=Maps/Missions/ARKA00.MAP`, `Side=`, opis). Kopia `.bak` przed edycją.
5. ARKA (kopia `RAPDOX` z wysokim HP, bez supermocy) na 10, 4 elektrownie na 11–14, reszta bazy Aliantów wokół (wolne miejsce na zachód i północ od 10).
6. Licznik 25:00, spowalnianie za utracone elektrownie, fale (Sowieci 18/19 → 20, Nod z 40–45 na plaże), Tanya na 17, szpieg Nod w ostatnich 3 minutach (sugestia: Camp Bay 26 → 10), przerywnik końcowy.

## Pułapki

1. **Skrypt nadpisuje `Maps/Custom/arka00_gibraltar.map` w całości.** Triggery dopisane ręcznie do tego pliku znikną przy przebudowie. Misję trzymaj w osobnym pliku. Jeśli teren trzeba zmienić, przebuduj i przenieś do misji tylko sekcje terenu: `IsoMapPack5`, `OverlayPack`, `OverlayDataPack`, `Terrain`, `Structures` (cywilne), `Waypoints` (sprawdź, czy numery się nie przesunęły), `Map`.
2. **Hovercrafty i desant lądują tylko na plażach.** Klify wodne mają komórki skalne (kod 7/8), przez które `HVC`/`HVCSAM`/`HVR` (`SpeedType=Hover`) ani `LST` (`Amphibious`) nie wyjadą. Płytka woda plaży ma kod 1 (przejezdny). Desanty planuj na 23, 24, 26, 27. Nod ma też łodzie `SPEEDBOAT`, `TORPBOAT` (Float), które pływają wszędzie po morzu.
3. **`HomeCell` to numer waypointu, nie komórka.** Konwerter wpisał `HomeCell=98`, `AltHomeCell=99`, a takich waypointów nie ma. SE01 ma `HomeCell=2`. Ustaw `HomeCell=10` (ARKA) albo dodaj waypoint 98. **(niezweryfikowane w grze)**
4. **Obelisk Nod ma zasięg 9 komórek** (`LaserFire Range=9`). Z hiszpańskiego brzegu zatoki do pasa startowego jest ok. 19 komórek, do miasta ponad 25. „Lasery z wybrzeża Hiszpanii” muszą więc być skryptem (np. ostrzał w strefie) albo Obeliskami po hiszpańskiej stronie granicy, pilnującymi rejonu 20.
5. **Mur północny nie zamyka bazy.** Ma dwie bramy (15, 16), a pas wschodni (22 → 25 → 33) obchodzi go od południa. Przy wschodnim końcu muru, pod klifem Skały, może zostać przesmyk **(niezweryfikowane w grze)**. To zamierzone: dwa fronty. Jeśli ma być jeden, zablokuj pas wschodni (np. mur albo budynek przy 25: „tunel Dudley Ward zawalony”).
6. **Mapa jest długa** (229 wierszy). Z zbiórki 18 do ARKI jest ok. 80 komórek, z Europa Point ok. 120. Fale z Hiszpanii nie muszą startować z krawędzi: posiłki (reinforcements) można zrzucać na 18/19. Licznik 25:00 licz w sekundach gry. „Minuty” z Rules to 15 ticków/s, a gra chodzi szybciej (zob. [[workflow/known-mistakes]]).
7. **Domy:** nie zmieniaj `[Houses]` w Rules.ini. Mapy misji DTA mają domy od indeksu 14 ([[engine/sides-and-houses]]). Budynki cywilne stoją jako `Neutral`, więc ten dom musi zostać w `[Houses]` misji.
8. **Kodowanie:** mapa jest zapisywana w Windows-1252. W nazwach w INI mapy pisz bez polskich znaków (nazwa mapy i opisy waypointów w skrypcie są celowo bez ogonków).
9. **Rezerwacje są tylko w skrypcie.** Działki (10–14, 17–19) są wolne od drzew i budynków, ale gra o nich nie wie. Budynki gracza stawiaj w `[Structures]` misji: komórka = lewy górny róg fundamentu, a nie środek.
10. **Drzewa** (ok. 250, typy T01–T17) blokują ruch i strzały pojazdów. Jeśli jakaś trasa okaże się zatkana, usuń wpis z `[Terrain]` (klucz `y*1000+x`) albo zmniejsz gęstość w skrypcie (`PlaceTrees`).
11. **Ruda** (`ZORE`, 44 komórki) jest opcjonalna. Plan kampanii nie mówi o ekonomii, więc agent może ją usunąć (overlay 147–150 w `OverlayPack`) i dać graczowi kredyty.

## Znane wady wyglądu

- Przy latarni (36) został klin lądu na styku plaży z klifem wodnym. Kosmetyka, przejezdny.
- Duże połacie jednolitej trawy (teatr Temperate nie ma suchej, śródziemnomorskiej trawy). Skała jest z ziemi i zieleni, miasto z bruku (drogi, doki, Casemates).
- Pas startowy zaczyna się na linii brzegu. Prawdziwy wchodzi w zatokę, ale wąski cypel nie mieści klifów wodnych z obu stron.

## Jak to zbudowano (dla kolejnych map z prawdziwego terenu)

- Woda = kolor wody ze zrzutu (144, 217, 237 ± 40), potem głosowanie w oknie i usunięcie drobnicy (napisy, falochrony, slipy marin). Etykiety mapy leżące na wodzie trzeba wyciąć ręcznie wielokątami.
- Skała obrysowana ręcznie. Automatyczny próg cieniowania dał hak na północy i przewężenie do 3 komórek.
- Pas wschodni poszerzony, przesuwając brzeg na wschód: klif (ok. 2 komórki) + brzeg (1–2) + droga potrzebują co najmniej 6 komórek szerokości.
- Plaże: osobny etap `DesignToDta.Beaches` (zob. [[engine/connected-tiles]]: woda w szablonach Shores ma kod 9 **albo 1**, zestaw nie ma reguły Front/Back).
- Bez wykrywania grobli (`FindBridges`): w mapie projektowanej dawało schodkowe brzegi i przecinało cypel pasa startowego.
