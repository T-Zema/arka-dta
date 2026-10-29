# Indeks wiki modowania DTA

Czytaj ten plik jako pierwszy. Schemat i zasady prowadzenia: `../CLAUDE.md`. Historia: [log](log.md). Wpisy są krótkie, szczegóły są na stronach.

## Zacznij tutaj
- [[overview]]: silnik (TS + Vinifera), strony i domy, zasada „mapa/opcja zamiast Rules.ini”.
- [[workflow/known-mistakes]]: **znane błędy** (objaw → przyczyna → reguła). Czytaj przed nowym modem.
- [[workflow/tools-catalog]]: **co robi każdy skrypt** z `Modding/tools/`, co zapisuje, kolejność generatorów.
- [[workflow/repo-and-updates]]: repo git w folderze gry, `dta-capture` po każdej zmianie, aktualizacje DTA.

**Gdzie leżą nasze zmiany w grze:**

| Co | Gdzie | Strona |
|---|---|---|
| Frakcje skirmisha Terran/Zerg/Protoss | `INI/Map Code/SC Factions/NNN <warstwa>.ini` (łańcuch `BasedOn` od `INI/Map Code/Terran Faction.ini`) | [[engine/map-code-layers]] |
| Checkbox STARCRAFT (jednostki i budynki SC w każdej frakcji) | `INI/Game Options/StarCraft.ini` (bloki `; >>> X`) | [[mods/starcraft-marine]], [[mods/starcraft-terran-units]] |
| Checkbox Super Mod | `INI/Game Options/Super Mod.ini` | [[mods/super-mod-v1]] |
| Grafika (art) i dźwięki | bloki `; >>> X` w `INI/Art.ini`, `INI/Sound.ini` (każdy generator ma swój) | [[workflow/tools-catalog]] |
| Grafiki i dźwięki SC | `MIX/ECACHE76–98.MIX`, `SideC/sidenc/Speech07–09.mix` | rejestr numerów: [[engine/shp-graphics]] |
| Łatki silnika | `game.exe`, `Vinifera.dll` (odbudowywane skryptami, nie w gicie) | [[engine/game-exe-patching]] |
| Lobby (strony, tryby) | `Resources/GameOptions.ini`, `INI/MPMaps.ini`, `Resources/SkirmishLobby.ini` | [[engine/sides-and-houses]], [[engine/client-lobby-options]] |
| Mapy skirmisha i misje | `Maps/Custom/*.map`, `Maps/Missions/arka0N.map`, `INI/BattleE.ini`, `MOVIES/ARKA0NB.MP4` | [[plans/campaign-arka]] |

