# Mod: budynki Terran ze StarCrafta

14 budynków Terran wyciągniętych z StarCraft: Remastered i przekonwertowanych na SHP TS. Włączane tym samym checkboxem **STARCRAFT** co Marine. Stan: zainstalowany, **(niezweryfikowane w grze)**.

Źródła: `C:\Program Files (x86)\StarCraft` (CASC, build 1.23.10: `unit/terran/*.grp`, `TileSet/jungle.wpe`, `game/tunit.pcx`),
`MIX/Cache.mix` (wzorce DTA: `WEAP`, `RAPOWR`, `BIB43`, `GUN_A`, `SAM_A`), `INI/Rules.ini` (`[RAPOWR]`, `[PYLE]`, `[RABARR]`, `[WEAP]`, `[AFLD]`,
`[TDPROC]`, `[GFACT]`, `[SAM]`, `[RAPBOX]`, `[HQ]`, `[RAATEK]`, `[RAMSLO]`, `[General]` Prerequisite*), `INI/Art.ini`.

## Pliki

| Plik | Co | Kto |
|---|---|---|
| `MIX/ECACHE98.MIX` | 43 SHP: `<ID>.SHP`, `<ID>MK.SHP` (buildup), `<ID>IC.SHP` (cameo), `SCMTUR_A.SHP` (głowica wieżyczki) | ta sesja |
| `INI/Game Options/StarCraft.ini` | blok „StarCraft Terran buildings” na końcu + `SC02=SCMTUR_A` w `[Animations]` | plik współdzielony z [[mods/starcraft-marine]] |
| `INI/Art.ini` | blok „StarCraft Terran buildings” na końcu (kopia oryginału: `Art.ini.bak`) | współdzielony |
| `Resources/SkirmishLobby.ini` | dopisane zdanie w `ToolTip` checkboxa `chkStarCraft` | współdzielony |
| `INI/Rules.ini` | jedna linia `SCMTUR_A=SCMTUR_A` w `[Animations]` (linia 2351) | współdzielony |
| `Modding/tools/ScBuildings.cs`, `build-scterran.ps1` | konwerter i skrypt budujący | ta sesja |
| `MIX/ECACHE96.MIX`, `Modding/tools/build-scuberdepot.ps1` | Uber Supply Depot: `SCUDEPO.SHP`, `SCUDEPMK.SHP`, `SCUDEPIC.SHP` (pozłacany `SCDEPO`, cameo z „x4”), podglądy w `%TEMP%\scuberdepot` | sesja frakcji |
| `StarCraft.ini` / `Art.ini` | `SCU01=SCUDEPO` w `[BuildingTypes]` + blok „Uber Supply Depot” na końcu obu plików | sesja frakcji |
| `MIX/ECACHE89.MIX`, `Modding/tools/build-scliftoff.ps1`, `StarCraft.ini` / `Art.ini` | latające budynki: `<ID>F.SHP`, `SCL01–SCL11` w `[VehicleTypes]`, `UndeploysInto=` w 11 budynkach, blok „Lifted Terran buildings” na końcu obu plików | sesja frakcji |

Przebudowa: `powershell -File Modding/tools/build-scterran.ps1` (podglądy PNG w `%TEMP%\scterran-preview`).
Skrypt nie dotyka `ECACHE77.MIX` z Marine'em (dawniej `ECACHE99`), bo `build-scmarine.ps1` zapisuje ten plik od zera.

## Budynki i drzewko

```
SCCC Command Center (construction yard) ─┬─ SCDEPO Supply Depot (+100 power)
                                          ├─ SCREFI Refinery (+TDHARV)
                                          ├─ SCEBAY Engineering Bay ── SCMTUR Missile Turret (AA)
                                          └─ SCBARR Barracks* ─┬─ SCBUNK Bunker
                                                               ├─ SCACAD Academy ── SCCOMS Comsat Station (radar)
                                                               └─ SCFACT Factory* ─┬─ SCARMO Armory
                                                                                    └─ SCSTAR Starport ── SCSCIF Science Facility* ── SCNUKE Nuclear Silo
```
`*` Barracks i Factory wymagają też Supply Depot. Barracks, Factory, Comsat i Science Facility są dopisane do grup
`BARRACKS`, `FACTORY`, `RADAR`, `TECH` (nadpisane `[General] Prerequisite*`). Dzięki temu Marine (`Prerequisite=FACTORY`)
i Upgraded Marine (`FACTORY,TECH`) da się zbudować w czysto terrańskiej bazie. `POWER` jest pełna (122 znaki), więc Supply Depot nie jest w grupie.

