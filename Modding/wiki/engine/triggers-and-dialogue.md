# Triggery, drużyny i dialogi w misjach (format INI mapy)

Jak misja DTA/TS opisuje logikę: triggery (zdarzenia → akcje), tagi przypinane do obiektów i komórek, zmienne, drużyny (TaskForce + skrypt + TeamType), teksty dialogów i licznik. Wszystko jest tekstem w INI mapy, więc misję da się pisać skryptem, bez edytora.

Źródła: `Map Editor/FinalSun/FSData.ini` (słowniki `[Events]`, `[Actions]`, `[Scripts]`, `[ParamTypes]`: nazwy i parametry wszystkich ID), `Maps/Missions/rsovm1.map`, `cr01.map`, `SE01.MAP`, `Maps/Co-Op/freezingly_desperate_grip.map` (obrona Chronosfery na czas), skan `Timer Set` + tekstów we wszystkich `Maps/Missions` i `Maps/Co-Op`, `INI/Tutorial.ini`, `INI/Battle.ini`, `INI/Campaigns.ini`, `Resources/ClientDefinitions.ini`, `INI/Theme.ini`.

## Narzędzia

- **`Modding/tools/dump-triggers.ps1 -Map <mapa> [-Out plik]`**: dekompilator. Wypisuje każdy trigger z domem, flagami i tagiem, zdarzenia `IF` i akcje `DO` z nazwami z `FSData.ini`, teksty `Text Trigger` rozwiązane z `[Tutorial]` mapy albo `INI/Tutorial.ini`, zmienne lokalne, drużyny (skład + skrypt) i obiekty z tagami. Najszybszy sposób, żeby nauczyć się wzorca z misji DTA.
- **`Modding/tools/build-arka00-mission.ps1`**: pierwszy generator misji (zob. [[missions/arka-00-triggers]]). Ma mały DSL (`Trigger`, `Ev`, `Act`, `Text`, `Team`, `Reinf`, `Enable`/`Disable`), szukanie wolnych działek pod budynki i kontrole. Kolejne misje kampanii można robić na jego wzór.
- **`Modding/tools/build-arka02-mission.ps1`**: trzeci generator (zob. [[missions/arka-02-ewakuacja]]): `Team … -tag` (klucz `Tag=` w TeamType), eskorta kolonistów skryptem drużyny `39,N` + `37,0`, „dwa z trzech” na parach zmiennych, jeden licznik na dwa cele, kontrola „zmienna lokalna ze skryptu jest w `[VariableNames]`”.
- **`Modding/tools/MissionKit.ps1` `Add-ZergBuilder`**: komputer Zergów buduje bazę dronami (`4 Create Team` → wylęg w Wylegarni → `4 Move to cell` → `9 Deploy`, strażnik `80`), zob. [[engine/zerg-ai]]. Pierwsze użycie: `build-arka04-mission.ps1`.
- **`Modding/tools/build-arka01-mission.ps1`**: drugi generator (zob. [[missions/arka-01-marsara]]), ten sam DSL plus: kopiowanie typów StarCrafta do mapy z domknięciem zależności (`Get-ScClosure`), strefy-pierścienie `Zone` (jeden tag na komórkę, wewnętrzne najpierw), `Squad` sam stawia pojazdy SHP (Marines) w `[Units]`, kontrole „obiekt w sekcji zgodnej z listą typu” i „prerequisites wskazują istniejące typy”, scalanie `BattleE.ini`.

## Sekcje

| Sekcja | Format wartości | Uwagi |
|---|---|---|
| `[Triggers]` | `ID=Dom,PowiązanyTrigger,Nazwa,Wyłączony,Easy,Normal,Hard,0` | `PowiązanyTrigger` zwykle `<none>`; gdy jeden obiekt ma uruchamiać kilka triggerów, zob. pułapka 13. Flagi trudności `1/0`: DTA robi warianty E/M/H jako osobne triggery (`diff 100`, `010`, `001`). **Nazwa nie może mieć przecinka** (rozjeżdża pola). |
| `[Events]` | `ID=liczba,zd1,zd2…`, zdarzenie = `id,0,param` | **Wszystkie zdarzenia muszą zajść naraz (AND).** Np. `2,13,0,900,37,0,0` = „minęło 900 s i zmienna lokalna 0 wyczyszczona”. |
| `[Actions]` | `ID=liczba,ak1,ak2…`, akcja = `id,rodzaj,p1,p2,p3,p4,p5,waypoint` (8 pól) | `rodzaj`: `0` zwykły parametr, `1` p1 to ID drużyny (TeamType), `2` p1 to ID triggera. Waypoint zapisany literami. |
| `[Tags]` | `ID=trwałość,Nazwa 1,IDtriggera` | Tag to „uchwyt” przypinany do obiektu lub komórek. Trwałość: `0` jednorazowy, `2` powtarzalny (DTA: `Repeat obj`, nalot co N s). |
| `[CellTags]` | `y*1000+x=IDtagu` | Strefa wejścia: zdarzenie `1 Entered by` odpala, gdy jednostka danego domu wejdzie na którąś komórkę. |
| `[VariableNames]` | `n=Nazwa,0` | Zmienne lokalne 0…N (akcje 56/57, zdarzenia 36/37). |
| `[TaskForces]`, `[ScriptTypes]`, `[TeamTypes]` | lista `n=ID` | Każde ID ma własną sekcję (niżej). |
| `[Tutorial]` | `numer=tekst` | Teksty misji. Gra szuka numeru najpierw w mapie, potem w `INI/Tutorial.ini` (łatka ts-patches). |
| `[Briefing]` | `1=…`, `2=…` | Tekst odprawy, `@@` = nowy akapit (jak w `rsovm1.map`). |

