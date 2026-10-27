# ARKA 0 „Ostatnia brama”: warstwa misji (triggery, dialogi, baza)

Skrypt, budynki i dialogi preludium kampanii [[plans/campaign-arka]] na terenie z [[missions/arka-00-gibraltar]]. Etap 1: pełny szkielet scenariusza (start, licznik 25:00, elektrownie, Tanya, fale, agent Nod, finał) i kluczowe budynki. Balans fal, trudność, Obeliski w Hiszpanii i przerywniki graficzne są na później. **(niezweryfikowane w grze)**

Źródła: `Modding/tools/build-arka00-mission.ps1`, `Maps/Custom/arka00_gibraltar.map` (teren, sesja mapy), [[engine/triggers-and-dialogue]] (format i wzorce z misji DTA), `INI/Rules.ini` (`[RAPDOX]`, jednostki), `INI/Art.ini` (fundamenty).

## Pliki

| Plik | Rola |
|---|---|
| `Maps/Missions/arka00.map` | misja; **nadpisywana** przy każdym uruchomieniu skryptu |
| `INI/BattleE.ini` | wpis klienta (nagłówek „ARKA: Blad znaku” + `M_ARKA00`, kategoria Standalone); nowy plik, pisany przez skrypt (`-NoBattle` pomija) |
| `Modding/tools/build-arka00-mission.ps1` | cała warstwa misji jako dane |
| `%TEMP%\arka00-mission\` | `log.txt`, `triggers.txt` (dekompilacja), render z `-Render` |

```powershell
powershell -NoProfile -File Modding\tools\build-arka00-mission.ps1            # ok. 1 min
powershell -NoProfile -File Modding\tools\build-arka00-mission.ps1 -Render    # + render do sprawdzenia rozstawienia
Modding\tools\dump-triggers.ps1 -Map Maps\Missions\arka00.map                 # czytelny podgląd logiki
```

Po przebudowie terenu przez sesję mapy wystarczy uruchomić skrypt ponownie (kontrakt: waypointy 10–45). Skrypt sprawdza, czy wszystkie są na mapie, i kończy się błędem, jeśli któregoś brak.

## Domy

| Dom | Rola | Sojusznicy |
|---|---|---|
| `Allies` (2) | gracz, 10 000 kredytów, krawędź południowa | `Allies1` |
| `Soviet` (3) | fale z Hiszpanii, strażnicy Tanyi | `Nod`, `Allies1` |
| `Nod` (1) | desanty z morza, Stealth Tanki, agent | `Soviet`, `Allies1` |
| `Allies1` (10) | Tanya przed odbiciem (złota); sprzymierzona ze wszystkimi, więc strażnicy jej nie ruszają | wszyscy |
| `Neutral`, `Special` | budynki cywilne z terenu | |

## Budynki i siły startowe

- **ARKA** = nowy typ `ARKACORE` (w mapie, `Image=RAPDOX`): 20 000 HP, `Armor=heavy`, bez supermocy, nie do zbudowania (`TechLevel=-1`), nie do przejęcia i sprzedania. Stoi na waypoincie 10 (lewy górny róg 117,130).
- **4 elektrownie** `RAPOWR` na środkach działek 11–14, każda z własnym tagiem.
- ARKA i elektrownie stają dokładnie na waypointach. Gdy fundament jest zablokowany (np. po przebudowie terenu), skrypt bierze najbliższe wolne miejsce i wypisuje `WARN` (teren v1: elektrownia 4 przesunięta z 132,136 na 131,136, bo stała pod klifem; teren v2: 0 przesunięć).
- Teren DTA jest płaski: w v2 wszystkie 29 083 komórki mają `Level=0`, a flaga `Ramp` w TMP wynosi 0 (sprawdzone 2026-10-26). „Poziomy” Skały to tylko kafle klifów z kodem 7/8, więc warunek „kod 0 albo 11–14” nie wpuszcza fundamentu na klif. Test wysokości z TMP byłby pusty i go usunięto. Rampy to zwykłe komórki bez klifu. Gdyby trzeba było odróżnić płaskowyż od nizin, zalewa się teren od wp 10 z pominięciem ramp (wp 28–33 i C1/C2). Dziś wystarcza promień szukania i render.
- **Baza** (skrypt szuka najbliższej wolnej działki z 1 komórką odstępu, poza działkami ARKI i elektrowni, **nie na drogach**: kod terenu 11 = kafle Paved Roads i bruk, żeby budynek nie zatkał przejazdu): `AFACT` Construction Yard, `RATENT` koszary, `RAPROC` rafineria, `AWEAP` fabryka, `RADOME` radar. Przy każdej bramie muru (15, 16) 2× `RAPBOX` i `RAGUN`.
- **Wojsko:** 3× `2TNK`, 2× `1TNK`, `RANG`, 6× `E1`, 3× `E3`, `MEDIC`, `ENGINEER`, a od 2026-10-27 też `RAHARV` (misja `Harvest`). Rafineria postawiona w mapie nie daje darmowego harvestera; gracz musiał go zbudować.
- **Skrzynka z odkryciem mapy** (ułatwienie na życzenie użytkownika): przy Construction Yardzie, `Add-RevealCrate` z `tools/MissionKit.ps1` ([[engine/triggers-and-dialogue]], pułapka 9). **(niezweryfikowane w grze)**
- **Tanya** (`TANYA`, dom `Allies1`, misja Sleep) na 17 w La Línea; straż sowiecka: 3× `E1`, `E2`, `E3`, 2× `DOG`, `3TNK` (Area Guard). Strefa odbicia: komórki w promieniu 3 od Tanyi.

Rozstawienie sprawdzone na renderze (CNCMaps): budynki stoją na trawie w mieście, bez kolizji z murem, drzewami i klifami.

## Przebieg (czasy w sekundach gry, 1500 = 25:00 na liczniku)

| Kiedy | Trigger | Co się dzieje |
|---|---|---|
| 1, 38, 78, 106, 134, 170 | Start 1–5 | kamera na ARKĘ, muzyka AWAIT, von Esling („…Ktoś musi zamknąć drzwi”), cel główny, **licznik 25:00 start (78)**, cel: elektrownie, Stavros o Tanyi, cel dodatkowy, znacznik radaru na 17. Odstępy wylicza `Set-DialoguePacing` z długości kwestii (wcześniej 6–12 s, za szybko) |
| 210 | Fala 1 | sama piechota (9× `E1`, 5× `E2`; czołg usunięty, test 4) z 18 → zbiórka na granicy (20), ~24 s czekania → atak w ruchu na ARKĘ (`16,10`) → Hunt; Hell March |
| 300 | Fala 2 | z 19 prosto na ARKĘ (`16,10` → `11,14`), bez zbiórki |
| 420 | Nod 1 | `NLST` z zatoki (41) na Camp Bay (26): 2× `ARTY`, 2× `LTNK`, 2× `BGGY` |
| 480 / 720 / 900 | Fale 3–5 | V2, Mamut i Shock Trooperzy, Mamuty + Tesla Tanki + V2 (fala 5 przesunięta z 1020 s); prosto na ARKĘ, bez zbiórki: duża grupa czołgów nie kończyła `3,20` i stała do końca misji (test 6) |
| 540 | Piechota Nod 1 | `NLST` 41 → Camp Bay (26): 4× `E1`, 3× `E3` (rakietowa), 3× `E4` (miotacze) |
| 600 | Jaki | 2× `YAK` na ARKĘ: `1,10` → `3,18` (powrót nad granicę) → `37,0` (znikają). Wcześniej `11,14`: po nalocie wisiały nad bazą (test 2026-10-27) |
| 660 | Transport Nod 1 | `NLST` 41 → Camp Bay (26): 2× `BIKE`, 2× `BGGY`, 2× `LTNK` |
| 780 | – | Einstein: połowa ładowania |
| 840 | Piechota Nod 2 | `NLST` z 42 na Catalan Bay (24), 10 piechoty |
| 900 | Tanya sama | jeśli nie odbita: przechodzi do gracza i przebija się sama, bez dokumentu |
| 960 | Nod 2 | 3× `STNK` pasem wschodnim (22 → 25 → 33 → ARKA, wszystko `16`) |
| 1080 | Transport Nod 2 | `NLST` z 45 na Eastern Beach (23): 3× `BIKE`, `BGGY`, 2× `LTNK` |
| 1140 | Nod 3 | `NLST` 45 → Eastern Beach (23): 3× `ARTY`, 2× `LTNK` |
| 1200 | Piechota Nod 3 | `NLST` z 43 na Europa Point (27), 10 piechoty |
| 1260 | Szturm | duża fala + Jaki, Stavros: „Pięć minut do skoku!” |
| 1310 | Piechota Nod 4 | `NLST` 45 → Eastern Beach (23), 10 piechoty |
| 1110 | Agent Nod | `SPY` Nod (w mapie `Disguised=no`, widoczny) z plaży Camp Bay (26) + odsłonięcie okolicy 26, skrypt `15,10` (wejście do ARKI); szpieg w przebraniu = „kameleon”. Wejście w pierścień 32 komórek wokół ARKI → błysk, agent przechodzi z `Nod2` (sojusz ze wszystkimi) do `Nod` i można go zabić, znacznik radaru, Einstein: „Zlapcie go, zanim ucieknie!”. Wcześniej znikał tylko z drużyny i zostawał nietykalny (test 2026-10-27) |

Desanty piechoty: `3,<plaża>` → `8,2` (rozładunek) → `16,10` → `11,14` (działa, test 3). Desanty pojazdów: wzór cr06 `3,<plaża>` → `8,2` → `11,14` i warianty `AIARTY`/`AILTNK`/`AIBGGY`/`AIBIKE` (`GuardRange=12`), bo z `16,10` wysadzone pojazdy stały **(niezweryfikowane w grze)**. Mapa podnosi `NLST` do 10 pasażerów. Poduszkowce (`HVC`, `HVR`, `HVCSAM`) usunięte: to rakiety chemiczne/hover spoza epoki (użytkownik).
| licznik = 0 | Finał 0–8 | wyłącza porażki, blokuje wejście, kamera na ARKĘ, dialog Einstein/Stavros („Plus siedem, profesorze”), błysk, „Kryształ jarzy się na zielono”, konsola `ROK DOCELOWY: 2499`, ostatnia transmisja von Eslinga, duży błysk, **wygrana** |

**Odbicie Tanyi:** wejście gracza w strefę → cały dom `Allies1` przechodzi do gracza (`36`), zmienna 0 „Tanya uratowana”, łańcuch: „Mam dokument Nod” → „Klop, drzewo, drugie drzewo, trzecie drzewo… Tarzan by się zarumienił” → „Kane wie o ARCE. I chce, żeby wystartowała.” → Einstein „Kim jest ten Kane?” → „Mamy jedno zdjęcie”.

**Tanya w bazie:** tag `ARKA0G11` na samej Tanyi i zdarzenie `34 Comes near waypoint` z waypointem 10 (ARKA) → „Ruscy przeszukali cały park, tylko nie klop i nie korony drzew… Zupełnie jak świnie.” Promień „near” nieznany **(niezweryfikowane w grze)**.

**Elektrownie:** każda zniszczona = tekst Einsteina + `Timer Extend 60` (licznik +1:00) + znacznik radaru.

**Porażka:** zniszczenie ARKI (zdarzenie `29`, bez infiltracji: agent może do niej wejść, bo i tak „kryształ już leży w rdzeniu”) albo utrata wszystkiego, albo **śmierć Tanyi** po jej przejściu do gracza (od 2026-10-27; wcześniej jej śmierć nic nie robiła). Trigger „Tanya zginela” jest powiązany z jej tagiem przez „Tanya w bazie” (pułapka 13 w [[engine/triggers-and-dialogue]]). Uzbraja się 5 s po zmianie domu, bo zmiana domu odpala „zniszczony” (pułapka 6), a finał go wyłącza. **(niezweryfikowane w grze)**

Dialogi: `[Tutorial]` mapy, numery 9001–9031, ASCII bez polskich znaków. Kwestie są skrócone z [[plans/campaign-arka]] (Preludium); finał jest prawie dosłowny.

## Test użytkownika 2026-10-27

- Misja jest na liście klienta (Campaign → Standalone Missions) i uruchamia się z `BattleE.ini`. `ARKACORE` się rysuje i dostaje prąd z elektrowni. Licznik działa.
- Rafineria bez harvestera → dodany `RAHARV`.
- Teksty szły za szybko, szczególnie po kilka naraz → `MissionKit.ps1` (jeden tekst na trigger, odstęp z długości, oś czasu 0 WARN), przypomnienie celu co 600 s usunięte.
- Desant Nod: poza poduszkowcami powinien być transport z podstawowymi pojazdami fabryki → dwa desanty `NLST` (660 s, 1080 s).
- W toku: test niszczenia elektrowni (+1:00 do licznika).
- **Test 3:** Rosjanie atakują bazę, desanty piechoty działają; wysadzone pojazdy Nod stoją (→ wzór cr06), szpiega nie widać (`Disguised=yes` = wygląda jak żołnierz gracza; pojawiał się na 22:30 i nie zdążał przed skokiem → widoczny, 1110 s).
- **Drugi test (2026-10-27):** desanty, Stealth Tanki i fale stały bezczynnie, szpieg nie wchodził do ARKI. Przyczyna: akcja skryptu `1,10` (pułapka 10 w [[engine/triggers-and-dialogue]]). Zamiana na `16,10`/`15,10`. Poduszkowce zastąpione transportowcami z `ARTY`. Doszły 4 transportowce piechoty (`E1`/`E3`/`E4`).

- **Test 5:** dwa załadowane `NLST` stały na Eastern Beach i nic z nich nie wyjechało. Pojazdy z transportowca nie wychodzą, piechota tak. Szpieg nie poszedł do ARKI (`15,10` nic nie zrobił). Ostatnia fala sowiecka zbierała się za wolno. Zmiany:
  - **desanty pojazdów** (`Landing` w generatorze): `NLST` płynie pusty, a pojazdy pojawiają się na waypoincie plaży, gdy transport wejdzie w strefę `[CellTags]` (zdarzenie `Entered by Nod`). Zapasowo po 150 s od startu, gdyby strefa nie odpaliła. Dwa desanty na jednej plaży: strefa wewnętrzna (r 0–1) i pierścień r 2–3. Pusty transport odpływa (`3,<morze>` → `37,0`). Desanty piechoty bez zmian, prawdziwy rozładunek działa;
  - **szpieg** w osobnym domu `Nod2`, sprzymierzonym z wszystkimi, więc nikt do niego nie strzela. Ma skrypt `3,10`. Wejście w pierścień wokół ARKI daje błysk, tekst i `5 Destroy Team` (szpieg „znika w rdzeniu”);
  - **szturm sowiecki** (1260 s): `16,10` → `11,14` od razu, bez zbiórki.
- **Test 6:** fala 5 (Mamuty, Tesla, V2) czekała na zbiórce do końca → fale 2–5 bez zbiórki, fala 5 o 2 min wcześniej (900 s). Zbiórkę ma tylko piechota fali 1.

## Do zrobienia (następne etapy)

- **Test w grze:** czy drużyny z `16,10` atakują bazę, czy `NLST` dopływają i rozładowują się na plażach 26/23/24/27, czy szpieg wchodzi (`15,10`), skrzynka, nowe tempo tekstów (`$GameSecPerReal`), elektrownie.
- Balans fal i warianty trudności (globalne 10–15, kopie triggerów E/N/H).
- Wysadzone/rozstawione Obeliski Nod nad zatoką (zasięg 9, zob. pułapka 4 w [[missions/arka-00-gibraltar]]) albo ostrzał skryptem.
- Spadochroniarze sowieccy (w planie), MiG-i.
- Agent Nod jako osobny typ (dziś zwykły `SPY` w domu Nod).
- Tanya „ranna” po samodzielnym przebiciu (dziś pełne HP).