| ID | GRP | Foundation | Funkcja | Koszt | HP |
|---|---|---|---|---|---|
| SCCC | control | 4x3 | `ConstructionYard=yes`, `Factory=BuildingType`, `Storage=40` + `PipScale` (mały silos). **Rafineria w CC: dodana i wycofana 2026-10-25.** Test użytkownika: zbieracze stawały na CC i obok, blokując się, a przy Refinery wszystko działało. Przyczyna w kodzie Vinifery: budynek ma jeden kanał radiowy, a construction yard przy każdym stawianym budynku (`RADIO_BUILDING`/`RADIO_COMPLETE`) przełącza kontakt na budowę i zmienia misję, więc zadokowany zbieracz zostaje bez kontaktu. ConYard nie może być rafinerią. (2026-10-26 na chwilę znowu dok z łatką `Vinifera.dll`, na prośbę użytkownika wycofane. Refinery daje teraz 2 SCV, zob. [[mods/sc-workers]].) | 2000 | 12000 |
| SCDEPO | depot | 3x2 | `Power=100`, `Storage=100` + `PipScale=Tiberium` (działa też jako silos; zmiana sesji frakcji 2026-10-25 na prośbę użytkownika, kopia `StarCraft.ini.bak`) | 300 | 4000 |
| SCREFI | refinery | 4x3 | `Refinery=yes`, `FreeUnit=TDHARV`, dopisana do `Dock=` 5 harvesterów | 900 (rebalans 2026-10-26, było 1500) | 6000 |
| SCBARR | tbarrack | 4x3 | `Factory=InfantryType`, `GDIBarracks=yes` | 400 | 8000 |
| SCEBAY | weaponpl | 4x3 | tech | 600 | 6800 |
| SCMTUR | missile (+missilet) | 2x2 | `Primary=RedEYE2`, `Turret=yes`, `Sensors=yes` | 500 | 4000 |
| SCACAD | academy | 3x2 | tech | 800 | 4800 |
| SCBUNK | pillbox | 3x2 | `SCBunkerGun` (2×15, ROF 10, zasięg 6, dźwięk `SCMAFIRE` z ECACHE77) | 600 | 6000 |
| SCFACT | factory | 4x3 | `Factory=UnitType`, `WeaponsFactory=yes` bez drzwi (jak `AFLD`) | 1200 (rebalans 2026-10-26, było 2000) | 10000 |
| SCARMO | chemlab | 3x2 | tech | 1000 | 6000 |
| SCSTAR | starport | 4x3 | od 2026-10-25 fabryka testowych okrętów Fly (`Factory=UnitType`, `WeaponsFactory`, `Naval=yes`, `ExclusiveFactory=yes`; zob. [[mods/starcraft-terran-units]]) | 1500 | 10400 |
| SCSCIF | research | 4x3 | tech, grupa `TECH` | 1500 | 6800 |
| SCCOMS | comsat | 2x2 | `Radar=yes` | 1000 | 4000 |
| SCNUKE | nukesilo | 2x2 | `SuperWeapon=SCNukeSpecial` (Nuclear Strike, `Action=NuclearStrike2`) | 2500 | 4800 |
| SCUDEPO | depot (pozłacany) | 3x2 | **Uber Supply Depot**: `Power=400`, `Storage=400` (4× depot), `Prerequisite=SCDEPO`; dodany 2026-10-25 na prośbę użytkownika | 900 (3×) | 6000 (1,5×) |

Wszystkie: `Owner=GDI1` (tylko frakcja Terran), `AIBuildThis=no`, `Adjacent=2`.

