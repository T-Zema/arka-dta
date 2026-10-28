# ARKA 4 „Zielony kryształ” (Antiga Prime, 2499): mapa i misja

Czwarta misja z [[plans/campaign-arka]]. Teren to mapa kampanii StarCrafta **T6 „Norad II”** (w SC dokładnie ta sama scena: okręt Duke'a rozbity na Antidze Prime w terenie Zergów) z CASC użytkownika, powiększona 1,5× i przeniesiona na teatr **TEMPERATE** (Antiga to muliste równiny, niskie płaskowyże i zarośla, nie pustynia Mar Sary). Misja ma być **spokojna i ekonomiczna** (prośba użytkownika 2026-10-27): 20 minut analizy bez licznika na ekranie, Norad II bez pośpiechu, ubogie pole przy bazie i bogate ekspansje z kopalniami kryształów. Kompletna od startu do wygranej, **(niezweryfikowane w grze)**.

Źródła: CASC StarCrafta `SD/campaign/Terran/Terran06/staredit/scenario.chk` (T6, 96×96 badlands; obejrzane też T4, T5, T7), `Modding/tools/build-arka04-antiga.ps1`, `Modding/tools/build-arka04-mission.ps1`, `Modding/tools/build-arka-previews.ps1`, `INI/Rules.ini` (`[OREMINE]`, `[Ore]`, `[Gems]`, `[BlueGems]`, `[BIO]`, `[OverlayTypes]` 27–38 kryształy i 147–150 ruda), `INI/Game Options/StarCraft.ini` (`[SCRAYN]`, `[SCRAYNS]`, `[SCRaynGun]`, `[SCHERO]`, `[SCBCF]`), `Map Editor/FinalSun/FSData.ini` (akcja `106 Give Credits`), lore Antigi Prime od użytkownika (StarCraft Wiki: oceany i skamieniałości, winnice, Stickler Woods z odnawiającymi się surowcami, masakra Andasar City 2478), [[missions/arka-02-ewakuacja]] (wzór).

## Pliki

| Plik | Rola |
|---|---|
| `Maps/Custom/arka04_antiga.map` (+ `.png`) | teren (do obejrzenia w skirmishu „Custom Map”), waypointy 10–62, kopalnie; **nadpisywany** przez skrypt terenu |
| `Maps/Missions/arka04.map` (+ `.png` 300×200) | misja; **nadpisywana** przez skrypt misji; podgląd z `build-arka-previews.ps1 -Only arka04` (scena w niecce Norad II) |
| `INI/BattleE.ini` | wpis `M_ARKA04`; skrypt **scala** |
| `Modding/tools/build-arka04-antiga.ps1` | teren: CASC → ScToDta, zoom 1,5×, TEMPERATE, przerzedzone pole przy bazie, kryształy Stickler Woods z lasem, kopalnie, waypointy |
| `Modding/tools/build-arka04-mission.ps1` | misja: typy SC skopiowane do mapy, Duke-Marine, Norad II, laboratorium, domy, 18 drużyn, 83 triggery, 65 tekstów, kontrole. Parametr `-AnalysisSecs` (domyślnie 1200 = „20 minut”) |
| `%TEMP%\arka04-terrain\` | `grid.png` (komórki DTA z siatką SC i waypointami), `sc_grid.png`, `reach.png`, render `arka04_antiga_full.png` |
| `%TEMP%\arka04-mission\` | `log.txt` (oś czasu tekstów, kontrole), render z `-Render` |

```powershell
powershell -NoProfile -File Modding\tools\build-arka04-antiga.ps1          # teren, ok. 2 min z renderem
powershell -NoProfile -File Modding\tools\build-arka04-mission.ps1 -Render  # misja
powershell -NoProfile -File Modding\tools\build-arka-previews.ps1 -Only arka04
```

## Teren

- **Dlaczego T6:** to jedyna mapa kampanii SC z Norad II (budynek SC o id 126) na Antidze. Baza Konfederacji z CC na SW to baza Aliantów przy ARCE, niecka na SE (nizina w pierścieniu klifów) to miejsce katastrofy, gniazdo z Lairem w centrum i Hive na północy to dwa gniazda misji. T5 „Revolution” (też Antiga) zostaje dla misji 3, T7 „The Trump Card” (128×128) na misję 6 albo 7.
- **Teatr TEMPERATE** z ustawieniami `convert-scmap.ps1`. **Grunt Antigi** (od 2026-10-28; użytkownik: „Antiga Prime miała tak zielono?”, nie miała): konwerter maluje nizinę trawą, więc skrypt po `PaintGround` przemalowuje: niziny na błoto (`Dirt LAT`, wyschnięte dno oceanów) z rzadkimi kępami zarośli i małymi płatami trawy, płaskowyże głównie na zarośla (lore: „low mesas covered by native scrub”). Zarośla to slot 3 z `Autumn Grass` (oliwkowo-rdzawe). Płaty pochodzą z gładkiego szumu (bloby, nie sól z pieprzem). Beton (slot 2) bez zmian. Wynik: 35 tys. komórek błota, 15 tys. zarośli, 3 tys. trawy. Na granicach płatów zostaje cienki szew trawy, bo przejścia LAT konwertera liczą tylko względem trawy. Gejzery usunięte jak w misjach 1–2 (konwerter zrobiłby z nich drzewa Tyberium).
- **Surowce:** pole przy bazie (34 komórki) ma kryształy na etapach 3–5 zamiast 9–11 i szybko się kończy. Pola NW (21), w centrum (20) i przy Hive (25) mają pełne kryształy. **Stickler Woods** na NE: najbogatsze pole niebieskich kryształów (65 komórek), dookoła pierścień drzew. Kryształy odrastają (`[BlueGems] Growth` w mapie misji), stąd lore „surowce powoli się odnawiają”. W wersji 1 była tu ruda (złoto), usunięta na prośbę użytkownika.
- **Kopalnie** (prośba użytkownika 2026-10-27): przy każdym polu kryształów stoi `OREMINE2`, który misja przestawia na kopalnię niebieskich kryształów (`TiberiumToSpawn=6` = `BlueGems`), także w Stickler Woods. Miejsce: komórka najbliżej środka pola, która dotyka pola, nie leży przy waypoincie i ma wolnych sąsiadów (nie zamyka przejścia). W skirmishu `OREMINE2` sieje rudę, bo przestawienie jest tylko w mapie misji.
- Kontrole: 0 nieudanych łańcuchów klifów, wszystkie 53 waypointy osiągalne z ARKI. Droga z ARKI: pole NW 64 komórki, centrum 95, Stickler 142, pole Hive 153, Norad II 198. Wlot fali SE musiał wyjść z zamkniętej doliny w rogu (wp 45 na płaskowyżu).
- Renderer CNCMaps **nie rysuje `RAPDOX`** (ARKA) ani kopalń w tym teatrze; w mapie są (kontrola Art.ini przeszła).

## Waypointy (kontrakt teren ↔ misja)

Kafle oryginalnej mapy SC (96×96), skrypt przesuwa każdy na najbliższą wolną komórkę.

| Nr | Co | Nr | Co |
|---|---|---|---|
| 10 | ARKA | 34 / 35 | Norad II / Duke i załoga |
| 11 | start armii gracza | 36, 37 | bunkry Norad II |
| 12 | laboratorium Einsteina | 38 | wejście do niecki (strefa) |
| 13–18 | ConYard, koszary, rafineria (pole bazy), War Factory, 2 elektrownie | 39 | Stickler Woods (kryształy) |
| 19 | drugie MCV | 40 | gniazdo NE z sekretem |
| 20 | pole NW | 41 | pole przy Hive |
| 21 | pole w centrum | 42–45 | wloty fal: W, NW, E, SE |
| 22–27 | gniazdo w centrum: Wylegarnia, Pool, Hydra Den, Evo, Spire, Sunken | 46 | środkowa równina |
| 28–33 | Hive, Pool, Hydra Den, Spire, 2 Sunken | 47 / 48 | obrona bazy: północ / wschód |
| 49–51 | stada Zergów przy niecce (W, N, S) | 52–58 | pole kolonii: Sunken ×5, Spore ×2 |
| 59 | wlot ostatniej fali (północ) | 60–62 | straże: gniazdo w centrum, pole NW, Hive |

## Nowe typy w mapie

| Typ | Co |
|---|---|
| `ARKDUKE` / `ARKDUKES` | **Edmund Duke jako Marine** (bez czołgu, prośba użytkownika): klucze `SCRAYN` (bohater-Marine Raynora), **4000 HP jak Raynor**, broń `ARKDukeGun` = `SCRaynGun` z obrażeniami ×1,5 (45 → 68), ten sam stimpack (wersja `S` z 2667 HP i podwójną szybkostrzelnością), głosy Duke'a z `SCHERO`, grafika złotego Marine (`Image=SCRAYN`), samoleczenie |
| `ARKNORAD` | **Norad II**: grafika SC Battlecruisera (`SCBCF`) jako pojazd na ziemi (lokomotor gąsienicowy, `Speed=1`, bez broni, misja `Sleep`, 9000 HP, dym), dom `Soviet2` |
| `BIO` (nadpisany) | **Laboratorium Einsteina**: Bio Research Lab z TD, 4000 HP, gracza, bez poboru prądu. Einstein jest w środku: zniszczenie = porażka |
| `RAPDOX` (nadpisany) | ARKA: `Immune=yes`, w tej misji nie da się jej stracić |
| `ARKZKRY` | sekret: „Zerg z zielonym kryształem” (obraz Creep Colony), budynek `Neutral`, `Capturable=true`, `Immune=yes` |
| `ARKRAYN` | Raynor na Vulture jak w misjach 1–2 |
| `OREMINE2`, `BlueGems` | kopalnia niebieskich kryształów, powolny wzrost niebieskich kryształów (`Growth=3000`, `GrowthPercentage=.05`) **(niezweryfikowane: czy mapa nadpisuje `[BlueGems]`)** |

## Domy

| Dom | Rola |
|---|---|
| `Allies` (2) | gracz, 3000 kredytów, `TechLevel=6` (śmigłowce od misji 3, artyleria, działka AA), bez silosu rakietowego i Chronosfery |
| `GDI` (0) | Duke i załoga Norad II (Alpha Squadron, ciemnoczerwoni), sojusznik; po ewakuacji **cały przechodzi do gracza** |
| `Soviet2` (13) | kadłub Norad II |
| `Soviet` (3) | Synowie Korhalu (Dropship ewakuacyjny) |
| `Nod1` (7) | Zergi: gniazdo w centrum, pole kolonii wokół niecki, gniazdo NE, najazdy |
| `Nod2` (9) | Zergi: Hive na północy i jego najazdy |
| `Nod` (1) | Zergi: **ostatnia fala** (wszystkie jednostki zniszczone = wygrana) |
| `Neutral` | sekret w gnieździe NE |

## Przebieg (czas gry w sekundach)

| Kiedy | Co się dzieje |
|---|---|
| 1–260 | Einstein w laboratorium, alarm Stavrosa, „idą na próbkę”, **cel 1** (bronić laboratorium ok. 20 minut), warunki porażki, Stavros o ubogim polu i drugim MCV (radar na pole NW) |
| 316–540 | Mengsk: Norad II, Duke, „zna wszystkie kody”, **cel 2**, Duke przez radio („okopaliśmy się”), Stavros o lasach Stickler |
| 600 / 900 | Einstein melduje postęp (połowa, trzy czwarte). **Bez licznika na ekranie** |
| 1200 (`-AnalysisSecs`) | analiza gotowa: pełny dialog o Krysztale X z planu (ruda czy trucizna, destylat, bateria, „zielony szajs”), cel 1 wykonany. Jeśli Duke jeszcze czeka: Einstein go ponagla |
| gracz w niecce **i** cel 2 dany | „No proszę. Muzealnicy.”, **licznik 3:00** (jedyny widoczny, krótki cel), fale na kadłub z północy, wschodu, SE (+ trudny z zachodu) |
| licznik 0 | Dropship Synów Korhalu zabiera załogę, Duke: „Dziękuję. Nie przyzwyczajajcie się.”, **Duke z oddziałem (5 Marines, 2 Goliathy, 2 bunkry) przechodzi do gracza**, gracz dostaje drugi Dropship (wersja 2) |
| Duke wysiada przy laboratorium (wp 63–65) | „tani szmaragd”, Einstein, Raynor: „Duke w naszej bazie. Świat się kończy.”, cel 2 wykonany |
| analiza **i** Duke przy laboratorium | ostrzeżenie (2–3 minuty), po 240 s **ostatnia fala**: 6 Mutalisków, 3 Guardiany, rój z północy, Zerglingi z Ultraliskiem z zachodu (+ trudny) |
| wszystkie jednostki `Nod` martwe (albo 720 s po fali) | Einstein „odparte”, Mengsk składa Duke'owi ofertę, Duke przechodzi do Mengska, „kawałek szkła, zielonego”, **wygrana** |
| 560, 760, 1050, 1150, 1560; od 900 co 600 (centrum), od 1500 co 720 (Hive) | najazdy na laboratorium: małe (5–11 Zergów), najazdy z gniazda ustają, gdy padnie jego Wylegarnia/Hive |

**Porażka:** zniszczenie laboratorium (Einstein w środku), śmierć Raynora, Tanyi lub Duke'a, zniszczenie Norad II przed ewakuacją, utrata wszystkiego. ARKA jest niezniszczalna.

**Cele poboczne i nagrody:**
- Wylegarnia w centrum: koniec najazdów z centrum, wolne pole kryształów, **oddział Synów Korhalu** dla gracza (4 Marines, 2 Goliathy) i kwestia sierżanta z Andasar (lore: masakra Andasar City w 2478).
- Hive: koniec najazdów z północy, **premia Mengska** akcją `106 Give Credits` (3000, **niezweryfikowane:** jednostka kwoty w łatce ts-patches).
- Sekret: inżynier w „Zergu z zielonym kryształem” w gnieździe NE (Stickler Woods) → inżynier i Einstein: „Ktoś je karmi” (zapowiedź misji 9). **Jak zdobyć:** w prawym górnym rogu mapy, na północ od lasów Stickler (wp 40), stoi budynek o wyglądzie Creep Colony (dom `Neutral`; po najechaniu kursorem nazwa „Zerg z zielonym krysztalem”). Pilnują go Sunken Colony, Creep Colony, 5 Zerglingów i 2 Hydraliski. Trzeba oczyścić teren, podprowadzić inżyniera (na start są 2) i kliknąć nim w budynek (kursor przejęcia). Budynku nie da się zniszczyć, strzelanie nic nie daje.

## Odstępstwa od planu

- **Licznik 20 minut jest cichy** (prośba użytkownika): czas liczą triggery `Elapsed`, a Einstein melduje postęp. Na ekranie jest tylko 3:00 obrony Norad II.
- **Norad II bez presji czasu:** Zergi nie atakują kadłuba, dopóki gracz nie wejdzie do niecki (kolonie i stada stoją ≥ 18 komórek od kadłuba). Gracz sam decyduje, kiedy idzie. Ostatnia fala przychodzi dopiero po analizie **i** uratowaniu Duke'a.
- **Duke walczy po stronie gracza** do końca misji jako Marine-bohater (plan: tylko „przechodzi do Mengska” w zakończeniu; to zostaje w końcowym dialogu).
- **Sekret na NE**, nie „na wschodzie”: tam stoi małe gniazdo przy Stickler Woods.
- Wybór z misji 3 (kasa albo oddział) nie przechodzi między misjami: oddział Synów Korhalu jest nagrodą za gniazdo w centrum.
- Kerrigan nie występuje (plan misji 4 jej nie wymienia).

## Poprawki po teście 1 (2026-10-27, wersja 2)

Użytkownik zgłosił: Zergi na górze strzelają do jakiejś kolonii, Duke ma lecieć Dropshipem gracza, działko AA nie rani Mutalisków, na mapie ma nie być złota, AI Zergów ma naprawdę budować i trzeba dociągnąć creep.

- **Zergi strzelały do sekretu:** „Zerg z zielonym kryształem” (obraz Creep Colony) należał do `Neutral`, a ten był dla Zergów wrogiem. Jest niezniszczalny, więc ogień trwał w nieskończoność. Teraz `Neutral` i domy Zergów są w sojuszu w obie strony.
- **AA:** `RAAGUN` strzela `ZSU-23` z głowicą `FlakWH`, która ma `Modifier.wood=0%`. Mutalisk ma `Armor=light`, a `[light] BaseArmor=wood` (Rules `[ArmorTypes]`), więc obrażenia były zerowe. Mapa daje `FlakWH Modifier.light=770%` (jak `medium`). Ta sama pułapka dotyczy każdej jednostki `light`, zob. [[workflow/known-mistakes]].
- **Bez złota:** Stickler Woods to teraz niebieskie kryształy (nakładki 31–34), także kopalnia `OREMINE2`. Kryształy odrastają dzięki `[BlueGems] Growth` w mapie.
- **Dropship Duke'a:** po 3:00 obrony Mengsk zabiera załogę swoim Dropshipem, a drugi Dropship (`SCDROP`, `IsVehicleTransport=yes`, 8 miejsc) dostaje gracz. Duke i jego oddział przechodzą do gracza (`36`, porażka Duke'a wyłączona na 8 s). Dalszy dialog („tani szmaragd”, Raynor, cel 2 wykonany) rusza, gdy Duke wysiądzie przy laboratorium: tag Duke'a (powtarzalny) prowadzi łańcuch `34 Comes near waypoint` na trzech lądowiskach przy laboratorium (wp 63–65, liczone przez generator) → `29` „Duke zginął” (pole „PowiązanyTrigger”, pułapka 13). Zapas: 1500 s po ewakuacji Duke „dociera sam”. Lokalna 1 („Duke uratowany”, warunek ostatniej fali) jest ustawiana dopiero przy laboratorium. **(niezweryfikowane w grze: promień zdarzenia 34)**
- **AI Zergów buduje dronami** (wersja 3, po pytaniu użytkownika „czy AI wie, jak stawiać budynki?”): w wersji 2 gniazda budowały węzły bazy „po konstruktorowemu” przez laboratoria (budynek wyrastał na miejscu). Teraz `Add-ZergBuilder` ([[engine/zerg-ai]]): od 300/330 s co 110/130 s każde gniazdo zamawia drużynę `4 Create Team` z dronem `SCZD<x>`. Wylegarnia/Hive go wykluwa za kredyty domu (`IQ=5`, 8000), dron idzie na zaplanowane miejsce (`4 Move to cell`) i się przepoczwarza (`9 Deploy`). Plan to 8 budynków na gniazdo (kolonie, Evolution Chamber, Hydralisk Den), każde pole ≤ 7,5 od źródła creepu. Jeśli dron nie dojdzie w 300 s, wykluwa się zapasowo (`80`). Usunięte: `NodeCount`, nadpisany `[AI] BuildConst`, `TechLevel` budynków. **(niezweryfikowane w grze)**
- **Creep w misji kampanii:** siewniki to `ActiveAnim` w Art.ini (globalne), ale reszta bloku creepu jest w kodzie mapy frakcji, którego kampania nie ładuje. Mapa dostaje: `[Basic] VeinGrowthEnabled=yes`, `[General] VeinholeGrowthRate=60`, `Insignificant=yes` dla `VEINS`/`VEINHOLEDUMMY`, 4 animacje-siewniki w `[Animations]` i `ImmuneToVeins=yes` dla 886 typów (wszystkie listy Rules + typy mapy).
- **Zasady z [[workflow/mission-design]]:** 4 skrzynki z pieniędzmi (szczątki Norad II 3000, konwój winiarzy w centrum 2000, obozowisko drwali w Stickler 2500, skrytka powstańców z Andasar przy polu NW 1500), rajdy powtarzane na gospodarkę (centrum → pole NW, Hive → Stickler, zachód → pole bazy; wszystkie `0,3` na zbieracze), wyłączane przy ostatniej fali. Kopalnia jest niebieska, nie `OREMINE` (prośba użytkownika: tylko niebieskie kryształy).

## Wersja 4 (2026-10-28)

- Użytkownik: AI Zergów rozstawia drony w grze ([[engine/zerg-ai]]).
- **Oblężenie Norad II** (prośba użytkownika): pierścień 9 kolonii (Sunken i Spore na zmianę, co 30°, 13–21 pól od kadłuba i Duke'a) i 4 dodatkowe stada (Zerglingi, Hydraliski, Infested Terrany, Ultralisk). Wszystko poza zasięgiem Sunkenów (`GuardRange=8`) od załogi, więc walka zaczyna się dopiero z graczem. Wejście do niecki jest od północnego wschodu.

## Wersja 5 (2026-10-28, prośby użytkownika ze zrzutu północnej krawędzi niecki)

- **Obrona:**
  - 3 kolonie na płaskowyżu na NW od niecki: Sunken (132,115), Spore (135,119), Sunken (137,116);
  - 2 Sunkeny przed północnym wejściem do niecki (156,113) i (160,112) użytkownik po obejrzeniu renderu kazał usunąć: „za blisko Norada”;
  - wszystkie stoją ≥ 13 pól od kadłuba i Duke'a, jak pierścień oblężenia;
  - drugi zrzut: na otwartym terenie na północ od kolonii nad niecką stoją Sunken (130,97), Spore (129,90), Sunken (136,91) i 2 stada (4 Zerglingi + 3 Hydraliski, 5 Zerglingów + 2 Hydraliski, `Area Guard`).
  
  Kadr renderu = kadr zrzutu: piksel renderu ≈ `((x−y)·24 + 1739, (x+y)·12 − 955)` dla mapy 3456×3528.
- **Nękanie z gniazda w centrum:** Spawning Pool wykluwa drużyny przez `4 Create Team`, za kredyty `Nod1` (podniesione 8000 → 40000):
  - A: 4 Zerglingi i 4 Broodlingi na zbieracze (`16,15`, `0,3`, `11,14`), od ok. 600 s co 240 s;
  - B: 4 Zerglingi, 2 Broodlingi i 3 Hydraliski na bazę (`16,47`, `11,14`), od ok. 720 s co 240 s;
  - nękanie trwa, dopóki stoi gniazdo (lokalna 2) i do ostatniej fali (lokalna 5);
  - Broodling `SCZBRD` jest skopiowany do mapy bez wymagania Queen's Nest.
  
  **(niezweryfikowane w grze: czy AI produkuje piechotę przez `Create Team`; drony-pojazdy działały)**
- **Latające Centrum Dowodzenia Raynora:**
  - ok. 258 s kwestia Raynora, potem podpowiedź;
  - `SCCCF` gracza przylatuje z południowej krawędzi (wp 67) i staje przy drugim MCV (wp 66, miejsce wolne na fundament `SCCC`);
  - gracz rozstawia je (D) gdzie chce, jako drugi plac budowy;
  - `SCCC` ma w mapie `TechLevel=-1` (nie do zbudowania z paska);
  - Mengsk mówi teraz po podpowiedzi o CC (od ok. 361 s).
  
  **(niezweryfikowane w grze: lądowanie jumpjeta w budynek, [[mods/starcraft-terran-buildings]])**
- Generator: kontrola długości linii `[Actions]` (> 400 znaków = FAIL, pułapka 16).

## Wersja 6 (2026-10-28)

- **Creep od startu** (prośba: „creep fundament pod budynki, żeby nie było dziur”), jak w ARKA 2:
  - pod każdym budynkiem z siewnikiem leży w mapie Veinhole Monster: nakładka 167 i 8× 178, Hatchery/Hive w komórce (1,1), kolonie w (0,0), dziury co najmniej 3 pola od siebie;
  - dojrzałe żyły (126, data 48) leżą w kole o promieniu 5 wokół każdej dziury i pod każdym budynkiem `SCZ*` z marginesem 1 pola (także Pool, Hydra Den, Evo, Spire);
  - wynik: 36 dziur pod 49 budynkami, 2174 pola żył;
  - płaty niepołączone z dziurą gra usuwa przy wczytaniu (`Place_Monsters`). Przy dwóch koloniach przy klifie (77,101 i 182,121) dziury nie ma, bo pole 3×3 nie jest płaskim gruntem.
- **Centrum → Norad II:** od ok. 720 s co 300 s Pool w centrum wykluwa 3 Zerglingi i 3 Broodlingi. Idą do oblężenia na N od niecki (wp 50) i stoją tam w `Area Guard`, więc walczą dopiero z graczem, a Duke nie zginie bez niego.
- **Hive budzi się po upadku gniazda w centrum** (`nestC` → `sok` → `sok2` → `upWake`, jeśli Hive stoi):
  - Extractor `SCZEXT` Hive'a stoi od startu przy jego polu (65,33);
  - dochodzi jeden dron `SCZWORK` w misji Harvest (`11,9`) i tekst Stavrosa;
  - co 150 s fale na zmianę: A = 6 Zerglingów + 4 Broodlingi, B = 4 Zerglingi + 3 Broodlingi + 2 Hydraliski;
  - trasa fal: lasy Stickler (`16,39`), potem baza (`16,12`), potem polowanie;
  - fale trwają, dopóki stoi Hive, i do ostatniej fali;
  - kredyty `Nod2` podniesione do 25000, `SCZLNG`/`SCZHYL`/`SCZBRD` mają w mapie `Owner=Nod1,Nod2`.
  
  **(niezweryfikowane w grze: AI-produkcja piechoty, dron AI zbierający do Extractora)**
- `VeinholeShrinkRate=8` (było 5; prośba: zanikanie o 40% wolniej).

## Do sprawdzenia w grze

- Czy laboratorium (`BIO`, `Image=BIOE_UP`) i ARKA są widoczne (renderer ich nie rysuje).
- Czy Norad II jako pojazd stoi w miejscu i wygląda jak wrak (grafika latającego BC na ziemi); czy Zergi go atakują podczas obrony.
- Czy kopalnie sieją niebieskie kryształy i czy te rosną (`[BlueGems]` w mapie).
- Czy `36 All change house` przenosi Duke'a i oddział do gracza bez fałszywej porażki (pułapka 6, `dukeLost` wyłączony na 8 s).
- Czy stimpack Duke'a działa (`TransformsInto`) i czy po nim tag „Duke zginął” zostaje na jednostce.
- Czy `106 Give Credits` daje 3000 czy 300 000.
- Tempo: 1200 s analizy, odstępy najazdów (realny czas zależy od prędkości gry, zob. [[engine/triggers-and-dialogue]]). Gdy za szybko: `-AnalysisSecs` i czasy najazdów.