## Silnik
- [[engine/ini-layering]]: Rules → mapa → opcje gry; co da się nadpisać; klient scala powtórzone sekcje (późniejszy klucz wygrywa); `[INISystem] BasedOn=`.
- [[engine/map-code-layers]]: **kod mapy frakcji jako łańcuch warstw** (`MapCodeININame` = jeden plik, `BasedOn` łączy warstwy), tabela warstw, `tools/MapCode.ps1`, nowa warstwa, usuwanie modu.
- [[engine/tech-and-prerequisites]]: TechLevel, Owner, Prerequisite, grupy, zasięg budowania (`Adjacent`, `BaseNormal`).
- [[engine/adding-new-types]]: nowe typy z mapy lub opcji gry, `Image=`, jednostki bez cameo, jumpjet.
- [[engine/weapons-and-warheads]]: obrażenia × Modifier, `Super` = ×10, laser, tesla, railgun, atom, chemia, EMP.
- [[engine/houses-economy]]: kredyty, BuildTime i mnożniki, **silosy od środka** (`Capacity` tylko z budynków, Vinifera `_Harvested`), prąd.
- [[engine/superweapons]]: lista supermocy, `SuperWeapon=` na budynku.
- [[engine/game-exe-patching]]: łatanie `game.exe` odtwarzalnie, jaskinie, wolne miejsce, vtable, szablon skryptu, `patch-game.ps1`.
- [[engine/spawners]]: lotniskowce (łatka `patch-spawnreturn.ps1`, działa w grze), generator niewidzialności tylko w budynkach.
- [[engine/crates]]: skrzynka „Unit” zawiesza grę bez pojazdu z `CrateGoodie=yes`; poprawka w warstwie `900 Hand edits`.
- [[engine/client-lobby-options]]: własny checkbox w lobby (`$CCxx`, `CustomIniPath`).
- [[engine/debugging]]: logi w `Debug/`, procedura przy crashu.
- [[engine/shp-graphics]]: MIX-y, palety, układ klatek SHP, cameo 64×48, **rejestr numerów MIX**.
- [[engine/sounds-aud]]: `[SoundList]` → `<NAZWA>.AUD`, format AUD.
- [[engine/transform-deploy]]: deploy, `TransformsInto` (Vinifera), wzorzec stimpacka.
- [[engine/starcraft-assets]]: CASC Remastered, ścieżki GRP/WAV/portretów, format GRP.
- [[engine/map-format]]: geometria mapy, IsoMapPack5, OverlayPack, TMP, LAT, mury, renderer CNCMaps.
- [[engine/connected-tiles]]: klify i brzegi z `ConnectedTileDrawer.ini`, reguła łączenia.
- [[engine/starcraft-maps]]: mapy SC (`.scm/.scx`, CHK, tilesety, przejezdność).
- [[engine/fly-locomotor]]: pojazdy z lokomotorem samolotu, łatki `patch-flyhover.ps1` (wiszenie) i `patch-flyertarget.ps1` (AA celuje w lotników).
- [[engine/air-armor]]: AA Aliantów strzela do lotników SC tylko na rozkaz, Dragoon nie trafi Overlorda; pancerze Vinifery, `build-scairarmor.ps1`. Nietestowane w grze.
- [[engine/transports]]: wsiadanie do transportu (`IsVehicleTransport=yes`, transport musi stać), łatka `patch-airboard.ps1` dla piechoty.
- [[engine/buildup-timing]]: czas Buildupu (ok. 81 ticków), łatka `patch-buildup.ps1`, czas produkcji (minimum 54 ticki).
- [[engine/veins]]: żyły i Veinhole Monster: tworzenie w trakcie gry, wzrost, własność, kurczenie (`VeinholeShrinkRate`).
- [[engine/zerg-ai]]: AI Zergów buduje dronami (`Add-ZergBuilder` w `MissionKit.ps1`), skirmish wymagałby łatki. **Ogólne AI gniazda** `Add-ZergAI` (`tools/ZergAI.ps1`): produkcja w Niecce, ataki, alarm i obrona, kontratak, pomoc, rozbudowa.
- [[engine/triggers-and-dialogue]]: **jak pisać misje**: format triggerów, drużyny, ID zdarzeń i akcji, czas, dialogi i ich tempo, `[Tutorial]` (ARKA 9000+), trudność, `Battle.ini`/`BattleE.ini`, `dump-triggers.ps1`.
- [[engine/briefing-movies]]: filmy briefingu w stylu SC (`Brief=`, `MOVIES/*.MP4`, `build-briefing.ps1`). Niezweryfikowane w grze.
- [[engine/sides-and-houses]]: `[Sides]`/`[Houses]`, `Side=` klienta = indeks domu, pliki strony `SIDEC/SPEECH%02d.MIX`.

## Mody