**Rebalans 2026-10-26 (prośba użytkownika):** Factory 2000 → 1200 (−40%), Refinery 1500 → 900 (−40%),
przybudówka Machine Shop (`SCMSHP`, odblokowuje Siege Tanka) 500 → 1000 (×2). Latające wersje `SCFACTF`/`SCREFIF`
dostały te same ceny co budynki. Każda zmieniona linia `Cost=` w `StarCraft.ini` ma komentarz ze starą wartością. **(niezweryfikowane w grze)**

**Tylko frakcje SC (2026-10-25, zgłoszenie użytkownika: „klasyczne frakcje budują jednostki starcrafta”).** Wcześniej wszystkie 89 typów SC
w `StarCraft.ini` miały `Owner=GDI,Nod,Allies,Soviet,GDI1`. Opcja STARCRAFT powstała, zanim były nowe frakcje, więc GDI, Nod, Alianci i Sowieci
szkolili jednostki SC, a ich ConYard stawiał nawet budynki Terran (`Who_Can_Build_Me` przepuszcza typy, których `Owner` obejmuje `ActLike` ConYardu).
Teraz typy Terran, budynki i badania mają `Owner=GDI1`, a piechota Zergów `GDI1,Nod1`. Poprawione też w `Rules.ini [SCNUKE]` i w generatorach
(`build-scresearch.ps1`, `build-sczerg.ps1`, regex w `build-sczergbase.ps1`), a tooltip `chkStarCraft` w `SkirmishLobby.ini` opisuje nowy stan.
**Zasada:** nowe typy SC dostają `Owner=` tylko domów frakcji SC (`GDI1` Terran, `Nod1` Zerg). Kopia sprzed zmiany jest w scratchpadzie sesji mapowej (`pre-owner`).

**Start frakcji Terran:** `SCMCVT` = niebudowalna kopia `SCMCV` z `Owner=GDI1`, pierwsza w `BaseUnit` pliku frakcji
(szczegóły i kolejność doklejania: [[mods/terran-faction]]).
**Test 2026-10-24 (Fighting Spirit, Terran):** czołg startuje (`Base unit SCMCVT placed`) i się rozkłada, ale Command Center
nie dawał nic budować (gracz sprzedał go i przegrał). Przyczyna: `SCCC` nie był w `[AI] BuildConst`. Poprawione w `StarCraft.ini`:
`BuildConst=GFACT,NFACT,AFACT,SFACT,SCCC` **(niezweryfikowane w grze)**. Zob. [[engine/adding-new-types]].

### Terran Construction Tank (`SCMCV`), dodany 2026-10-24

MCV Terran: kopia `[GMCV]` z `DeploysInto=SCCC`, a `SCCC` ma `UndeploysInto=SCMCV` (jak `GFACT`↔`GMCV`). `Prerequisite=SCFACT`,
`TechLevel=2`, koszt 3000, głosy MCV GDI (`V2*`), zarejestrowany jako `SCT01=SCMCV` w `[VehicleTypes]` opcji gry.
Grafika: Siege Tank SC w trybie czołgu. Kadłub `tank.grp` (17 kierunków × 3 fazy gąsienic), wieża `tankt.grp` wtopiona w kadłub
(zawsze do przodu), pozycja wieży z **`tank.lol`** (format LO: `int32 klatki, int32 nakładki, int32 offset na klatkę` → pary `sbyte x,y`,
indeks = klatka kadłuba, przy lustrze x ze znakiem minus), cień `ttashad.grp`. SHP 128×128: 0–31 postój, 32–127 jazda (`WalkFrames=3`),
128–255 cienie. Kod: `ScVehicle` w `tools/ScBuildings.cs`. **(niezweryfikowane w grze)**. Dla frakcji Terran: dopisać `SCMCV` do
`[General] BaseUnit=` w pliku frakcji, żeby gracz startował tym czołgiem (BaseUnit bierze pierwszy typ, którego `Owner=` pasuje do domu).

## Dźwięki ataku (2026-10-25, sesja frakcji na prośbę użytkownika)

