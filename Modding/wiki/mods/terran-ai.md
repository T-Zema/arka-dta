# Mod: AI frakcji Terran w skirmishu (Advanced AI, czysto SC)

Komputer grający frakcją Terran (dom `GDI1`) buduje bazę z budynków SC, robi badania, buduje SCV i armię SC i atakuje według taktyk w stylu DTA i AI StarCrafta. Stan: **działa w grze** (test użytkownika 2026-10-30 na Easy AI: „super zadziałał”); łatka Siege Mode z tego samego dnia jeszcze niezweryfikowana. Wymaga checkboxów STARCRAFT i Advanced AI (domyślny).

Źródła: [[engine/advanced-ai]] (mechanika, disasemblacja `Vinifera.dll`), `INI/Game Options/Advanced AI.ini` (taktyki DTA jako wzór), skrypty AI SC z CASC (`tools/sc-aiscript.ps1`: `Ter8` „Confederate Town” z „The Trump Card”, melee `TMCx`), `Maps/Missions/se09.map`, `se11.map` (wzorce AI misji DTA), [[mods/terran-faction]], [[mods/starcraft-terran-buildings]], [[mods/starcraft-research]].

## Dlaczego było potrzebne

Przed modem AI-Terran: stawiał klony Aliantów (budynki SC miały `AIBuildThis=no`), nie miał żadnej taktyki (wszystkie `House=0..3`), więc **nigdy nie tworzył armii**. AITriggery są przy Advanced AI wyłączone.

## Pliki

| Plik | Co |
|---|---|
| `Modding/tools/build-scterranai.ps1` | generator; `-WhatIf` wypisuje blok bez zapisu |
| `INI/Game Options/StarCraft.ini` | blok `; >>> Terran AI` na końcu (kopia `StarCraft.ini.bak`) |
| `Modding/tools/patch-vinifera-siegeai.ps1` | łatka `Vinifera.dll`: rozkładanie maszyn przez komputer dopiero w zasięgu celu, zwijanie dla Terran |

Blok jest w `StarCraft.ini`, nie w warstwie kodu mapy: ten plik scala się po kodzie frakcji i po `Advanced AI.ini`, więc jego klucze wygrywają, a bez checkboxa STARCRAFT Terran i tak nie ma swoich typów. Uruchamiać ponownie po zmianach w generatorach budynków, jednostek i badań Terran (czyta scalone reguły).

## Co robi blok

1. **Czysto SC** (decyzja użytkownika 2026-10-30): 115 typów spoza SC traci `GDI1` w `Owner=` (klony Aliantów z warstwy `000`, typy GDI, które mają `GDI1` w Rules: zbieracze, `AMCV`, `RAPROC`, mury, `TRAN`, `HELI`…). Dotyczy też gracza-Terrana. Zostają Zergi z koszar ([[mods/starcraft-zerg]], mod dla wszystkich frakcji). Bez tego AdvAI brało `AMCV`/`TDHARV`/`RAPROC` jako „pierwszy posiadany” MCV, zbieracz i rafinerię.
2. **`AIBuildThis=yes`** dla 18 budynków Terran (bez Command Center) i 12 badań. Ostatni krok kolejki AdvAI stawia jedną sztukę każdego, więc AI samo robi Academy, Armory, Comsat, Science Facility, Nuclear Silo i **badania** (jak AI SC: `upgrade`/`tech`).
3. **Listy `[AI]`**: na końcu `BuildPower=…,SCDEPO,SCUDEPO` (podstawowa i zaawansowana: Supply Depot i Uber Supply Depot), `BuildRefinery=…,SCREFI`, `BuildBarracks=…,SCBARR`, `BuildWeapons=…,SCFACT` (warunek „ma fabrykę”), `BuildDefense`/`BuildPDefense=…,SCBUNK`, `BuildAA=…,SCMTUR`, `BuildNavalYard=…,SCSTAR`. `BuildRadar` i `BuildTech` bez zmian (krok radaru pomija wymagania; `Enhance.ini` i `Advanced AI.ini` różnie ustawiają `BuildTech`).
4. **`[General] HarvesterUnit=…,SCSCV`**: bez tego AI sprzedawało Refinery jako „bez zbieraczy”.
4a. **`GuardRange=12`** (albo zasięg broni, gdy większy: Hero 16) dla 34 bojowych jednostek Terran, także wersji po badaniach i formy `_D`. Wzorem są klony `AI*` z DTA. Bez tego AI „nie reagowało na atak” (test użytkownika 2026-10-30): samoobrona dowozi jednostki pod uszkodzony budynek, ale jednostka bez `GuardRange` strzela tylko w zasięgu broni. Pomijane są Zergi z koszar, typy z własnym `GuardRange` (blok `SC balance (user)`), Medic, SCV i MCV. Gracza to zmienia tylko w trybie `Guard Area`, bo w zwykłym `Guard` gra bierze zasięg broni dla ludzi ([[engine/advanced-ai]] „Samoobrona”). **(niezweryfikowane w grze)**
5. **Taktyki `House=6`** (pierwsza pasująca wygrywa):

