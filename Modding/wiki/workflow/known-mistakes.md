# Znane błędy (i jak ich nie powtórzyć)

Katalog pomyłek z dotychczasowej pracy: objaw → przyczyna → reguła. Czytaj przed nowym modem; szczegóły na stronach w linkach.
Każdy nowy błąd, który kosztował rundę testu, dopisuj tutaj.

Źródła: `log.md` (2026-10-23 … 2026-10-26), testy użytkownika, raporty crashy z `Debug/`, sondy pamięci w `tools/`.

## Łatki game.exe

| Objaw | Przyczyna | Reguła |
|---|---|---|
| Crash `0x66666666` w `AircraftClass::Assign_Destination` | łatka wołała `What_Am_I` (vtable `+0x78`) na celu, który był `CellClass` | na `AbstractClass*` tylko sloty `AbstractClass`; RTTI przez `[obj+4]` → `call [ecx+0Ch]`. [[engine/game-exe-patching]] |
| Łatka morfów przestała działać | nowe jaskinie łatki fly zajęły jej miejsce; `-FromBackup` startuje od czystego exe | rejestr jaskiń w [[engine/game-exe-patching]]; po `-FromBackup` zawsze `patch-game.ps1` |
| Łatka deployu piechoty bez efektu (test 2026-10-27) | hak w `TechnoClass::Can_Deploy_Now`, a Vinifera podmienia tę funkcję w pamięci własną (`TechnoClassExt::_Can_Deploy_Now`) | przed łataniem funkcji sprawdzić `Vinifera.pdb` (zastępnik `_<Nazwa>@…Ext`, haki `_hk__0x00…`); łatać wywołującego. [[engine/game-exe-patching]] |
| Crash: EIP w środku napisu w jaskini (D na pojazdach, 2026-10-27) | podprogram z argumentem położonym przez wejście **nad** adresem powrotu kończył się `ret 4`, czyli wracał pod adres napisu | argument nad adresem powrotu zdejmować `lea esp,[esp+4]` + `ret`; po asemblacji prześledzić stos na kartce. [[engine/game-exe-patching]] |
| Zepsuta grafika/crash po instalacji | MIX lub exe nadpisany przy działającej grze | przed `-Install`/łatką: `Get-Process game` |

## Silnik i INI