Tag obiektu siedzi w polu wpisu obiektu: `[Structures]` pole 7 (`Dom,Typ,HP,X,Y,Kier,TAG,Sprzedawalny,…`), `[Units]` pole 8, `[Infantry]` pole 9. Jeden tag → jeden trigger. Drugi trigger na tym samym obiekcie przez pole `PowiązanyTrigger` **(niezweryfikowane)**, dlatego ARKA 0 tego nie używa.

### Waypointy w akcjach

Pole waypointu akcji i klucz `Waypoint=` drużyny używają liter: `A`=0 … `Z`=25, `AA`=26, `AB`=27 (bijektywny system o podstawie 26). Potwierdzone na `rsovm1.map`: drużyna `Waypoint=K` wjeżdża na waypoint 10. Akcje, w których waypoint jest **parametrem** (`17 Reveal around waypoint`, `63`, `64–66` błyski), biorą zwykłą liczbę w `p1`. Akcje „przy waypoincie” (`8`, `41`, `42`, `48`, `55`, `80`, `99`) biorą literę w polu 8.

### Drużyny

```ini
[ARKA0F01]            ; TaskForce: n=liczba,TYP
0=4,E1
1=1,3TNK
Name=Sowieci fala 1
Group=-1
[ARKA0S01]            ; ScriptType: n=akcja,parametr
0=3,20                ; Move to waypoint 20 (zbiórka)
1=5,4                 ; Guard area 4 x 6 s
2=16,10               ; Patrol to waypoint 10 = atak w ruchu na bazę (NIE 1,10, zob. pułapka 10)
3=11,14               ; Assign new mission: 14 = Hunt
Name=Sowieci fala 1
[ARKA0M01]            ; TeamType (pełna lista kluczy w build-arka00-mission.ps1)
House=Soviet
TaskForce=ARKA0F01
Script=ARKA0S01
Waypoint=S            ; start drużyny (litera)
```

**Tag drużyny:** klucz `Tag=<ID tagu>` w TeamType przypina tag do każdego członka stworzonego przez drużynę (DTA: 267 użyć w 44 misjach, np. `cr07` „Soviet1 MCV” z tagiem „genocide”). Tak bohater, który pojawia się akcją `80`, może mieć trigger „zginął” **(niezweryfikowane w grze, ARKA 2)**.

**Eskorta i „wsiadanie”:** skrypt `3,<meta>` → `39,N` (ustaw zmienną lokalną N) → `37,0` (usuń członków drużyny). Zmienna oznacza „doszli”, usunięcie „wsiedli do transportu”. Porażkę grupy liczy `11 Destroyed, All` jej domu **razem z** `37 Local is clear N` (usunięcie też opróżnia dom), a trigger porażki włącza się dopiero kilka sekund po pojawieniu się grupy (pusty dom na starcie). Wzór: [[missions/arka-02-ewakuacja]].

Misje w akcji 11 skryptu: `14` Hunt (366 użyć w misjach DTA), `10` Area Guard (263), `5` Guard, `0` Sleep. Akcje skryptu w misjach DTA (skan `Maps/Missions`, bez ARKA): `3` move to waypoint (≈2000), `16` patrol = atak w ruchu (≈1400), `0` attack target type (≈850), `11` nowa misja (≈700), `4` move to cell, `5` guard na czas, `46` attack enemy structure, `15` spy on structure at waypoint (szpieg wchodzi do budynku). Najczęstsze sekwencje drużyn naziemnych: `3,N | 11,N` i `16,N | 11,N`. **`1` attack waypoint** pojawia się prawie wyłącznie w skryptach samolotów („Attack N and fly away”); drużyny naziemne stają na nim na stałe (pułapka 10). Pełna lista: `[Scripts]` w `FSData.ini`.

## Najważniejsze zdarzenia i akcje

| Zdarzenie | Param | Do czego |
|---|---|---|
| `1` Entered by | dom | strefa z `[CellTags]` albo wejście do budynku |
| `4` Discovered by player | – | odkrycie obiektu z tagiem (cr01: odsłonięcie sojuszników) |
| `8` Any Event | – | odpala od razu (ze znanym błędem przy starcie; DTA woli `13` z 0–1) |
| `11` Destroyed, All | dom | porażka/wygrana „wszyscy zniszczeni” |
| `13` Elapsed Time | sekundy | czas od **utworzenia albo włączenia** triggera (niżej) |
| `14` Timer Expired | – | licznik na ekranie doszedł do zera |
| `27`/`28` Global set/clear | nr | zmienne globalne, w tym poziom trudności (niżej) |
| `29` Destroyed by anything [not infiltrate] | – | zniszczenie obiektu z tagiem, **bez** wejścia szpiega |
| `36`/`37` Local set/clear | nr | stan misji |
| `48` Destroyed by anything | – | zniszczenie, przejęcie **albo** infiltracja (szpieg w budynku odpali „porażkę”!) |

