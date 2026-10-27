# Indeks wiki modowania DTA

Czytaj ten plik jako pierwszy. Schemat i zasady prowadzenia: `../CLAUDE.md`. Historia: [log](log.md).

## Przegląd
- [[overview]]: silnik (TS + Vinifera), strony i domy, gdzie modować, zasada „mapa/opcja zamiast Rules.ini”.

## Silnik
- [[engine/ini-layering]]: Rules → mapa → opcje gry; co da się nadpisać; `spawnmap.ini`; `$Inherits` tylko w obrębie pliku; klient scala powtórzone sekcje (późniejszy klucz wygrywa).
- [[engine/tech-and-prerequisites]]: TechLevel, Owner, Prerequisite (AND), grupy POWER/BARRACKS/FACTORY/RADAR/TECH, pułapki, zasięg budowania (`Adjacent`, `BaseNormal`).
- [[engine/adding-new-types]]: nowe jednostki i budynki z mapy lub opcji gry, `Image=`, jednostki bez cameo na mapie, jumpjet.
- [[engine/weapons-and-warheads]]: obrażenia × Modifier, `Super` = ×10, laser, tesla, railgun, atom, chemia, EMP.
- [[engine/houses-economy]]: Credits ×100 (overflow ~21 mln), BuildTime i mnożniki domu, `[General] BuildSpeed`; **silosy od środka** (`Capacity` tylko z budynków, urobek rozkładany bal po balu do budynków, Vinifera `_Harvested`, `TiberiumStorage`, AI omija silosy), prąd też tylko z budynków.
- [[engine/superweapons]]: lista supermocy, `SuperWeapon=` na budynku.
- [[engine/game-exe-patching]]: łatanie `game.exe` odtwarzalnie: zainstalowane łatki i ich jaskinie, wolne miejsce (`.p_text`), sloty vtable (`In_Air` vs `What_Am_I`, RTTI przez `[obj+4]`), szablon skryptu, `tools/patch-game.ps1` po aktualizacji DTA.
- [[engine/spawners]]: lotniskowce (łatka `game.exe` `tools/patch-spawnreturn.ps1`, **działa w grze**, wszystkie łatki naraz `tools/patch-game.ps1`) (`Spawner=yes`, `Spawns=`, matka może być pojazdem, wypuszczany musi być voxelowym samolotem), generator niewidzialności tylko w budynkach.
- [[engine/crates]]: skrzynka „Unit” zawiesza grę, gdy dom nie ma pojazdu z `CrateGoodie=yes` (było: Zerg i Protoss); blok „Crate goodies” w pliku frakcji.
- [[engine/client-lobby-options]]: własny checkbox w lobby skirmisha (`$CCxx`, `CustomIniPath`), brak miejsca w panelu.
- [[engine/debugging]]: logi w `Debug/`, liczniki typów w logu, procedura przy crashu.
- [[engine/shp-graphics]]: MIX-y, palety (remap 16–31), układ klatek pojazdu SHP (kierunki zgodnie z zegarem, cienie w 2. połowie), cameo 64×48.
- [[engine/sounds-aud]]: `[SoundList]` → `<NAZWA>.AUD`, format AUD (IMA ADPCM, 22 050 Hz mono, młodszy półbajt pierwszy).
- [[engine/transform-deploy]]: piechota bez deploy; `TransformsInto` (Vinifera) zachowuje % HP; ładowanie jako cooldown; wzorzec stimpacka.
- [[engine/starcraft-assets]]: CASC Remastered (tekstowy root), ścieżki GRP/WAV/portretów, format GRP, 17 kierunków + lustro.
- [[engine/map-format]]: geometria mapy (Size/LocalSize, `y*1000+x`), IsoMapPack5 (LZO), OverlayPack (Format80, `y*512+x`), TMP i kody terenu, reguła LAT, klatki murów, mapy w `Maps/Custom`, renderer CNCMaps.
- [[engine/connected-tiles]]: klify, Water Cliffs i brzegi z `ConnectedTileDrawer.ini` (WAE), potwierdzona reguła łączenia, strona „góry” klifu, automatyczne układanie.
- [[engine/starcraft-maps]]: mapy SC (`.scm/.scx` = MPQ + `scenario.chk`), sekcje CHK, tilesety cv5/vf4/vx4ex, przejezdność; spostrzeżenia o Lost Temple.
- [[engine/fly-locomotor]]: pojazdy z lokomotorem samolotu (wzór Hunter-Seeker), budowa przez „stocznię” Vinifery, skąd lądowanie (deasemblacja `game.exe`), łatka `tools/patch-flyhover.ps1` (wiszenie zamiast lądowania), łatka `tools/patch-flyertarget.ps1` (jednostki AA same celują w latające pojazdy), pola klas z `Vinifera.pdb`.
- [[engine/transports]]: wsiadanie do transportu w `game.exe`: `IsVehicleTransport=yes` (klucz DTA) wpuszcza pojazdy (też Marines-pojazdy SC), transport musi stać (`Is_Moving`), pojazdy wsiadają do wiszącego transportu Fly, piechota dopiero z łatką `tools/patch-airboard.ps1` (szuka transportu tylko wśród okupantów pola na ziemi); Dropship (Fly) i Shuttle.
- [[engine/buildup-timing]]: czas Buildupu (stałe ok. 81 ticków, `game.exe` `0x4403DD`, przy >81 klatkach budowa stoi) i łatka `tools/patch-buildup.ps1` (1 klatka = 1 tick); czas produkcji (`BuildTimeMultiplier`, minimum 54 ticki).
- [[engine/veins]]: żyły i Veinhole Monster: klucze, nakładki 126/167/178 na sztywno, gdzie rosną żyły (bez warunku wysokości), tworzenie potwora w trakcie gry (`OverlayClass::Mark`, test 3×3 i wysokość ≥ 1, łatka `0x661C89`), budynek-mur `Wall=yes` + `ToOverlay=` zamienia się w nakładkę, `TiberiumSpawnType` w animacji dodaje losowo 0–3.
- [[engine/triggers-and-dialogue]]: **jak pisać misje**: format `[Triggers]/[Events]/[Actions]/[Tags]/[CellTags]`, drużyny (TaskForce/Script/TeamType), litery waypointów, najważniejsze ID zdarzeń i akcji, czas w sekundach gry (`1500` = 25:00), łańcuchy dialogów (`Enable` + `Elapsed`), teksty `[Tutorial]` (ASCII, numery ARKA 9000+), **tempo dialogów** (sekunda gry ≈ 1/3 realnej, jeden tekst na trigger, `tools/MissionKit.ps1`: pacing, oś czasu, skrzynka z odkryciem mapy), desant z transportowcem `NLST`, trudność (globalne 10–15), rejestracja w `Battle.ini`/`BattleE.ini`; dekompilator `tools/dump-triggers.ps1`.
- [[engine/briefing-movies]]: filmy briefingu w stylu SC: `Brief=` w `[Basic]`, Vinifera odtwarza `MOVIES\X.MP4/WMV/AVI` zamiast `X.VQA`, generator `tools/build-briefing.ps1` (JSON → portrety, zapis łączności, cele, dźwięk → H.264), pierwszy film `ARKA02B` **(niezweryfikowane w grze)**.
- [[engine/sides-and-houses]]: `[Sides]`/`[Houses]`, klient `Side=` = indeks domu, 122 mapy z domami od 14, `SIDEC/SPEECH%02d.MIX`, AI Side=n+1, Advanced AI.

