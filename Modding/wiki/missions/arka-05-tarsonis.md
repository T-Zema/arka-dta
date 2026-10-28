# ARKA 5 „Upadek Tarsonis” (Tarsonis, 2500): mapa i misja

Piąta misja z [[plans/campaign-arka]]. Teren to mapa kampanii StarCrafta **„Operation Silent Scream”** (CASC `Terran10`, Tarsonis), powiększona 1,25× i przeniesiona na teatr TEMPERATE. Do tego place i ulice LAT w czterech dzielnicach New Gettysburga, trzy pola kryształów i kopalnia kryształów. Gracz wyprowadza cywilów z kolejno padających dzielnic na lądowisko Raynora (co najmniej 30 z 48). Może wysadzić psi-nadajniki Mengska. Do Kerrigan dociera za późno (tak ma być), a na końcu broni lądowiska do startu ostatniego transportu. Kompletna od startu do wygranej, z filmem briefingu, **(niezweryfikowane w grze)**.

Źródła: CASC StarCrafta `SD/campaign/Terran/Terran07…Terran12/staredit/scenario.chk` (obejrzane, wybrane `Terran10`), `Modding/tools/build-arka05-tarsonis.ps1`, `Modding/tools/build-arka05-mission.ps1`, `Modding/briefings/arka05.json`, `Map Editor/FinalSun/FSData.ini` (zdarzenia 9, 12, akcje 106, 115), `INI/Rules.ini` (`[C2]` `Civilian=yes`), `Maps/Missions/se11.map` (własne domy od 14), [[missions/arka-02-ewakuacja]] i misja 4 (wzory).

## Pliki