| Akcja | Param | Do czego |
|---|---|---|
| `1`/`2` Winner/Loser is | dom | koniec misji (dom gracza = wygrana/porażka) |
| `7` Reinforcement (team) | drużyna (rodzaj 1) | jednostki z krawędzi `Edge=` domu |
| `80` Reinforcement at waypoint | drużyna + litera | jednostki pojawiają się na waypoincie („poof”); fale ataku i desanty |
| `11` Text Trigger | nr tekstu | dialog/cel na ekranie |
| `14` Change House | dom | zmienia dom obiektów z tym tagiem |
| `36` All change house | dom | **cały dom triggera** przechodzi do podanego (przejmowanie rozbitków, cr01) |
| `17` Reveal around waypoint | nr waypointu | odsłonięcie okolicy |
| `20` Play Music Theme | indeks z `Theme.ini [Themes]` | np. `43` HELL226M (Hell March), `58` AWAIT |
| `21` Play speech | indeks EVA | |
| `23`/`24`/`25`/`26`/`27` Timer start/stop/extend/shorten/set | sekundy | licznik na ekranie |
| `46`/`47` Lock/Unlock input | – | przerywnik na silniku |
| `48` Center camera | prędkość 0–4 + litera | |
| `53`/`54` Enable/Disable trigger | trigger (rodzaj 2) | łańcuchy i warianty |
| `55` Create radar event | typ 1–6 + litera | `3` strefa zrzutu (czerwony), `4` baza atakowana, `6` wykryty wróg (żółty, na stałe) |
| `56`/`57` Local set/clear | nr | |
| `64`/`65`/`66` Light flash small/medium/large | nr waypointu | błysk (finał ARKI) |

Pełne listy z opisami: `[Events]` (0–55) i `[Actions]` (0–117, od 106 akcje łatki ts-patches: kredyty, auto-save, ciche usunięcie obiektu) w `FSData.ini`.

## Czas: sekundy gry, nie realne

- `Elapsed Time` i `Timer Set/Extend` liczą **sekundy zegara gry** (15 klatek logiki). Autorzy DTA piszą tak, jak pokazuje licznik: `crc10` ustawia `600` przy tekście „MCV will arrive … in 10 minutes”, `se06` `1200` = „within 20 minutes”, `seext` `10800` = „3 hours”. Więc `1500` = **25:00 na liczniku**.
- Realny czas jest krótszy, bo gra chodzi szybciej niż 15 klatek/s (zob. [[workflow/known-mistakes]]: skirmish 60 FPS, kampania zależnie od prędkości gry). **(niezweryfikowane: ile realnie trwa 25:00 w kampanii)**
- **Łańcuch dialogów:** trigger wyłączony (`Wyłączony=1`) z `Elapsed Time N` liczy N od chwili `Enable Trigger`. Tak DTA robi opóźnione posiłki (cr01: „bonus” włączany z `Elapsed 10/20/50`) i serie naloty (`freezingly_desperate_grip`: `MIG strike` wyłączony, powtarzalny, `Elapsed 2`, sam się wyłącza). Dialog = trigger z tekstem, który włącza następny. Odstęp 5–7 s gry okazał się **za krótki** (test ARKA 0), zob. niżej.

## Tempo dialogów (test użytkownika 2026-10-27: „tekst za szybko idzie”)

Objaw: w ARKA 0 kwestie znikały, zanim dało się je przeczytać, najgorzej przy kilku tekstach naraz. Przyczyny:

1. **Sekunda gry ≠ sekunda realna.** `Elapsed Time 7` to 7 × 15 klatek logiki, a gra chodzi szybciej niż 15 klatek/s (skirmish: zmierzone 45–60). 7 „sekund” to ok. 2 realne sekundy.
2. **Kilka akcji `11 Text Trigger` w jednym triggerze** pokazuje wszystkie teksty w tej samej klatce. Długie kwestie łamią się na 2–3 linie i nowe wypychają stare.
3. **Niezależne triggery czasowe trafiały na siebie:** fala z tekstem w trakcie łańcucha wstępu, powtarzalne przypomnienie co 600 s na tekście nalotu.

Reguły (wdrożone w `Modding/tools/MissionKit.ps1`, dołączanym przez generatory misji):

- **Jeden tekst na trigger.** `Split-MultiText` sam rozbija trigger z kilkoma tekstami na łańcuch; akcje `Enable` przechodzą do ostatniego ogniwa.
- **Odstęp = czas czytania poprzedniej kwestii:** `(3 s + znaki / 12) × 3` sekund gry. Na przykład 110 znaków daje 37 s gry, czyli około 12 s realnie. Współczynnik 3 (`$GameSecPerReal`) jest **(niezweryfikowany w grze)**: po teście stroić tylko tę stałą. `Set-DialoguePacing` wydłuża krótkie `Elapsed` w łańcuchach dialogów, dłuższe ręczne zostawia.
- **Oś czasu bez nakładek:** `Test-TextTimeline` liczy czasy triggerów czasowych i ich łańcuchów, wypisuje je do `log.txt` i daje `WARN`, gdy tekst zaczyna się przed przeczytaniem poprzedniego albo trigger ma kilka tekstów. Misja ma mieć 0 WARN. Wyjątkiem są kwestie zależne od zdarzeń gracza (strefy, śmierci), których czasu nie da się policzyć.
- **Test 2026-10-29 (ARKA 0): z `$GameSecPerReal = 3` dalej „nie ma czasu czytać”.** Generator może nadpisać stałą zaraz po dołączeniu `MissionKit.ps1` (`$GameSecPerReal = 4.5` w `build-arka00-mission.ps1`; `Get-ReadSecs` czyta ją przy każdym wywołaniu). Domyślne 3 zostało dla innych misji do ich testu. 110 znaków daje teraz 55 s gry.
- **Fale nie w trakcie dialogu:** `Test-QuietDialogue` (zasada 6 w [[workflow/mission-design]]). Czasy triggerów liczy wspólna funkcja `Get-TriggerTimes`, której używa też `Test-TextTimeline`.
- Kwestie krótkie (do ok. 110 znaków). Powtarzalne przypomnienia celu tylko przez `Add-ObjectiveReminder` (niżej), rzadko: co 900 s gry i tylko dla otwartego celu.

