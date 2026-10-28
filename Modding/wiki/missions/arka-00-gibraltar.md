# Misja ARKA 0: „Ostatnia brama” — mapa Gibraltaru (1953)

Teren preludium kampanii [[plans/campaign-arka]]: Gibraltar z Hiszpanią na północy, zbudowany skryptem ze zrzutu Google Maps, danych OpenStreetMap i modelu wysokości terenu. Strona dla agentów, którzy dokładają triggery, domy i jednostki: co jest na mapie, gdzie są waypointy i na co uważać. Jak robić takie mapy: [[workflow/mission-maps]].

Źródła: `Modding/raw/maps/gibraltar-google.png` (zrzut 620×930 od użytkownika, 2026-10-26), `Modding/raw/maps/gibraltar-geo/` (OSM i DEM Terrarium z15, pobrane 2026-10-26), drugi zrzut użytkownika (widok satelitarny z nazwami ulic i atrakcji), `Modding/tools/build-arka-gibraltar.ps1`, `DesignToDta.cs`, `GeoData.cs`, `ScToDta.cs`, `Maps/Missions/SE01.MAP` (wzór misji DTA), `INI/Battle.ini`, `INI/Rules.ini` (`[OBLI]`, `LaserFire`, `[RAPDOX]`, jednostki pływające), `INI/Art.ini` (fundamenty).

## Stan

- **Wersja 2 (2026-10-26):** Skała z DEM w dwóch poziomach z 6 rampami, prawdziwe drogi z OSM ułożone kaflami `Paved Roads`, wschodni brzeg i pas Sir Herbert Miles Road po prawdziwej linii brzegu, ok. 300 budynków z obrysów OSM (port i przemysł na zachodzie, La Línea, miasto), atrakcje Gibraltaru jako obiekty neutralne. Kontrole przejezdności przechodzą. **(niezweryfikowane w grze)**
- **Recenzja 2026-10-27 (v3 terenu):** drogi przerobione na `Paved Road LAT` z zamykaniem ślepych końców (jak w misjach DTA, [[workflow/mission-maps]]). Pas wschodni ma teraz drogę od granicy do Europa Point (`Sir Herbert Road`, `Dudley Ward Way`). Złoża (ok. 380 komórek rudy zamiast 15): Skała (poziom 1, wp 47), lotnisko (39), Windmill Hill (38) z kopalnią `OREMINE` (223,218). Nowe waypointy 46 (drzwi kościoła The Convent, skrzynka z pieniędzmi) i 47. Zasady: [[workflow/mission-design]]. **(niezweryfikowane w grze)**
- Wersja 1 (ręczna Skała, drogi z bruku LAT) jest w `Modding/archive/arka00-gibraltar-v1_2026-10-26/` (+ zip), z instrukcją przywrócenia.
- Mapa terenu jest skirmishowa do obejrzenia: `Maps/Custom/arka00_gibraltar.map`, w kliencie Skirmish → **Custom Map**, 2 graczy. Misja z triggerami: `Maps/Missions/arka00.map` (warstwa sesji 7b, niżej).

Podgląd z numerami waypointów: `missions/img/arka-00-gibraltar-waypoints.jpg` (żółte = ląd, niebieskie = morze, pomarańczowe S0/S1 = starty skirmisha; skrypt zapisuje go jako `%TEMP%\arka-gibraltar\waypoints.png`, po przebudowie skopiuj). Projekt rodzajów terenu na siatce zrzutu: `missions/img/arka-00-gibraltar-design.png` (jasny brąz = poziom 1, ciemny = grań, zielone koła = rampy).

**Podział pracy (2026-10-26):** teren należy do `tools/build-arka-gibraltar.ps1` (ta strona). Triggery, dialogi i kluczowe budynki robi sesja `dawn-of-the-tiberium-7b` jako osobną warstwę `tools/build-arka00-mission.ps1`. Ten skrypt czyta `Maps/Custom/arka00_gibraltar.map` tylko do odczytu i zapisuje `Maps/Missions/arka00.map`. Po przebudowie terenu wystarczy uruchomić skrypt misji ponownie (`powershell -NoProfile -File Modding\tools\build-arka00-mission.ps1`). Na terenie v2 dał `CHECKS: PASS` bez WARN: ARKA na 117,130, elektrownie 105,127 / 114,118 / 122,145 / 132,136. Warstwa misji: [[missions/arka-00-triggers]]. Format triggerów: [[engine/triggers-and-dialogue]]. Misja używa waypointów 10–14 (ARKA i elektrownie na środkach działek), 15/16 (bunkry za bramami), 17 (Tanya), 18/19/22/26/41/45 (spawny fal) i 20/21/23/25/33 (trasy). **Numery waypointów 10–47 to kontrakt między warstwami** (46–47 od 2026-10-27; nowe tylko dopisywać na końcu): nie przenumerowywać. Każde przesunięcie waypointu wpisać do `log.md` i do tabeli niżej.

