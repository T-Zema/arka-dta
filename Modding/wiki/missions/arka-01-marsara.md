# ARKA 1 „Obcy piasek” (Mar Sara, 2499): mapa i misja

Pierwsza misja na Mar Sarze z [[plans/campaign-arka]] (użytkownik liczy preludium jako „misję 1”, więc dla niego to **misja 2**). Teren to mapa kampanii StarCrafta **T2 „Backwater Station”** z CASC użytkownika, powiększona 2× i przeniesiona na pustynny teatr DTA. Na niej warstwa misji: wrak ARKI w kraterze, rozbitkowie, uszkodzony MCV, osada Mar Sara z Raynorem i gniazdo Zergów. Kompletna i grywalna od startu do wygranej, **(niezweryfikowane w grze)**.

Źródła: CASC StarCrafta `SD/campaign/Terran/Terran02/staredit/scenario.chk` (T2 Backwater Station, 64×64 badlands; też T1 Wasteland i T3 Desperate Alliance obejrzane), `Modding/tools/build-arka01-marsara.ps1`, `Modding/tools/build-arka01-mission.ps1`, `INI/Desert.ini`, `Map Editor/Editor/Config/ConnectedTileDrawer.ini` (`DesertCliffSet`), `INI/Game Options/StarCraft.ini`, `INI/Map Code/Terran Faction.ini`, `INI/Rules.ini` (`[CHAN]`, `[C2]`, `[AMCV]`, `[SmudgeTypes]`), render CNCMaps.

## Pliki