**Przypominajki celów i postęp (od 2026-10-29, prośba użytkownika „do wszystkich misji, ale nie przesadzaj”)**, `MissionKit.ps1`, wywołanie przed `Split-MultiText`:
- `Add-ObjectiveReminder 'remNest' 'Cel (przypomnienie): ...' -From 'nestObj' -Until 7 [-Every 900]`: wyłączony, powtarzalny trigger z jednym tekstem co `Every` sekund gry. Włącza go trigger `From` (kilka kluczy = alternatywy, np. strefa albo czas; `Enable` dopisane na końcu, więc po `Split-MultiText` trafia za ostatnią kwestię celu). Jednorazowy trigger `<klucz>~off` wyłącza go, gdy wszystkie zmienne lokalne z `Until` są ustawione; bez `Until` generator wyłącza go sam (`Disable '<klucz>'`).
- `Add-CountProgress 'surv' @(0,1,2) { param($k,$n) "Rozbitkowie: $k z $n ..." }`: kwestia przy k-tej z n ustawionych zmiennych (k = 1…n−1), w dowolnej kolejności. Na każdy k-elementowy podzbiór jeden jednorazowy trigger (`36 Local is set` dla każdej, AND), pierwszy wyłącza rodzeństwo. n z n to własna kwestia „cel wykonany” misji. Do 4 zmiennych.
- Oba **(niezweryfikowane w grze)**. Powtarzalny trigger z `13 Elapsed Time` liczy czas od nowa po każdym odpaleniu (tak działają powtarzane naloty DTA).
- Trigger bez tekstu po ostatniej kwestii (błysk, wygrana) potrzebuje ręcznego `Elapsed` ≥ czas czytania (`Get-ReadSecs`), bo pacing go nie wydłuża.
- `MessageDelay=4.0` w `Rules.ini [AudioVisual]` to czas wiadomości multiplayer. Czy dotyczy też `Text Trigger`, **(niezweryfikowane)**. Problemem był odstęp, nie czas wyświetlania.

## Dialogi i teksty

- Każda kwestia to akcja `11 Text Trigger` z numerem linii `[Tutorial]`. Konwencja DTA: `Mówca: tekst` („Nod Officer: …”, „Soldier: …”, „EVA: …”), cele jako `Objective N: …`, `HINT: …`, `Bonus Objective: …`.
- Numery: `Tutorial.ini` ma 2843 linie z kluczami do 60035, więc numery nie mają limitu. Mapa może mieć własną sekcję `[Tutorial]` (68 map DTA tak robi) i ona ma pierwszeństwo. Kampania ARKA rezerwuje **9000 + 100·nr misji** (ARKA 0 = 9001–9099, misja 1 = 9101–9199…); zakres 9000–9699 jest w `Tutorial.ini` pusty.
- **Bez polskich znaków.** Mapa jest w Windows-1252, a czcionka gry ma tylko znaki 1252; `ą, ł, ś, ż` się nie zapiszą. Piszemy ASCII („Rdzen naladowany w polowie”). Czy czcionka ma `ó` (jest w 1252): **(niezweryfikowane)**, więc też bez.
- Kwestie mówione: `21 Play speech` (EVA) i `19 Play sound` (z `Sound.ini`). Głosów postaci DTA w misjach nie ma; dialog jest tekstowy.

## Poziom trudności

**Selektor:** suwak trudności w oknie kampanii klienta (`trbDifficultySelector`, `Resources/CampaignSelector.ini`). Etykiety domyślne Easy/Medium/Hard. `DifficultyLabels=NORMAL,HARD,BRUTAL` w sekcji misji zmienia napisy, a `HasExtendedDifficulty=yes` dodaje czwarty poziom (Brutal). Klient zapisuje wybór w `spawn.ini` (`DifficultyName`, `ClientDifficulty=10`, `DifficultyModeHuman`, `DifficultyModeComputer`; komputer ma skalę odwróconą: Easy = 2). Do kopii mapy (`spawnmap.ini`) dokleja trigger `DifficultyGlobal` (`Neutral`, zdarzenie `8 Any Event`), taki sam jak bloki `INI/Map Code/Difficulty *.ini` w co-op. Ustawia on zmienne globalne (`Campaigns.ini [GlobalVariables]`):

| Poziom | Globalne ustawione |
|---|---|
| Easy | `10`, `13` (Easy lub Medium) |
| Medium | `11`, `13`, `14` (Medium lub Hard) |
| Hard | `12`, `14` |
| Brutal | `12`, `14`, `15` |

Misje DTA robią **kopie triggerów** z `27 Global is set 10/11/12` (skan `Maps/Missions`: 727/726/801 zdarzeń) i bonusowe fale na `27 Global is set 12`. Flagi E/N/H w `[Triggers]` przy `PlayerAlwaysOnNormalDifficulty=yes` nie pomagają, bo gracz jest wtedy zawsze na Normal.

**Mnożniki domów nie idą za poziomem w mapie.** Vinifera podmienia `HouseClass::Assign_Handicap` (`game.exe` `0x4BB460`) na `HouseClassExt::_Assign_Handicap`. W kampanii (`Session.Type == GAME_NORMAL`) dom dostaje `Armor`, `Cost`, `BuildTime`, `ROF` i `Groundspeed` **wyłącznie** z sekcji trudności, a mnożniki kraju (`[Allies] Armor=`) są pomijane. Sekcje `[Easy]`, `[Normal]`, `[PlayerNormal]` (DTA: `[General] HasPlayerNormal=yes`, człowiek na Normal) i `[Difficult]` czyta tylko `RulesClassExtension::Difficulty` w `Process` (`Rules.ini`), nie ze scenariusza. Bez `PlayerAlwaysOnNormalDifficulty` człowiek na Easy dostaje `[Easy]`, a z tej samej sekcji korzysta komputer na Hard. Więc „+10% HP tylko na Easy” mapą się nie da. Możliwe są tylko globalne zmiany `Rules.ini` (dla całego DTA) albo osobne typy jednostek.