## Katalogi
- [[catalog/hidden-units]]: ukryte (`TechLevel=-1`) i międzyfrakcyjne jednostki, samoloty, budynki.
- [[catalog/custom-units-from-maps]]: unikalne typy z map (Bunzilla, SS-22N, Obelisk of Brightness…) i ich źródła.

## Misje
- [[missions/frostbite]]: dane misji, baza startowa, ograniczenia autora.
- [[missions/arka-00-triggers]]: warstwa misji preludium ARKA (`tools/build-arka00-mission.ps1` → `Maps/Missions/arka00.map` + `INI/BattleE.ini`): domy, ARKA (`ARKACORE`), 4 elektrownie, baza Aliantów, Tanya do odbicia, 46 triggerów (licznik 25:00, fale Sowietów, 8 transportowców `NLST` Nod z artylerią, pojazdami i piechotą, Stealth Tanki, szpieg `15,10`, finał z dialogiem), skrzynka z odkryciem mapy, harvester; testy 2026-10-27: ARKA i prąd działają, tempo tekstów poprawione, drużyny naziemne bez `1,N` (stały bezczynnie).
- [[missions/arka-01-marsara]]: misja 1 ARKA „Obcy piasek” (dla użytkownika „misja 2”), **teren + triggery w jednej sesji**: mapa kampanii SC T2 Backwater Station z CASC, zoom 2×, teatr DESERT (`tools/build-arka01-marsara.ps1` → `Maps/Custom/arka01_marsara.map`), misja (`tools/build-arka01-mission.ps1` → `Maps/Missions/arka01.map` + scalony `INI/BattleE.ini`): wrak ARKI, 3 grupy rozbitków, MCV, osada z Raynorem, gniazdo Zergów, 46 triggerów, **typy SC skopiowane do mapy** (misja nie ładuje opcji SC), Marines = pojazdy. Nietestowana w grze.
- [[missions/arka-02-ewakuacja]]: misja 2 ARKA „Ewakuacja”, teren + triggery w jednej sesji: mapa kampanii SC **T3 Desperate Alliance** z CASC, zoom 1,5×, DESERT, beton na platformach i w mieście (`tools/build-arka02-marsara.ps1` → `Maps/Custom/arka02_marsara.map`, `grid.png` z siatką SC do planowania), misja (`tools/build-arka02-mission.ps1` → `Maps/Missions/arka02.map` + `BattleE.ini` + podgląd): Raynor znika w zainfekowanym CC (licznik 10:00, C4 Tanyi), 3 schrony z kolonistami eskortowanymi na lądowisko Synów Korhalu (skrypt drużyny `39` zmienna + `37` usuń), Mengsk, 15:00 skoku z 4 elektrowniami, Konfederacja, flota Protossów; `Tag=` w drużynie. Nietestowana w grze.
- [[missions/arka-00-gibraltar]]: teren preludium ARKA (Gibraltar 1953), wersja 2: zrzut Google Maps + OSM + DEM, `Maps/Custom/arka00_gibraltar.map`. Skała w 2 poziomach z 6 rampami, drogi z kafli, budynki i atrakcje z OSM, strefy i trasy wroga, 36 waypointów (10–45, kontrakt z warstwą misji), **pułapki** (plaże dla hovercraftów, `HomeCell`, zasięg Obeliska, skrypt nadpisuje mapę). v1: `archive/arka00-gibraltar-v1_2026-10-26/`.