| Plik | Rola |
|---|---|
| `Maps/Custom/arka01_marsara.map` (+ `.png`) | teren (do obejrzenia w skirmishu „Custom Map”), waypointy 10–45; **nadpisywany** przez skrypt terenu |
| `Maps/Missions/arka01.map` | misja; **nadpisywana** przez skrypt misji |
| `INI/BattleE.ini` | wpis klienta `M_ARKA01` (pod nagłówkiem „ARKA: Blad znaku”, obok `M_ARKA00`); skrypt **scala**, nie nadpisuje |
| `Modding/tools/build-arka01-marsara.ps1` | teren: CASC → ScToDta, zoom 2×, teatr DESERT, dekoracje, waypointy, render i podgląd |
| `Modding/tools/build-arka01-mission.ps1` | misja: typy SC skopiowane do mapy, domy, obiekty, strefy, drużyny, 46 triggerów, 43 teksty, kontrole |
| `%TEMP%\arka01-terrain\` | `sc_grid.png` (mapa SC z siatką kafli i waypointami), `waypoints.png`, `compare_sc.png`, `log.txt`, pełny render |
| `%TEMP%\arka01-mission\` | `log.txt`, render z `-Render`; dekompilacja: `tools/dump-triggers.ps1 -Map Maps\Missions\arka01.map` |

```powershell
powershell -NoProfile -File Modding\tools\build-arka01-marsara.ps1          # teren, ok. 2 min z renderem
powershell -NoProfile -File Modding\tools\build-arka01-mission.ps1 -Render  # misja, ok. 1 min
```

Kolejność: najpierw teren, potem misja (czyta teren). Po przebudowie terenu zawsze uruchomić skrypt misji ponownie.

## Teren

- **Dlaczego T2:** układ Backwater Station pokrywa się z misją: baza gracza w kotlinie SW (tu wrak ARKI), opuszczona osada Terran na płaskowyżu NW (tu osada Mar Sara z Raynorem), zainfekowane Command Center z Creep Colonies na NE (tu gniazdo Zergów). Pierwsze misje Terran w SC (T1 Wasteland, T2 Backwater Station) to dokładnie „rozbitkowie + Raynor + pierwsze gniazdo”.
- **Mapy kampanii SC są w CASC**, nie w folderze `Maps` (tam są tylko Enslavers). Ścieżka `SD/campaign/<Rasa>/<Misja>/staredit/scenario.chk` czyta się `Casc.ReadFile` i od razu `Chk` (bez MPQ). Wersje `locales/enUS/...` nie są zainstalowane lokalnie (`ekey not in index`), działają ścieżki `SD/`.
- **Zoom 2×:** mapa 64×64 kafli SC daje w konwerterze tylko 32×64 komórek. Skrypt powiększa minikafle (`ScTerrain.Flags/Rgb/W/H`), `Chk.Width/Height` i pozycje jednostek/sprite'ów, zanim poda je do `ScToDta`. Wynik: `Size=0,0,68,137`, widoczne 64×128 (3072×3072 px ekranu).
- **Teatr DESERT:** konwerter jest od teatru niezależny poza nazwami zestawów. `Theater "INI\Desert.ini","des"`, klify `DesertCliffSet`, podłoże: niziny = `Clear` (rdzawy piasek), płaskowyże = `Light Sand` + `Light/Dark Sand LAT`, „trawa” SC na płaskowyżach = `~~~Rough LAT tile` + `~~~Clear/Rough LAT`, skały 1×1 = `Rocks` (1267+). `WriteMap` wpisuje `Theater=TEMPERATE`, skrypt podmienia na `DESERT`.
- **Zmiany względem SC:** gejzery usunięte (konwerter robi z nich drzewa Tyberium, a nikt na Mar Sarze nie może jeszcze znać Tyberium), dodane pole kryształów przy MCV na południu, środkowa „świątynia” konwertera (Lost Temple) usunięta. Minerały SC = niebieskie klejnoty (pole przy wraku, przy osadzie, na wschodzie, na południu).
- **Dekoracje pustyni:** 107 obiektów (`BR1–9`, `SROCK01–07`, kaktusy, `BT`) gęściej przy podnóżach klifów, rzadko na otwartym terenie, nigdy w promieniu 5 komórek od waypointu i tylko tam, gdzie wszystkie 8 sąsiadów jest wolne (żaden kamień nie zamknie rampy); 155 kafli kamyków (`Pebbles`) na czystym piasku nizin.
- Kontrole: 4 starty SC połączone, 0 nieudanych łańcuchów klifów, 0 odciętych komórek, 187 „przecieków” (dna dwóch wąwozów N–S są tu dostępne z dołu, w SC nie; to ślepe zaułki, nieszkodliwe). Waypointy 10–45 osiągalne z miejsca katastrofy poza 26 (Obserwator nad krawędzią, nie musi).

## Waypointy (kontrakt teren ↔ misja)

Współrzędne w kaflach oryginalnej mapy SC (siatka 64×64 w `sc_grid.png`); skrypt przesuwa każdy na najbliższą wolną komórkę.

| Nr | Kafel SC | Co | Nr | Kafel SC | Co |
|---|---|---|---|---|---|
| 10 | 6,50 | wrak ARKI (krater) | 28 | 4,45 | wrak elektrowni |
| 11 | 10,55 | start oddziału gracza | 29 | 46,51 | Zerglingi przy MCV |
| 12 | 3,50 | (nieużywany od 2026-10-27; był osobny rdzeń) | 30 | 50,4 | Spawning Pool |
| 13 | 44,58 | uszkodzony MCV | 31–33 | 44,8 / 48,15 / 58,12 | Creep Colony 1–3 |
| 14 | 17,34 | rozbitkowie 1 (pierwszy kontakt) | 34–35 | 45,18 / 40,11 | Sunken Colony 1–2 |
| 15 | 36,30 | rozbitkowie 2 | 36–38 | 20,4 / 20,11 / 11,21 | bunkry osady |
| 16 | 57,41 | rozbitkowie 3 (kryształy na wschodzie) | 39 | 5,10 | Academy osady |
| 17 | 7,5 | Command Center osady | 40 | 15,9 | Barracks osady |
| 18 | 12,14 | Raynor i Marines | 41 | 3,3 | Supply Depoty |
| 19 | 55,5 | Wylegarnia (Hatchery) | 42 | 30,50 | zbiórka najazdu z południa |
| 20 | 51,10 | zbiórka fal Zergów | 43 | 8,40 | północny skraj krateru (linia obrony) |
| 21 | 42,30 | trasa: centralna dolina | 44 | 56,40 | pole kryształów na wschodzie |
| 22 | 22,33 | trasa: pas zachodni | 45 | 33,22 | trasa: wyjście z północnego wąwozu |
| 23 | 28,7 | zbiórka oblężenia osady | 25 | 62,1 | wlot Mutalisków (róg NE) |
| 24 | 24,31 | zasadzka na rozbitków 1 | 26 | 62,62 | Obserwator Protossów (krawędź SE) |
| 27 | 12,44 | wrak koszar | | | |

## Typy StarCrafta w misji kampanii

Misja z `BattleE.ini` **nie ładuje** checkboxa STARCRAFT (`INI/Game Options/StarCraft.ini`) ani kodu mapy frakcji (`INI/Map Code/Terran Faction.ini`). Bez kopii reguł Zerglingi, Marines i budynki SC po prostu by nie istniały. Skrypt misji:

1. Czyta oba pliki SC jak klient (powtórzone sekcje scalane, późniejszy klucz wygrywa, więc blok „SC balance (user)” też wchodzi).
2. Od listy korzeni (`SCZLNG SCZHYL SCZMUT SCZOVL SCZHAT SCZPOL SCZCRP SCZSUN SCMARINE SCVULT SCSCV SCCC SCBARR SCACAD SCBUNK SCDEPO SCPOBSV`) zbiera **domknięcie**: każdą sekcję SC, którą nazywa jakikolwiek klucz (broń, pocisk, głowica, `TransformsInto`, `UndeploysInto`…). Nie idzie po `Prerequisite*`, `BuiltAt`, `Owner`, `Image`. Wynik: 38 sekcji.
3. Kopiuje je do mapy i rejestruje w tych samych listach (`[InfantryTypes]`, `[VehicleTypes]`, `[BuildingTypes]`…), klucze `ARKA1xx###`.
4. `Prerequisite`/`BuiltAt` filtruje do nazw, które w misji istnieją (grupy `ZHATCHERY` itp. i nieskopiowane budynki wypadają). Nikt tych typów w misji nie buduje.
5. Grafika (`Art.ini`), dźwięki (`Sound.ini`) i `ECACHE*.MIX` są globalne, nic nie trzeba.