**Ręczna edycja w WAE (użytkownik, 2026-10-28, zapis 12:01).** `Maps/Custom/arka00_gibraltar.map` nie jest już czystym wynikiem skryptu:
- drogi w bazie przemalowane i poszerzone (pełny kafel `Paved Road LAT` 2269 zamiast przejść krawędziowych), nowa droga od wp 12 do ARKI i na skos do 13;
- mur `BRIK` z 35 do 61 komórek, bramy 15 i 16 zostały otwarte;
- 27 domków usuniętych (bramy, baza, La Línea), dodane rafinerie, beczki i skrzynie w dokach oraz `ARCO` przy murze;
- doszły samochód `CAR2G` w La Línea i 3 bombowce `BADGER` (Neutral) przy pasie startowym.

Waypointy 10–47 bez zmian. **Nie uruchamiać `build-arka-gibraltar.ps1`**, dopóki tych zmian nie przeniesie się do skryptu, bo skrypt nadpisze mapę w całości. Kopia sprzed edycji: `Modding/archive/arka00-kopia_2026-10-28_1127/`. Skrypt misji (`build-arka00-mission.ps1`) tylko czyta teren i działa z ręczną mapą (po poprawce brakujących komórek, zob. [[workflow/known-mistakes]]): baza stoi, ARKA jest osiągalna z Hiszpanii, ze wszystkich plaż i z trasy zasadzki (BFS).

## Pliki i przebudowa

| Plik | Rola |
|---|---|
| `Maps/Custom/arka00_gibraltar.map` (+ `.png`) | wynik; nadpisywany przy każdej przebudowie |
| `Modding/tools/build-arka-gibraltar.ps1` | cała geometria jako dane (poprawki wody, progi wysokości, rampy, plaże, strefy, atrakcje, waypointy) |
| `Modding/tools/GeoData.cs` | georeferencja zrzutu, OSM, DEM |
| `Modding/tools/DesignToDta.cs` | warstwy projektu i budowa mapy |
| `Modding/tools/fetch-geodata.ps1` | ponowne pobranie OSM i DEM |

```powershell
Modding\tools\build-arka-gibraltar.ps1               # ok. 5–8 min z renderem; log i obrazy w %TEMP%\arka-gibraltar\
Modding\tools\build-arka-gibraltar.ps1 -DesignOnly   # tylko warstwy projektu (design_kind/ground/zone/buildings.png)
```

- Współrzędne w skrypcie to **piksele zrzutu** (x 0–620, y 0–930; y < 0 to Hiszpania dopisana nad zrzutem). OSM i DEM rzutuje `GeoRef` (dopasowany do linii brzegu: średnio 1,1 px, 1 px ≈ 6,3 m). Widoczny prostokąt: x 115–590, y −60…930. Jedna komórka ≈ 7,8 × 4,5 px zrzutu.
- Wynik jest deterministyczny (`Random(1998)`).
- Uruchamiaj w osobnym `powershell -NoProfile`.

## Geometria

- `Size=0,0,64,229`, `LocalSize=2,5,60,220`, teatr TEMPERATE, ok. 10,8 tys. komórek przejezdnych. Komórka w INI = `y*1000+x`.
- Północ mapy = północ ekranu. Z góry na dół: Hiszpania (La Línea) → granica → zatoka i pas startowy → mur północny → miasto i baza → Skała → miasto południowe → Europa Point.

## Strefy i trasy