**ARKA (od 2026-10-28):** `Add-Difficulty` w `Modding/tools/MissionKit.ps1`, wołane przez każdy generator po `Set-DialoguePacing`. Misja w wersji z generatora to **Hard**. Na Easy fale wroga mają połowę jednostek, a kasa gracza jest podwojona. Medium daje 3/4 fal i +50% kasy.
- Akcje `80`/`7` z drużyną domu spoza `Allies=` gracza przechodzą do trzech triggerów-pomocników (wyłączone, powtarzalne, `13 Elapsed 1` + warunek poziomu, na końcu same się wyłączają). Oryginał je włącza. Easy: `27 Global is set 10`. Medium: `27 … 11`. Hard: `28 Global is clear 10` + `28 … 11`, więc misja bez klienta też działa jak Hard. Sekunda opóźnienia jest po to, żeby trigger klienta zdążył ustawić globalne.
- Drużyny Easy/Medium to kopie TeamType z sufiksem `E`/`M` (ten sam skrypt i tag) i przeskalowanym TaskForce. Suma ładunku jest zaokrąglana w górę (min. 1) i rozdzielana metodą największych reszt. Transporty (`Passengers>0`: `NLST`, Overlord) zostają. Drużyna, którą nazywa inna akcja (`4 Create Team` budowniczego Zergów), ma jeden rozmiar.
- Kasa: trigger `diffStart` daje na starcie +100%/+50% `Credits` domu gracza (`106`). Każda akcja `106` dla gracza (skrzynki, nagrody) dostaje dopłatę w pomocniku E/M. Liczniki na kredytach innych domów (ARKA 5) zostają bez zmian. Pieniądze z wydobycia i premia drewnianej skrzynki (`SoloCrateMoney`) rosnąć nie mogą.
- Istniejące „fale tylko na Hard” (`27 Global is set 12`) zostają, więc Medium ich nie ma.
- **(niezweryfikowane w grze)**: działanie `Global is set` na globalnych z triggera klienta w tej samej misji (DTA tak robi), samowyłączające się pomocniki.

## Domy w misji

- `[Houses]` w mapie powtarza 14 domów z Rules (0 GDI … 13 Soviet2). Własne domy dopisuje się od 14 (SE01: `14=Player`, cr01: `TLAllies`). Można też grać standardowym domem: `rsovm1` ma `Player=Soviet`, ARKA 0 `Player=Allies`.
- Sekcja domu: `IQ, Edge, Side, Color, Allies, Credits (×100), ActsLike, NodeCount, TechLevel, PercentBuilt, PlayerControl`. `Allies=` to lista sojuszników (wzajemność trzeba wpisać po obu stronach).
- **Wzorzec „ukryty sojusznik”**: postać do odbicia (Tanya w ARKA 0) należy do domu pomocniczego (`Allies1`) sprzymierzonego ze wszystkimi, więc strażnicy jej nie atakują. Wejście gracza w strefę → `36 All change house` (trigger w domu `Allies1`) przenosi ją do gracza i od tej chwili jest wrogiem strażników.

## Komputerowy dom, który „gra” (sojusznik albo wróg)

Wzorzec z misji DTA (`Production Begins` w 305 akcjach, `AI triggers begin` w 282, własne `[AITriggerTypes]` w 44 mapach), użyty dla osady Raynora w [[missions/arka-01-marsara]]:

- **Dom:** `IQ=5` (`[IQ] Production=5`: od tego poziomu AI samo produkuje; `Harvester=2`: wymienia utracone zbieracze), `Credits`, fabryki i rafineria postawione w mapie, zbieracze z misją `Harvest`.
- **Węzły bazy** w sekcji domu: `NodeCount=N` i `000=TYP,x,y`… AI odbudowuje te budynki (potrzebuje typu z `[AI] BuildConst`; Vinifera inaczej nie zbuduje żadnej struktury).
- **Akcja `3 Production Begins`** (dom) uruchamia produkcję i odbudowę, a **`74 AI triggers begin`** wysyłanie drużyn z AI triggerów.
- **`[AITriggerTypes]`**: `ID=Nazwa,Drużyna,Dom,TechLevel,-1,<none>,<64 zera>,50,30,70,1,0,Strona,0,<none>,1,1,1` (warunek −1 = zawsze, wagi start/min/max, flagi E/N/H). **Strona to `ActsLike` domu + 1 albo 0 (każdy dom), a nie indeks z `[Sides]`**: `AITriggerTypeClass::Process` (`game.exe` `0x4109EF`) odrzuca trigger, gdy `MultiSide ≠ 0` i `MultiSide − 1 ≠ HouseClass::ActLike` (`+0xC0`, z `Vinifera.pdb`). Dla domów bazowych to się zgadza (Soviet: `ActsLike=3`, strona 4), dla `GDI1` (`ActsLike=6`) potrzeba 7. Z wartością 1 osada w ARKA 1 nie zbudowała ani jednej jednostki (test 2026-10-27), bez żadnego błędu w logu + `[AITriggerTypesEnable] ID=yes`. Drużyny: `Autocreate=no`, `AreTeamMembersRecruitable=yes`, `Max=` instancji naraz; skrypt jak zwykle (ruch, atak waypointu, Hunt albo Area Guard).
- Grupy `[General] PrerequisiteFactory/Barracks` muszą znać fabryki domu (Marines z modu SC mają `Prerequisite=FACTORY`, a Terran Factory dopisuje do tej grupy dopiero `StarCraft.ini`), a `[General] HarvesterUnit` jego zbieracza.

