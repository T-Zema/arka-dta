# ARKA 6 „Ogień z nieba” (Antiga Prime, 2500): mapa i misja

Szósta misja z [[plans/campaign-arka]]. Teren to niewydana mapa kampanii StarCrafta **T7 „Biting the Bullet”** (CASC `Terran07`, „Antiga Prime Colony: 08:56 SCT, 01.03.2500”, z flotą Tassadara: Gantrithor, Carriery, Scouty przy zachodniej krawędzi). Mapa jest powiększona 1,25× i przeniesiona na TEMPERATE z gruntem Antigi z misji 4. **Na razie jest tylko teren** (2026-10-30). Misja (triggery, domy, typy) nie jest napisana.

Źródła: CASC StarCrafta `SD/campaign/Terran/Terran07/staredit/scenario.chk` (obejrzane też `Protoss01` First Strike, `Protoss02`, `Terran05`, `Terran08` The Trump Card), `Modding/tools/build-arka06-antiga.ps1`, rozmowa z użytkownikiem 2026-10-30.

## Pliki

| Plik | Rola |
|---|---|
| `Maps/Custom/arka06_antiga.map` (+ `.png`) | teren (do obejrzenia w skirmishu „Custom Map”), waypointy 10–47; **nadpisywany** przez skrypt terenu |
| `Maps/Missions/arka06.map` | misja (etap 1: ARKA i Antioch, bez triggerów); **nadpisywana** przez skrypt misji; jeszcze bez wpisu w `BattleE.ini` |
| `Modding/tools/build-arka06-mission.ps1` | misja, etap 1: typy SC skopiowane do mapy, ARKA, kolonia Antioch; `-Render` |
| `Modding/tools/build-arka06-antiga.ps1` | teren: CASC → groble → ScToDta, zoom 1,25, TEMPERATE, grunt Antigi, lądowisko ARKI, place, ulice, kryształy, kopalnie, kontrole |
| `%TEMP%\arka06-terrain\` | `sc_grid.png` (mapa SC z siatką, groblami i waypointami, **do planowania**), `grid.png`, `reach.png`, `log.txt`, pełny render `arka06_antiga_full.png`, `arka06_strefy.png` (render z opisanymi strefami) |

```powershell
powershell -NoProfile -File Modding\tools\build-arka06-antiga.ps1          # teren, ok. 2 min z renderem
```

## Wybór mapy SC

| Folder | Mapa | Dlaczego tak / nie |
|---|---|---|
| `Terran07` | **Biting the Bullet** (128×128 badlands) | **wybrana.** Antiga 2500, flota Tassadara w oryginale. Badlands daje błotnisty wygląd Antigi z misji 4. Szerokie południowe wybrzeże pod rozbudowaną bazę. Wada: w SC to archipelag (mapa powietrzna), środek, NE i SE to wyspy, stąd groble |
| `Protoss01` | P1 First Strike (96×96 jungle) | Antiga, cel „rescue Fenix”, połączona po ziemi, ale zielona dżungla z autostradami Protossów, mniejsza; zapas, gdyby T7 nie przeszła |
| `Terran08` | T8 The Trump Card (128×96 badlands) | Antiga, oblężona tajna baza, zostawiona na misję 7 „Zdrada” |
| `Terran05` | T5 The Antigan Revolt | na misję 3 |

## Teren

- **ARKA w nowym miejscu** (pomysł użytkownika 2026-10-30): po roku Terranie doczepili ARCE silniki odrzutowe, więc może latać jak budynki Terran. Stoi na lądowisku (bruk r 7) na południowym wybrzeżu, gdzie w SC startują Raynor i Duke. Obok pole kryształów bazy.
- **Groble** (przed konwersją skrypt podnosi pas minikafli SC przez kanały, kolor = średni grunt mapy): ARKA ↔ środek (8 kafli), środek ↔ zachód (5), środek ↔ NE (5), ARKA ↔ wyspa SE (8). Pas 3-kafelkowy konwerter brał za most SC (bruk z ząbkami na wodzie, przesmyk 2 komórek). Od 5 kafli powstaje naturalny przesmyk z brzegami. Pionowe pasy potrzebują 8, bo w rzucie izometrycznym są węższe.
- **Brzegi** (użytkownik 2026-10-30: „problem z wodą i water clifami”, zrzut z wyspy SE): poprawka konwertera z sesji ARKA 3 (`PruneBridges`, `RepairCoast`, [[engine/starcraft-maps]]) i **plaże pod klifami** w skrypcie. Wiele płaskowyżów SC schodzi prawie do wody i zostaje pas ziemi szerokości jednej komórki, w którym nie mieści się water cliff. Dlatego przed konwersją woda w promieniu 6 minikafli od wysokiego terenu staje się lądem. Wyjątki: minikafel, przy którym w promieniu 9 leży ląd dwóch różnych składowych (≥ 200 minikafli), zostaje wodą, więc plaża nie łączy wysp. Bez testu „niebieskie = woda”, bo woda u stóp klifu jest w SC zacieniona na brązowo. Wynik: surowych krawędzi wybrzeża 29 → 8, 0 nieudanych łańcuchów, trasy bez nowych skrótów (płaskowyż NW dalej 151 komórek).
- **Artefakty ze zrzutów użytkownika (2026-10-30), poprawki w skrypcie terenu:**
  - **płaskowyż NE spłaszczony.** Jego krawędź miała ten sam grunt po obu stronach i wyglądała jak zabłąkana linia klifu; obozy Raynora stoją teraz na równym;
  - **woda węższa niż ok. 2 kafle zasypana** (otwarcie morfologiczne wody, promień 4 minikafle, ta sama ochrona przed łączeniem lądów co przy plażach). Dotyczy skrawka wody przy Antioch, mini-jeziorka NW i paska wody SW;
  - **skrawki lądu odcięte wodą** (po klasyfikacji, poniżej 40 komórek) zamienione w wodę. Ten krok po `SettleWater` zalewał plażę pod klifem, więc go nie ma;
  - **kanał między płaskowyżem NW a środkiem zasypany** (wybór użytkownika, kafle SC 42–58 × 41–50). Miał ok. 2 kafle szerokości i ciągle dawał ząbki. Powstał niski teren pod klifem płaskowyżu, a trasy się nie zmieniły (wjazd na płaskowyż dalej od zachodu);
  - resztę zrobiła poprawka konwertera z sesji ARKA 3: `MinWaterBody=60`, naprawa końców łańcuchów brzegu, usuwanie kawałków brzegu na suchym lądzie.

  Wynik: surowych krawędzi 14 → 3, końców łańcuchów 8 → 6, 0 nieudanych łańcuchów, 38/38 waypointów osiągalnych.
- **Strefy:** baza Aliantów na S; strefa Protossów na W (Pylony: wp 20 NW pod Gantrithorem, 21 W, 22 SW; obóz Fenixa wp 23); Synowie Korhalu na NE (obóz wysunięty wp 35, główny 36); środek na wysokim płaskowyżu (wp 30, plac) to miejsce spotkania z Tassadarem, a groble z W i NE spotykają się na nim, więc Fenix i Raynor ścierają się w środku.
- **Ulice** (Paved Road LAT): ARKA → środek (droga Einsteina), środek → obóz Protossów, środek → obóz Raynora → jego główny obóz; 0 wolnych końców.
- **Kryształy** (bez złota): bazy (wp 15, 48 pól, bezpieczne), zachód (25, 32, w strefie Protossów), płaskowyż NW (26, 69, daleko, bogate), środek (31, 41 + kopalnia `OREMINE2`, sporne), wyspa SE (38, 49 + kopalnia, bogate i wystawione), NE (37, 51; 40, 22; Raynora).
- Kontrole 2026-10-30: wszystkie 34 waypointy osiągalne z ARKI (środek 45 komórek, Pylon SW 47, obóz Protossów 85, Raynor 116).

## Kolonia Antioch (wyspa SE)

Użytkownik 2026-10-30: „render z budynkami neutralnymi, jeśli w scenariuszu to jest miasto”. Scenariusz mówi o kolonii („wszystkie ekrany Antigi pokazują orędzie Mengska”), więc na wyspie SE stoi **Antioch** (w lore SC miasto na Antidze Prime, z misji Protossów „First Strike”). Z bazą ARKI łączy ją grobla SE i ulica. Zgodnie z zasadą użytkownika miasto składa się z **budynków Terran SC w dzielnicach tematycznych z przybudówkami**, jak Nowy Gettysburg w [[missions/arka-05-tarsonis]]. Właściciel to dom `Neutral`, bo kolonia przeczekuje wojnę.

| Wp | Dzielnica | Budynki |
|---|---|---|
| 50 | plac główny | 4 Supply Depoty (mieszkania kolonistów) |
| 51 | administracja | Command Center + Comsat, Academy, Engineering Bay, 2 Missile Turrety, Bunker |
| 52 | port kosmiczny (N) | 2 Starporty + Control Tower, Science Facility + Physics Lab, Supply Depot |
| 53 | górnicza (płaskowyż przy kryształach wp 38) | Factory + Machine Shop, Armory, 2 Supply Depoty |
| 51 / 53 / 52 | budynki neutralne SC ([[mods/sc-neutral-buildings]], `ECACHE75`) | 2 Power Generatory `SCNGEN`, stacja kosmiczna `SCNSTB` przy porcie |

Place (bruk) przy 50–53 i ulice od placu 50 do każdej dzielnicy, 0 wolnych końców. Budynki stawia `build-arka06-mission.ps1` (etap 1: tylko obiekty, czyli ARKA i Antioch, a typy SC są skopiowane do mapy z `TechLevel=-1`; bez domów, drużyn i triggerów). Budynek nie staje na ulicy ani na dwóch poziomach naraz. Render: `%TEMP%\arka06-mission\arka06_mission.png`, zbliżenie `antioch.png`. Rola kolonii w misji jest jeszcze do ustalenia.

## Budynki neutralne SC (pytanie użytkownika 2026-10-30)

SC nie ma cywilnych domów jako jednostek. Neutralne budynki z grafiką (`unit/neutral/*.grp`) to Power Generator (`Generate`, cywilna elektrownia Terran), `starbase` (nieużywana stacja), Stasis Cell, `gastank`, wrak Norad II, Ion Cannon, świątynia Xel'Naga i Psi Disrupter; szczegóły w [[missions/arka-07-zdrada]] („Budynki neutralne SC”). Domy, sklepy z neonami i szklane pawilony badlands (tileset Antigi) to **doodady terenu** #29–#46, nie obiekty. Arkusze: `%TEMP%\arka06-mission\sc_neutral.png`, `sc_domy_badlands.png`. Przeróbka doodadów na budynki DTA to osobny generator grafiki z numerem MIX (wspólny z misją 7). **Do decyzji użytkownika.**

## Waypointy (kontrakt teren ↔ misja)

Kafle oryginalnej mapy SC (128×128); skrypt przesuwa każdy na najbliższą wolną komórkę. Pełna lista z opisami: `$wps` w skrypcie.

| Nr | Co | Nr | Co |
|---|---|---|---|
| 10 | ARKA (lądowisko) | 20 / 21 / 22 | Pylony NW / W / SW |
| 11 / 12 | start armii / środek bazy | 23 | obóz Protossów, Fenix |
| 13 | Einstein przy ARCE | 24 | Gantrithor (Tassadar) |
| 14 | baza: elektrownie | 25 / 26 | kryształy W / płaskowyż NW |
| 15 | kryształy bazy | 30 | środek, spotkanie z Tassadarem |
| 16 / 17 / 18 / 19 | bramy bazy W / N / E, grobla na wyspę SE | 31 | kryształy środka |
| 32 / 33 / 34 | środek: końce grobli W / NE / S | 35 / 36 | Synowie Korhalu: obóz wysunięty / główny |
| 37 / 40 | kryształy NE | 38 / 39 | wyspa SE: kryształy / środek (skrzynka) |
| 42 / 43 / 44 | wloty: W, NW, SW | 45 / 46 / 47 | wloty: NE, E, E-południe (powietrze) |
| 50 / 51 | Antioch: plac / administracja | 52 / 53 | Antioch: port kosmiczny / dzielnica górnicza |

## Do zrobienia

- Ocena terenu przez użytkownika (render pokazany 2026-10-30), potem skrypt misji `build-arka06-mission.ps1`: ARKA lądująca na start (latająca jak budynki Terran), fale Fenixa przez Pylony, Raynor z Siege Tankami i Vulture'ami, eskorta Einsteina na środek, rozejm.
