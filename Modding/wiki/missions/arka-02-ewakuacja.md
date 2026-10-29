# ARKA 2 „Ewakuacja” (Mar Sara, 2499): mapa i misja

Druga misja na Mar Sarze z [[plans/campaign-arka]]. Teren to mapa kampanii StarCrafta **T3 „Desperate Alliance”** (w SC: przetrwać 30 minut do ewakuacji przez Synów Korhalu) z CASC użytkownika, powiększona 1,5× i przeniesiona na pustynny teatr DTA. Na niej: baza Aliantów przy wraku ARKI, Mar Sara City z zainfekowanym Command Center, trzy schrony z kolonistami, lądowisko Synów Korhalu i 15 minut ładowania skoku. Kompletna od startu do wygranej, **(niezweryfikowane w grze)**.

Źródła: CASC StarCrafta `SD/campaign/Terran/Terran03/staredit/scenario.chk` (T3, 96×96 badlands; obejrzane też T1 Wasteland), `Modding/tools/build-arka02-marsara.ps1`, `Modding/tools/build-arka02-mission.ps1`, `Modding/tools/ZergAI.ps1`, `Modding/tools/build-arka-previews.ps1`, `Map Editor/FinalSun/FSData.ini` (`[Scripts]` 37 i 39), `Maps/Missions/cr07.map` (`Tag=` w drużynie), `INI/Map Code/SC Factions/010 Zerg faction.ini` (`[SCZICC]`, `[SCZINF]`), `INI/Rules.ini` (`[TANYA]` `C4=yes`, `[C2]`, `[C8]`), [[missions/arka-01-marsara]] (wzór).

## Pliki