## Rejestracja misji w kliencie

- `INI/Battle.ini`: `[Battles]` (lista `klucz=SEKCJA`, nagłówki `HEADER_*`, odstępy `X_SPACING=.`) + sekcja misji: `Scenario=Maps/Missions/<plik>`, `Description`, `Side=` (indeks domu: 2 = Alianci), `IconPath`, `LongDescription` (`@@` = akapit, albo blok `$$$TextBlockBegin$$$ … $$$TextBlockEnd$$$`), `Categories=` (z `Campaigns.ini [Categories]`), `UnlockMissions=`, `RequiresUnlocking=`, `StartCutscene/EndCutscene`.
- `Resources/ClientDefinitions.ini` ma `BattleFSFileName=BattleE.ini`: drugi plik misji, którego DTA nie dostarcza. Kampania ARKA trzyma wpisy właśnie tam (`INI/BattleE.ini`, pisany przez generator), żeby nie ruszać `Battle.ini`, który podmienia aktualizator. Klient pokazuje misje z `BattleE.ini` bez dodatkowego klucza: sprawdzone w grze 2026-10-27 (nagłówek „ARKA: Blad znaku” i obie misje są na liście).
- `Author=` w sekcji misji to napis „Mission Author:” w oknie kampanii (ARKA: `Zema`). Pole `Author` w `[Basic]` mapy klient tu nie pokazuje, ale generatory trzymają je zgodne.
- **Podgląd misji** to plik `<nazwa mapy>.png` obok mapy (`Maps/Missions/a_bridge_too_few.png`), bez żadnego klucza w INI. Format: PNG **300x200** (kilka starych ma 320x200), czyli kadr ze sceną w skali ok. 0,5–0,6. Dla ARKI robi go `Modding/tools/build-arka-previews.ps1`: kopia mapy misji dostaje „ustawioną” scenę (jednostki z kierunkami, kratery `CR*` w `[Smudge]`), CNCMaps ją renderuje, a skrypt wycina okno i skaluje do 300x200. Piksel renderu na komórkę: `px = (x−y+W−1)·24 − LX·48 + 24`, `py = (x+y−W−1)·12 − LY·24 + 60` (`W` z `[Map] Size`, `LX/LY` z `LocalSize`; +60 zmierzone, bo sprite stoi niżej niż wynika ze wzoru izometrii). Kierunki jednostek: 0 = północ mapy, a na ekranie 224 = w górę, 96 = w dół, 160 = w lewo, 32 = w prawo.
- `BattleE.ini` piszą generatory kilku misji: każdy **scala** swój wpis z istniejącym plikiem (od 2026-10-26 także `build-arka00-mission.ps1`), żadnego nie nadpisuje w całości.
- **Misja kampanii nie ładuje opcji gry ani kodu mapy frakcji** (`INI/Game Options/*.ini`, `INI/Map Code/*.ini` to rzeczy lobby skirmisha). Jednostki z modów, które żyją tylko tam (wszystkie typy StarCrafta), trzeba skopiować do INI mapy razem z bronią, pociskami, głowicami i animacjami, które nazywają, i zarejestrować w listach typów. `$Inherits` z mapy nie sięga do Rules, więc kopie typów z Rules rozwija się ręcznie. Wzór: [[missions/arka-01-marsara]].
- `[Basic]` misji: `Player=<dom gracza>`, `MultiplayerOnly=no`, `HomeCell=<numer waypointu>` (nie komórka), `SkipMapSelect=yes`, `OneTimeOnly=yes`, `Theme=<utwór>`, `RequiredAddOn=1`, `MinPlayer=2`, `MaxPlayer=0` (jak SE01).

## Pułapki