- **Missile Turret** strzelała bronią DTA `RedEYE2` (`Report=ROCKET2`, dźwięk z gry). Teraz `Primary=SCLongbolt`: kopia `RedEYE2`
  (te same obrażenia, zasięg i pocisk `Patriot`) z `Report=SCHKMISL` = `Bullet\HKMISSLE` (dźwięk pocisku Longbolt w SC, odczytany z iscript).
  `[SCLongbolt]` stoi w bloku „StarCraft weapon sounds” na końcu `StarCraft.ini`, a AUD w `MIX/ECACHE88.MIX` (`tools/build-scsfx.ps1`,
  `Sound.ini` `TFS01=SCHKMISL`).
- **Goliath** (blok jednostek): `SCHellfire Report=SCGOFIR2` (`tgofi200`) → `SCHKMISL`. Działko `SCGOFIRE` = `tgofir00` było poprawne.
- Obrót głowicy: `TurretAnim=SCMTUR_A` (32 kierunki) obraca się do celu. Stałe kręcenie w bezczynności jak w SC jest niedostępne:
  `TurretSpins` Vinifery działa tylko dla pojazdów (`MHQ`) i wieżyczka z bronią przestałaby celować.

## Latające budynki (lift-off jak w SC), 2026-10-25, sesja frakcji na prośbę użytkownika

**6 budynków lata, jak w SC:** `SCCC`, `SCBARR`, `SCEBAY`, `SCFACT`, `SCSTAR`, `SCSCIF`. Pierwotnie latało 11. 2026-10-25 użytkownik
poprosił (sesja mapowa wykonała): Bunker, Academy i Missile Turret mają stać, więc razem z Refinery i Armory (w SC też nie latają)
mają zakomentowane `;UndeploysInto=<ID>F` z dopiskiem. Ich pojazdy `<ID>F` (`SCL`…) i grafika w ECACHE89 zostały, ale są
nieosiągalne (`TechLevel=-1`, budynek się w nie nie składa). Przywrócenie = usunąć średnik. Na ziemi zostają też przybudówki
(`SCMSHP`, `SCCTWR`, `SCPHYS`, `SCCOVO`), Supply Depot i Uber Supply Depot oraz Comsat i Nuclear Silo (w SC to przybudówki CC).
Przy okazji te 5 budynków nie łapie się już w zaznaczenie ramką (skutek uboczny opisany niżej).
- **Mechanizm:** budynek ma `UndeploysInto=<ID>F`, a `<ID>F` to wolny pojazd jumpjet (`Speed=4`, `JumpjetSpeed=6`,
  `JumpjetCruiseHeight=300`, `TechLevel=-1`) z `DeploysInto=<ID>`. Tak samo działa `BFRT`↔`DBFRT` w DTA, a Vinifera wprost
  wspiera budynki składane inne niż ConYard. `SCCC` składał się wcześniej w Construction Tank (`SCMCV`), teraz w latający CC;
  sam czołg nadal się buduje i rozkłada w CC. Wartości (HP, pancerz, właściciel, koszt, wybuchy) skopiowane z budynku,
  procent HP przechodzi przy zamianie.
- **Sterowanie:** zaznacz budynek → kursor „deploy” na nim samym (jak przy składaniu ConYardu) = start. Latający budynek po
  zatrzymaniu siada na ziemi (zachowanie lokomotora jumpjet). Wtedy deploy = lądowanie w budynek, a teren pod fundamentem musi być wolny.
  Wymaga opcji lobby „Re-Deployable MCV” (włączona domyślnie).
- **Grafika:** `MIX/ECACHE89.MIX`, `<ID>F.SHP` z `tools/build-scliftoff.ps1`: klatka 0 budynku (z ECACHE98) przesunięta tak,
  że środek fundamentu `(12(W−H), 6(W+H))` jest w środku kanwasu. 8 identycznych kierunków + 8 cieni (cień budynku), a
  Missile Turret ma doklejoną głowicę `SCMTUR_A`. Nogi nie są schowane (SC ma klatki startu w GRP, np. `control` 2–5,
  `tbarrack` 2–6, do ewentualnego użycia później).
- **Skutek uboczny (kod Vinifery `Vinifera_Bandbox_Select`):** budynki z `UndeploysInto` (poza ConYardem) **łapią się w zaznaczenie
  ramką**. Zaznaczenie wojska ramką przez bazę złapie też te budynki (Command Center nie, bo to ConYard).
