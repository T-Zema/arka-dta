# ARKA 7 „Zdrada” (Antiga Prime, 2500): mapa i obiekty misji

Siódma misja z [[plans/campaign-arka]]. Teren to mapa kampanii StarCrafta **„The Trump Card”** (CASC `Terran08`, Antiga Prime, badlands 128×96), powiększona 1,5× i przeniesiona na TEMPERATE z gruntem Antigi z misji 4. Zachodnie betonowe platformy z drogami i mostami (w SC tajna baza Mengska) to teraz **miasto Dominium** z budynków Terran SC, z portem kosmicznym i zadokowanym Hyperionem. Wschodnia równina to baza Aliantów wokół ARKI, okrążona z trzech stron. **Etap 1 (2026-10-30): mapa i obiekty, bez triggerów, tekstów i wpisu w `BattleE.ini`.** **(niezweryfikowane w grze)**

Źródła: CASC StarCrafta `SD/campaign/Terran/Terran08/staredit/scenario.chk` (opis: „The Secret Base has been surrounded by the Confederates. You must use the Zerg against the Confederate forces to break the siege.”; obejrzane też `Terran05`, `Terran07`), `arr/units.dat`, `arr/flingy.dat`, `arr/sprites.dat`, `arr/images.dat`, `arr/images.tbl`, `rez/stat_txt.tbl`, `TileSet/badlands.cv5|vx4ex|vr4|wpe`, `Modding/tools/build-arka07-antiga.ps1`, `Modding/tools/build-arka07-mission.ps1`, [[missions/arka-04-zielony-krysztal]] i [[missions/arka-05-tarsonis]] (wzory).

## Pliki