| Plik | Rola |
|---|---|
| `Maps/Custom/arka05_tarsonis.map` (+ `.png`) | teren (do obejrzenia w skirmishu „Custom Map”), waypointy 10–64; **nadpisywany** przez skrypt terenu |
| `Maps/Missions/arka05.map` (+ `.png` 300×200) | misja; **nadpisywana** przez skrypt misji; podgląd z `build-arka-previews.ps1 -Only arka05` (plac Omegi) |
| `MOVIES/ARKA05B.MP4` | film briefingu (`Brief=ARKA05B`), spec `Modding/briefings/arka05.json`, [[engine/briefing-movies]] |
| `INI/BattleE.ini` | wpis `M_ARKA05`; skrypt **scala** z resztą misji ARKA |
| `Modding/tools/build-arka05-tarsonis.ps1` | teren: CASC → ScToDta, zoom 1,25, TEMPERATE, place, ulice, kryształy, kopalnia, kontrole |
| `Modding/tools/build-arka05-mission.ps1` | misja: typy SC skopiowane do mapy, 22 domy, obiekty, 40 drużyn (desant Overlordami), 144 triggery, 88 tekstów, kontrole |
| `%TEMP%\arka05-terrain\` | `sc_grid.png` (mapa SC z siatką i waypointami, **do planowania**), `grid.png`, `reach.png`, `log.txt`, pełny render |
| `%TEMP%\arka05-mission\` | `log.txt`, render z `-Render`; dekompilacja: `tools/dump-triggers.ps1 -Map Maps\Missions\arka05.map` |

```powershell
powershell -NoProfile -File Modding\tools\build-arka05-tarsonis.ps1          # teren, ok. 2 min z renderem
powershell -NoProfile -File Modding\tools\build-arka05-mission.ps1 -Render  # misja + BattleE.ini
powershell -NoProfile -File Modding\tools\build-arka-previews.ps1 -Only arka05
powershell -NoProfile -File Modding\tools\build-briefing.ps1 -Spec Modding\briefings\arka05.json
```

## Wybór mapy SC

Mapy kampanii Terran w CASC nie mają numerów z gry (folder `Terran07` to niewydana „Biting the Bullet”). Na Tarsonis są trzy:

| Folder | Mapa | Tileset | Dlaczego tak / nie |
|---|---|---|---|
| `Terran09` | The Big Push | platform | miasto na platformach, ale pustka kosmiczna konwertowałaby się na przeszkody |
| `Terran10` | **Operation Silent Scream** | jungle | **wybrana.** Opis: „Command Ship Hyperion, holding close orbit over Confederate Capitol World, Tarsonis”. Trzy psi-nadajniki (jednostka 195 na lokacjach `Beacon 1–3`), trzy miasta Konfederacji (Delta, Nova, Omega) z cywilami SC (jednostka 15), Kerrigan (16) i Raynor (19) w kraterze pośrodku, kwestia Kerrigan „Who authorized the use of Psi Emitters?”. To dokładnie fabuła misji. |
| `Terran11` | New Gettysburg | platform | lądowiska Protossów i miasto Zergów; ta sama wada co platform |
| `Terran12` | The Hammer Falls | platform | działo jonowe, nie pasuje |

## Teren

- **Zoom 1,25×**: 128×128 kafli SC daje `Size=0,0,84,169`. Ścieżki z lądowiska: Omega 71 komórek, Gamma 72, Nova 120, Delta 139.
- Jungle → TEMPERATE jak w Lost Temple: dżungla to wysoka trawa, plaża i jezioro na północy zostają wodą, konwerter usuwa swoją „świątynię” (`DBTMPL`) z krateru.
- **Place** (bruk, tylko na poziomie waypointu): lądowisko (wp 10, r 5), place dzielnic (20/25/30/35, r 5), CC i miejsca skrzynek (r 2–3).
- **Ulice** (`Paved Road LAT`, jak w misjach DTA, [[workflow/mission-maps]]): najkrótsza otwarta ścieżka lądowisko → plac każdej dzielnicy przez waypointy 61–64, pędzel 2×2. Krok po skosie dostaje wolną komórkę boczną, bo styk tylko narożnikiem rysuje się jako przerwa w trawie. Oba końce każdej ulicy leżą na placu, więc **wolnych końców jest 0**. LAT jak `ApplyGroundRoads` z `DesignToDta` (bruk liczy sąsiednią ulicę jako swój grunt, ulica przy samym bruku dostaje `Pavement/Paved Road LAT`).
- **Złoża** ([[workflow/mission-design]]): **same kryształy, bez złota** (użytkownik 2026-10-27). Minerały SC w trzech miastach to niebieskie kryształy (75 komórek, bogate, pełne Zergów). Do tego trzy pola kryształów (nakładki 31–34, jak minerały z konwertera): wp 15 nad kraterem (43 komórki, bezpieczne), wp 52 na zachodniej równinie z kopalnią kryształów `OREMINE2` (44, sporne, na drodze fal z zachodu) i wp 53 na wschodniej równinie (96, najbogatsze, otwarte na wschód). W misji `OREMINE2` ma `TiberiumToSpawn=6` (BlueGems), a `[BlueGems]` rośnie powoli (`Growth=3000`, `GrowthPercentage=.05`), jak w misji 4; `TiberiumGrows=yes`, `TiberiumSpreads=no`.
- Kontrole: 0 nieudanych łańcuchów klifów, wszystkie 54 waypointy osiągalne z lądowiska.

## Waypointy (kontrakt teren ↔ misja)

Współrzędne w kaflach oryginalnej mapy SC (128×128). Skrypt przesuwa każdy na najbliższą wolną komórkę.

| Nr | Kafel SC | Co | Nr | Kafel SC | Co |
|---|---|---|---|---|---|
| 10 | 56,66 | lądowisko (krater), cel cywilów | 40–42 | 4,65 / 20,113 / 103,113 | psi-nadajniki W, SW, SE |
| 11 | 52,71 | start oddziału gracza | 43 / 44 / 45 | 1,72 / 6,108 / 126,92 | wloty fal: zachód, wybrzeże SW, wschód-południe |
| 12 | 61,74 | MCV gracza | 46 / 47 | 50,3 / 126,52 | wloty: północ, wschód |
| 13 / 14 | 48,62 / 64,61 | posterunki Synów Korhalu | 48 | 79,106 | punkt oporu Kerrigan (miejsce zaznaczone przez użytkownika) |
| 15 | 54,50 | kryształy 1 (bezpieczne) | 49 | 95,110 | śluzowaty ślad „w głąb roju” (w stronę nadajnika SE) |
| 16 | 52,79 | wrak w kraterze (kratery) | 50 / 51 | 118,102 / 111,103 | lądowisko Protossów, straż |
| 17 / 18 / 19 | 54,84 / 38,64 / 78,68 | wyjścia z krateru S, W, E | 52 / 53 | 26,48 / 86,56 | kryształy 2 (+ kopalnia), kryształy 3 |
| 20–24 | 16,10 … | Delta: plac, CC, kryształy, Zergi, bank | 54 | 60,40 | środkowa równina |
| 25–29 | 110,26 … | Nova: plac, CC, kryształy, Zergi, zbrojownia | 55 | 124,3 | wlot Mutalisków |
| 30–34 | 42,98 … | Omega: plac, CC, kryształy, Zergi, magazyn | 56 / 57 | 127,40 / 1,30 | przelot floty Protossów |
| 35–38 | 113,70 … | Gamma: plac, ratusz, Zergi, magazyn | 58–60 | 74,104 / 88,103 / 76,112 | zachodnia strona punktu oporu, zrzuty roju na wschód i południe od niego |
| 61–64 | 28,30 / 36,84 / 86,74 / 84,40 | punkty pośrednie ulic do Delty, Omegi, Gammy, Novej; posterunki Konfederacji | 77–81 | 124,125 / brzeg S | liczone przez skrypt misji: wlot Overlordów siejących creep (róg SE) i ich miejsca przy brzegu |

Liczone przez skrypt misji: 65–68 wyjścia cywilów na placach (Delta, Nova, Omega, Gamma), 69–70 transportowce Raynora obok lądowiska (nie na wp 10, na który idą cywile).

## Domy

| Dom | Rola |
|---|---|
| `Allies` (2) | gracz, 6000 kredytów, `TechLevel=10` (pełny tech), bez Chronosfery (`RAPDOX`) i silosu (`RAMSLO`) |
| `Soviet` (3) | Synowie Korhalu: bunkier i oddział przy każdym boku lądowiska; jednostki mają tag „odlatują” |
| `GDI1` (6) | **Kerrigan i jej punkt oporu** (złoty kolor Synów Korhalu): Kerrigan, 14 Marines, 3 bunkry, 3 Supply Depoty; od startu walczą z rojem |
| `GDI2` (8) | 2 Dropshipy Raynora na lądowisku: **sojusznik wszystkich**, nikt ich nie zestrzeli |
| `Allies1` (10) | New Gettysburg: budynki Konfederacji SC (CC, Supply Depot, Barracks, Factory, Starport, Academy), bunkry i wieżyczki, oddział na każdym placu (Marines, Firebaty, Goliath, Siege Tank), posterunki na ulicach (bunkier + 4 jednostki) i milicja; walczą z Zergami. Miasto to **budynki Terran SC w dzielnicach tematycznych** (2026-10-28; bloki DTA `CITY*` z [[catalog/city-buildings]] użytkownik obejrzał i odrzucił: „nie pasuje”): **Delta** administracja (CC + Comsat, Engineering Bay, Academy), **Nova** przemysł (3 Factory + Machine Shop, 2 Armory), **Omega** garnizon (CC, 3 Barracks, Academy, Engineering Bay, bunkry), **Gamma** port kosmiczny (2 Starport + Control Tower, Science Facility + Physics Lab, Science Facility + Covert Ops), wszędzie Supply Depoty (po 2 przy każdym posterunku). Przybudówka (2×2) stoi przy prawym boku budynku, równo z dolną krawędzią (`Place-WithAddon`: jedno wolne miejsce na oba). Bez Nuclear Silo (supermoc dla domu komputera). Desanty na place mają rozkaz `0,2` (atakuj budynki). Ciemnoczerwony jak Konfederacja w misji 2 |
| `Neutral` (4) | nieużywany (wcześniej domy wiejskie `V01–V11`, `HOSP`; zastąpione budynkami Terran w `Allies1`) |
| `Nod1` (7) | Zergi (stada w dzielnicach, przy nadajnikach, fale) |
| `Nod2` (9) | psi-nadajniki Mengska; sojusz z Zergami i Synami Korhalu, **gracz nie jest sojusznikiem**, więc może je zniszczyć |
| `GDI` (0) | lądowisko Protossów, wrogie wszystkim poza `GDI2`. **Buduje się samo w trakcie misji** (AI z węzłami bazy, `tools/arka05-protoss.ps1`, niżej) |
| `Soviet2` (13) | flota Protossów w zakończeniu, sojusznik wszystkich |
| `Allies2` (11), `Soviet1` (12) | **domy-liczniki**: kredyty = uratowani / grupy stracone |
| `Cyw1`–`Cyw8` (14–21) | 8 grup cywilów, każda w osobnym domu (zdarzenie „zginęli wszyscy” działa na dom) |

## Przebieg (czas gry w sekundach)

| Kiedy | Co się dzieje |
|---|---|
| 1–412 | wstęp: Tarsonis, Einstein i Mengsk („Historia wybacza zwycięzcom”), Raynor (transportowce w kraterze), cel 1 i kolejność padania dzielnic, Tanya i nadajniki (cel dodatkowy), Mengsk o Kerrigan |
| gracz na placu dzielnicy (r ≤ 5) | dzielnica się otwiera: grupa A (6 cywilów) wychodzi na wp 65–68, grupa B 20 s później. Sami idą na lądowisko: skrypt `3,10` → `39,<lokalna>` → `37` (wsiedli) |
| od startu | punkt oporu Kerrigan walczy: od 120 s trzy Overlordy naraz (Zerglingi, Hydraliski, Ultralisk), co 210 s z dwóch stron i co 330 s z północy, do wezwania. Miasto zaczyna walczyć dopiero od 900 s (spokojny start, 2026-10-28): desanty na place co 660–840 s, milicja Konfederacji co 645–780 s, desanty na posterunki od 1100 s co 840–1020 s (bez tekstów i zdarzeń radaru), do upadku dzielnicy albo ewakuacji |
| 1440 / 1940 / 2440 / 2940 | ostrzeżenia Raynora, jeśli dzielnica jeszcze zamknięta |
| **1800 Omega, 2300 Gamma, 2800 Nova, 3300 Delta** | dzielnica pada, jeśli gracz jej nie otworzył: obie grupy stracone, Overlord zrzuca rój na plac |
| 1000 / 1300 / 1600, potem co 720 / 780 / 660 | strumienie z nadajników W, SW, SE (Overlord z 8 Zergami): zrzut na złoże (52, Omega, 53), zbieracze (`0,3`), potem lądowisko. Każdy płynie, dopóki stoi jego nadajnik |
| 1900 co 1290, 2400 co 1000 | desant z północy na kryształy przy kraterze (4 Zerglingi + 4 Broodlingi `SCZBRD`; 2026-10-28: tylko Zerglingi i Broodlingi, o 30% rzadziej, było co 900 z Hydraliskami), Mutaliski na lądowisko. Zerglingi zza północnej krawędzi (`topA`/`topB`) co 430/515 s (było 300/360), po 4 Zerglingi + 2 Broodlingi; ostatnia fala z północy: 5 Zerglingów + 3 Broodlingi |
| 3 grupy na pokładzie i ≥ 1200, najpóźniej 2600 | **Kerrigan wzywa** (i mówi, że Protossi lądują na SE i palą wszystko wokół roju), 3 Overlordy zrzucają rój na jej punkt oporu, Raynor, Mengsk („odwrót”), Synowie Korhalu odlatują (akcja `115`), cel 2. Po 60 s rój ją zabiera: Kerrigan i jej Marines znikają (`115` na ich wspólnym tagu) |
| gracz na pozycji Kerrigan po jej zniknięciu | karabin i śluzowaty ślad (kratery `BURN` od wp 48 do 49), „Sarah! SARAH!”, Tanya, Raynor do Mengska |
| scena + 30 na pokładzie | **ewakuacja**: licznik 7:00, muzyka `CRUS226M`, rajdy powtarzane wyłączone, ostatnie fale z każdej strony, której nadajnik stoi, + północ + Mutaliski (+ trudny); po dwa Overlordy z każdej strony zrzucają Zergi przy wyjściach z krateru |
| licznik 0 | błyski, start transportu, zakończenie (flota Protossów nad miastem, okręt na Antigę, sen Raynora), **wygrana** |

**Porażka:** śmierć Tanyi lub Raynora, utrata wszystkiego, **4 grupy stracone** (zostaje najwyżej 24 cywilów).

## Nowe mechanizmy

- **Licznik na kredytach.** Silnik nie liczy jednostek, a zmienne są tylko 0/1. Grupa, która wsiadła, daje 6 kredytów domowi `Allies2` (akcja `106 Give Credits`, `106,0,11,6,0,0,0,A`). Triggery tego domu ze zdarzeniem **`12 Credits exceed`** z progami 5, 11, …, 47 (6n − 1 działa i dla „>”, i dla „≥”) ogłaszają 6, 12, …, 48 cywilów, a próg 29 kończy cel 1. Straty tak samo: grupa stracona daje 1 kredyt domowi `Soviet1`, dzielnica, która padła, daje 2, a próg 3 oznacza porażkę. Próg „3 grupy” (17) uruchamia wezwanie Kerrigan **(niezweryfikowane w grze: czy `12` porównuje surowe kredyty z akcją `106`)**.
- **`Civilian=no` w typie cywila.** `C2` ma `Civilian=yes`, a opis zdarzenia `9 Destroyed, Units, All` w `FSData.ini` mówi „does not include civilian objects”. Grupa prawdziwych cywilów liczyłaby się wtedy jako zniszczona zaraz po pojawieniu się. `ARKCIV1/2` mają też 200 HP i `Fraidycat=no` (jak w misji 2).
- **22 domy**: własne domy od indeksu 14 jak w misjach DTA (`se11`: 28 domów, `se10`: 32).
- **`115 Erase Attached Object`** (ts-patches) na tagu dzielonym przez 12 jednostek Synów Korhalu: odlatują bez wybuchów **(niezweryfikowane w grze: czy akcja przy zdarzeniu czasowym usuwa wszystkie obiekty z tagiem)**. Gdyby nie zadziałała, Synowie zostają jako sojusznik, a misja działa dalej.
- **Psi-nadajnik `ARKPSIE`**: Comsat Station SC jako osobny budynek, `ThreatPosed=0` (jednostki gracza nie strzelają do niego same, więc zniszczenie to wybór), `Repairable=yes` dla C4 Tanyi (pułapka z misji 2), zniszczenie łapie zdarzenie `48` (C4 też).
- **Kerrigan od startu na mapie** (użytkownik 2026-10-27: „nie widać tej Kerrigan, musi walczyć z potężnym rojem i garstką Marines”): `ARKKERR` to Ghost SC w złotym kolorze domu `GDI1`, bez maskowania (`Cloakable=yes` Ghosta ją chował), ×3 HP, broń `ARKKerrGun` = `SCC10` ×3, samoleczenie, **`Immune=yes`** (nie zginie przed wezwaniem). Ona i 14 Marines mają wspólny tag triggera „rój zabiera Kerrigan”: wyłączony `13 Elapsed 60` + `115 Erase Attached Object` + lokalna 25, włączany przy wezwaniu. Akcje `32`/`115` przy zdarzeniu czasowym są w misjach DTA częste (34 i 7 triggerów). Strefa przy jej pozycji jest powtarzalna i od wezwania (`57` czyści lokalną) liczy tylko nowe wejścia. Scena wymaga wezwania, zniknięcia i wejścia gracza.
- **Desant Overlordami** (użytkownik 2026-10-27): w mapie `[SCZOVL]` dostaje `Passengers=8`, `IsVehicleTransport=yes` (Infested Terran to pojazd). Drużyna `Drop`: pierwszy członek Overlord, potem do 8 Zergów; akcja `80` tworzy ją z ładunkiem w środku (wzór `cr06`/ARKA 0), skrypt `3,<zrzut>` → `8,2` (rozładunek, Overlord odchodzi z drużyny i zostaje nad miejscem zrzutu) → dalsze rozkazy ładunku. Overlord jest lokomotorem Fly, rozładunek wymaga zawisu (łatka `patch-flyhover.ps1`, [[engine/transports]]) **(niezweryfikowane w grze)**. Fale wszystkie idą tak, poza Mutaliskami.
- **Puste Overlordy przy każdym zrzucie** (2026-10-28): `Drop` tworzy drugą drużynę z 2 pustymi Overlordami (`3,<zrzut>` → `5,2` → `3,<wlot>` → `37,0`), a generator dopisuje ją do każdej akcji `80` prawdziwego zrzutu. Widać, że nadchodzi atak.
- **Punkt oporu Kerrigan** (2026-10-28): poza 14 Marines także 2 Goliaty i rozstawiony Siege Tank (budynek `SCSIEGB`, składa się w `SCSIEGE`), wszystkie z tagiem `ARKA5G08`, więc przy wezwaniu znikają razem z Kerrigan.
- **Protossi przychodzą powoli** (agent pomocniczy, 2026-10-28; `tools/arka05-protoss.ps1`, generator dołącza go sam): dom `GDI` z `IQ=5`, Nexus jako ConYard dopisany do `[AI] BuildConst` mapy (lista z Rules + `SCPNEX`), 10 węzłów bazy (`NodeCount`, `000=TYP,x,y`) i `3 Production Begins`; typy `SCPNEX`, `SCPPYL`, `SCPGAT`, `SCPFOR`, `SCPCAN`, `SCPCYB` z `Owner=GDI`, `TechLevel=1`. Tempo wyznaczają pieniądze: 0 kredytów na starcie i `106 Give Credits` po cenie jednego budynku. Na starcie Nexus (tag `ARKA5G06`, odkrycie → kwestia Tanyi), Pylon i 2 Zealoty; potem 45 s Pylon, 150 Gateway, 300 Forge, 480 / 780 / 1140 działka, 660 / 1320 Pylony, 960 Cybernetics Core; przywołanie Zealotów i Dragoonów (błysk + `80`, `11,10`) 420 / 900 / 1260 / 1500 s; od 1680 s co 360 s 400 kredytów na odbudowę; dwa małe desanty Zergów na lądowisko (1150, 2150 s). **(niezweryfikowane w grze: czy AI stawia węzły, których nie było na starcie, i czy czeka przy 0 kredytach)**
- **Gniazdo Zergów z własnym AI** (agent pomocniczy, 2026-10-28; `tools/arka05-zerg.ps1`, generator dołącza go sam): na płaskowyżu dżungli nad Kerrigan i Protossami (wp 71 Hatchery, 72 pole kryształów 46 komórek + kopalnia `OREMINE2`, 73 wyjście). Dom `Nod` (wcześniej pusty, `IQ=5`, sojusz z `Nod1`/`Nod2`/`GDI2`/`Soviet2`): Hatchery (tag `ARKA5Z01`), Spawning Pool (`ARKA5Z02`), Hydralisk Den, Extractor, 2 Sunken, Creep Colony, 3 Overlordy, 2 drony `SCZWORK` na pokaz, straż 7 Zerglingów + 3 Hydraliski. **Produkcja:** `3 Production Begins`, a na osi czasu `4 Create Team` z kosztem drużyny płaconym akcją `106` (+10%). Brakujących członków AI szkoli w Poolu; `SCZLNG`/`SCZHYL` mają w mapie `Owner=Nod1,Nod`, `TechLevel` 1/2, wymóg Pool + Hatchery (Hydralisk także Den). Drużyny po 8 (`16,cel` → `11,14`): 7:00 Kerrigan, 12:00 Protossi, 17:00 Gamma, 22:00 Protossi, 26:00 Kerrigan (obie tylko przed wezwaniem), 30:00 zbieracze i baza gracza, potem powtarzane: Protossi co 600 s od 34:00, Gamma co 720 s od 39:00, gracz co 900 s od 45:00. **Zabezpieczenie:** pierwsza linia skryptu drużyny ustawia lokalną 30 „Gniazdo produkuje”. Jeśli po 240 s jest pusta, ten sam skład wykluwa się akcją `80` na wp 73. Zniszczenie Hatchery albo Poola (lokalna 31) kończy produkcję. 2 teksty (odkrycie gniazda, zniszczenie Wylegarni). **(niezweryfikowane w grze: czy AI szkoli piechotę dla drużyn z `4 Create Team`)**
- **Punkt oporu Kerrigan przesunięty o 4 kafle SC w dół** (2026-10-28, użytkownik): wp 48 (79,110), 58, 59, 60 razem z nim.
- **Poprawki po teście 2026-10-28** (użytkownik: misja wygrywa się za szybko, Protossi za bierni, działko nic nie robi Overlordom):
  - Kerrigan wzywa dopiero po **4 grupach** na pokładzie i najwcześniej w **35:00** (najpóźniej w 50:00; było 3 grupy / 20:00 / 43:20). Druga grupa z dzielnicy wychodzi **90 s** po pierwszej (było 20 s). Czas ewakuacji (7:00) bez zmian.
  - Po **12 cywilach** na pokładzie (`12 Credits exceed 11` domu `Allies2`) Zerglingi wbiegają z północnej krawędzi: po 6 co 300 s z wp 46 (na kryształy przy kraterze, zbieracze, lądowisko) i co 360 s z wp 55 (przez Novą na lądowisko). Wyłączane przy ewakuacji.
  - **Overlord** w tej mapie ma 1800 HP (było 4000, pancerz `heavy`, samoleczenie 16 HP na krok). Działko Photon (pocisk `AA=yes`, 50 × 500% = 250 na strzał, prąd w porządku: Pylon +100, Nexus +50) nie mogło go zbić. Leczy się dalej, ale wolniej: 10 HP na krok, bo od 2026-10-28 wszystkie Zergi moda leczą się o 40% wolniej ([[mods/zerg-faction]]).
  - **Wypady Protossów na gniazdo Zergów** (`tools/arka05-protoss.ps1`; od 2026-10-28 agresywniej: od 900 s co 420 s, a od 1200 s dodatkowo wypad Dragoonów co 540 s; pierwotnie od 1500 s co 600 s): przywołanie na wp 51, trasa wzdłuż klifów przez wp 74 i 75. Teren liczy je jako najkrótszą ścieżkę z wp 51 do 71 trzymającą się 16 komórek od Kerrigan, więc Protossi nie wdają się po drodze w walkę z Terranami, choć dalej są wrodzy. Na końcu `16,71` → `11,10`.
  - **Limit wypadów** (użytkownik 2026-10-28: „Protossi spamują”). Oddziały zostawały na ruinach gniazda (`11,10`), a co 420 s i co 540 s dochodził następny. Teraz w każdym strumieniu jest naraz tylko jeden oddział:
    - członkowie oddziału mają tag strumienia (`Tag=` w TeamType: `ARKA5GPZ` duże wypady, `ARKA5GPD` Dragoony);
    - trigger tego tagu na zdarzeniu `48` (zniszczony) ma tag półtrwały (`1`), więc odpala dopiero, gdy zginie cały oddział;
    - wtedy włącza trigger czasowy strumienia (420 s / 540 s), a ten po wysłaniu oddziału sam się wyłącza.

    Na mapie są więc najwyżej 7 + 6 jednostek z wypadów i do 12 strażników lądowiska (start + 4 przywołania). Gdy oddział przeżyje na ruinach gniazda, strumień stoi. Jeśli tag półtrwały nie działa tak w grze, wypad wróci najwyżej w starym tempie (odpali po pierwszej stracie) albo w ogóle się nie powtórzy. **(niezweryfikowane w grze)**
  - **Pole kryształów w prawym górnym rogu** (wp 76, SC 120,7, ok. 134 komórki).
- **Creep Zergów od startu** (użytkownik 2026-10-28: „creep przy bazie zergów klasycznym sposobem”): tak samo jak w misji 4 ([[mods/zerg-creep]]). Pod Hatchery gniazda (pole (1,1) fundamentu) i pod koloniami (Creep/Sunken, pole (0,0)) gniazda `Nod` i nadajników `Nod1` leży w mapie Veinhole Monster: nakładka 167 + 8× 178, odstęp ≥ 3 pola. Wokół każdej dziury leżą dojrzałe żyły (126, dane 48) w kole r 5, a także pod każdym budynkiem `SCZ*` z marginesem 1. Wynik generatora: 10 dziur pod 13 budynkami, 531 pól żył. Misja ustawia sama to, co w skirmishu daje blok creepu: `VeinGrowthEnabled=yes`, `VeinholeGrowthRate=60`, `VeinholeShrinkRate=8`, `Insignificant=yes` na `VEINS`/`VEINHOLEDUMMY`, 4 animacje siewu w `[Animations]` i `ImmuneToVeins=yes` na 923 typach. **(niezweryfikowane w grze)**
- **Overlordy siejące creep** (użytkownik 2026-10-28: „w momencie kiedy Kerrigan się broni”): `ARKOVLC` to kopia `SCZOVL` (1400 HP, bez transportu) z bronią `ARKA5CrpSpit`. Strzela kwasem Guardiana (`SCZGAcidProj`, obrażenia 8, ROF 90, zasięg 6). Głowica `ARKA5CrpWH` ma jedyną animację `SCZCRSHL`, czyli odłamek creepu. Tam, gdzie kwas trafi, powstaje dziura z żyłami (łatki `patch-vinifera-veins` i `patch-veins`, miejsce 6). Kolejna dziura powstaje co najmniej 3 pola od poprzedniej. Dziury zostają po śmierci Overlordów, jak dziura Creep Tumora.
  - Wersja 1 (Overlordy nad pozycją Kerrigan) nie działała: według użytkownika „tam umierają”.
  - Wersja 2 to na prośbę użytkownika próba przy krawędzi mapy. Overlordy wlatują w rogu SE (wp 77), z dala od działek Protossów. Każdy z nich ma swoje miejsce przy południowej krawędzi i pluje tam w ziemię skryptem `3,N` → `1,N` („atakuj waypoint”, bez końca).
  - Południowa krawędź to morze (kod terenu 9). Generator szuka więc najbliższego lądu przy brzegu, na którym dziura może powstać (3×3 płaskie i czyste). Lądu szuka co najmniej 14 pól od Kerrigan, 18 od Protossów i 6 od innego miejsca, a miejsce bez lądu pomija. Wyszły wp 78 (218,169), 80 (193,194) i 81 (191,201); wp 79 wypadło nad morzem.
  - Waypointy liczy z kafli SC przekształceniem afinicznym, dopasowanym dokładnie do 8 waypointów krawędziowych: x = 7,85 + 0,625·sx + 1,25·sy, y = 87,46 − 0,625·sx + 1,25·sy.
  - Trigger `kerCreep1`: jeden raz w 180 s, przed wezwaniem, z kwestią Kerrigan.
  - Test użytkownika 2026-10-28: Overlordy przy krawędzi plują i creep rośnie (`1,N` strzela w pustą komórkę), **ale creep Overlordów kasował creep budynków**. Przyczyna, z deasemblacji, niezweryfikowana w grze ([[engine/veins]], „Własność żył”):
    - dziura z mapy przy wczytaniu zalewa wszystkie połączone żyły;
    - od pierwszego `AI` dziura pod budynkiem `SCZ*` dostaje znacznik `'ZG'` i posiada już tylko koło dx² + dy² ≤ 72 (miejsca 10 i 12);
    - pierwsza dziura zrobiona w grze (od Overlorda) przebudowuje kolejki (miejsce 6), a żyły bez właściciela znikają: pod Niecką, Hydralisk Den, Extractorem i na łącznikach.
  
    Poprawka: dziura pod **każdym** budynkiem Zergów (najpierw siewniki, potem reszta; 13 dziur pod 13 budynkami), a na koniec generator symuluje własność (zalew 8 kierunków w kole r² ≤ 72 od każdej dziury) i od razu usuwa żyły, których nic nie utrzyma (34 pola). Creep ze startu to więc creep, który zostaje.
  - Wersja 3 (użytkownik 2026-10-28):
    - przy wezwaniu Kerrigan przylatują 2 Overlordy siejące, na ziemię dziury przy zrzutach roju na wschód i południe od niej (wp 82, 83; wloty 47 i 45; dopisane do triggera `call`);
    - w 480 s przylatuje po jednym Overlordzie przy skupiskach Zergów, przy gnieździe dwa (wp 84–87: gniazdo ×2, nadajnik W, nadajnik SW), z kwestią Tanyi. Każde miejsce leży 11–14 pól od środka skupiska, więc koło żył Overlorda (~8,5) styka się z kołami dziur budynków. Z pierścienia generator bierze pole najdalsze od tego, co go zestrzeli: lądowisko ≥ 18, place dzielnic i posterunki ≥ 12, Kerrigan ≥ 14, Protossi ≥ 18, inne miejsca ≥ 10;
    - wlot to najbliższy waypoint krawędzi, z którego prosty lot omija Protossów (≥ 16) i Kerrigan (≥ 12);
    - przy nadajniku SE takiego pola nie ma (leży między Protossami a Kerrigan), więc tam Overlorda nie ma.
  - Wersja 4 (użytkownik 2026-10-28: „wyjątkowo w tej misji creep rośnie na 30 pól od Overlordów”):
    - mapa ustawia `[General] VeinholeMonsterStrength=30` i `MaxVeinholeGrowth=3000` (koło r 30 to ok. 2830 pól, a wzrost staje przy `Max − 40`);
    - łatka `patch-veins.ps1` (miejsce 14, [[engine/veins]]) daje dziurze zrobionej w grze (`'ZC'`) taki promień, gdy klucz ma 1–100. Dziury pod budynkami i wszystkie inne mapy zostają przy ~8,5;
    - przy `VeinholeGrowthRate=60` dziura dokłada średnio 3 pola na 60 klatek, więc pełne koło rośnie kilkanaście minut.
    - Test użytkownika 2026-10-28: creep 30 pól działa, ale Overlordy zabijały własne dziury. Teraz głowica `ARKA5CrpWH` ma `Modifier.*=0%` na każdy pancerz (bazowe, z `[ArmorTypes]` Rules i pancerze lotników SC). Broń zostaje przy `Damage=8`, bo z obrażeń broni gra wybiera animację głowicy, czyli odłamek creepu. **(niezweryfikowane w grze)**
  
  **(niezweryfikowane w grze: czy `1,N` każe Overlordowi strzelać w pustą komórkę, czy odłamek z głowicy stawia dziurę jak odłamek z budynku)**
- **Budynki nie stają na ulicach**: skrypt misji czyta kafle `Paved Road` z `IsoMapPack5` (`Theater.SetOf`) i `Place-AtWp` omija te komórki.

## Odstępstwa od planu

- **„Bohaterowie i cywile muszą odlecieć ostatnim transportem”**: silnik nie sprawdzi, czy konkretny bohater stoi na lądowisku (strefa reaguje na każdą jednostkę domu). Ewakuacja to obrona lądowiska przez 7:00, a Tanya i Raynor muszą przeżyć do startu.
- **Karabin Kerrigan** to tekst (obiektu-karabinu nie ma), ślad to kratery `BURN`. Kerrigan nie stoi już przy samym lądowisku Protossów, tylko w miejscu wskazanym przez użytkownika na zachód od nadajnika SE; o Protossach mówi przez radio.
- **„Mengsk zapamięta”**: misje ARKA są osobnymi bitwami w `BattleE.ini`, nie łańcuchem kampanii, więc zmienna globalna nie przejdzie do misji 7. Mengsk komentuje pierwszy zniszczony nadajnik.
- Einstein nie występuje na mapie (jest na mostku Hyperiona, mówi przez radio).

## Do sprawdzenia w grze

- Czy `12 Credits exceed` domu `Allies2` reaguje na kredyty z `106` (cel 1, liczniki, wezwanie Kerrigan).
- Czy grupa cywilów z `Civilian=no` nie jest „stracona” od razu (5 s po wyjściu) i czy dochodzi na wp 10 i znika.
- Czy `115` usuwa wszystkie jednostki Synów Korhalu oraz Kerrigan z Marines (zdarzenie czasowe na tagu wielu obiektów).
- Czy Overlordy rozładowują się po `3,N` + `8,2` (zawis Fly) i czy wyskakują z nich też Infested Terran (pojazdy).
- Czy Tanya wysadza `ARKPSIE` C4 i czy jednostki gracza same go nie ostrzeliwują.
- Czy lądowisko Protossów rośnie według osi czasu (a nie od razu albo wcale) i czy działka nie zestrzeliwują wszystkich Overlordów lecących na Kerrigan.
- Czy gniazdo Zergów szkoli Zerglingi i Hydraliski w Poolu (inaczej po 240 s wykluwa je zapasowo na wp 73) i czy jego drużyny nie zrównają Protossów za wcześnie (Nexus nie jest węzłem bazy: bez niego Protossi przestają się budować).
- Tempo: czasy padania dzielnic (1800–3300, rozsunięte po uwadze „za szybko”), długość marszu z Delty (139 komórek), siła strumieni i ostatnich fal, 7:00 ewakuacji; czy walki w mieście nie zalewają mapy jednostkami (desanty i milicja się powtarzają).
- Creep: czy pod gniazdem i koloniami przy nadajnikach od startu leżą żyły i czy rosną. Czy od 3:00 trzy Overlordy `ARKOVLC` przy południowym brzegu (wp 78, 80, 81) plują w ziemię, przeżywają i czy tam rośnie creep. Czy nic nie dostaje obrażeń od żył. Czy creep Overlordów sięga ok. 30 pól, a creep budynków dalej ok. 8,5.
- Limit Protossów: czy następny wypad przychodzi dopiero po rozbiciu poprzedniego (tag półtrwały na zdarzeniu `48`).
- Film `ARKA05B` przed misją, podgląd `arka05.png` i wpis `M_ARKA05` w kliencie.