| Strona | Stan | Co |
|---|---|---|
| [[mods/frostbite-cheats]] | zainstalowany | kasa, MCV, działo jonowe, 40+ jednostek w misji Frostbite |
| [[mods/super-mod-v1]] | zainstalowany, zarchiwizowany | checkbox w skirmishu, 8 jednostek, 2× budowanie |
| [[mods/starcraft-marine]] | zainstalowany, nietestowany | checkbox STARCRAFT, Marine ze stimpackiem (`ECACHE77`) |
| [[mods/starcraft-terran-buildings]] | częściowo przetestowany | 18 budynków Terran, Construction Tank (`ECACHE98`) |
| [[mods/starcraft-terran-units]] | nietestowany | 12 jednostek Terran, okręty jako pojazdy Fly (`ECACHE97`, `ECACHE90`) |
| [[mods/starcraft-research]] | nietestowany | 11 badań Terran jako ulepszenia budynków (`ECACHE87`) |
| [[mods/starcraft-zerg]] | nietestowany | Zergi jako piechota w każdych koszarach (`ECACHE80`) |
| [[mods/terran-faction]] | nietestowany | piąta frakcja „Terran” (dom `GDI1`, strona 6), warstwa `000` |
| [[mods/zerg-faction]] | morf działa, reszta nietestowana | szósta frakcja „Zerg” (dom `Nod1`, strona 7): drony morfują w budynki (`ECACHE86`) |
| [[mods/zerg-heroes]] | nietestowany | bohaterowie i budynki kampanii Zergów, Overmind's Wrath (`ECACHE82`) |
| [[mods/zerg-research]] | nietestowany | 13 badań Zergów (`ECACHE84`) |
| [[mods/zerg-side]] | nietestowany | EVA i sidebar Zergów (`Speech08`, `SideC08`) |
| [[mods/zerg-creep]] | **rośnie w grze**, poprawki nietestowane | creep z żył TS, łatki `patch-veins.ps1`, `patch-zergbuild.ps1` |
| [[mods/overlord-storage]] | **działa w grze** | Overlord jako silos `Storage=100` (łatki `game.exe` + `Vinifera.dll`) |
| [[mods/protoss-faction]] | częściowo przetestowany | siódma frakcja „Protoss” (dom `GDI2`, strona 8), zasięg budowania od Pylonów (`ECACHE85`, `ECACHE83`) |
| [[mods/sc-building-sounds]] | nietestowany | dźwięki zaznaczania budynków SC (`ECACHE79`) |
| [[mods/sc-workers]] | animacje działają | SCV/Dron/Probe z animacją wydobycia, Refinery daje 2 SCV (`ECACHE78`) |
| [[mods/sc-infantry-stim]] | nietestowany | łatka deploy piechoty `patch-infdeploy.ps1`, Marine i Firebat jako piechota (`ECACHE81`) |
| [[mods/sc-music]] | nietestowany | 23 utwory SC jako tematy DTA (luźne `MUSIC\SC*.AUD`, indeksy 89–111 w `Theme.ini`) |
| [[mods/sc-lost-temple]] | **działa w grze**, zarchiwizowana | mapa SC (4)Lost Temple |
| [[mods/sc-fighting-spirit]] | zarchiwizowana, nietestowana | mapa SC (4)Fighting Spirit |

## Misje (kampania ARKA)
- [[plans/campaign-arka]]: scenariusz kampanii mashup RA1 × StarCraft „ARKA: Błąd znaku” (preludium, misje 1–11, bonusowe 12–13). HTML: `exports/campaign-arka.html`, przebudowa `tools/build-campaign-html.ps1` po każdej zmianie strony.
- [[workflow/mission-design]]: **zasady projektu misji** (czytaj przed każdą misją): złoża na różnym ryzyku + kopalnia, skrzynki z kasą, rajdy AI na zbieracze, drogi bez ślepych końców, najpierw dialog, potem fala (`Test-QuietDialogue`).
- [[workflow/mission-maps]]: mapy misji z prawdziwego terenu (Google Maps + OSM + DEM → DTA).
- [[missions/arka-00-gibraltar]]: teren preludium (Gibraltar 1953), waypointy 10–47 jako kontrakt z warstwą misji.
- [[missions/arka-00-triggers]]: warstwa misji preludium (`arka00.map`): ARKA, elektrownie, fale Sowietów, desanty Nod, 100 Ton Gun do przejęcia inżynierami. Testy 2026-10-27: ARKA i prąd działają. Od 2026-10-29: nietykalna Tanya-atrapa, mur i obrona wokół ARKI (28 000 HP), licznik 33:00, fale nie w trakcie dialogów.
- [[missions/arka-01-marsara]]: ARKA 1 „Obcy piasek” (dla użytkownika „misja 2”): mapa SC T2 Backwater Station, typy SC skopiowane do mapy, creep od startu, przesmyk gniazda z produkcją obrońców w Spawning Poolu, wrak ARKI z pancerzem 0%. Nietestowana.
- [[missions/arka-02-ewakuacja]]: ARKA 2 „Ewakuacja”: mapa SC T3 Desperate Alliance, eskorta kolonistów, licznik skoku. Nietestowana.
- [[missions/arka-04-zielony-krysztal]]: ARKA 4 „Zielony kryształ”: mapa SC T6 Norad II, TEMPERATE, misja ekonomiczna, Duke jako Marine. Nietestowana. (Misja 3 nie jest zbudowana.)
- [[missions/arka-05-tarsonis]]: ARKA 5 „Upadek Tarsonis”: CASC `Terran10`, ewakuacja cywilów liczona na kredytach, `Civilian=no`. Nietestowana.
- [[missions/frostbite]]: dane misji Frostbite, baza startowa.

