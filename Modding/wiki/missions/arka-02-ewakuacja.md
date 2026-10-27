# ARKA 2 „Ewakuacja” (Mar Sara, 2499): mapa i misja

Druga misja na Mar Sarze z [[plans/campaign-arka]]. Teren to mapa kampanii StarCrafta **T3 „Desperate Alliance”** (w SC: przetrwać 30 minut do ewakuacji przez Synów Korhalu) z CASC użytkownika, powiększona 1,5× i przeniesiona na pustynny teatr DTA. Na niej: baza Aliantów przy wraku ARKI, Mar Sara City z zainfekowanym Command Center, trzy schrony z kolonistami, lądowisko Synów Korhalu i 15 minut ładowania skoku. Kompletna od startu do wygranej, **(niezweryfikowane w grze)**.

Źródła: CASC StarCrafta `SD/campaign/Terran/Terran03/staredit/scenario.chk` (T3, 96×96 badlands; obejrzane też T1 Wasteland), `Modding/tools/build-arka02-marsara.ps1`, `Modding/tools/build-arka02-mission.ps1`, `Modding/tools/build-arka-previews.ps1`, `Map Editor/FinalSun/FSData.ini` (`[Scripts]` 37 i 39), `Maps/Missions/cr07.map` (`Tag=` w drużynie), `INI/Map Code/Terran Faction.ini` (`[SCZICC]`, `[SCZINF]`), `INI/Rules.ini` (`[TANYA]` `C4=yes`, `[C2]`, `[C8]`), [[missions/arka-01-marsara]] (wzór).

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
- Kontrole: 0 nieudanych łańcuchów klifów, wszystkie 46 waypointów osiągalne z wraku. Skrypt wypisuje długość drogi do każdego (wrak → lądowisko 35 komórek, bród 52, brama miasta 81, CC 84, schrony 96–111, gniazdo 122).
- Biała linia murów wzdłuż środkowej rzeki to mury konwertera z nieprzechodnich doodadów SC (jak w misji 1).

## Waypointy (kontrakt teren ↔ misja)

Współrzędne w kaflach oryginalnej mapy SC (96×96). Skrypt przesuwa każdy na najbliższą wolną komórkę.

| Nr | Kafel SC | Co | Nr | Kafel SC | Co |
|---|---|---|---|---|---|
| 10 | 9,86 | wrak ARKI | 30 | 88,70 | zainfekowane Command Center |
| 11 | 22,88 | start oddziału gracza | 31 | 84,75 | przed CC (tu wychodzi Raynor) |
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
| `Nod1` (7) | Zergi: gniazdo, miasto, fale |
| `Nod2` (9) | stada na drodze do miasta („droga czysta” = wszystkie jednostki `Nod2` zniszczone) |
| `GDI` (0) | oddział Konfederacji z rozkazem aresztowania Raynora, wrogi wszystkim |
| `Neutral` | nieużywany. W wersji 1 miał ruiny i schrony, ale SC Bunker `Neutral` ma działko i strzelał do gracza (test 2026-10-27) |

**Baza gracza (od wersji 2):** wrak, 4 elektrownie, ConYard, koszary, rafineria z harvesterem, **War Factory** (`RAWEAP`) i **6 SC Bunkrów gracza** na płaskowyżach przy bazie: 5 na płaskowyżu w kształcie jodełki na północ od wraku (narożniki i końce ramion, 125,170 / 136,169 / 149,169 / 125,177 / 148,178) i 1 na płaskowyżu lądowiska (169,172). Wszystkie płaskowyże mają rampy (flood fill z bazy dochodzi wszędzie), więc Zerglingi też tam wejdą.

## Przebieg (czas gry w sekundach)