1. Przecinek w nazwie triggera lub tagu przesuwa pola: trigger dostaje złe flagi trudności i traci tag (złapane w ARKA 0: „Fala 3: Sowieci, V2” → `diff 011`).
2. `48 Destroyed by anything` liczy też infiltrację. Jeśli do budynku-celu może wejść szpieg wroga, porażkę wiąż z `29`.
3. `Any Event (8)` przy starcie bywa zawodny; DTA zaczyna od `Elapsed Time 0/1`.
4. **Desant z transportowcem** (wzór `cr06.map`): pierwszy wpis TaskForce to transport (`1,NLST` dla Nod, `ALST` Alianci; 6 miejsc, wozi też pojazdy), dalej ładunek (`2,BIKE`, `2,BGGY`…). Akcja `80` tworzy drużynę na waypoincie morskim z ładunkiem już w środku. Skrypt: `3,<plaża>` → `8,2` (Unload; `2` = transport odchodzi z drużyny, ładunek gra dalej) → `1,<cel>` → `11,14`. Bez transportu w TaskForce `80` stawia jednostki na waypoincie („poof”), więc pojazdy lądowe muszą wtedy startować na lądzie, a z morza mogą przyjść tylko poduszkowce (`HVC`, `HVR`, `HVCSAM`, `SpeedType=Hover`). **Pojazdy z transportowca nie wychodzą** (ARKA 0, dwa testy: `NLST` z pojazdami stały na plaży, także ze skryptem jak w cr06 `8,2` → `11,14` i wariantami `AILTNK`/`AIBGGY`/`AIARTY`). Piechota z tych samych transportowców wysiada i atakuje. Obejście (`Landing` w `build-arka00-mission.ps1`): pusty `NLST` płynie na plażę, a pojazdy pojawiają się akcją `80` na waypoincie plaży, gdy transport wejdzie w strefę `[CellTags]`, albo zapasowo po czasie **(niezweryfikowane w grze)**. Skrypt `15,N` (spy on structure) też nic nie zrobił. Wejście szpiega jest dlatego udawane: pierścień `[CellTags]` wokół celu + `5 Destroy Team`, a szpieg należy do domu sprzymierzonego z graczem, żeby go nie ostrzeliwano. **Szpieg** (`SPY`) ma `Disguised=yes`: gracz widzi go jako własnego żołnierza; żeby był widoczny, w mapie `[SPY] Disguised=no`. Ładowność można podnieść w mapie (`[NLST] Passengers=10` w ARKA 0, nadpisanie reguł mapą). ARKA 0: 8 desantów `NLST` na 4 plaże **(niezweryfikowane w grze)**.
5. Generatory w PowerShellu: aliasy wygrywają z funkcjami (`Ac` = `Add-Content`, `Group` = `Group-Object`, `R` = `Invoke-History`), `$n` = `$N`, a `Group-Object` z jednym wynikiem zwraca skalar, nie tablicę (`@()`!). Zob. [[workflow/known-mistakes]].
6. **`36 All change house` / `14 Change House` to dla silnika przejęcie**, a przejęcie odpala na tagu obiektu zdarzenie „zniszczony” (`29`, też `48`). Trigger „X zginął → porażka” na tagu bohatera, którego dom się zmienia, daje fałszywą przegraną (ARKA 1, 2026-10-27: Raynor po ocaleniu osady). Reguła: w tej samej liście akcji **najpierw** `54 Disable` triggera porażki, potem zmiana domu, a po kilku sekundach `53 Enable` z osobnego triggera `Elapsed`.
7. **Budynek postawiony w mapie nie dostaje darmowej jednostki** (rafineria bez harvestera, test ARKA 0): `RAHARV` z misją `Harvest` trzeba dopisać do `[Units]`.
8. **Tekst za szybko:** zob. „Tempo dialogów”.
9. **Skrzynka z odkryciem mapy** (ułatwienie, w każdej misji ARKA obok bazy): `Add-RevealCrate` z `MissionKit.ps1` kładzie nakładkę `SCRATE` (`[OverlayTypes]` 61, `CrateTrigger=yes`), ustawia `[Powerups]` mapy na sam `Reveal` i dodaje tag komórki „wejście gracza → `16 Reveal all map`”. Akcji „utwórz skrzynkę” w TS nie ma (`FSData.ini`), więc skrzynka jest nakładką w `OverlayPack`. **(niezweryfikowane w grze)**
   **Skrzynka z pieniędzmi** (od 2026-10-27, [[workflow/mission-design]]): `Add-MoneyCrate x y kwota 'tekst'` kładzie drewnianą `CRATE` (`[OverlayTypes]` 179). W misji solo daje ona `[CrateRules] WoodCrate=Money` (`SoloCrateMoney=2000`). Do tego tag komórki z akcją **`106 Give Credits`** (ts-patches): `106,0,<indeks domu>,<kredyty>,0,0,0,A`, kwota w zwykłych kredytach (cr05: 3000, a_bridge_too_few: 5000). `[Powerups]` po `Add-RevealCrate` nie przeszkadza, bo w misji solo skrzynka drewniana i stalowa biorą premię z `[CrateRules]`, a nie z losowania. **(niezweryfikowane w grze)**