| Objaw | Przyczyna | Reguła |
|---|---|---|
| Marines i Rocket Soldierzy w Guard nie strzelają sami do Mutaliska (ARKA 1, 2026-10-27) | skan zagrożeń `Greatest_Threat` bierze z warstwy TOP tylko samoloty i jumpjety; latające pojazdy Fly (RTTI 1) pomija, a w komórkach mapy ich nie ma | łatka `patch-flyertarget.ps1`; lotnik-pojazd potrzebuje jej, żeby być celem automatycznym. [[engine/fly-locomotor]] |
| AI kolonii nic nie produkuje mimo `Production Begins` i `AI triggers begin` (ARKA 1) | pole „strona” AI triggera = 1, a gra wymaga `ActsLike+1` (7 dla `GDI1`) albo 0 | strona = `ActsLike` domu + 1; kontrola w skrypcie misji. [[engine/triggers-and-dialogue]] |
| Interceptory nie wracają do latającego Carriera | `game.exe` odrzuca cele `In_Air()` jako cel lotu samolotu; zmiany INI (`Landable`, hover, naziemny Carrier) nic nie dały | sonda pokazała `NavCom=0`, przyczyna w kodzie; łatka. [[engine/spawners]] |
| Gra zawiesza się po wzięciu skrzynki | „Unit” crate szuka w nieskończoność pojazdu z `CrateGoodie=yes` dla domu (Zerg/Protoss nie mieli) | każda nowa frakcja: ≥1 pojazd `CrateGoodie=yes`. [[engine/crates]] |
| Jednostki niewidoczne w sidebarze | `TechLevel=8`, a lobby ma TL 7 | `TechLevel` ≤ 7 |
| Brak dźwięku śmierci pojazdu | pojazdy ignorują `DieSound` | `Explosion=` animacja z `Report=` |
| Regeneracja tylko do połowy HP | Vinifera self-heal ma domyślnie limit `ConditionYellow` i krok 1 HP | `SelfHealingCap`, `SelfHealingStep` per typ. [[mods/protoss-faction]] |
| `UnitRepair` na Shield Battery nie leczy | budynek nie jest warsztatem dla takich jednostek | łańcuch skrzynki leczącej (`ActiveAnim` → `TrailerAnim` → cząsteczki z ujemnymi obrażeniami) |
| Druga supermoc odpala pierwszą | kliknięcie mapy uruchamia PIERWSZĄ supermoc z tym samym `Action=` | każda supermoc: unikalne `Action=`. [[engine/superweapons]] |
| Buildup trwa zawsze ~81 ticków | stała w `game.exe` | `patch-buildup.ps1`. [[engine/buildup-timing]] |
| Czasy 4× za krótkie/długie | „minuty” Rules liczą 15 ticków/s, skirmish chodzi 60 FPS (zmierzone 45) | przeliczaj czasy z pomiaru, nie z założeń |
| Klasyczne frakcje budują jednostki SC | `Owner=` zawierał GDI/Nod/Allies/Soviet | typy SC tylko z domami frakcji SC (`GDI1`, `Nod1`, `GDI2`) |
| Zmiana `[Houses]` psuje mapy | 122 mapy misji/co-op mają domy od indeksu 14 | nowe frakcje na domach pomocniczych. [[engine/sides-and-houses]] |
| Mod w `ECACHE91–95.MIX` znika | klient kopiuje `Resources/ECache9x.mix` przy starcie | nie używaj 91–95; rejestr numerów w [[engine/shp-graphics]] |
| Zepsute polskie znaki w Rules.ini | zapis przez UTF-8, plik jest Windows-1252 | Latin-1 bajt 1:1. [[workflow/tooling]] |
| Trigger ma złe flagi trudności i brak tagu | przecinek w nazwie triggera/tagu przesuwa pola | nazwy bez przecinków; kontrola „8 pól” w generatorze. [[engine/triggers-and-dialogue]] |
| Szpieg wroga „niszczy” budynek-cel | `48 Destroyed by anything` liczy infiltrację | porażka na `29` (bez infiltracji). [[engine/triggers-and-dialogue]] |
| Jednostki SC w misji kampanii nie istnieją (złapane przed testem) | misja nie ładuje `Game Options/StarCraft.ini` ani `Map Code/Terran Faction.ini` | skopiować typy z domknięciem zależności do mapy. [[missions/arka-01-marsara]] |
| Marines w `[Infantry]` mapy (złapane przed testem) | Marines/SCV to w modzie pojazdy SHP (stimpack = `TransformsInto`) | sekcja obiektu wg listy typu; kontrola w generatorze |
| „Mission failed” po zabiciu ostatniego Hydraliska oblężenia (test 2026-10-27) | `36 All change house` przeniósł Raynora do gracza; zmiana domu = przejęcie = „zniszczony” na jego tagu → trigger porażki | przed zmianą domu wyłączyć trigger porażki, włączyć po kilku s. [[engine/triggers-and-dialogue]] |
| Vulture Raynora bez grafiki (test 2026-10-27) | kopia `SCVULT` pod nazwą `ARKRAYN` bez `Image=`; sekcja grafiki szukana po nazwie obrazu, `[ARKRAYN]` w Art.ini nie ma | każda kopia typu pod nową nazwą: `Image=<oryginał>`; generator sprawdza Art.ini |
| Sojusznicze AI stoi bezczynnie (test 2026-10-27) | dom bez IQ 5, bez fabryki/rafinerii, bez `Production Begins`/AI triggerów | wzorzec „komputerowy dom, który gra”. [[engine/triggers-and-dialogue]] |
| Inżynier nie wchodzi do wraku ARKI (test 2 ARKA 1) | wrak należał do gracza; inżynier przejmuje tylko cudze (wrogie/neutralne) budynki | budynek „do zajrzenia” neutralny i `Capturable`; przejęcie i zniszczenie to to samo zdarzenie `48`, rozróżnić domem docelowym + `10 Destroyed Buildings All`. [[missions/arka-01-marsara]] |
| Rakietami nie da się zestrzelić Mutalisków (test 2 ARKA 1) | niepotwierdzone: lotniki Zergów mają `Naval=yes` (wylęg w Hatchery) i/lub broń dobierana jak na cel naziemny | w misji bez `Naval` + pociski AA+AG; potwierdzić w grze, sprawdzić skirmish |
| AI sojusznika odbudowuje, ale nie produkuje ani nie naprawia (test 2 ARKA 1) | `Prerequisite=FACTORY` nie wskazywało Terran Factory w misji; pole 15 `[Structures]` (AI naprawia) = 0 | w kopiach typów grupy → konkretne budynki; pole 15 = 1 dla domu komputera |
| Przejęcie wraku ARKI = porażka (test 3 ARKA 1) | silnik odpala tag przejęcia (`48`) **przed** zmianą właściciela; `14 Change House` w tym triggerze zostało nadpisane przejęciem | stan po przejęciu sprawdzać później: `32 Building exists` na typie z Rules (indeks z listy Rules) + lokalne zmienne; nie przenosić obiektu w triggerze jego własnego przejęcia. [[missions/arka-01-marsara]] |
| Przejęcie wraku ARKI dalej = porażka (test 4 ARKA 1, po „sędziach” z testu 3) | rozróżnianie „przejęty” i „zniszczony” na jednym tagu jest kruche (przejęcie odpala tag przed zmianą właściciela, Vinifera podmienia ocenę zdarzeń), a logi nie mówią, który trigger zadziałał | obiekt „do zajrzenia inżynierem” robić niezniszczalnym (`Immune=yes`) i nie wiązać z nim porażki; zdarzenie na tagu uruchamia tylko sekret. Jeśli utrata ma przegrywać: łańcuch DTA z cra12 (pkt 13 w [[engine/triggers-and-dialogue]]). [[missions/arka-01-marsara]] |
| Jaki wiszą nad bazą gracza po nalocie | skrypt `1,10` → `11,14`, a przy `Ammo=1` i braku lotniska samolot nie ma dokąd wrócić | nalot: atak → `3,<krawędź>` → `37,0`. [[engine/triggers-and-dialogue]] |
| Wpis jednej misji znika z klienta | generator pisał `INI/BattleE.ini` w całości | generatory scalają swój wpis z plikiem |
| „Neutralne” budynki w mieście strzelają do gracza (ARKA 2) | budynek z bronią (SC Bunker) w domu `Neutral`, który nie jest sojusznikiem gracza | budynki z bronią, które mają być przyjazne, dawać sojuszniczemu domowi, nie `Neutral` |
| Tanya / piechota z `C4=yes` tylko strzela do budynku, nie podkłada C4 (ARKA 2, zainfekowane CC) | silnik daje Sabotage tylko budynkom z `Repairable=yes` (`InfantryClass::What_Action` `0x4D73BA`, `TechnoTypeClass::IsRepairable` `+0x450`); budynki Zergów SC mają `Repairable=no` | budynek do wysadzenia: `Repairable=yes` (+ `ClickRepairable=no`, jeśli gracz nie ma go naprawiać) |
| Drużyna z akcji `80` się nie pojawia (ARKA 2, koloniści) | waypoint pod budynkiem; trigger komórkowy wyłączony do czasu celu | wejście na wolnej komórce obok; strefa ustawia lokalną, a pojawienie się robi trigger logiczny na lokalnych |
| Dialogi misji za szybkie, kilka kwestii naraz | odstępy 5–8 „s” gry (gra chodzi ~3× szybciej niż 15 klatek/s), po 2 teksty w triggerze, fale i przypomnienia trafiały w dialog | `MissionKit.ps1`: jeden tekst na trigger, odstęp z długości, `Test-TextTimeline` 0 WARN. [[engine/triggers-and-dialogue]] |
| Fale, desanty i szpieg stoją, nie atakują bazy | skrypt drużyny naziemnej z `1,N` (Attack waypoint); w DTA używają go tylko samoloty | `16,<cel>` + `11,14`, szpieg `15,<wp>`; kontrola `FAIL` w generatorze. [[engine/triggers-and-dialogue]] |
| Brak harvestera w misji | rafineria postawiona w mapie nie daje darmowego `RAHARV` | dopisać harvester do `[Units]` |