**Marines i SCV są w modzie pojazdami SHP** (stimpack = `TransformsInto`, działa tylko dla pojazdów). Stawia się je w `[Units]`, nie `[Infantry]`. Skrypt sam sprawdza listę typu (`Is-Vehicle`), a kontrola zgłasza FAIL, gdy obiekt stoi w złej sekcji. Zerglingi i Hydraliski to prawdziwa piechota.

Typy własne misji: `ARKAWRAK` (wrak ARKI: `Image=RAPDOX`, 20 000 HP, start 35%, `Repairable=no`, bez prądu, **neutralny i do przejęcia**, żeby dało się wprowadzić inżyniera; osobny „rdzeń” `ARKARDZN` usunięty 2026-10-27), `ARKEINST` (Einstein: `[CHAN]` ← `[C2]` rozwinięte ręcznie, bo `$Inherits` nie sięga z mapy do Rules, 400 HP, `Fraidycat=no`), `ARKRAYN` (Jim Raynor: kopia `SCVULT`, **`Image=SCVULT`**, HP Vulture'a +40% = 2240 (do testu 5: +20% = 1920), samoleczenie, **głosy Raynora-Marine** `SCRAYN`: `SCRAWHT*`, `SCRAPSS*`, `SCRAYES*`). Pierwsza wersja nie miała `Image=` i Vulture Raynora był w grze niewidoczny (test 2026-10-27). Skrypt sprawdza teraz, czy każdy typ zarejestrowany przez mapę ma sekcję grafiki.

## Domy

| Dom | Rola | Uwagi |
|---|---|---|
| `Allies` (2) | gracz | 3000 kredytów, `TechLevel=3`; `RAATEK`, `AHPAD`, `ASYRD`, `RAPDOX`, `RAGAP`, `HELI`, `TRAN`, `APC` mają w mapie `TechLevel=-1` (wczesny tech: koszary, rafineria, fabryka, radar) |
| `Allies1`, `Allies2`, `Soviet1` | rozbitkowie 1–3 | sojusznicy gracza; każda grupa osobny dom, bo `36 All change house` przenosi cały dom |
| `Soviet2` | załoga MCV | jw. |
| `GDI1` (6) | osada Mar Sara: **komputerowy sojusznik, który gra** | `IQ=5`, 4000 kredytów; CC, Barracks, Academy, 3 Supply Depoty, 3 bunkry, Refinery przy kryształach, Terran Factory, 3 SCV na minerałach (`Harvest`), cywile `C2`; 11 węzłów bazy (odbudowa); od startu `Production Begins`, po oblężeniu `AI triggers begin`: drużyna obrony (4 Marines + Firebat) i ataki na gniazdo (6 Marines + 2 Firebaty, 4 Vulture'y) z `[AITriggerTypes]` mapy; wzorzec w [[engine/triggers-and-dialogue]] |
| `GDI2` (8) | Raynor i 8 Marines | przechodzi do gracza po ocaleniu osady |
| `Nod1` (7) | gniazdo Zergów | Hatchery, Spawning Pool, 3 Creep, 2 Sunken, 2 Overlordy, straże; fale |
| `Nod2` (9) | rój oblegający osadę | osobny dom, żeby „wszystkie jednostki zniszczone” mierzyło tylko oblężenie |
| `Soviet` (3) | Obserwator Protossów | sprzymierzony ze wszystkimi, pojawia się w finale |

## Przebieg (czas gry w sekundach)

Od 2026-10-27 przy starcie (komórka 125,174) leży **skrzynka z odkryciem mapy** (`Add-RevealCrate`). Triggery z kilkoma tekstami są rozbite na łańcuchy, a fala 1 przeszła z 420 s na 470 s, żeby nie nachodziła na cel „gniazdo”. Oś czasu tekstów: 0 WARN ([[engine/triggers-and-dialogue]], „Tempo dialogów”).

| Kiedy | Co się dzieje |
|---|---|
| 1, 40, 65, 85, 114, 159, 186, 205, 242 (od 2026-10-27 odstępy z długości kwestii, `MissionKit.ps1`; wcześniej co 5–10 s) | obcy kanał radiowy Konfederacji, Tanya („Czyja to konfederacja?”), Einstein („czyj to wszechświat?”), Stavros, cele (rozbitkowie, MCV, Einstein i wrak muszą przetrwać), znaczniki radaru na grupach i MCV, wskazówki: wraki do przejęcia, inżynier do wraku ARKI |
| wejście w pierścień 4–9 wokół wp 14 albo 300 | **pierwszy kontakt**: 4 Zerglingi napadają rozbitków 1; „Psy?!” / „To nie jest nawet nasza biologia.” |
| wejście w strefę grupy (r ≤ 3) | grupa przechodzi do gracza; po wszystkich trzech: cel wykonany |
| wejście w strefę MCV (r ≤ 4) | MCV i załoga do gracza, cel: rozstaw MCV |
| `Building exists AFACT` | Einstein o kryształach „podobnych do rudy”, Stavros o ekonomistach |
| 400 | cel główny: gniazdo na NE (znacznik radaru) |
| 470 / 690 / 840 / 960 / 1200 / 1380 | fale (prosto na wrak ARKI, bez objazdu przez środek mapy): 6 i 8 Zerglingów, najazd z południa (5, z wp 29), Zerglingi + 3 Hydraliski (pierwsze Hydraliski w misji, z kwestią Einsteina), Zerglingi + 5 Hydralisków, 1 Mutalisk; od 1500 fala co 300 s; na trudnym dodatkowa fala w 1080 |
| wejście w pierścień 10–15 wokół wp 18 albo 540 | **oblężenie osady**: wezwanie Raynora, dwa oddziały samych Zerglingów (`Nod2`, 7 i 8) co 45 s |
| 2 | osada: `Production Begins` (produkcja, SCV, odbudowa) |
| `Nod2` bez jednostek | Raynor i Marines do gracza („czołgi z muzeum”), Tanya: „Kowboj na motorze.”; po 20 s osada zaczyna wysyłać własne drużyny (`AI triggers begin`), najpóźniej w 900 |
| inżynier wchodzi do wraku ARKI | wrak przechodzi do gracza (`Building exists` RAPDOX), sekret: pęknięty zielony kryształ; Einstein: „Ktoś nam pomógł się pomylić.” |
| Wylegarnia zniszczona | wszystkie fale wyłączone |
| wszystkie budynki `Nod1` zniszczone | Duke przez radio, Raynor na prywatnym kanale, Obserwator Protossów migocze na krawędzi SE, **wygrana** |

**Porażka:** śmierć Einsteina, śmierć Tanyi (tag `ARKA1G02`, trigger `tanLost`, dodane 2026-10-27: wcześniej jej śmierć nie dawała porażki), śmierć Raynora (wrak ARKI od testu 4 jest niezniszczalny, `Immune=yes`, i nie jest już warunkiem porażki) (dodane względem planu: Raynor jest potrzebny w misji 2 „Ewakuacja”), utrata wszystkiego.

**Błąd z testu 2026-10-27 (naprawiony):** zabicie ostatniego Hydraliska oblężenia dawało „mission failed”. Ostatni Hydralisk kończył oblężenie, a „Kolonia ocalona” przenosiła dom Raynora do gracza (`36`). Zmiana domu to dla silnika przejęcie i odpala na tagu Raynora zdarzenie „zniszczony”, więc trigger „Raynor zginął” dawał przegraną. Teraz ten trigger jest wyłączany przed zmianą domu i włączany znowu po 3 s (`rayRearm`). Logi `Debug/` nie zapisują, który trigger zadziałał; przyczynę ustaliłem z przebiegu.

**Test 2 (2026-10-27), poprawki:**
- **Inżynier do wraku ARKI:** wrak należał do gracza, a do własnego budynku inżynier nie wejdzie. Teraz wrak jest neutralny i do przejęcia. Jeden tag i to samo zdarzenie `48` odpalają zarówno przejęcie, jak i zniszczenie, więc trigger na tagu przenosi wrak (jeśli istnieje) akcją `14 Change House` do domu `GDI` („ARKA”) i włącza dwa triggery. „Wrak zniszczony” (`Elapsed 2` + `10 Destroyed Buildings All` domu `GDI`) daje porażkę od razu po zniszczeniu i pilnuje wraku do końca misji. Sekret (`Elapsed 4`) pokazuje się tylko wtedy, gdy porażki nie było. **(niezweryfikowane w grze)**
- **Mutaliski nie do zestrzelenia rakietami:** Rocket Soldier Aliantów to `E3A`, a broń przeciwlotniczą (`AA70mmMslRA`) ma. Lotniki Zergów mają `Naval=yes` (tylko po to, żeby Hatchery je wylęgała jak stocznia). Podejrzenie: przez tę flagę broń w nie nie celuje. W misji `SCZMUT`/`SCZOVL` tracą `Naval`/`BuiltAt`, a rakiety (`70mmMsl`, `70mmMslRA`, `AA70mmMsl`, `AA70mmMslRA`) dostają pocisk `ARKA1AAG` (kopia `AGHeatSeeker` z `AA=yes`, `AG=yes`), więc trafiają w powietrze niezależnie od tego, którą broń silnik wybierze. **Marines** (`SCGauss`, `SCGaussS`) strzelają pociskiem `Invisible3` (AA i AG). Która z przyczyn była prawdziwa: niepotwierdzone. Ten sam problem może dotyczyć skirmisha.
- **AI osady** odbudowywało bunkry, ale nie produkowało jednostek i nie naprawiało budynków. Naprawa: pole 15 w `[Structures]` (AI naprawia) = 1 dla `GDI1`, tak jak w misjach DTA. Produkcja: jednostki SC miały `Prerequisite=FACTORY`, a grupa `FACTORY` w misji najwyraźniej nie obejmowała Terran Factory, więc w kopiach typów SC `FACTORY` → `SCFACT`, `BARRACKS` → `SCBARR`.
- Oblężenie osady to same Zerglingi (Hydraliski pierwszy raz w fali 3, z kwestią Einsteina), Zerglingi zamiast Hydraliska w centralnej dolinie, fale idą prosto na wrak (wcześniej trasa przez wp 21 w środku mapy), najazd z południa z wp 29, przy kwestii Tanyi „one też latają” jest tylko 1 Mutalisk (także w fali dodatkowej).
**Test 3 (2026-10-27), poprawki:**
- **Przejęcie wraku dawało porażkę.** Silnik odpala tag przejęcia **zanim** zmieni właściciela, więc `14 Change House` do domu „ARKA” zostało nadpisane przez przejęcie, dom „ARKA” był pusty, a „wszystkie budynki zniszczone” dawało przegraną. Nowy mechanizm nie zależy od kolejności. Wrak to prawdziwy typ `RAPDOX` (Chronosfera; w mapie 20 000 HP, `Capturable=true`, `SuperWeapon=none`, `NukeSilo=no`, bez prądu), bo `32 Building exists` bierze **indeks** typu, a pewne są tylko indeksy z Rules (82, liczony przez skrypt z listy i sprawdzany na komentarzach `#n` DTA; typy dopisane przez mapę przesuwają typy tworzone w locie: 514 w logu zamiast 507). Powtarzalny tag wraku (`48`) uzbraja dwóch sędziów: 1) 3 s po zdarzeniu wrak nie jest u gracza (lokalna 8 pusta) → porażka; 2) zdarzenie po przejęciu (lokalna 9, ustawiana 10 s po przejęciu) → porażka. „Wrak przejęty” = `Building exists` RAPDOX u gracza → lokalna 8, sekret. Dom „ARKA” (`GDI`) usunięty. **(niezweryfikowane w grze)**
- **Drużyny naziemne nie używają `1,N`** (atak waypointu). W misjach DTA robią tak tylko samoloty, a w teście ARKA 0 każda drużyna naziemna stawała na tej linii na stałe (znalazła to sesja ARKA 0). Teraz `16,N` (patrol = atak w ruchu) i `11,14` (Hunt); `1,10` został tylko Mutaliskowi. Kontrola FAIL „ground team uses script action 1” jak w ARKA 0.
**Test 4 (2026-10-27), poprawka:**
- **Wejście inżyniera do wraku nadal dawało porażkę** (sędziowie z testu 3). Log nie mówi, który trigger zadziałał, a analiza `game.exe` + `Vinifera.pdb` nie wskazała jednoznacznej przyczyny (szczegóły: [[engine/triggers-and-dialogue]], „Przejęcie budynku a triggery”). Zamiast zgadywać dalej: **wrak ma `Immune=yes`** (klucz używany w DTA, np. `[HORV]`, `[MCRATER]`), więc nie da się go zniszczyć i przestał być warunkiem porażki. Sędziowie (`arkaJudge1/2`, `arkaArm2`) są usunięci. Jednorazowy tag wraku (`48`) albo `32 Building exists` RAPDOX u gracza tylko uruchamia sekret. Cel w tekstach: „Einstein musi przetrwać”. **(niezweryfikowane w grze)**
- Do sprawdzenia: czy Zergi nie tracą czasu na bicie niezniszczalnego wraku (jeśli tak, można dodać `LegalTarget=no`, o ile inżynier nadal wejdzie).
**Test 5 (2026-10-27), poprawki:**
- **Marines i Rocket Soldierzy w Guard nie celowali sami w Mutaliska** (na rozkaz trafiali, czyli przeciwlotnictwo z testu 2 działa). Przyczyna w `game.exe`, nie w misji: skan zagrożeń w powietrzu bierze tylko samoloty i jumpjety, a Mutalisk to latający pojazd Fly. Łatka `tools/patch-flyertarget.ps1` (w `patch-game.ps1`) działa we wszystkich trybach. Szczegóły: [[engine/fly-locomotor]]. **Potwierdzone w grze (test 6).**
- **Raynor:** HP Vulture'a +40% (2240), wcześniej +20%.
- **AI osady nadal nie budowało jednostek.** Prawdziwa przyczyna: pole „strona” AI triggerów było 1, a gra przyjmuje tylko 0 albo `ActsLike + 1` domu (dla `GDI1` = 7). Każdy trigger był po cichu odrzucany. Teraz strona jest liczona z `ActsLike`, a kontrola zgłasza FAIL przy złej wartości ([[engine/triggers-and-dialogue]]). Poprawka `FACTORY` → `SCFACT` z testu 2 zostaje (nie szkodzi). Drużyny ruszają po `AI triggers begin`, czyli 20 s po ocaleniu osady albo w 900 s. **Potwierdzone w grze (test 6): fabryka produkuje, drużyny idą na gniazdo.**