## Katalogi
- [[catalog/hidden-units]]: ukryte (`TechLevel=-1`) i międzyfrakcyjne jednostki, samoloty, budynki.
- [[catalog/custom-units-from-maps]]: unikalne typy z map (Bunzilla, SS-22N, Obelisk of Brightness…).
- [[catalog/city-buildings]]: nowoczesne bloki DTA do miast (w miastach SC **odrzucone**, przed użyciem zapytać), arkusz `build-bldg-sheet.ps1`.

## Plany (historia decyzji)
- [[plans/starcraft-factions]]: frakcje SC, otwarte pytania i ścieżka konwersji.
- [[plans/new-faction]]: piąta frakcja bez ruszania Rules.ini (przejęty dom `GDI1`). Wdrożone: [[mods/terran-faction]].
- [[plans/zerg-faction]]: frakcja Zerg przez drony z `DeploysInto`. Wdrożone: [[mods/zerg-faction]].
- [[plans/zerg-creep]]: studium creepu z żył TS. Wdrożone: [[mods/zerg-creep]].
- [[plans/overlord-storage]]: Overlord jako silos, warianty A/B. Wdrożony wariant A: [[mods/overlord-storage]].

## Warsztat
- [[workflow/tools-catalog]]: katalog skryptów (biblioteki, generatory z numerami MIX i plikami INI, łatki, misje, repo, sondy).
- [[workflow/tooling]]: parser INI w PowerShell, kodowanie INI (Latin-1), pułapki PowerShella, narzędzia C#.
- [[workflow/repo-and-updates]]: git w folderze gry: `dta-capture.ps1` po każdej zmianie, `dta-precheck.ps1`/`dta-restore.ps1` przy aktualizacji DTA (aktualizacja przywraca zmienione pliki DTA i usuwa `ECACHE99.MIX`/`BattleE.ini`).
- [[workflow/installer]]: instalator i deinstalator `Modding/dist/DTA-SCMod-Setup.exe` w stylu instalatora SC 1998 (grafika i font SC1 z CASC; `build-installer.ps1`, budować po `dta-capture`), UI sprawdzać tylko przez `/shot`.
- [[workflow/scmap-pipeline]]: mapa SC → `Maps/Custom` jednym poleceniem `port-scmap.ps1`.

## Archiwa
- `archive/super-mod-v1_2026-10-24/` (+ `.zip`): Super Mod v1 + Frostbite cheats, README.
- `archive/sc-lost-temple_2026-10-24/` (+ `.zip`): mapa The Lost Temple, migawka konwertera.
- `archive/sc-fighting-spirit_2026-10-24/` (+ `.zip`): mapa Fighting Spirit.
- `archive/arka00-gibraltar-v1_2026-10-26/` (+ `.zip`): teren Gibraltaru v1, README z przywracaniem.

## Surowe źródła
- `raw/README.md`: mapa plików gry jako źródeł. `raw/sources/karpathy-llm-wiki.md`: wzorzec wiki.
- `raw/maps/gibraltar-google.png`, `raw/maps/gibraltar-geo/`: dane terenu Gibraltaru (OSM, DEM).