- **(niezweryfikowane w grze):** start, lot, lądowanie jumpjet, **deploy z powrotem** (czy jednostka jumpjet może się rozłożyć w budynek),
  zachowanie kolejki produkcji fabryki przy starcie, rafineria z dokowanym zbieraczem. Plan B, jeśli lądowanie w budynek nie działa:
  lokomotor poduszkowy zamiast jumpjet (zmiana samych kluczy INI, ta sama grafika).

## Konwersja (zob. [[engine/shp-graphics]], [[engine/starcraft-assets]])

- GRP budynku SC: klatka 0 = gotowy, 1 = w budowie (Missile Turret: 2 = sama podstawa). Nakładka `*t.grp` klatka 0
  (światła, antena Comsatu) jest wtapiana w klatkę budynku. Cień: `t??shad.grp`, ta sama numeracja klatek.
- SHP budynku: `normal, damaged, cień, cień`. Wersja uszkodzona = przyciemnione plamy (`ScBuildings.DamageMap`), bo SC nie ma klatki zniszczeń.
- Buildup (20 klatek + 20 cieni): rusztowanie `tbldlrg/tbldmed/tbldsml` (3 etapy) → klatka „w budowie” → gotowy.
- Głowica wieżyczki: `missilet.grp` klatki 0–16 (17 kierunków, zachód lustrzany) → 32 kierunki + 32 puste cienie, ten sam kanwas co podstawa.
- Cameo 64×48: zmniejszony sprite na granatowym gradiencie, paleta `CAMEO.PAL`. Kolor gracza w cameo = czerwony (rampa gracza 1 z `tunit.pcx`).
- Kolory: `ScBuild.BuildMap` (paleta `jungle.wpe` → `UNITTEM.PAL`, kolor gracza SC 8–15 → remap TS 16–31).

## Do sprawdzenia w grze

1. Czy silnik ładuje `ECACHE98.MIX` (log `Debug/`, lista MIX-ów na starcie).
2. Pozycja sprite'ów względem fundamentu, czy cień nie „pływa”, czy z-buffer nie ucina wysokich części (CC, Starport).
3. Czy Command Center działa jako drugi construction yard i czy budynki SC pojawiają się w sidebarze.
4. Dokowanie harvestera do `SCREFI`. **Test użytkownika 2026-10-24: harvester nie mógł się rozładować.** W logu
   `DEBUG_24-10-2026_17-40-02.LOG` było 148× `Regular findpath failure` z jednej komórki. Przyczyna: brak `Bib=yes`,
   który mają wszystkie rafinerie DTA (`PROC`, `TDPROC`, `RAPROC`). Poprawione, **(niezweryfikowane w grze)**.
5. Wyjazd pojazdów z `SCFACT` (`WeaponsFactory=yes` bez `DoorAnim`) i wyjście piechoty z `SCBARR`. `SCFACT` dostał
   zapobiegawczo `Bib=yes`, jak `WEAP`/`AFLD`/`RAWEAP`.
5a. **Rafineria: test użytkownika 2026-10-24 po poprawce `Bib=yes` = działa.**
5b. **Nuclear Silo: test 2026-10-24 = pocisk nie startował.** Brakowało sekwencji `SpecialAnim` (zob. [[engine/superweapons]]).
   Dodane: `SCNUKE_A.SHP` (32 klatki: 0–7 normalne zamknięty/otwarty/zamknięty, 8–15 uszkodzone, potem cienie;
   „otwarty” = klatka 1 `nukesilo.grp` bez pokryw), sekcje `SCNUKE_A1/A2/A3` + `…D` w Art.ini (czasy jak `RAMSLO_A*`,
   A1 odpala `NUKEUP1RA`), klucze `SpecialAnim*` i `HideDuringSpecialAnim=yes` w `[SCNUKE]`, 6 wpisów w `Rules.ini [Animations]`
   (linie 2353–2358). `MultiSpecial` ma `IsPowered=true`: przy niedoborze prądu nie ładuje się.