| Plik | Rola |
|---|---|
| `Maps/Custom/arka02_marsara.map` (+ `.png`) | teren (do obejrzenia w skirmishu „Custom Map”), waypointy 10–55; **nadpisywany** przez skrypt terenu |
| `Maps/Missions/arka02.map` (+ `.png` 300×200) | misja; **nadpisywana** przez skrypt misji; podgląd z `build-arka-previews.ps1 -Only arka02` |
| `INI/BattleE.ini` | wpis `M_ARKA02` obok `M_ARKA00`/`M_ARKA01`; skrypt **scala** |
| `Modding/tools/build-arka02-marsara.ps1` | teren: CASC → ScToDta, zoom 1,5×, teatr DESERT, beton na platformach i w mieście, waypointy, długości dróg |
| `Modding/tools/build-arka02-mission.ps1` | misja: typy SC skopiowane do mapy, domy, obiekty, strefy, 16 drużyn, 77 triggerów, 62 teksty, kontrole |
| `%TEMP%\arka02-terrain\` | `grid.png` (mapa komórek DTA z siatką kafli SC i waypointami: **tego używać do planowania**), `sc_grid.png`, `reach.png`, `log.txt`, pełny render |
| `%TEMP%\arka02-mission\` | `log.txt`, render z `-Render`; dekompilacja: `tools/dump-triggers.ps1 -Map Maps\Missions\arka02.map` |

```powershell
powershell -NoProfile -File Modding\tools\build-arka02-marsara.ps1          # teren, ok. 2 min z renderem
powershell -NoProfile -File Modding\tools\build-arka02-mission.ps1 -Render  # misja, ok. 1 min
powershell -NoProfile -File Modding\tools\build-arka-previews.ps1 -Only arka02
```

## Teren

- **Dlaczego T3, nie T1:** T2 (Backwater Station) poszło na misję 1. T1 Wasteland ma 64×64 i jedną bazę, a T3 to ewakuacja: baza gracza w SW, gniazdo Zergów na północy, start Synów Korhalu, rzeki i brody. Do tego płaskowyż na SE z koloniami Zergów (w SC lokacja „Zerg Town”), który został Mar Sara City.
- **Zoom 1,5×** (nie 2×): 96×96 kafli SC daje `Size=0,0,76,153`, trochę więcej niż misja 1. Przy 2× droga do miasta i z powrotem byłaby za długa. Skrypt skaluje minikafle najbliższym sąsiadem z ułamkową skalą (`Floor(x / 1.5)`).
- **Beton:** szare platformy bazy SC (płaskowyże o szarym średnim kolorze SC) dostają `Pavement LAT tile`. Jedna z nich jest lądowiskiem Synów Korhalu (wp 19). W mieście na plac wokół CC, schronów i budynków też idzie beton (na pustyni to ciemnooliwkowe plamy). Asfaltowe drogi SC nie są przenoszone.
- Gejzery usunięte jak w misji 1. Minerały SC to niebieskie klejnoty: pole przy bazie (32 komórki) i dwa przy gnieździe.
- **Ekspansja (2026-10-28, miejsce zaznaczone przez użytkownika na renderze):** skrypt misji dokłada 35 pól klejnotów (nakładki 31–34, dane 9–11, jak konwerter) wokół skał na wschodniej równinie na północ od miasta, komórka 123,78. **(niezweryfikowane w grze)**
- **Pole pod zainfekowanym CC (2026-10-28, prośba użytkownika):** 37 klejnotów wokół 184,123, czyli „pod” CC (177,117) na ekranie (`+x +y` od dalszego rogu). Tylko wolne komórki na poziomie wysokości CC, więc pole nie zejdzie pod klif. Dokładane po rozstawieniu miasta, z własnym generatorem losowym (`Random 2502`), więc reszta mapy się nie przesuwa. W wersji v2026.10.28.2 zmieniły się tylko paczki nakładek. **(niezweryfikowane w grze)**
- **Creep od startu (2026-10-28, prośba użytkownika):** pod każdym Hatchery, Creep, Sunken i Spore Colony `Nod1` mapa ma Veinhole Monstera: nakładka 167 w komórce siewu budynku (Hatchery (1,1), kolonie (0,0)), 8× `VEINHOLEDUMMY` 3×3 i wyrośnięte żyły (126, dane 48) na pierścieniu 5×5, tak jak DTA zapisuje potwora w mapie. Bez żył w polu 5×5 `Place_Monsters` przy wczytaniu nie zbuduje kolejki wzrostu ([[engine/veins]]). Dziury co najmniej 3 pola od siebie. Wyszło 8 dziur: gniazdo (Hatchery, 3 Sunken, 2 Creep) i miasto (Creep Colony, Sunken w bramie). Mapa ma też to, czego misja nie dostaje z kodu frakcji: `[Basic] VeinGrowthEnabled=yes`, `[General] VeinholeGrowthRate=60` i `ImmuneToVeins=yes` dla 850 typów (Rules i skopiowane SC, plus bohaterowie ARKI). Dziury z mapy nie mają znacznika „ginie z budynkiem”, więc zostają po zniszczeniu budynku ([[mods/zerg-creep]]). **(niezweryfikowane w grze)**
- **Creep wersja 2 (2026-10-28, wzorem ARKA 4):** wersja pierwsza kładła żyły tylko na pierścieniu 5×5 wokół dziur, więc Pool, Hydra Den, Spire i zainfekowane CC stały na gołej ziemi. Teraz:
  - żyły leżą w kole o promieniu 5 wokół dziury i pod każdym budynkiem `SCZ*` z marginesem 1 pola;
  - blok jest zapisywany na końcu, po skrzynkach;
  - mapa dostaje `Insignificant=yes` dla `VEINS`/`VEINHOLEDUMMY` i 4 siewniki w `[Animations]` (`ARKA2ZC01–04`);
  - dziura sprawdza teren 3×3 (czysty grunt). Gdy pole siewnika leży przy skale, dziura przechodzi na inne pole fundamentu: Sunken 169,122 → 170,122, Sunken przy bramie miasta 82,88 → 83,89. Pierwsza wersja kładła tam `VEINHOLEDUMMY` na skale;
  - luźne łaty żył (bez połączenia z dziurą, gra usuwa je przy wczytaniu) skrypt spina z creepem drogą BFS.

  Wynik: 8 dziur pod 12 budynkami, 619 pól żył, 0 luźnych. **(niezweryfikowane w grze)**
- Kontrole: 0 nieudanych łańcuchów klifów, wszystkie 46 waypointów osiągalne z wraku. Skrypt wypisuje długość drogi do każdego (wrak → lądowisko 35 komórek, bród 52, brama miasta 81, CC 84, schrony 96–111, gniazdo 122).
- Biała linia murów wzdłuż środkowej rzeki to mury konwertera z nieprzechodnich doodadów SC (jak w misji 1).

## Waypointy (kontrakt teren ↔ misja)

Współrzędne w kaflach oryginalnej mapy SC (96×96). Skrypt przesuwa każdy na najbliższą wolną komórkę.

| Nr | Kafel SC | Co | Nr | Kafel SC | Co |
|---|---|---|---|---|---|
| 10 | 9,86 | wrak ARKI | 30 | 88,70 | zainfekowane Command Center |
| 11 | 22,88 | start oddziału gracza | 31 | 84,75 | przed CC (punkt na trasie Raynora; drzwi CC = wp 61, liczony przez generator) |
| 12–15 | 3,81 / 16,82 / 3,92 / 17,93 | 4 elektrownie rdzenia | 32–34 | 82,85 / 92,90 / 93,64 | schrony 1–3 |
| 16 | 27,90 | Construction Yard | 35 | 78,67 | brama miasta |
| 17 | 31,86 | koszary | 36–39 | 87,80 / 91,76 / 85,91 / 94,82 | ruiny miasta |
| 18 | 21,80 | rafineria (kryształy) | 40 | 24,57 | bród zachodni (stado) |
| 19 | 47,88 | lądowisko Synów Korhalu (platforma) | 41 | 40,46 | środkowa równina |
| 20 | 44,20 | zbiórka fal (gniazdo) | 42 | 62,58 | wschodnia równina (stado) |
| 21 | 42,22 | Wylegarnia | 43 | 73,63 | przed miastem (stado) |
| 22–24 | 40,17 / 49,16 / 47,25 | Spawning Pool, Hydralisk Den, Spire | 44 / 46 / 47 | 30,2 / 1,38 / 95,44 | wloty fal: N, W, E |
| 25–27 | 32,21 / 52,22 / 44,28 | Sunken Colony | 45 | 14,66 | linia obrony bazy N |
| 28–29 | 37,12 / 55,14 | Creep Colony | 48 | 95,28 | (nieużywany) wlot E |
| 49 | 60,40 | flota Protossów na radarze | 50 | 95,2 | wlot Mutalisków |
| 51 | 56,76 | bród południowy (główna droga) | 52 | 90,68 | Zergi w mieście |
| 53 | 33,76 | wschodnie podejście do bazy | 54 | 53,81 | posterunek Synów Korhalu |
| 55 | 1,71 | wlot Konfederacji (zachód) | | | |

## Domy

| Dom | Rola |
|---|---|
| `Allies` (2) | gracz, 4000 kredytów, `TechLevel=3` i ta sama lista wyłączeń co w misji 1 (do średniego czołgu, bez lotnictwa) |
| `Allies1`, `Allies2`, `Soviet1` | koloniści schronów 1–3 i **ich bunkry** (sojusznicy, nie do sterowania). Działko bunkra strzela do Zergów |
| `Soviet2` | ruiny Mar Sara City (Supply Depoty, Barracks, Academy), sojusznik |
| `Soviet` (3) | Synowie Korhalu (Mengsk) |
| `GDI2` (8) | Raynor w drodze do miasta: **sprzymierzony ze wszystkimi** (też z Zergami), żeby nikt go nie zastrzelił po drodze |
| `Nod1` (7) | Zergi: miasto i fale z krawędzi mapy. 0 kredytów, więc nie naprawia zainfekowanego CC |
| `Nod` (1) | **gniazdo na północy** z własnym AI (od 2026-10-29, `ZergAI.ps1`): `IQ=5`, 3000 kredytów na drony, wykluwa drużyny w Spawning Pool |
| `Nod2` (9) | stada na drodze do miasta („droga czysta” = wszystkie jednostki `Nod2` zniszczone) |
| `GDI` (0) | oddział Konfederacji z rozkazem aresztowania Raynora, wrogi wszystkim |
| `Neutral` | nieużywany. W wersji 1 miał ruiny i schrony, ale SC Bunker `Neutral` ma działko i strzelał do gracza (test 2026-10-27) |

**Baza gracza (od wersji 2):** wrak, 4 elektrownie, ConYard, koszary, rafineria z harvesterem, **War Factory** (`RAWEAP`) i **6 SC Bunkrów gracza** na płaskowyżach przy bazie: 5 na płaskowyżu w kształcie jodełki na północ od wraku (narożniki i końce ramion, 125,170 / 136,169 / 149,169 / 125,177 / 148,178) i 1 na płaskowyżu lądowiska (169,172). Wszystkie płaskowyże mają rampy (flood fill z bazy dochodzi wszędzie), więc Zerglingi też tam wejdą.

## Przebieg (czas gry w sekundach)

| Kiedy | Co się dzieje |
|---|---|
| 1–234 | Raynor (mapa kolonii), Duke („aresztować”), Tanya, Raynor („pojadę przodem”), Stavros (bród na południu), cel 1, warunki porażki, gniazdo na północy. Raynor czeka 3 minuty w bazie (`5,30`, dodane 2026-10-27: użytkownik zgłosił, że jedzie za wcześnie), potem odjeżdża drużyną `GDI2` (`3,43` → `3,31` → `3,61` → `39,19` → `37` usuń): „wchodzi” do CC przez komórkę tuż pod nim (wp 61, liczona przez generator przy budynku, 2026-10-27; wcześniej znikał na wp 31, ok. 10 komórek dalej) i ustawia lokalną 19 „Raynor w CC”. Jego Marines zostają u gracza. |
| `Nod2` bez jednostek | cel 1 wykonany (droga czysta) |
| wejście w strefę bramy (wp 35, r ≤ 6) albo przedpola (wp 43, r ≤ 4) **po** ustawieniu lokalnej 19 (triggery stref są wyłączone, włącza je `rayInCC`; inaczej Raynor wzywałby z drogi), najpóźniej 1200 | Raynor przez radio: odcięty w CC. **Licznik 10:00** (zdrowie Raynora), cel 2: wysadzić CC |
| strefa tuż przy CC przed uwolnieniem | Tanya: „Wyłaź, kowboju, zaraz będzie głośno.” |
| CC zniszczone (`48`) | licznik stop, błysk, drużyna gracza z Raynorem na wp 61 tuż pod ruiną CC („Mogłaś zapukać!”), fajerwerki z muzeum, „Robione ręcznie”, cel 3 |
| cel 3 + 41 s | Synowie Korhalu lądują przy platformie (5 Marines, 2 Goliathy, 2 Dropshipy), Mengsk ×2, Einstein o bankierze |
| gracz był w strefie schronu (r ≤ 4, kiedykolwiek) **i** cel 3 aktywny | wychodzi 6 kolonistów (dom schronu) na wolnej komórce przed bunkrem (wp 56–58), sami idą na lądowisko; skrypt `39,N` ustawia lokalną „uratowany”, `37` usuwa ich („na pokładzie”) |
| 2 schrony uratowane | **skok**: licznik 15:00, muzyka, 4 elektrownie muszą wytrzymać; fale +60 (8 Zerglingów), +200 (zachód), +330 (północ, z Infested Terran), +440 (3 Mutaliski), +500 (trudny), +540 **Konfederacja** z zachodu (6 Marines, 2 Firebaty, 2 Vulture'y, 2 Goliathy, Siege Tank) z kwestią Duke'a, +680 dwie fale naraz, +830 flota Protossów na radarze |
| licznik 0 | porażki wyłączone, błyski, „SKOK!”, epilog na Antidze Prime (Mengsk „spóźniliście się trzy dni”, „dla nas to była sekunda”, „to był mój dom”), **wygrana** |
| 560 | dzikie stado z zachodu (wp 46) |
| od 300 | **AI gniazda** (niżej): drużyny wyklute w gnieździe na zbieracze, bazę, kolonistów i ARKĘ, obrona gniazda, pomoc dla miasta |

**Porażka:** śmierć Einsteina, Tanyi lub Raynora (po uwolnieniu), zniszczenie wraku ARKI, licznik Raynora do zera, 2 schrony stracone (wszyscy koloniści grupy zginęli, zanim doszli), wszystkie 4 elektrownie zniszczone, utrata wszystkiego. Każda zniszczona elektrownia wydłuża licznik o 60 s.

## AI gniazda Zergów (2026-10-29, prośba użytkownika)

„Daj Zerga bardziej aktywnego … ma atakować, bronić się, odpowiadać na ataki gracza … ale naprawdę buduje Zergi czy Broodlingi”. Gniazdo (Wylegarnia, Spawning Pool, Hydralisk Den, Spire, kolonie, strażnicy, Overlordy) należy teraz do domu `Nod`, a jego zachowanie robi `Add-ZergAI` z [[engine/zerg-ai]]. Usunięte zostały najazdy z gniazda wykluwane wcześniej akcją `80` (`raid2`, `raidRep`, fale skoku 1 i 5 z wp 20). Fala skoku 1 idzie teraz z północnej krawędzi (wp 44). Bez zmian zostały stado z zachodu (560 s), fale skoku z krawędzi, Mutaliski i Konfederacja. **(niezweryfikowane w grze)**

| Zamówienie | Skład (Hard) | Kiedy | Trasa |
|---|---|---|---|
| na zbieracze | 4 Zerglingi, 2 Broodlingi | od 300 s co 360 s, do skoku | bród zachodni (wp 40), `0,3` harvestery, Hunt |
| najazd | 6 Zerglingów, 2 Hydraliski | od 480 s co 420 s, do skoku | linia obrony N (45), baza (10), Hunt |
| duży najazd | 6 Zerglingów, 4 Broodlingi, 4 Hydraliski | od 1500 s co 480 s, do skoku | równina (41), wschodnie podejście (53), baza |
| na kolonistów | 5 Zerglingów, 3 Broodlingi | co 300 s od celu 3 (lokalna 15) do skoku | bród południowy (51), Hunt |
| atak na ARKĘ | 8 Zerglingów, 4 Broodlingi, 4 Hydraliski | co 150 s w czasie skoku (lokalna 8) | bród zachodni, baza |
| obrona | 6 Zerglingów, 4 Broodlingi | alarm: gracz w pasie 5–8 pól od budynków gniazda (844 komórki, tag `ARKA2Z01`) albo atakuje Den, Spire lub kolonie gniazda (`ARKA2Z02`); potem 150 s przerwy | Hunt od gniazda |
| kontratak | 6 Zerglingów | razem z obroną | linia obrony N, baza |
| pomoc dla miasta | 4 Zerglingi, 2 Hydraliski | gracz atakuje Creep Colony albo Sunken w bramie miasta (`ARKA2Z03`); potem 240 s | przedpole (43), miasto (52), Area Guard |
| rozbudowa | 3 drony → Sunken Colony | 600, 900, 1200 s | 76,73 / 64,83 / 60,87, od strony środkowej równiny, na creepie |

- Koniec gniazda: zniszczenie Wylegarni (stary trigger `hatch`, teraz z lokalną 21) albo Spawning Pool (`ARKA2Z04`). Potem nie ma zamówień ani zapasowego wyklucia.
- Easy i Medium mają te same zamówienia, z drużynami 1/2 i 3/4.
- Stavros na starcie: „Gniazdo na północy wykluwa Zergi i wysyła je na nas. Bez Wylegarni albo Niecki ucichnie.”
- Hydraliski i Broodlingi wymagają w tej mapie tylko Niecki i Wylegarni (`Prerequisite=SCZPOL,SCZHAT`). Hydralisk Den nie jest potrzebny, a Broodling nie wymaga Queen's Nest.

**Do sprawdzenia w grze:**
- czy przy Niecce pojawiają się nowe Zerglingi i Broodlingi (produkcja) i czy drużyna rusza dopiero w komplecie;
- czy około 240 s po zamówieniu drużyna nie pojawia się „z powietrza” na wp 20. To byłby strażnik, czyli znak, że produkcja nie działa;
- czy wejście pod gniazdo wywołuje kwestię Stavrosa i obronę;
- czy ostrzał kolonii w mieście ściąga posiłki;
- czy drony stawiają Sunkeny;
- czy tempo nie jest za ostre.

## Odstępstwa od planu

- **Elektrownie:** plan mówi „postawić 4 elektrownie przy wraku”. Silnik nie umie policzyć zbudowanych budynków jednego typu (`32 Building exists` widzi tylko „jest/nie ma”), więc 4 elektrownie rdzenia stoją od startu (przetrwały katastrofę) i trzeba ich bronić. Gracz może stawiać kolejne, ale do skoku liczą się te 4.
- **Raynor nie jest odcięty na oczach gracza:** jedzie przodem i znika w CC (skrypt drużyny `37`), a wraca nową drużyną gracza z tagiem. Bez zmiany domu, więc bez pułapki z fałszywą porażką z misji 1.
- Epilog (Mengsk na Antidze, Mar Sara płonie) jest tekstem po skoku, przed wygraną.

## Nowe mechanizmy (względem misji 1)

- **`Tag=` w TeamType:** tag dostaje każdy członek drużyny stworzonej akcją `80` (wzór DTA `cr07`: drużyna MCV z tagiem „genocide”). Tak Raynor po wyjściu z CC ma tag „Raynor zginął” **(niezweryfikowane w grze)**.
- **Eskorta bez stref na mecie:** drużyna kolonistów ma skrypt `3,19` (idź na lądowisko) → `39,N` (ustaw zmienną lokalną N) → `37,0` (usuń członków drużyny). Zmienna mówi „uratowani”, a usunięcie to „wsiedli”. Porażkę grupy liczy `9 Destroyed, Units, All` domu grupy (od wersji 2 dom ma też bunkier, więc nie `11`) **i** `37 Local is clear N`, bo usunięcie też opróżnia dom; trigger porażki jest włączany 5 s po pojawieniu się grupy (pusty dom na starcie dałby „zniszczony” od razu).
- **„Dwa z trzech”** bez OR: trzy triggery na pary zmiennych (`36` i `36`), każdy wyłącza pozostałe.
- **Jeden licznik, dwa cele:** licznik Raynora (600) i licznik skoku (900) to ten sam licznik na ekranie. Trigger „licznik zero” Raynora jest włączany przy wezwaniu i wyłączany przy wysadzeniu CC (`24 Timer Stop`), a trigger skoku włącza dopiero start skoku.
- SC typy dodane względem misji 1: `SCZINF` (Infested Terran), `SCZICC` (w mapie 6000 HP zamiast 12 000, bez `Factory`/`Naval`), `SCZHDN`, `SCZSPI`, `SCGOLI`, `SCSIEGE`, `SCDROP`. Razem 61 sekcji. Koloniści to `ARKCIV1/2` (rozwinięte `C2`/`C8`, 200 HP, `Fraidycat=no`, bo panikujący cywil opuszcza drużynę).

## Poprawki po teście (2026-10-27, wersja 2)

Użytkownik zgłosił: koloniści nie wychodzą po uwolnieniu Raynora, bunkry w mieście są wrogie, bunkry nie chowają piechoty, baza startowa za skromna.

- **Koloniści:** w wersji 1 wychodzili drużyną akcji `80` **na waypoincie schronu, który leżał pod bunkrem** (3×2 na wp), z triggera komórkowego wyłączonego do celu 3. Dokładna przyczyna nie jest pewna, więc usunięto oba podejrzane elementy. Wyjście jest teraz na wolnej komórce przed bunkrem (wp 56–58). Trigger komórkowy „gracz przy schronie” jest włączony od startu i tylko ustawia lokalną 16–18. Wychodzenie robi trigger logiczny `36 local 15` (cel 3 aktywny) **i** `36 local 15+k`. Gracz, który stał przy schronie już w czasie walki o CC, nie musi więc wychodzić ze strefy i wracać **(niezweryfikowane w grze)**.
- **Wrogie bunkry:** schrony należały do `Neutral`, a SC Bunker ma działko `SCBunkerGun`, więc strzelał do gracza. Schrony mają teraz domy kolonistów, a ruiny `Soviet2`.
- **Piechota w bunkrze:** silnik TS ani Vinifera nie ma garnizonów. `Garrison`/`OpenTopped`/`Bunker` z RA2 nie istnieją (sprawdzone w napisach `Vinifera.dll`). Nawet transport-atrapa (nieruchomy pojazd z `Passengers=`) nie da strzelania ze środka. Pasażerowie siedzą w środku, ale nie strzelają (`IsVehicleTransport=yes` z [[engine/transports]] wpuściłby nawet Marines-pojazdy, ale też nie dałby im strzelać). SC Bunker zostaje „obsadzony czterema Marines” (opis typu): ma własne działko 2×15.
- **Baza:** dodane War Factory i 6 bunkrów gracza na płaskowyżach (wyżej, w „Domach”).

## Poprawki po teście 2 (2026-10-27, wersja 3)

- **C4 Tanyi na zainfekowane CC:** Tanya mogła tylko strzelać. Przyczyna w `game.exe` (`InfantryClass::What_Action`, `0x4D73BA`, wejście przekierowane przez DTA do `0x86B0E0` i z powrotem). Piechota z `C4=yes` (`InfantryTypeClass::IsBomber`, `+0x4AF`) dostaje akcję Sabotage (15) zamiast Attack (5) tylko wtedy, gdy typ budynku ma **`IsRepairable`** (`TechnoTypeClass+0x450`, `Repairable=`). Budynki Zergów w `StarCraft.ini` mają `Repairable=no`. W mapie `SCZICC` dostaje `Repairable=yes` i `ClickRepairable=no`; Zergi i tak nie naprawią, bo `Nod1` ma 0 kredytów **(niezweryfikowane w grze)**.
- **Dropshipy na lądowisku:** razem z lądowaniem Synów Korhalu pojawiają się 2 Dropshipy (`Soviet`, skrypt `11,5` „stój”) na wp 59 i 60 obok lądowiska. Nie stoją na samym wp 19, bo tam idą koloniści i stojący Dropship mógłby zablokować im dojście (skrypt nie doszedłby do „uratowani”). Drużyna Synów Korhalu na wp 54 nie ma już Dropshipów.

## Przypominajki celów (2026-10-29)

Prośba użytkownika: przypominajki celów i postęp we wszystkich misjach, „ale nie przesadzaj”. Funkcje `Add-ObjectiveReminder` i `Add-CountProgress` z `Modding/tools/MissionKit.ps1` ([[engine/triggers-and-dialogue]]):
- **Cel 1 (droga):** przypominajka co 900 s gry od tekstu celu (`intro6`) do oczyszczenia drogi (lokalna 13).
- **Cel 3 (schrony):** przypominajka co 900 s od tekstu celu (`shelters`) do startu skoku (lokalna 8). Postęp: po każdym uratowanym schronie „Uratowane schrony: k z 3 (potrzeba 2)” (lokalne 2–4, kolejność dowolna). Ta linia zastąpiła osobny tekst pilota w `civSaved1–3`, żeby nie było dwóch tekstów naraz; trzeci schron ma własną linię (`civAll`).
- Cele 2 (Raynor) i 4 (skok) mają licznik na ekranie, więc bez przypominajki.

Przebudowa: CHECKS PASS, oś tekstów 0 WARN. **(niezweryfikowane w grze)**

## Briefing (2026-10-27)

Film w stylu SC `MOVIES\ARKA02B.MP4` (Raynor, Duke przechwycony, Stavros, Einstein; 5 celów), spec `Modding/briefings/arka02.json`, podpięty jako `Brief=ARKA02B`. Mechanizm i generator: [[engine/briefing-movies]].

## Do sprawdzenia w grze

- Czy film `ARKA02B` odtwarza się przed misją (w `Debug/DEBUG_*.LOG` szukać `Play_Movie` i `ARKA02B`).

- Czy koloniści wychodzą przed bunkrem po celu 3 (wersja 2).
- Czy „Schron k stracony” nie pojawia się 5 s po wyjściu kolonistów: `ARKCIV1/2` mają z `C2` `Civilian=yes`, a zdarzenie `9` według `FSData.ini` pomija cywilów (zob. [[engine/triggers-and-dialogue]], pułapka 15). Jeśli tak, dopisać `Civilian=no` jak w [[missions/arka-05-tarsonis]].

- Czy Raynor jadący jako `GDI2` dociera do CC i znika (`37`), i czy wraca po wysadzeniu.
- Czy `Tag=` drużyny działa (śmierć Raynora po uwolnieniu = porażka).
- Czy koloniści idą na lądowisko na platformie (wp 19) i znikają, a „uratowany” się liczy; czy Zergi ich atakują (powinny).
- Czy Tanya wysadza `SCZICC` C4 (budynek Zergów z `Capturable=false`).
- Tempo: licznik 10:00 na Raynora i 15:00 skoku, siła fal i Konfederacji, długość marszu do miasta.
- Czy klient pokazuje `M_ARKA02` i podgląd `arka02.png`.