## Mody
- [[mods/frostbite-cheats]]: zainstalowany. Kasa, MCV, działo jonowe, 40+ jednostek, jednostki z innych map.
- [[mods/super-mod-v1]]: zainstalowany, zarchiwizowany. Checkbox w skirmishu, 8 nowych jednostek, 2× budowanie.
- [[mods/starcraft-marine]]: zainstalowany, nietestowany. Checkbox STARCRAFT, Marine + Upgraded Marine ze stimpackiem, portrety, dźwięki SC.
- [[mods/starcraft-research]]: badania SC jako ulepszenia budynków (11 badań na E-Bay/Academy/Armory/Machine Shop/Control Tower/Covert Ops/Physics Lab/Science Facility), ulepszone wersje 11 jednostek, generator `build-scresearch.ps1`.
- [[mods/sc-lost-temple]]: zainstalowana, zarchiwizowana, **działa w grze** (test 2026-10-24). Mapa SC (4)Lost Temple jako mapa skirmisha (`Maps/Custom`).
- [[mods/sc-fighting-spirit]]: zainstalowana, zarchiwizowana, nietestowana w grze. Mapa SC (4)Fighting Spirit (iCCup 1.3), kanały z mostami, mury X w centrum.
- [[mods/starcraft-terran-buildings]]: zainstalowany, częściowo przetestowany. 18 budynków Terran z SC (CC = ConYard, 4 addony), Construction Tank, ten sam checkbox, `ECACHE98.MIX`.
- [[mods/starcraft-terran-units]]: zainstalowany, nietestowany. 12 jednostek Terran (SCV…Battlecruiser) z trybami deploy (stim, Siege Mode, Yamato), cloak, Lockdown/EMP, leczenie, jumpjety, 128 dźwięków SC, `ECACHE97.MIX`. Okręty: tylko ze Starportu, pojazdy z lokomotorem Fly (`SCWRAF`…, `ECACHE90.MIX`, łatka `game.exe` na wiszenie); wersje z koszar usunięte.
- [[mods/starcraft-zerg]]: zainstalowany, nietestowany. Zergling, Hydralisk, Ultralisk jako prawdziwa piechota w każdych koszarach (checkbox STARCRAFT), regeneracja, `ECACHE80.MIX`.
- [[mods/zerg-faction]]: pełna frakcja zainstalowana, nietestowana (morf przez deploy potwierdzony). Szósta frakcja „Zerg” (dom `Nod1`, strona 7) bez ConYardu: 17 budynków (każdy = dron z `DeploysInto`, kokon z SC tyle co w SC przy 60 FPS, łatka `patch-buildup.ps1`), Hatchery/Lair/Hive jako „stocznie” larw, 6 typów piechoty, Infested Terran, 6 latających (Fly), grupy `[PrerequisiteGroups]`, `ECACHE86.MIX`, `build-sczergbase.ps1`.
- [[mods/zerg-heroes]]: zainstalowany, nietestowany. Bohaterowie Zergów (Kerrigan, Duran, Torrasque, Hunter Killer, Devouring One, Unclean One, Kukulza ×2, Matriarch, Yggdrasill; złoci, `BuildLimit=1`) i budynki z kampanii (Overmind z pancerzem i bez, Cerebrate, Daggoth, Mature Chrysalis), supermoc Overmind's Wrath, `build-sczergheroes.ps1`, `ECACHE82.MIX`.
- [[mods/zerg-side]]: EVA i sidebar Zergów (`Speech08.mix`: 9 kwestii doradcy Zergów z SC zamiast Nod, `SideC08.mix`: paleta sidebaru fioletowo-brązowa), `build-sczergside.ps1 -Install` (tylko przy zamkniętej grze). Tabela numerów EVA (vox → `00-iNNN.aud`) z `game.exe`.
- [[mods/zerg-creep]]: zainstalowany 2026-10-27, nietestowany. Creep Zergów z żył TS: dron „Creep Tumor” (`Wall=yes` + art `ToOverlay=VEINHOLE`) staje się Veinhole Monsterem, a Hatchery/Lair/Hive i Creep/Sunken/Spore Colony stawiają potwora obok siebie niewidzialnym spreaderem. Odporność na żyły dla wszystkich 516 typów jednostek. Łatka `patch-veins.ps1`, generator `build-sczergcreep.ps1`.
- [[mods/overlord-storage]]: zainstalowany 2026-10-27, nietestowany. Overlord (też Upgraded i Yggdrasill) `Storage=100`: podnosi limit silosów gracza; łatka `game.exe` `patch-overlordstorage.ps1` (pojazd z `Storage=` bez `Harvester` liczy się do `Capacity`) + łatka `Vinifera.dll` `patch-vinifera-overlord.ps1` (sekcja `.scstor`: nadwyżka ponad budynki trafia do pierwszego silosu). Śmierć Overlorda nie zabiera kasy.
- [[mods/zerg-research]]: zainstalowany, nietestowany. 13 badań Zergów z SC (Melee/Missile/Flyer Attacks & Carapace, Metabolic Boost, Adrenal Glands, Grooved Spines…) montowanych na budynkach Zergów, budynki tech jako „laboratoria” (`Factory=BuildingType` + `BuildConst`), 12 ulepszonych jednostek, `build-sczergresearch.ps1`, `ECACHE84.MIX`.
- [[mods/protoss-faction]]: zainstalowany, częściowo przetestowany (zasięg budowania działa). Pełna frakcja „Protoss” (dom `GDI2`, strona 8, pliki strony z GDI): 16 budynków, 16 jednostek (Gateway, Robotics, Stargate, lotnicy Fly, Archony z trzech warstw), zasięg budowania tylko od Nexusa i Pylonów (`BaseNormal`/`Adjacent`), przywołanie jako Buildup, `ECACHE85.MIX`, `build-scprotoss.ps1`.
- [[mods/sc-building-sounds]]: zainstalowany, nietestowany. Dźwięki zaznaczania budynków ze SC (Terran, Zerg, Protoss; dane z `units.dat`), też latające budynki i rozstawione jednostki, `ECACHE79.MIX`, `build-scbldgsounds.ps1`.
- [[mods/sc-workers]]: zainstalowany 2026-10-26, animacje działają w grze. SCV/Dron/Probe z animacją wydobycia z iscriptu SC (Vinifera `IdleRate`, tylko podczas zbierania), surowce tylko do rafinerii swojej rasy (doki w CC/Nexusie/Hatchery wycofane), Refinery daje 2 SCV (łatka `game.exe` `patch-freescv.ps1`), `UnloadingClass` (bez niej rysowani jako harvester GDI), łatka `Vinifera.dll` (`tools/patch-vinifera-workers.ps1`, ConYard-rafineria nie traci radia), `ECACHE78.MIX`, `build-scworkers.ps1`.
- [[mods/terran-faction]]: zainstalowany, nietestowany. Piąta frakcja „Terran” w skirmishu Deathmatch (dom `GDI1`, strona 6), etap 0 = klon Aliantów. Kopie `GameOptions.ini.bak`, `MPMaps.ini.bak`.