5c. **Nuclear Silo: test użytkownika 2026-10-25 = działa.** Ostateczna konfiguracja: własna supermoc `SCNukeSpecial` w `Rules.ini`
   (`Type=MultiMissile`, `IsPowered=false`, `RechargeTime=9.5`, `WeaponType=NukeWeaponS2`) z **unikalnym `Action=NuclearStrike2`**.
   Prawdziwa przyczyna wszystkich wcześniejszych porażek: z `Action=DropPod` (skopiowanym z `MultiSpecial`) klik odpalał
   sowiecką `MultiSpecial` (zob. [[engine/superweapons]]). Testowy silos `SCNUKER`/`SCNukeTest` usunięty po teście.
   Do diagnozy podobnych problemów: sonda pamięci `Modding/tools/nukeprobe.ps1` (tylko odczyt, uruchamiać przy włączonej grze).
6. Kierunek obrotu głowicy Missile Turret (przyjęta konwencja DTA: klatki zgodnie z ruchem wskazówek zegara od północy).
7. Czy nadpisanie `[General] Prerequisite*` z opcji gry działa (Marine z SC Factory).
8. **Prawdopodobny błąd (dopisała sesja frakcji, 2026-10-24, po teście sesji Marines):** `SCMTUR_A` jest zarejestrowany
   tylko w `[Animations]` opcji gry. Animacje dodane w ten sposób nie mają SHP, bo obrazy animacji ładują się w
   `Initializing Theater`, przed `Rule->Addition()` (zob. [[engine/shp-graphics]], [[mods/starcraft-marine]]: `SCMADTH`).
   Głowica Missile Turret będzie więc najpewniej niewidoczna. Poprawka: `SCMTUR_A=SCMTUR_A` w `Rules.ini [Animations]`
   po linii `SCMADTH=SCMADTH` (ok. linii 2350), wstawione bajtowo (Windows-1252). Dotyczy też przyszłych ActiveAnim.
   **Zrobione 2026-10-24:** linia 2351 `Rules.ini` (`Rules.ini.bak` = oryginał). Wpis `SC02` w opcji gry został, nie szkodzi.
9. **Linie innych sesji w tym bloku: przy przebudowie NIE usuwać** (przekazała sesja frakcji, 2026-10-25):
   - `[SCACAD] Upgrades=1` (sesja Marines): miejsce na ulepszenie-badanie `SCU238` (U-238 Shells, `PowersUpBuilding=SCACAD`,
     `[BuildingTypes] SCR01=SCU238`), wymagane przez Upgraded Marine. Vinifera liczy ulepszenia budynku jako spełnione wymagania
     (rodzic musi mieć prąd).
   - Sesja frakcji: `UndeploysInto=<ID>F` w 11 budynkach (5 zakomentowanych na prośbę użytkownika), `Storage/PipScale` (bez rafinerii, wycofana)
     w `[SCCC]`, `Storage=100` + `PipScale` w `[SCDEPO]`, `Primary=SCLongbolt` w `[SCMTUR]`. (`,SCCC` w `Dock=` zbieraczy usunięte razem z rafinerią w CC.)
   - Sesja badań (Marines, `tools/build-scresearch.ps1`, [[mods/starcraft-research]]): linie `Upgrades=N` (z komentarzem „research session”) w
     `SCEBAY`, `SCACAD`, `SCARMO`, `SCMSHP`, `SCCTWR`, `SCCOVO`, `SCPHYS`, `SCSCIF`, a także wpisy `SCR01–SCR11` i `SCX90` w `[BuildingTypes]` oraz
     `SCX01–SCX11` w `[VehicleTypes]`. **Prefiksów `SCR`/`SCX` nie używać.** Generator badań kopiuje sekcje bazowych jednostek
     (ulepszone wersje `*2`): po zmianie jednostki bazowej trzeba go uruchomić ponownie.

## Pomysły na dalej

ActiveAnim (obracająca się antena `comsatt` 10 klatek, `depott`), dźwięki budynków SC, Starport jako `Factory=AircraftType`
po dodaniu jednostek lotniczych, addony (Machine Shop, Control Tower, Physics Lab, Covert Ops: `machines`, `drydocks`, `physics`, `genelab`),
SCV jako harvester zamiast `TDHARV`, `Owner=` → dom Terran, gdy powstanie nowa strona (zob. [[engine/sides-and-houses]]).