| Kiedy | Co się dzieje |
|---|---|
| 1–234 | Raynor (mapa kolonii), Duke („aresztować”), Tanya, Raynor („pojadę przodem”), Stavros (bród na południu), cel 1, warunki porażki, gniazdo na północy. Raynor odjeżdża drużyną `GDI2` (`3,43` → `3,31` → `37` usuń): „wchodzi” do CC. Jego Marines zostają u gracza. |
| `Nod2` bez jednostek | cel 1 wykonany (droga czysta) |
| wejście w strefę bramy (wp 35, r ≤ 6) albo przedpola (wp 43, r ≤ 4), najpóźniej 1200 | Raynor przez radio: odcięty w CC. **Licznik 10:00** (zdrowie Raynora), cel 2: wysadzić CC |
| strefa tuż przy CC przed uwolnieniem | Tanya: „Wyłaź, kowboju, zaraz będzie głośno.” |
| CC zniszczone (`48`) | licznik stop, błysk, drużyna gracza z Raynorem na wp 31 („Mogłaś zapukać!”), fajerwerki z muzeum, „Robione ręcznie”, cel 3 |
| cel 3 + 41 s | Synowie Korhalu lądują przy platformie (5 Marines, 2 Goliathy, 2 Dropshipy), Mengsk ×2, Einstein o bankierze |
| gracz był w strefie schronu (r ≤ 4, kiedykolwiek) **i** cel 3 aktywny | wychodzi 6 kolonistów (dom schronu) na wolnej komórce przed bunkrem (wp 56–58), sami idą na lądowisko; skrypt `39,N` ustawia lokalną „uratowany”, `37` usuwa ich („na pokładzie”) |
| 2 schrony uratowane | **skok**: licznik 15:00, muzyka, 4 elektrownie muszą wytrzymać; fale +60 (8 Zerglingów), +200 (zachód), +330 (północ, z Infested Terran), +440 (3 Mutaliski), +500 (trudny), +540 **Konfederacja** z zachodu (6 Marines, 2 Firebaty, 2 Vulture'y, 2 Goliathy, Siege Tank) z kwestią Duke'a, +680 dwie fale naraz, +830 flota Protossów na radarze |
| licznik 0 | porażki wyłączone, błyski, „SKOK!”, epilog na Antidze Prime (Mengsk „spóźniliście się trzy dni”, „dla nas to była sekunda”, „to był mój dom”), **wygrana** |
| 560 / 1000, od 1500 co 450 | najazdy na bazę (zachód, gniazdo), dopóki stoi Wylegarnia i nie zaczął się skok |

**Porażka:** śmierć Einsteina, Tanyi lub Raynora (po uwolnieniu), zniszczenie wraku ARKI, licznik Raynora do zera, 2 schrony stracone (wszyscy koloniści grupy zginęli, zanim doszli), wszystkie 4 elektrownie zniszczone, utrata wszystkiego. Każda zniszczona elektrownia wydłuża licznik o 60 s.

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

## Briefing (2026-10-27)

Film w stylu SC `MOVIES\ARKA02B.MP4` (Raynor, Duke przechwycony, Stavros, Einstein; 5 celów), spec `Modding/briefings/arka02.json`, podpięty jako `Brief=ARKA02B`. Mechanizm i generator: [[engine/briefing-movies]].

## Do sprawdzenia w grze

- Czy film `ARKA02B` odtwarza się przed misją (w `Debug/DEBUG_*.LOG` szukać `Play_Movie` i `ARKA02B`).

- Czy koloniści wychodzą przed bunkrem po celu 3 (wersja 2).

- Czy Raynor jadący jako `GDI2` dociera do CC i znika (`37`), i czy wraca po wysadzeniu.
- Czy `Tag=` drużyny działa (śmierć Raynora po uwolnieniu = porażka).
- Czy koloniści idą na lądowisko na platformie (wp 19) i znikają, a „uratowany” się liczy; czy Zergi ich atakują (powinny).
- Czy Tanya wysadza `SCZICC` C4 (budynek Zergów z `Capturable=false`).
- Tempo: licznik 10:00 na Raynora i 15:00 skoku, siła fal i Konfederacji, długość marszu do miasta.
- Czy klient pokazuje `M_ARKA02` i podgląd `arka02.png`.