**Creep Zergów od startu (2026-10-28, prośba użytkownika „dodaj creep klasycznie do budynków zergów”):** wcześniej misja nie miała żadnego creepu. Kampania nie ładuje bloku creepu z `Terran Faction.ini`, więc `build-arka01-mission.ps1` robi to samo co ARKA 4 ([[missions/arka-04-zielony-krysztal]], [[mods/zerg-creep]]):
- mapa dostaje `[Basic] VeinGrowthEnabled=yes`, `[General] VeinholeGrowthRate=60`, `VeinholeShrinkRate=8`, `Insignificant=yes` dla `VEINS`/`VEINHOLEDUMMY`, 4 siewniki w `[Animations]` (`ARKA1ZC01–04`) i `ImmuneToVeins=yes` dla 886 typów;
- pod Hatchery (komórka fundamentu (1,1)) i koloniami ((0,0)) leży Veinhole Monster (nakładka 167 + 8× 178): 6 dziur pod 7 budynkami (Pool ma creep z koła Hatchery);
- dojrzałe żyły (126, dane 48) leżą w kole o promieniu 5 wokół dziur i pod każdym budynkiem `SCZ*` z marginesem 1 pola, razem 405 pól;
- żyły niepołączone z dziurą (4-sąsiedztwo) gra usuwa przy wczytaniu, więc skrypt spina luźne łaty z najbliższym creepem drogą BFS po wolnym terenie. Łata bez drogi (1 pole za klifem przy Sunkenie) jest usuwana.