## Skrypty PowerShell (ten komputer)

| Objaw | Przyczyna | Reguła |
|---|---|---|
| W Art.ini tylko ostatni budynek | `foreach ($b in $B)`: nazwy zmiennych bez wielkości liter | lista ≠ zmienna pętli (`$Bldgs`/`$b`) |
| Brak `.bak` łatki DLL | `param($Dll)` nadpisany przez `$dll = …` | cel w zmiennej o innej nazwie |
| Wszystkie lotniki Protossów jeździły po ziemi | `$true -eq 'hover'` daje `True` | porównanie tekstowe `"$x" -eq 'hover'` |
| Funkcja się nie wywołuje | alias wygrywa z funkcją (`R` = `Invoke-History`, `Ac` = `Add-Content`, `Group` = `Group-Object`) | długie nazwy pomocników; sprawdź `Get-Alias <nazwa>` |
| `IndexOutOfRange` w siatce mapy | `foreach ($n in 10..45)` nadpisał `$N` (szerokość siatki) | stałe z nazwą nie do pomylenia (`$GW`) |
| TaskForce `0=2` zamiast `0=2,YAK` | Misje 1 i 2 znikają z listy w kliencie po każdej przebudowie misji 0 (2026-10-27, dwa razy) | „scalanie” `BattleE.ini` w `build-arka00-mission.ps1` sprawdzało `$null -eq $ini.Get(s, k, $null)`, a PowerShell przekazuje `$null` do parametru `string` w C# jako `""`, więc `Get` nigdy nie zwraca `$null` i nic nie było dopisywane | brak klucza w `[Ini]` sprawdzać `-not $ini.Get(…)`, nigdy `$null -eq`; po przebudowie dowolnej misji ARKA zajrzeć do `[Battles]` w `BattleE.ini` |
| `Group-Object` z jednym wynikiem zwraca skalar, `$grp[0]` to znak | `@( … )` wokół każdego potoku, który ma dać tablicę |
| 205 zepsutych napisów w generatorze | masowa zamiana `` `n `` na prawdziwy koniec linii | nigdy w całym pliku; naprawa parserem tokenów. [[workflow/tooling]] |
| Skrypt nie parsuje się | cudzysłowy „” w napisie w podwójnym cudzysłowie | apostrofy albo narzędzie Edit |
| „type Casc already exists” | dwa `Add-Type` w jednym procesie | każdy generator w osobnym `powershell -NoProfile` |
| Exit code 255 przy poprawnym wyniku | `Select-Object -First N` na wyjściu procesu potomnego | `-Last N` albo bez obcinania |
| Drogi nie narysowane, brak błędu | `@( (P 1,2) <nowa linia> (P 3,4) )` spłaszcza tablice w jedną listę liczb | każdy element z przecinkiem: `,(P 1,2)` |
| `ArgumentOutOfRangeException` przy `$d[10] = …` | `[ordered]@{ 10 = … }`: klucz liczbowy w indeksie = **pozycja**, nie klucz | klucze tekstowe `'10'` i `$d["$k"]` |
| Kafel OSM nr −488 zamiast 15 897 | `F 36.14 -5.35`: ujemna liczba pozycyjnie = tekst, `"-5.35"+180` skleja napis | parametry typowane `[double]` i `(-5.35)` w nawiasie |
| Atrakcje na x = 76 552 | `$pos = if (…) { $osm.Find(…) }`: lista z 1 wynikiem rozwija się do `{lat, lon}`, `$pos[0][1]` = `$null` | przypisanie wewnątrz gałęzi `if`, nie wynik `if` |
| `Could not create SSL/TLS secure channel` | PS 5.1 bez TLS 1.2; Overpass odrzuca handshake z tego komputera także po włączeniu | `[Net.ServicePointManager]::SecurityProtocol = Tls12`; zamiast Overpass API OSM (`/api/0.6/map`). [[workflow/mission-maps]] |

## Mapy

| Objaw | Przyczyna | Reguła |
|---|---|---|
| Schodki trawy od strony morza, plaża odwrócona | woda w szablonach Shores ma kod `9` **albo `1`**, koszt widział tylko `9` | `DesignToDta.Beaches`. [[engine/connected-tiles]] |
| Kanał wody przecina cypel, schodkowe brzegi bez klifu | `FindBridges` wykrył tylko część wąskiego lądu jako groblę | w mapach projektowanych bez grobli; cypel ≥ 6 komórek albo usunąć. [[missions/arka-00-gibraltar]] |
| Etykiety Google Maps jako pasy lądu na wodzie | ciemny tekst ≠ kolor wody | wyciąć wielokątami przed głosowaniem |
| Miasto zalane równoległymi drogami | kafel drogi ma 2 komórki, a wzięto też `tertiary` | tylko `trunk/primary/secondary` w gęstej zabudowie. [[workflow/mission-maps]] |
| Pół Gibraltaru z bruku | `landuse=military` (tereny MOD) brane jako przemysł | bez `military`/`construction` w bruku |
| Grań z DEM prawie znikła | wycięcie pasa przy brzegu + odsunięcie 24 px zjadły wąski grzbiet | odsunięcie 18 px, próg 220 m |
| Wschodnia krawędź Skały jak od linijki | wycinanie pasa ograniczone stałym `x ≥ 430` | ogranicza tylko odległość od brzegu |
| Pojedyncze kawałki plaży na otwartym morzu | drugi przebieg `Beaches` po przerwach (łuki ≥ 2) | nie używać; drobne surowe styki zostawić |
| `IndexOutOfRange` w `Road` | punkty OSM poza projektem, `Idx` zawija wiersz | `CellAt` zwraca −1 poza mapą |

## Diagnoza

- **Najpierw dane, potem poprawki.** Interceptory: 5 rund zmian INI na podstawie hipotez, a dopiero sonda pamięci wskazała
  przyczynę w kodzie. Supermoc: tak samo. Przy zachowaniu silnika, którego nie wyjaśnia INI, od razu sonda albo deasemblacja.
- **Czytanie sondy:** gdy numer klatki stoi (np. 19 klatek w 2 minuty), gra jest spauzowana albo na ekranie wyników. Jednostki
  „wiszące” wtedy w logu nie są błędem.
- **Raport crasha:** adres z `Call Stack` + `Game.pdb` daje funkcję; śmieciowy EIP = zły slot vtable. [[engine/debugging]]
- Rzeczy nieprzetestowane w grze oznaczaj **(niezweryfikowane w grze)**, a po teście użytkownika usuń znacznik.