10. **Drużyny naziemne stoją bezczynnie na akcji skryptu `1,N` (Attack waypoint).** Test ARKA 0 (2026-10-27): fale sowieckie zebrały się na granicy i nie zaatakowały, desanty i Stealth Tanki stały, szpieg nie wszedł do ARKI. Wszystkie stawały na `1,10`. W DTA `1,N` mają tylko samoloty. Reguła: atak naziemny to `16,<cel>` + `11,14`, szpieg: `15,N` też nic nie dał (test 5), więc wejście jest udawane, zob. „Pojazdy z transportowca” wyżej. Generator ARKA 0 daje `FAIL`, gdy drużyna bez samolotów ma `1,N` w skrypcie. Zdarzenie „szpieg wszedł” bez drugiego tagu na budynku: pierścień `[CellTags]` wokół celu i trigger `Entered by Nod`, wyłączony do chwili pojawienia się szpiega **(niezweryfikowane w grze)**.
11. **Zbiórka `3,N` dużej grupy pojazdów nigdy się nie kończy.** Ruch do waypointu kończy się, gdy **każdy** członek drużyny stoi przy waypoincie, a tłum czołgów (Mamuty, Tesla Tanki, V2) nie mieści się wokół jednej komórki. Fala 5 w ARKA 0 stała na zbiórce do końca misji (test 2026-10-27). Piechota z fali 1 dochodziła bez problemu. Reguła: zbiórka (`3,N` + `5,N`) tylko dla piechoty i małych grup; fale pojazdów `16,<cel>` → `11,14` od razu.
12. **Samolot bez lotniska wisi nad celem.** Test ARKA 0 (2026-10-27): Jaki (`Ammo=1`, `Dock=` lotniska sowieckie, których na mapie nie ma) ze skryptem `1,10` → `11,14` po jednym nalocie zawisły w powietrzu nad bazą gracza. Hunt każe szukać celu, a bez amunicji i miejsca do przezbrojenia samolot stoi. Wzór DTA dla nalotów spoza mapy (ponad 40 drużyn, m.in. chainbreaker, cr03, cra10, crb11, crb12): **atak → `3,<waypoint przy krawędzi>` → `37,0`** (Delete team members: drużyna znika). Atak to `1,<wp>` albo `0,<typ celu>` (1 = wszystko, 4 = piechota, 5 = pojazdy, 7 = obrona, 9 = zasilanie). Hunt (`11,14`) i `0,N` bez dalszych akcji mają tylko samoloty budowane przez AI, które mają lotnisko.
13. **Jeden obiekt, kilka triggerów: pole `PowiązanyTrigger`.** Obiekt ma jeden tag, a tag wskazuje jeden trigger. W DTA (118 powiązań w misjach) obiekt dostaje tag pierwszego triggera, a ten w drugim polu `[Triggers]` wskazuje następny. Zdarzenia obiektu sprawdza wtedy cały łańcuch, np. cra12: „Radar captured” → „Radar destroyed pre-capture - lose” → „…post-capture - lose”. Tag na obiekcie musi być **powtarzalny** (`2`), tak jak w cra12. Jednorazowy tag znika z obiektu, gdy jego trigger zadziała, a z nim reszta łańcucha. Trigger, który ma zadziałać raz, sam się wyłącza (`54` na sobie). ARKA 0: tag Tanyi to „Tanya w bazie” (`34`) → „Tanya zginela” (`29` → porażka). Generator ma parametr `-link`. **(niezweryfikowane w grze)**
14. **Wróg nie do zabicia po „wykonaniu zadania”.** Dom sprzymierzony ze wszystkimi (agent Nod w `Nod2`, Tanya w `Allies1`) chroni jednostkę po drodze, ale potem nikt jej nie atakuje. `5 Destroy Team` tylko rozwiązuje drużynę, a jednostka zostaje. Gdy rola się kończy: `36 All change house` w triggerze **należącym do tego domu** przenosi jednostkę do wrogiego domu (ARKA 0: `Nod2` → `Nod`).
15. **Cywile a „wszyscy zniszczeni”.** `C2` (i wszystko, co z niego dziedziczy) ma `Civilian=yes`, a opis zdarzenia `9 Destroyed, Units, All` w `FSData.ini` mówi „does not include civilian objects”. Dom, który ma samych cywilów, może więc liczyć się jako zniszczony od razu. Typy cywilów do eskorty dostają w mapie `Civilian=no` (ARKA 5). W ARKA 2 (`ARKCIV1/2` z `Civilian=yes`) to samo grozi fałszywym „schron stracony” 5 s po wyjściu kolonistów **(niezweryfikowane w grze)**.
16. **Za długa linia akcji triggera wywala grę przy wczytywaniu misji.** ARKA 5 (test 2026-10-28): trigger „Ewakuacja: start” miał 33 akcje, a jego linia `[Actions]` 774 znaki. Gra kończyła się kodem `C0000409` (przepełnienie bufora na stosie) w trakcie wczytywania scenariusza, przed ekranem misji. Log urywał się na `Initializing SPEECH03.MIX`, bo plik logu jest buforowany i ostatnie linie przed crashem przepadają. Triggery wczytują się zaraz potem: `Read_Waypoints` → `TeamTypeClass`/`ScriptTypeClass`/`TaskForceClass`/`TriggerTypeClass::Read_Scenario_INI` (Vinifera `0x100ea720`–`0x100ea888`). Linia 472 znaków działała (ARKA 2), więc bufor ma prawdopodobnie 512 bajtów. Reguła: najwyżej ok. 12 akcji na trigger, nadmiar do triggera-kontynuacji (wyłączony, `13 Elapsed 1`, włączany z oryginału). Generator ARKA 5 robi to sam i daje `FAIL` dla linii sekcji triggerów dłuższej niż 400 znaków.

## Liczenie w triggerach (ARKA 5)

Zmienne lokalne i globalne mają tylko dwa stany, a silnik nie liczy jednostek. Licznik da się zrobić na **kredytach domu, który nic nie ma** (własny dom, `IQ=0`, bez fabryk):

- dodawanie: akcja `106 Give Credits` (ts-patches) `106,0,<indeks domu>,<kwota>,0,0,0,A`;
- próg: trigger **należący do tego domu** ze zdarzeniem `12 Credits exceed` (`12,0,<próg>`). Wartości będące wielokrotnościami kroku i progi `krok·n − 1` działają, czy silnik porównuje `>`, czy `≥`;
- tak samo osobny dom na straty (próg = porażka).

Grupy, które trzeba policzyć osobno (np. „zginęli wszyscy z tej grupy”), dostają **własne domy** od indeksu 14 (`[Houses] 14=…` + sekcja domu jak w `se11.map`; DTA ma misje z 28–32 domami). Wzór i wartości: [[missions/arka-05-tarsonis]] **(niezweryfikowane w grze)**.

## Przejęcie budynku a triggery (analiza 2026-10-27)

- `TechnoClass::Captured` (0x6324D0) odpala tag obiektu zdarzeniem `1` (Entered by) **przed** `Tracking_Active_Remove` i zmianą `House`, a potem woła `Tracking_Active_Add` u nowego właściciela (bez warunków). `BuildingClass::Captured` (0x42F660) woła je po `Active_Remove`.
- Vinifera podmienia `TEventClass::operator()` i `Attaches_To` (`TEventClassExt`), więc kod oceny zdarzeń z `game.exe` nie jest miarodajny. W Viniferze `32 Building exists` = `house->ActiveBQuantity.Value(typ) > 0`, gdzie `house` to dom triggera (`TriggerClass::Is_Triggered` 0x649500 podaje `House_From_HousesType` domu z typu triggera).
- `TriggerClass::Enable` (0x6498F0) resetuje liczniki `13 Elapsed Time`: czas liczy się od włączenia triggera.
- Wniosek: nie budować porażki na rozróżnianiu „przejęty” i „zniszczony” na jednym tagu. Obiekt do przejęcia, który ma przetrwać, lepiej zrobić niezniszczalnym (`Immune=yes`), a jeśli jego utrata ma przegrywać misję, użyć łańcucha z cra12 (pkt 13). [[missions/arka-01-marsara]]