| Plik | Rola |
|---|---|
| `Maps/Custom/arka07_antiga.map` (+ `.png`) | teren (skirmish „Custom Map”), waypointy 10–63; **nadpisywany** przez skrypt terenu |
| `Maps/Missions/arka07.map` | mapa misji z obiektami (etap 1, bez triggerów); **nadpisywana** przez skrypt misji |
| `Modding/tools/build-arka07-antiga.ps1` | teren: CASC → ScToDta, zoom 1,5, TEMPERATE, bruk miasta z platform SC, place i autostrada do bazy, kryształy, kopalnie, kontrole |
| `Modding/tools/build-arka07-mission.ps1` | obiekty: typy SC skopiowane do mapy, domy, miasto w dzielnicach, port z Hyperionem i zaczepami, Duke, baza Aliantów, kontrole |
| `%TEMP%\arka07-terrain\` | `sc_grid.png` (mapa SC z siatką i waypointami, **do planowania**), `waypoints.png`, `reach.png`, `log.txt`, pełny render |
| `%TEMP%\arka07-mission\` | `log.txt`, render `arka07_mission.png` (z `-Render`) |

```powershell
powershell -NoProfile -File Modding\tools\build-arka07-antiga.ps1            # teren, ok. 2-3 min z renderem
powershell -NoProfile -File Modding\tools\build-arka07-mission.ps1 -Render  # obiekty + render
```

## Wybór mapy SC

Na Antidze Prime są w CASC `Terran05` (Antigan Revolt, 96×96), `Terran06` (Norad II, użyta w misji 4), `Terran07` (niewydana „Biting the Bullet”, użyta w misji 6) i **`Terran08` „The Trump Card”** (128×96). T8 pasuje do misji 7 dosłownie: baza okrążona przez wroga. W SC to baza Synów Korhalu na zachodnich platformach, a wokół niej Konfederaci: forty z bunkrami na północnym płaskowyżu, wielka baza na wschodniej równinie, przy niej **Battlecruiser na lokacji `Beacon`**. Tu role są odwrócone: tajna baza Mengska urosła w miasto Dominium (Mengsk jest już cesarzem), a Alianci z ARKĄ stoją tam, gdzie w SC stała baza Konfederacji.

## Teren

- **Zoom 1,5×**: `Size=0,0,100,153`. Droga z ARKI: brama miasta (wp 42) 83 komórki, port (wp 30) 126, pałac (wp 36) 99.
- **Bruk miasta**: konwerter uznaje za bruk tylko jasnoszare piksele (`mx > 60`), a asfalt i beton badlands są ciemne (średnio 26–31, R≈G≈B; błoto 52–57, brązowe). Bez poprawki miasto stało na błocie (pierwszy render).
  - Wersja 1: ciemne komórki DTA → bruk. Użytkownik (2026-10-30): „pavement jest nieregularny i w pavementach są drzewa”.
  - Wersja 2: skrypt klasyfikuje **kafle SC przed zoomem** (kafel = bruk, gdy 10+ z 16 minikafli ma `mx < 45`, `mx − mn < 10`; 1112 kafli). Potem próbkuje co 8 px te kafle i ich sąsiadów i oznacza komórkę jako bruk, gdy większość jej próbek trafia w bruk. Platformy SC to prostokąty z całych kafli, więc krawędzie wychodzą równymi schodkami. Na koniec 3 przejścia: domknięcie wcięć, usunięcie wypustek i okruchów (< 8 komórek). Wynik: 2564 komórki. Drzewa konwertera z bruku usunięte (4).
  - Kratka z kępkami trawy na platformach to był błąd PowerShella w pętli LAT (`$nx` = `$NX`, [[workflow/tooling]]), poprawiony.
- **Szwy woda/ląd** (użytkownik 2026-10-30: woda dotyka lądu bez klifu wodnego, np. jezioro na N od platformy przy moście): naprawiła je sesja ARKA 3 w `ScToDta.cs` (wspólny konwerter: `PruneBridges`, `RepairCoast`). Po przebudowie: konwerter 4 → 1 surowa krawędź, na końcu skryptu `RawCoast()` = 0 (linia „raw coast edges” w wyjściu). Wąskie mosty SC przez wodę zniknęły (28 zatoczek usuniętych, 0 przesmyków), miasto dalej jest połączone z bazą ARKI.
  - **Zostały szwy na końcach jezior** (użytkownik 2026-10-30, drugi zrzut): łańcuchy klifu wodnego obu brzegów dochodzą do wąskiego czubka jeziora i stają obok siebie, bo Water Cliffs nie mają kawałka końcowego. Zostaje szczelina zwykłej wody przy skalnej stronie kawałka albo przy gołym lądzie. Komórki DTA: długie jezioro 93–94,141 (koniec N), jezioro SE 129–131,154–156 (górna krawędź). `RawCoast()` ich prawie nie widzi (1 przed `FillWater`). Po `FillWater` zawsze daje 0, bo cała woda jest wtedy `Used`. Skrypt liczy go więc przed `FillWater`.
  - Próby w skrypcie misji, nieskuteczne i usunięte: (a) goły ląd przy wodnej komórce kawałka → woda + ponowne `RepairCoast()`: reguła `toLand` od razu odwraca taką komórkę; (b) „otwarcie” maski wody przed `Shores`: czubki nie są wąskie na poziomie `K`, szczelinę robią same łańcuchy.
  - Sesja ARKA 3 dodała do `RepairCoast` przejście po czubkach (`TipSeams()`). Na tej mapie oba szwy próbowało i cofnęło (`chain-end seams 2 -> 2`).
  - **Obejście w skrypcie terenu (2026-10-30):** oba czubki wypełnione lądem już w terenie SC, koło 1,5 kafla wokół SC (31,7; 40,8) i (46,7; 57,7). Środki wyliczone z komórek szwów wzorem dla zoomu 1,5: x = 8,5 + 0,75 sx + 1,5 sy, y = 103,5 − 0,75 sx + 1,5 sy (dopasowany na wp 30 i 41). Oba jeziora kończą się tępo, a klif je okrąża. Zostaje 1 szew (komórka 121,157, lewy górny róg jeziora SE przy drodze z platformy) i 1 surowa krawędź.
  - Dalsze próby tylko przesuwały szwy, bo łańcuchy kładzie się po kolei dla całej mapy. Trzecie wypełnienie przy (40,9; 55,4) dało 3 surowe krawędzie, a poszerzenie rogu wody przy (39,3; 55,3) dało nowy szew w 94,144. Obie próby wycofane.
  - Szwy, które zostaną, dostają krzak (`JBR*`) przykrywający krawędź, ale nie na drodze ani bruku. Ostatni szew leży na bruku, więc go nie dostał (0 z 1).
- **Grunt Antigi** jak w misji 4: nizina = błoto z kępami zarośli, płaskowyże = zarośla (`Autumn Grass`), bruk bez zmian.
- **Place i autostrada**: bruk wokół ARKI (r 6), wejść bazy W/S (wp 20/21), miejsca CC Raynora (wp 22) i bramy miasta (wp 42). `Paved Road LAT` z bramy miasta przez środek (wp 62) do wejścia zachodniego i dalej do ARKI, plus odcinki z wejścia południowego i z miejsca CC. **Wolnych końców 0.**
- **Złoża** ([[workflow/mission-design]]), same kryształy: minerały SC przy bazie pod północnym płaskowyżem (wp 15, 37 komórek, w zasięgu czołgów Duke'a), w środku (wp 56, sporne, z kopalnią) i w dzielnicy pałacowej (wp 57, w mieście); nowe pola: za bazą przy wschodniej krawędzi (wp 55, bezpieczne, 26), w zaroślach na południu (wp 58, bogate, 93, z kopalnią), na płaskowyżu północ-środek (wp 59, 34, z kopalnią). Kopalnie `OREMINE2` misja przestawia na niebieskie kryształy.
- Kontrole: 0 nieudanych łańcuchów klifów, wszystkie 47 waypointów osiągalne z ARKI.

## Waypointy (kontrakt teren ↔ misja)

Kafle oryginalnej mapy SC (128×96), skrypt przesuwa każdy na najbliższą wolną komórkę.

| Nr | Kafel SC | Co | Nr | Kafel SC | Co |
|---|---|---|---|---|---|
| 10 | 116,50 | ARKA (lokacja `Beacon`) | 30 | 16,80 | port: Hyperion na dużej platformie |
| 11 | 108,56 | armia startowa | 31 / 32 / 33 | 10,77 / 22,77 / 16,85 | zaczepy dokujące W, E, S |
| 12 | 121,44 | laboratorium Einsteina | 34 | 27,76 | oddział Raynora przy porcie |
| 13–18 | … | ConYard, koszary, rafineria (kryształy pod płaskowyżem), War Factory, 2 elektrownie | 35 | 7,84 | port: Starporty z Control Tower |
| 19 / 20 / 21 | 110,34 / 99,50 / 110,66 | obrona bazy: N, W (autostrada), S | 36 / 37 | 12,56 / 5,52 | dzielnica pałacowa (CC SC), skarbiec (skrzynka) |
| 22 | 124,63 | lądowisko CC Raynora | 38 | 35,68 | dzielnica przemysłowa |
| 45 / 46 | 30,10 / 96,8 | forty NW i NE na płaskowyżu | 39 | 30,28 | dzielnica północna: garnizon i badania |
| 47 / 48 / 49 | 112,22 / 101,30 / 92,64 | czołgi oblężnicze Duke'a: krawędź płaskowyżu N, mesa środek, mesa S | 40 | 12,68 | bloki mieszkalne (Supply Depoty) |
| 50 | 113,6 | kwatera Duke'a | 41 / 42 | 46,52 / 66,80 | posterunek przy moście, brama miasta |
| 51 / 52 / 53 / 54 | 100,1 / 66,84 / 104,95 / 127,86 | wloty fal: N, brama miasta, S, E-południe | 43 / 44 | 22,61 / 34,37 | skrzyżowanie, most do dzielnicy północnej |
| 55–59 | | pola kryształów (wyżej) | 60 / 61 | 34,6 / 118,80 | zbrojownia fortu NW, magazyn w zaroślach (skrzynki) |
| 62 / 63 | 80,56 / 56,52 | środek (zbiórka), wschodni koniec drogi z mostem | | | |

## Domy (etap 1)

| Dom | Rola |
|---|---|
| `Allies` (2) | gracz, 6000 kredytów, pełny tech Aliantów bez silosu; w etapie 1 także oddział Raynora i Tanya przy porcie |
| `GDI2` (8) | Raynor's Raiders (na przyszłość: CC Raynora, przekazanie) |
| `Soviet` (3) | **Dominium Terran**: miasto, port, garnizony (złoty kolor Synów Korhalu) |
| `GDI` (0) | **generał Duke** (Alpha Squadron, ciemnoczerwony jak w misji 4): forty, kwatera, czołgi oblężnicze |

## Miasto Dominium

Same budynki Terran SC (zasada z [[catalog/city-buildings]] i misji 5: miasta SC z budynków Terran w dzielnicach tematycznych, przybudówka przy prawym boku równo z dolną krawędzią, `Place-WithAddon`). Dzielnice:

| Dzielnica | Waypoint | Budynki |
|---|---|---|
| port kosmiczny | 30, 35 | 2 Starporty + Control Tower, Science Facility + Physics Lab, Hyperion (`ARKHYPD`) w środku platformy, 3 zaczepy (`ARKCLAMP`), 3 wieżyczki, 2 bunkry między oddziałem Raynora a portem, depoty |
| pałacowa | 36, 37 | CC + Comsat (siedziba Mengska), Science Facility + Covert Ops, 2 Academy, wieżyczki, bunkier na skrzyżowaniu |
| przemysłowa | 38 | 2 Factory + Machine Shop, 2 Armory, Engineering Bay |
| północna | 39, 44 | 2 Barracks, Science Facility + Physics Lab, Academy, Engineering Bay, bunkier przy moście |
| bloki mieszkalne | 40, 43 | 8 Supply Depotów w rzędach |
| posterunki | 41, 42 | bunkry, wieżyczki, depoty przy moście i bramie |

W każdej dzielnicy garnizon (`Area Guard`): Marines, Firebaty, Ghost, Goliaty, Siege Tanki, Vulture'y.

**Nowe typy w mapie:** `ARKHYPD` Hyperion zadokowany (grafika `SCBCF` na ziemi jak Norad II w misji 4, `Immune=yes`; etap 2 zamieni go na latającego bohatera z Yamato), `ARKCLAMP` zaczep dokujący (grafika Control Tower, 2000 HP, `Repairable=yes` dla C4 Tanyi, `ThreatPosed=0`). ARKA (`RAPDOX`) ma 28 000 HP i **nie** jest nietykalna (porażka po jej zniszczeniu).

**Duke**: kwatera na płaskowyżu N (Factory + Machine Shop, Armory, depoty, bunkier, złoty `SCHERO`), forty NW i NE z bunkrami, po 2 rozstawione Siege Tanki (`SCSIEGB`) z eskortą na wp 47, 48, 49 nad bazą.

## Budynki neutralne SC (sprawdzone 2026-10-30)

Pytanie użytkownika: czy StarCraft ma neutralne budynki do miasta. Wynik z `units.dat`/`images.dat`:

- **Z grafiką:** Norad II (`neutral\Cbattle.grp`, wrak), Ion Cannon (`neutral\ion.grp`), Psi Disrupter (`neutral\PsiDisr.grp`), Power Generator (`neutral\Generate.grp`), Stasis Cell (`neutral\stasis.grp`), świątynie Protossów i Xel'Naga, kryształy Khaydarin. W `unit/neutral/` leży też nieużywany `starbase.grp` (niebieska stacja 128×192).
- **Bez grafiki:** Cantina, Mining Platform, Independent Command Center, Independent Starport, Jump Gate, Ruins, Cave, Cave-in (jednostki 179–187) są rysowane grafiką Scouta. To puste wpisy.
- **Cywilne domy i sklepy SC** to **doodady terenu**, nie jednostki: w badlands (tileset Antigi i Mar Sary) doodady #29–#44 to sklepy z neonami, „zbrojownia”, szklane pawilony, domy; sprite'y `thingy/tileset/badlands/lcshop*.grp` i `lcsign*.grp` to tylko ich neony i szyldy. Podobne zabudowania mają tilesety desert (`JGB*`, `LDB*`), ice (`HDbld*`, `LDbld*`) i installation. Doodad = kolejne grupy `cv5` z `index=1` (bajty 12 `dddata`, 14 szerokość, 16 wysokość, 4 nakładka); arkusz: skrypt sesji `dood-sheet.ps1` (scratchpad).
- **Wniosek:** miasto z budynków Terran SC (jak w misji 5). Doodady cywilne badlands dałoby się wyciąć do SHP budynków DTA (maska z flag `vf4`), ale to osobny generator grafiki i numer MIX. **Nie zrobione, do decyzji użytkownika.**

## Do zrobienia (etap 2)

Triggery i teksty według planu: przerywnik (Mengsk, Einstein, Raynor, Duke), cel Hyperion (Raynor do portu, Tanya wysadza 3 zaczepy, Hyperion startuje jako bohater-Battlecruiser z Yamato), CC Raynora i tech Terran od połowy, licznik skoku 20 min, ostrzał Duke'a, fale z trzech stron (mocniejsze, jeśli w misji 5 zniszczono nadajniki), porażka (ARKA, Hyperion, bohaterowie), skrzynki (wp 37, 60, 61), rajdy na złoża, `BattleE.ini`, podgląd 300×200, film briefingu.