**(niezweryfikowane w grze)**

Wraki koszar i elektrowni (neutralne, 30–40% HP) przejmuje inżynier (próg `EngineerCaptureLevel` w DTA jest zakomentowany, czyli 1.0 = przejęcie od razu). Inżynierów jest 4: w oddziale startowym, u rozbitków 1 i 3, w załodze MCV.

## Do sprawdzenia w grze

- Czy klient pokazuje misję z `BattleE.ini` (to samo pytanie co przy ARKA 0).
- Czy skopiowane typy SC działają w misji tak jak w skirmishu (Zerglingi, Hydraliski, Mutaliski z lokomotorem Fly, Overlordy, Hatchery z `Naval=yes` postawiona na lądzie z mapy).
- ~~Przeciwlotnictwo~~: potwierdzone w teście 6, także samodzielne celowanie w Guard (łatka `patch-flyertarget.ps1`).
- Wrak ARKI: czy inżynier wchodzi (przejęcie neutralnego), czy po przejęciu wrak przechodzi do `GDI` i pokazuje się sekret, czy zniszczenie wraku (przed i po przejęciu) daje porażkę. Fale nadal atakują wrak (`1,10`).
- Paleta grafik SC w teatrze pustynnym (na renderze CNCMaps wyglądają poprawnie).
- Tempo fal i siła oblężenia osady (osada może się obronić sama, wtedy Raynor dołącza bez pomocy gracza).
- AI osady: produkcja w Factory i wyjście drużyn na gniazdo **potwierdzone w teście 6**; nadal do sprawdzenia: czy SCV kopią do Refinery, czy osada odbudowuje zniszczone budynki. Globalne AI triggery strony GDI z `ai.ini` mogą też próbować budować jednostki GDI, których `GDI1` nie umie zbudować; misje DTA z domem `GDI1` (cr05) działają tak samo.
- Czy po przeniesieniu Raynor zachowuje tag (wtedy jego śmierć nadal daje porażkę; jeśli nie, po prostu nie da, ale fałszywej porażki już nie będzie).
- Czy `Entered by` na strefach komórek odpala na każdą jednostkę gracza (także Raynora po zmianie domu).
- Creep gniazda: czy żyły leżą od startu pod budynkami Zergów i rosną z dziur, czy nie ranią jednostek gracza i czy po zniszczeniu gniazda schodzą (dziury z mapy nie mają znacznika „ginie z budynkiem”, zostają).