- [[mods/sc-infantry-stim]]: **deploy piechoty** (łatka `game.exe` `tools/patch-infdeploy.ps1`, w `patch-game.ps1`: klawisz D zamienia typ `X` ↔ `X_D` w miejscu, koszt 1/4 HP) + testowi Marine i Firebat jako prawdziwa piechota ze stimpackiem (`SCMARI`, `SCFIRI`, `tools/build-scinfstim.ps1`, `ECACHE81.MIX`). Nietestowany w grze.

## Plany
- [[plans/campaign-arka]]: kampania mashup RA1 × StarCraft „ARKA: Błąd znaku” (11 misji + preludium): Alianci uciekają Giga-Chronosferą, błąd znaku Einsteina i sabotaż Nod (kryształ Tyberium) → Mar Sara 2499. Rozpisane wszystkie misje: preludium, 1–11 i bonusowe 12–13 (Sarajewo 2047: przegrana na pokaz, w której Nod sam zanosi Rezonator Khaydarin do Świątyni Prime, potem tunele na czas, czołg Duke'a i dwa zakończenia), słabości Kane'a, wątki postaci (Raynor i Tanya, Fenix wypala psioniczny ślad Kerrigan, sojusz Kerrigan z Kanem). Wersja HTML: `exports/campaign-arka.html`; po każdej zmianie strony przebudować przez `tools/build-campaign-html.ps1`.
- [[plans/starcraft-factions]]: frakcje SC. Czeka na assety od użytkownika; otwarte pytania i ścieżka konwersji.
- [[plans/zerg-faction]]: frakcja Zerg (dom `Nod1`, indeks 7), budowa przez drony z `DeploysInto` (osobny dron na każdy budynek), Hatchery = fabryka larw, Pool = koszary. Pełna wersja zainstalowana jako [[mods/zerg-faction]].
- [[plans/zerg-creep]]: studium creepu Zergów: żyły TS (wdrożone jako [[mods/zerg-creep]]), zapas w postaci własnego typu `[Tiberiums]` siany spreaderem.
- [[plans/overlord-storage]]: Overlord jako silos: samo INI nie wystarczy, prąd Zergom zbędny, kredyty dwiema łatkami (`Tracking_Active_*` w `game.exe` + `_Harvested` w `Vinifera.dll`), wariant A (limit) albo B (kasa w Overlordzie). Wdrożony wariant A: [[mods/overlord-storage]].
- [[plans/new-faction]]: piąta grywalna frakcja bez ruszania Rules.ini (w skirmishu przejęty dom pomocniczy `GDI1` = „Terran”). Etap 0 zainstalowany jako [[mods/terran-faction]], czeka na test.

## Warsztat
- [[workflow/repo-and-updates]]: **repo git w folderze gry i aktualizacje DTA**: `tools/dta-capture.ps1` po każdej zmianie modu (nowe pliki + zmienione pliki DTA na miejscu w gicie, czyste bazy w `Modding/dta/base`, `game.exe`/`Vinifera.dll` odbudowywane skryptami bit w bit), `dta-precheck.ps1` przed aktualizacją, `dta-restore.ps1` po niej (3-way merge, ponowne łatanie, stara binarka „pinned”, gdy łatki odmawiają); **aktualizacja przywraca wszystkie zmienione pliki DTA i usuwa `ECACHE99.MIX` i `BattleE.ini`** (`preupdateexec`), więc po każdej restore; 16.2.3 zainstalowana 2026-10-27, łatki Vinifery przeniesione (tabela `$builds` po `TimeDateStamp`).
- [[workflow/known-mistakes]]: **znane błędy** (objaw → przyczyna → reguła): łatki `game.exe`, INI i silnik, pułapki PowerShella, diagnoza. Czytaj przed nowym modem.
- [[workflow/mission-maps]]: **mapy misji z prawdziwego terenu** (dla sesji robiących misje): zrzut Google Maps + OpenStreetMap + DEM → mapa DTA. Narzędzia `fetch-geodata.ps1`, `GeoData.cs`, `DesignToDta.cs`, wzór `build-arka-gibraltar.ps1`; przepis krok po kroku, kolejność etapów, pułapki (TLS/Overpass, plaże, cypel, pas pod klifem, drugi poziom, drogi 2-komórkowe, budynki neutralne z grafiką Temperate).
- [[workflow/scmap-pipeline]]: **jedno polecenie** `tools/port-scmap.ps1 -Map "<nazwa>"`: mapa SC → `Maps/Custom`, kontrole PASS/WARN/FAIL, arkusz `review.png`, archiwum; co konwerter umie i czego nie.
- [[workflow/tooling]]: parser INI w PowerShell, skany, siatka zajętości mapy, quirki tego komputera; narzędzia C# w `tools/` (CASC, MIX, SHP, GRP, AUD, PCX; mapy: MPQ, CHK, LZO, Format80, TMP, konwerter SC → DTA, mapy z projektu/zrzutu `DesignToDta`).

## Archiwa
- `archive/super-mod-v1_2026-10-24/` (+ `.zip`): Super Mod v1 + Frostbite cheats, `modified/` i `original/`, README.
- `archive/sc-lost-temple_2026-10-24/` (+ `.zip`): mapa The Lost Temple (StarCraft), `modified/Maps/Custom/`, migawka konwertera i pipeline'u `tools/`, `review.png`, README.
- `archive/arka00-gibraltar-v1_2026-10-26/` (+ `.zip`): teren Gibraltaru w wersji 1 (ręczna Skała, drogi z bruku), skrypt i klasy C# z tamtej wersji, README z przywracaniem.
- `archive/sc-fighting-spirit_2026-10-24/` (+ `.zip`): mapa Fighting Spirit (StarCraft), `modified/Maps/Custom/`, `review.png`, `summary.json`, README.

## Surowe źródła
- `raw/maps/gibraltar-google.png` (zrzut), `raw/maps/gibraltar-geo/` (OSM 11 części, DEM 70 kafli z15, ok. 51 MB): dane terenu Gibraltaru.
- `raw/README.md`: mapa plików gry jako źródeł. `raw/sources/karpathy-llm-wiki.md`: wzorzec wiki.