| Taktyka | Typ | Kiedy | Inspiracja |
|---|---|---|---|
| `TERRAN_EARLY_RUSH` | rush piechotą | slot 0 < 4, bez fabryki, < 2000 klatek, wróg nie Nod/Soviet/Protoss | GDI DTA |
| `TERRAN_EARLY_SCOUT` | zwiad | slot 0 < 11 (50%: ustaw 11) | GDI DTA |
| `TERRAN_EARLY_DEFEND` | obrona | slot 0 > 10, bez fabryki | GDI DTA |
| `TERRAN_BIO_PUSH` | rush piechotą do 3000 | 2000–7000 klatek, bez przewagi wroga, 50% | SC `TMCx`: Marines + Firebaty po Academy |
| `TERRAN_MID_VEHICLE_RUSH` | rush pojazdami + obrona | fabryka, < 4000 klatek, 50% | GDI DTA |
| `TERRAN_VULTURE_RAID` | samobójczy rajd na zbieracze do 2000 | fabryka, wróg ma > 1 rafinerię, co 5000 klatek, 40% | SC: Vulture'y na SCV, Nod DTA |
| `TERRAN_RAID_HIGH_PRIORITY` | duży rajd + piechota | > 6 rafinerii wroga, co 12000, 80% | Nod DTA |
| `TERRAN_FLANK_ATTACK` | atak na rafinerie | słabo bronione rafinerie, co 6000, 75% | GDI DTA |
| `TERRAN_HOLD_THE_LINE` | straż domowa do 3000, najwyżej 1 | przewaga wroga ×2, > 4000 klatek, 50% | SC `defensebuild`/`defenseuse` |
| `TERRAN_SIEGE_PUSH` | atak pojazdami (waga artylerii = Siege Tanki) + piechota | fabryka, > 6000 klatek, 50% | SC `Ter8`/`TMCx`: pchnięcia czołgami |
| `TERRAN_DIRECT_ATTACK` | atak mieszany | 50% | GDI DTA |
| `TERRAN_FAST_ATTACK` | szybki atak | zawsze (zapas) | GDI DTA |

Taktyki „morskie” (`[AdvancedAINavalTactics]`) to **flota lotników SC** (Wraith, Battlecruiser, Science Vessel to pojazdy `Naval=yes`, AdvAI buduje je tylko dla drużyn morskich, a te wymagają Starportu z `BuildNavalYard`): `TERRAN_FLEET_HARASS` (40%, do 4500) i `TERRAN_FLEET_ATTACK` (rośnie z czasem). Jak w SC `TMCx`: późne ataki Battlecruiserami.