| Strefa | Co tam jest | Waypointy |
|---|---|---|
| Baza gracza (North District, stare miasto) | strefa wolna od drzew i budynków cywilnych (zachód od Skały, od muru do ok. Trafalgar), działka ARKI 9×9 i 4 działki elektrowni (14 z zapasem 7×7); przez strefę idą drogi | 10–14 |
| Mur północny (Northern Defences) | betonowy mur `BRIK` (overlay 2) w poprzek przesmyku, dwie bramy | 15 (Landport), 16 (Waterport) |
| Lotnisko | pas startowy, terminal jako `HANGAR`, sporne pole rudy między granicą a pasem | 20, 21, 39 |
| Hiszpania (La Línea) | gęsta zabudowa z OSM, główne aleje, pola, park z drzewami; dwie zarezerwowane strefy zbiórki Sowietów | 17 (Tanya), 18, 19 |
| Skała, poziom 1 (Upper Rock, > 100 m) | płaskowyż z klifami, 4 rampy z miasta: NW (Willis's Road), W (Alameda / dolna stacja kolejki, nowa w v2), SW (Queen's Road przy St Michael's Cave), S (Windmill Hill Road); od 2026-10-27 także **E** od pasu wschodniego (seed 436,410, wynik 440,414; komórki ok. 150–154 × 123–134). Wcześniej przejście z pasu wschodniego na złoże na Skale miało 1 komórkę szerokości (klif x 151–153 kończył się na y 133, klif grani zaczyna się na y 135), teraz ok. 12. Trasa zasadzki misji (wp 61–63). Rajd `h2` z wp 18 dalej idzie przez Landport i rampę NW (BFS) | 28–33 |
| Skała, poziom 2 (grań, > 220 m) | środkowy grzbiet z 2 rampami z poziomu 1 (C1 Middle Hill, C2 Spur Battery Road); północny szczyt **bez rampy** (ozdoba, nieosiągalny po ziemi) | 34, 35 |
| Pas wschodni (Sir Herbert Miles Road) | ok. 6 komórek lądu pod klifem Skały, po prawdziwej linii brzegu, z drogą; od Eastern Beach do Europa Point; **druga droga z Hiszpanii na południe, omija mur** | 22–25 |
| Port i przemysł (zachód) | Dockyard, Coaling Island, North Mole: bruk, 4 dźwigi, magazyny `CITY09`, szopy `NV18`, silosy `NV17`, skrzynie, beczki | 37 |
| Południe | miasto z OSM, szpital `HOSP`, wiatrak `WDML` (Windmill Hill), ruda, latarnia `LHUS` | 26, 36, 38 |
| Morze | zatoka na zachodzie, Morze Śródziemne na wschodzie i południu (jeden akwen) | 40–45 |

**Atrakcje (pozycje z OSM):** Great Siege Tunnels (ruina wieży `DBTWR` + skrzynie amunicji `AMMOCRAT` na północnej ścianie), World War II Tunnels (`AMMOCRAT`), baterie O'Hara's (`DBATWR`), Princess Caroline's, Princess Anne's, Lord Airey's, Devil's Gap (`DBTWR`), Apes' Den (ognisko `CMPFRA`), The Convent (kościół `V01`), Europa Point Lighthouse, Windmill Hill, terminal lotniska, szpital. Bez miejsca w v2: Tower of Homage (`RUS02A`), 100 Ton Gun, St Michael's Cave (`CA0008` 2×2), King's Chapel. Leżą w gęstej zabudowie albo na krawędzi poziomu; do poprawki przesunięciem punktu w skrypcie.

Plaże (zestaw Shores, przejezdne): Playa de Levante (Hiszpania), Eastern Beach (23), Catalan Bay (24), Sandy Bay, Camp Bay (26), Little Bay / Europa Point (27). Reszta brzegu to klify wodne (skała).

Trasy wroga, które teren wymusza:
1. **Sowieci z północy:** zbiórka 18/19 → granica 20 → pas 21 → bramy 15/16 → baza. Najkrótsza.
2. **Obejście wschodem:** 19 → 22 → pas wschodni (24, 25) → południe (33/36) → miasto od południa. Długa, idealna dla Stealth Tanków Nod.
3. **Z morza (Nod):** łodzie z 40–45; desant tylko na plażach 23, 24, 26, 27. Camp Bay (26) to najkrótsza droga do ARKI od strony wody.
4. **Skała:** poziom 1 przez rampy NW/W/SW/S, grań przez C1/C2. Grań patrzy na pas wschodni i na miasto. Kto ją trzyma, ma osłoniętą pozycję.

## Waypointy

Numery 10–45 są dla misji. 0 i 1 to starty skirmisha. Litery = zapis waypointu w polu akcji triggera (A = 0, Z = 25, AA = 26), potwierdzone przez sesję misji na `rsovm1.map` (`Waypoint=K` = wp 10). Komórki po przebudowie v2 (2026-10-26). W porównaniu z v1 przesunęły się 16, 24, 25 i 28–35.

| Nr | Lit. | Komórka | Opis |
|---|---|---|---|
| 10 | K | 131118 | ARKA: środek działki 9×9 (Chronosfera `RAPDOX` ma 2×2) |
| 11 | L | 128106 | Elektrownia 1 (NW), działka 5×5 |
| 12 | M | 119115 | Elektrownia 2 (NE) |
| 13 | N | 146123 | Elektrownia 3 (SW) |
| 14 | O | 137133 | Elektrownia 4 (SE), pod klifem Skały, działka 7×7 |
| 15 | P | 107104 | Brama Landport (mur, droga z lotniska) |
| 16 | Q | 119093 | Brama Waterport (mur, zachód); 118092 do v2 |
| 17 | R | 47069 | Tanya: park w La Línea, za liniami wroga |
| 18 | S | 52036 | Sowieci: zbiórka NW |
| 19 | T | 28057 | Sowieci: zbiórka NE |
| 20 | U | 70077 | Przejście graniczne (Winston Churchill Ave) |
| 21 | V | 84091 | Pas startowy, skrzyżowanie z drogą |
| 22 | W | 83113 | Devil's Tower Rd pod północną ścianą Skały (wejście na pas wschodni) |
| 23 | X | 71111 | Lądowisko: Eastern Beach |
| 24 | Y | 108146 | Lądowisko: Catalan Bay |
| 25 | Z | 189218 | Pas wschodni, odcinek tunelu Dudley Ward |
| 26 | AA | 211207 | Lądowisko: Camp Bay (zachód, południe miasta) |
| 27 | AB | 244255 | Lądowisko: Europa Point |
| 28 | AC | 123127 | Skała: góra rampy NW (poziom 1) |
| 29 | AD | 123126 | Skała: dół rampy NW |
| 30 | AE | 184189 | Skała: góra rampy SW |
| 31 | AF | 184188 | Skała: dół rampy SW |
| 32 | AG | 215230 | Skała: góra rampy S |
| 33 | AH | 216231 | Skała: dół rampy S |
| 34 | AI | 102124 | Skała: szczyt północny, poziom 1 nad lotniskiem (Great Siege Tunnels); 101123 do v2 |
| 35 | AJ | 142150 | Skała: Middle Hill, **grań (poziom 2)** |
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
| 46 | AU | 149137 | Kościół The Convent: wolna komórka przy drzwiach; warstwa misji szuka po nim kościoła `V01`, w którym ukryte jest złoto (przejęcie inżynierem); od v3 |
| 47 | AV | 120128 | Ruda: Skała, poziom 1 (złoże „złota na górze”), u góry rampy NW; od v3 |
| 60 | BI | (misja) | **Nie w mapie terenu:** dopisuje go warstwa misji przy dziale 100 Ton Gun obok szpitala ([[missions/arka-00-triggers]]). Teren nie powinien używać numeru 60. |
| 61–63 | BJ–BL | (misja) | **Nie w mapie terenu:** trasa rosyjskiej zasadzki na złoże na Skale od wschodu: 61 pas wschodni przy Catalan Bay (144,112), 62 przesmyk pod końcem klifu (155,126), 63 złoże (138,128). Przejście istnieje w terenie v3 (BFS). Teren nie powinien używać 61–63 ani zamykać tego przesmyku. |
| 64 | BM | (misja) | **Nie w mapie terenu:** start desantów Nod na Camp Bay: otwarte morze przy południowo-zachodniej krawędzi (234,269). Wcześniej startowały z 41, w zatoce przy dokach. |

Kontrole w skrypcie (przejazd po ziemi, z obiektami; od v3 także ARKA → kościół, ruda na Skale, ruda lotnisko): Hiszpania → ARKA, Eastern Beach → ARKA, Catalan Bay → Europa Point, Camp Bay → ARKA, rampy NW/SW/S, ARKA → szczyt Skały, ARKA → grań, Tanya → zbiórka sowiecka, ARKA → ruda Windmill Hill, ARKA → doki. Wszystkie OK (v2, 2026-10-26).

## Pułapki

1. **Skrypt nadpisuje `Maps/Custom/arka00_gibraltar.map` w całości.** Triggery trzymaj w warstwie misji, nie w tym pliku.
2. **Hovercrafty i desant lądują tylko na plażach.** Klify wodne mają komórki skalne (kod 7/8), przez które `HVC`/`HVCSAM`/`HVR` (`SpeedType=Hover`) ani `LST` (`Amphibious`) nie wyjadą. Płytka woda plaży ma kod 1 (przejezdny). Desanty na 23, 24, 26, 27. Łodzie Nod (`SPEEDBOAT`, `TORPBOAT`) pływają wszędzie.
3. **`HomeCell` to numer waypointu, nie komórka.** Konwerter wpisuje `HomeCell=98`, `AltHomeCell=99`, a takich waypointów nie ma (SE01 ma `HomeCell=2`). W misji ustaw `HomeCell=10`.
4. **Obelisk Nod ma zasięg 9 komórek** (`LaserFire Range=9`). Z hiszpańskiego brzegu zatoki do pasa startowego jest ok. 19 komórek. „Lasery z wybrzeża Hiszpanii” to skrypt albo Obeliski po hiszpańskiej stronie granicy (rejon 20).
5. **Mur północny nie zamyka bazy.** Dwie bramy i pas wschodni (22 → 25 → 33) to zamierzone dwa fronty. Zamknięcie pasa: obiekt przy 25 („tunel Dudley Ward zawalony”).
6. **Mapa jest długa** (229 wierszy). Ze zbiórki 18 do ARKI jest ok. 80 komórek. Licznik (dziś 30:00) licz w sekundach gry, nie w „minutach” Rules (zob. [[workflow/known-mistakes]]).
7. **Domy:** nie zmieniaj `[Houses]` w Rules.ini ([[engine/sides-and-houses]]). Budynki cywilne i atrakcje to dom `Neutral`.
8. **Kodowanie:** mapa w Windows-1252, nazwy w INI bez polskich znaków.
9. **Drogi** to `Paved Road LAT` (od v3), 2–3 komórki szerokości, kod terenu 11 (przejezdne, budowlane). Każdy koniec łączy się z drogą, krawędzią mapy albo placem: `FinishRoads`, log `free ends 0`. Warstwa misji stawia budynki obok dróg, żeby nie zatkać przejazdu. Drogi przecinają mur tylko w bramach.
10. **Drzewa** (ok. 310) blokują ruch i strzały. Zatkaną trasę odblokujesz usunięciem wpisu z `[Terrain]` (klucz `y*1000+x`).
11. **Ruda** (`ZORE`, ok. 380 komórek od v3): Skała 85%, lotnisko 75%, Windmill Hill 70% + kopalnia `OREMINE`. Ruda na Skale jest tylko na poziomie 1 (`CellsIn`). Kopalnia rośnie sama, a reszta rudy się nie rozrasta (`[Ore] SpreadPercentage=0`).
12. **Północny szczyt grani nie ma rampy.** Jednostek naziemnych tam nie postawisz. Zrzut z powietrza albo skrypt zadziała, ale silnik może je uznać za uwięzione.

## Znane wady wyglądu

- **Naprawione 2026-10-27 (użytkownik: „nierówne wybrzeże”):** na południe od Catalan Bay (komórki ok. 147–156, 114–122) woda wcinała się w ląd prostokątnymi schodkami, a w morze sterczał jęzor lądu. Przyczyna: napis „EAST SIDE” na zrzucie Google w warstwie `kind`. Dwa wielokąty po prawdziwej linii brzegu, (525,342) → (501,362) → (494,372) → (492,397) w pikselach zrzutu, zaraz po `RemoveSmall`: wcięcie zamienione na ląd, jęzor na morze. Teraz brzeg to gładki łuk plaży. Kontrole przejazdów OK, wp 24 ma kod terenu 0, trasa zasadzki 22 → 61 → 62 → 63 przechodzi. Ta sama metoda pomoże przy innych napisach zrzutu, które wycięły brzeg.
- Ok. 10 komórek „surowego” brzegu (po naprawie Catalan Bay; wcześniej 13), w kilku miejscach, gdzie łańcuch plaży styka się z łańcuchem klifu wodnego: trawa dotyka wody prostą krawędzią. Drugi przebieg plaż na te przerwy stawiał pojedyncze kawałki plaży na morzu, więc go wyłączyłem. Lista miejsc: `%TEMP%\arka-gibraltar\rawcoast.png` (czerwone kółka).
- Drogi poziome na ekranie (wschód–zachód w Hiszpanii) układają się w schodki z kawałków ukośnych. Tak działa zestaw kafli.
- Część krótkich odcinków dróg to bruk LAT zamiast kafli (177 odcinków, ok. 740 komórek).
- Pas startowy zaczyna się na linii brzegu (wąski cypel w zatoce nie mieści klifów wodnych).

## Jak to zbudowano

Szczegóły i pułapki techniczne: [[workflow/mission-maps]]. W skrócie: woda ze zrzutu, Skała z DEM (próg 100 i 220 m, wschodni pas 48 px od brzegu zostaje niziną, grań odsunięta o 18 px od krawędzi poziomu 1), rampy dosunięte do krawędzi przy prawdziwych drogach, drogi `trunk/primary/secondary` z OSM złączone w ciągi między skrzyżowaniami, budynki z obrysów OSM (≥ 40% komórki), atrakcje z nazw OSM (trafienie najbliższe oczekiwanemu miejscu).