Ataki rosną z czasem (`FrameBasedDurationIncrease`), jak eskalujące fale `Ter8`. Generator sprawdza nazwy enumów w `Vinifera.dll` (literówka = koniec gry), czy wszystkie typy z list należą do `GDI1` i czy jest SCMCV do odbudowy placu.

## Czego AI nie zrobi (ograniczenia silnika)

- **Medic, Dropship, Valkyrie, SCV do walki**: broń główna bez `AG=yes` albo brak broni = wartość minimalna. To samo dotyczy medyków DTA.
- **Ekspansje na mapach SC**: AdvAI szuka drzew Tyberium, a na mapach z `port-scmap.ps1` ich nie ma. Rafinerie stoją przy środku bazy. Możliwe obejście: konwerter stawia przy polach minerałów obiekt terenu z `SpawnsTiberium=yes` (do zrobienia).
- **Siege Mode** (od 2026-10-30 łatka `tools/patch-vinifera-siegeai.ps1`, w łańcuchu `patch-vinifera.ps1`, sekcja `.scsiege`): bez łatki komputer rozkładał Siege Tanka w chwili, gdy drużyna zaczynała polować, gdziekolwiek stał, i nigdy go nie zwijał (zwijanie w AdvAI było tylko dla Allies). Z łatką czołg podjeżdża, rozkłada się, gdy cel jest w zasięgu jego działa (11,9 pola; w trybie oblężenia 20,4, minimum 3), i wraca do trybu czołgu, gdy przez 2250 klatek nie ma celu. Mechanizm: [[engine/advanced-ai]] „Rozkładanie jednostek”. **(niezweryfikowane w grze)**
- **Poziomy trudności**: Terran dostaje te same 7 poziomów co frakcje DTA (sekcje handicapu i 3 stopnie AdvAI działają na każdy dom), więc nic nie trzeba dopisywać. Tabela: [[engine/advanced-ai]] „Poziomy trudności”.
- **Lotnictwo `AircraftTypes`**: Terran nie ma lądowiska, więc żadnych nalotów z `[AdvancedAIAirTactics]`.
- Bez checkboxa Advanced AI Terran nie ma AITriggerów (Side 7), więc nie atakuje.

## Test (do zrobienia przez użytkownika)

Skirmish, STARCRAFT + Advanced AI, AI = Terran (najlepiej trudne) na mapie DTA i na mapie SC (Lost Temple):
1. AI rozkłada Construction Tank, stawia Supply Depot, Refinery, Barracks, buduje SCV (nie sprzedaje Refinery).
2. Pierwsza drużyna (zwiad albo rush Marines) w ciągu ok. 2–4 min, potem ataki pojazdami, rajdy Vulture'ów na zbieracze.
3. Factory, Starport, badania (ikony ulepszeń), później Wraithy/Battlecruisery atakujące jako flota.
4. W `Debug/` (log) co 10000 klatek „Unit values”: lista wartości jednostek. Przy crashu: `EXCEPT_*.TXT` i log, najpierw szukać „Unknown AdvAI”.
5. Kontrola: AI Allies i Soviet grają jak wcześniej; gracz-Terran nie ma już budynków Aliantów.
6. Siege Tanki AI: jadą z drużyną, rozkładają się dopiero przy wrogu, po walce wracają do trybu czołgu (do ok. 2250 klatek bez celu). AI Allies: Enforcer rozkłada się przy wrogu, a nie zaraz po wyjeździe.
7. Atak na bazę AI (np. na Refinery albo Barracks, nie na Bunker): wolne jednostki i te z drużyny, która się zbiera, podjeżdżają i walczą w promieniu ok. 12 pól. Atak na sam Bunker czy Turret nie wzywa pomocy (tak działa AdvAI).

## Odinstalowanie

Usunąć blok `; >>> Terran AI` … `; <<< Terran AI` z `INI/Game Options/StarCraft.ini` (`StarCraft.ini.bak` jest starszy, nie przywracać go w całości).
