# Mod: frakcja Protoss (pełna), zasięg budowania od Pylonów

Siódma grywalna frakcja w skirmishu: „Protoss” (przejęty dom pomocniczy GDI `GDI2`, indeks 8, strona 8). Ma wszystkie 16 budynków
i 16 jednostek z Brood War. Tylko Nexus i Pylony dają zasięg budowania. Stan: **pełna frakcja zainstalowana 2026-10-25**. Zasięg
budowania działa w grze (test 1). Poprawki po teście 1 i nowe typy **(niezweryfikowane w grze)**.

Źródła: `INI/Rules.ini` (komentarz `Adjacent`/`BaseNormal` w nagłówku, `[GDI2]`, `[Sides]`, `[AI] BuildConst`, `[Invisible]`, `[Invisible3]`,
`[InvisibleAA]`), `INI/Enhance.ini` (`[AIA10]`), dane SC z CASC (`arr/units.dat`, `images.dat`/`images.tbl`, `sprites.dat`, `flingy.dat`,
`weapons.dat`, `scripts/iscript.bin`, `arr/sfxdata.dat`/`.tbl`, `unit/protoss/*.grp`, `unit/thingy/psistorm.grp`, `SD/sound/protoss/...`),
kod Vinifery (`scenarioext.cpp` `Create_Units`, GitHub), wzorce: [[mods/zerg-faction]] (lotnicy Fly, `FlySec`, limit `Description`),
[[mods/terran-faction]], [[mods/starcraft-terran-buildings]] (Starport, CC jako ConYard), [[engine/fly-locomotor]].

## Jak się gra

1. Lobby skirmisha: strona **Protoss** (Deathmatch albo Custom Map). Checkbox STARCRAFT nie jest potrzebny.
2. Start: **„Probe: Nexus”** → deploy = Nexus (Construction Yard). Jednostki startowe to Probe'y.
3. Z Nexusa budujesz z paska jak zwykle, ale **każdy budynek musi stanąć blisko Nexusa albo Pylona** (do 8 komórek).
   Pylony stawiasz do 10 komórek od Nexusa albo innego Pylona, więc „łańcuch pylonów” poszerza bazę.
4. Fabryki: **Gateway** (piechota), **Robotics Facility** i **Stargate** (pojazdy pojawiają się obok, wzorzec stoczni Vinifery).

### Drzewko technologii (jak w SC, z dwoma wyjątkami)

```
Nexus ─┬─ Pylon ─┬─ Gateway ─┬─ Cybernetics Core ─┬─ Stargate ─┬─ Fleet Beacon
       │         │           │                    │            └─ (+ Templar Archives) Arbiter Tribunal
       │         │           │                    └─ Citadel of Adun ── Templar Archives
       │         │           └─ Shield Battery
       │         ├─ Forge ── Photon Cannon
       │         └─ Robotics Facility* ─┬─ Robotics Support Bay
       │                                └─ Observatory
       └─ Assimilator
```
\* Wyjątki: Robotics Facility wymaga tylko Pylona (w SC Cyber Core), bo produkuje Probe'y. ConYard nie może jednocześnie szkolić
jednostek (jeden `Factory=` na budynek). Archony są przywoływane od razu, bo silnik nie umie scalać jednostek.

| Fabryka | Jednostki (wymaganie) |
|---|---|
| Gateway | Zealot, Dragoon (Cyber Core), High Templar, Dark Templar (Templar Archives) |
| Robotics Facility | Probe, Probe: Nexus, Shuttle, Reaver (Support Bay), Observer (Observatory), Archon, Dark Archon (Templar Archives) |
| Stargate | Scout, Corsair, Carrier (Fleet Beacon), Arbiter (Arbiter Tribunal) |

## Zasięg budowania (mechanika)

TS sprawdza przy stawianiu, czy w promieniu `Adjacent=` **stawianego** budynku stoi budynek gracza z `BaseNormal=yes`
(zob. [[engine/tech-and-prerequisites]]).
- `SCPNEX`, `SCPPYL`: `BaseNormal=yes`, `Adjacent=10`.
- Pozostałe 14 budynków: `BaseNormal=no` (nie przedłużają zasięgu), `Adjacent=8`.
- Dla porównania budynki DTA mają `Adjacent` 1–4, a Terran `Adjacent=2`.

## Typy

Skala: HP budynku = (HP + tarcza z SC) × 8, HP jednostki = (HP + tarcza) × 20, koszt = (minerały + 2 × gaz) × 4, obrażenia ok. SC × 2,5,
ROF ok. cooldown SC × 1,33, zasięg ok. SC × 1,9. Tarcze zastępuje `SelfHealing=yes`. Głowice mają też `Modifier.light`. Jednostki nie mają
pancerza `light`, bo głowice Terran i Zergów go nie wymieniają (dostałyby 100% zamiast ~700%).

**Budynki** (wszystkie `Owner=GDI2`, `TechLevel=1`, `AIBuildThis=no`, `Capturable=false`):

| ID | Nazwa | Rola | Koszt | HP | Fund. |
|---|---|---|---|---|---|
| `SCPNEX` | Nexus | ConYard, radar, `Storage=40`, `Power=50`, zasięg | 1600 | 16000 | 4x3 |
| `SCPPYL` | Pylon | `Power=100`, silos `Storage=100`, zasięg | 400 | 4800 | 2x2 |
| `SCPASM` | Assimilator | rafineria, `Bib`, `FreeUnit=SCPPROBE`, `Storage=200` | 400 | 7200 | 4x3 |
| `SCPGAT` | Gateway | `Factory=InfantryType` | 600 | 8000 | 4x3 |
| `SCPFOR` | Forge | wymaganie działa | 600 | 8800 | 3x2 |
| `SCPCAN` | Photon Cannon | `SCPPhoton` ziemia+powietrze, `Sensors`, `Powered` | 600 | 3000 heavy | 2x2 |
| `SCPBAT` | Shield Battery | leczenie obszarowe: `ActiveAnim=SCPBATGL` (łańcuch skrzynki DTA) | 400 | 3200 | 2x2 |
| `SCPCYB` | Cybernetics Core | wymaganie | 800 | 8800 | 3x2 |
| `SCPROB` | Robotics Facility | stocznia (`Naval`, `ExclusiveFactory`) | 800 | 8000 | 3x2 |
| `SCPSTG` | Stargate | stocznia (`Naval`, `ExclusiveFactory`) | 1800 | 9600 | 4x3 |
| `SCPCIT` | Citadel of Adun | wymaganie Archives | 1400 | 7200 | 3x2 |
| `SCPRSB` | Robotics Support Bay | wymaganie Reavera | 1400 | 7200 | 3x2 |
| `SCPOBS` | Observatory | wymaganie Observera | 1000 | 4000 | 3x2 |
| `SCPFLB` | Fleet Beacon | wymaganie Carriera | 2800 | 8000 | 3x2 |
| `SCPARC` | Templar Archives | wymaganie templariuszy i archonów | 1600 | 8000 | 3x2 |
| `SCPTRB` | Arbiter Tribunal | wymaganie Arbitra | 2000 | 8000 | 3x2 |

**Jednostki:**

| ID | Nazwa | Typ | Broń | Koszt | HP | Uwagi |
|---|---|---|---|---|---|---|
| `SCPPROBE` | Probe | pojazd | — | 300 | 800 medium | zbieracz, start, `BuiltAt=SCPROB` |
| `SCPDNEX` | Probe: Nexus | pojazd | — | 1800 | 800 | `DeploysInto=SCPNEX`, `BaseUnit` |
| `SCPZEAL` | Zealot | piechota | `SCPPsiBlades` 40 wręcz | 400 | 3200 | |
| `SCPDRAG` | Dragoon | piechota | `SCPPhase` 50 explosive, z. 7,5, też powietrze | 900 | 3600 medium | |
| `SCPHTMP` | High Templar | piechota | `SCPStorm` 60 × 800%, `CellSpread=2`, z. 9, anim. burzy | 1400 | 2400 | `AffectsAllies=no` |
| `SCPDTMP` | Dark Templar | piechota | `SCPWarpBlades` 100 wręcz | 1300 | 2400 | `Cloakable=yes` |
| `SCPARCH` | Archon | pojazd (Robotics) | `SCPShockwave` 75, splash 1, z. 3, ziemia+powietrze | 2800 | 7200 medium | |
| `SCPDARC` | Dark Archon | pojazd (Robotics) | `SCPMaelstrom` 60, `CellSpread=1.5`, **`EMEffect=yes`**, z. 8 | 2600 | 4500 medium | anim. burzy |
| `SCPREAV` | Reaver | pojazd naziemny | `SCPScarab` 250, splash 1,5, **z. 20,4 (jak Siege Mode)**, tylko ziemia | 1600 | 3600 heavy | Speed 3 |
| `SCPSHUT` | Shuttle | Fly | — | 800 | 2800 medium | `Passengers=8`, od 2026-10-27 `IsVehicleTransport=yes` (wsiadają też pojazdy, do wiszącego Shuttle'a; [[engine/transports]]) |
| `SCPOBSV` | Observer | Fly | — | 700 | 1200 medium | `Cloakable`, `Sensors` (8–9 komórek) |
| `SCPSCOU` | Scout | Fly | `SCPScoutGround` 20 (ziemia) + `SCPScoutAir` 70 (`InvisibleAA`) | 2100 | 5000 medium | |
| `SCPCORS` | Corsair | Fly | `SCPNeutron` 13, ROF 11, splash 0,5, tylko powietrze | 1400 | 3600 medium | Speed 18 |
| `SCPCARR` | Carrier | poduszkowiec (sprite +60 px) | `SCPInterceptLauncher` (`Spawner=yes`, z. 12): 8 × `SCPINTC` | 3400 | 9000 heavy | Speed 7 |
| `SCPINTC` | Interceptor | samolot (`Spawned=yes`) | `SCPInterBeam` 20, ROF 30, z. 4, ziemia+powietrze | — | 800 medium | voxel `ORCAHORNS`, `Ammo=4` |
| `SCPARBI` | Arbiter | Fly | `SCPArbiterGun` 25 explosive, z. 7, ziemia+powietrze | 3200 | 7000 heavy | `Sensors`, `DeploysInto=SCPARBD` |
| `SCPARBD` | Arbiter (pole maskujące) | budynek 1x1 | `SCPArbiterGun` | — | 7000 heavy | `CloakGenerator=yes`, promień 6, `UndeploysInto=SCPARBI` |

## Pliki

| Plik | Co | Kopia |
|---|---|---|
| `MIX/ECACHE85.MIX` | 213 plików (~10,6 MB): 16 budynków (`<ID>`, `<ID>MK`, `<ID>IC`), 6 piechoty + cameo, 9 pojazdów + cameo, `SCPSTORM`, 134 AUD | — |
| `Modding/tools/build-scprotoss.ps1`, `ScProtoss.cs` | budowa (`-Install` = też INI, lobby i pliki strony). `ScProtoss.Warp` = etap przywołania, `Stack` = Archon z trzech warstw, `OnCanvas` = klatki z innego GRP | — |
| `INI/Map Code/Terran Faction.ini` | `ProtossSide=GDI2` w `[Sides]` (po `ZergSide`), `SCPDNEX` w `BaseUnit`, `SCPPROBE` w `HarvesterUnit`, `PRV01–09`, `GDI2` zdjęty z `[TDPROC]`/`[TDPROC_AI]`/`[DEPCARR]`, blok „Protoss faction” na końcu (strona, dom, `[AI] BuildConst`, `[ASTRP]`/`[AIA10]` bez `GDI2`, `PRB01–16`, `PRI01–06`, `PRA01`, typy, bronie) | `.bak` (sprzed Zergów) |
| `INI/Art.ini` | blok „Protoss faction” (16 budynków, 2 Probe'y, 6 piechoty z sekwencjami, 7 pojazdów, `SCPSTORM`) | `.bak` |
| `INI/Sound.ini` | `[SoundList] 1400–1533` + blok (priorytety śmierci, burzy) | `.bak` |
| `INI/Game Options/StarCraft.ini` | `[AI] BuildConst=…,SCCC,SCPNEX` (plik doklejany po pliku frakcji powtarza tę listę) | `.bak` |
| `Resources/GameOptions.ini` | `Sides=…,Terran,Zerg,Protoss` | `.bak` |
| `INI/MPMaps.ini` | 10× `DisallowedPlayerSides=4,5,6,7` → `4,5,6,7,8` | `.bak` |
| `MIX/SideC09.mix`, `sidenc09.mix`, `Speech09.mix`, `Resources/protossicon.png`, `l600s8{1,2}.pcx`, `l480s8{1,2}.pcx` | kopie plików **GDI** (sidebar, EVA, ikona, ekrany ładowania) | — |
| `Modding/tools/build-sczergbase.ps1` | przy ponownym `-Install` zachowuje `ProtossSide` po `ZergSide` i `SCPPROBE` w `HarvesterUnit` | — |

**Uwaga (badania Zergów, [[mods/zerg-research]]):** blok „Zerg research” na końcu pliku frakcji powtarza `[AI] BuildConst` (lista z tego bloku
+ laboratoria Zergów) i jako późniejszy wygrywa. Po zmianie `BuildConst` w bloku Protossów uruchom `build-sczergresearch.ps1`. W `StarCraft.ini`
laboratoria stoją przed `SCPNEX`, więc regex z `build-scprotoss.ps1` dalej działa.

## Grafika

- GRP z danych SC; cień = obraz zaraz po budynku w `images.dat`: Nexus `pneshad`, Pylon `ppyshad`, Assimilator `passhad`,
  Gateway `pgashad`, Forge `pfoshad` (+ nakładka `forget`), Photon `ppbshad`, Cyber Core `pgcshad` (+ `gencoret`), Robotics `proshad`,
  Archives `pacshad`, Shield Battery `pbashad`, Stargate `psgshad`, Citadel `pcishad`, Support Bay `pstshad`, Fleet Beacon `pwashad`,
  Observatory `pbeshad`, Tribunal `paushad`. Historyczne nazwy: Robotics Support Bay = `stasis.grp`, Fleet Beacon = `warp.grp`,
  Observatory = `beacon.grp`, Arbiter Tribunal = `prism.grp`, Reaver = `trilob.grp`, Observer = `witness.grp`.
- **Przywołanie (Buildup):** 12 etapów po 2 klatki: sylwetka budynku wypełniona teksturą `texture.grp` (21 klatek), rozjaśnioną na niebieską
  rampę (w palecie jednostek jest granatowa, bo SC rysuje ją własną paletą). Stały szum odsłania coraz więcej pikseli budynku, cień pojawia się od połowy.
- Klatki piechoty z iscript (`playfram = zestaw × 17 + kierunek`): Zealot stój 5, chód 5–12, atak 0–4, śmierć 221–227; Dragoon stój 0, chód 8–15,
  atak 16–23, śmierć 408–414 + `pdrdeath`; High Templar stój 6, chód 14,15,16,5, atak 0–4, śmierć 289–295; Dark Templar stój 13,
  chód 14–17,10–13, atak 0–9, śmierć pożyczona od High Templara (w SC tylko błysk), cień = własna sylwetka.
- **Archony:** w SC to trzy obrazy: niekierunkowa kula energii (`archon.grp`/`darchn.grp`, klatki 0–9), kierunkowa postać
  (`archonT.grp` 14 zestawów, `darchnT.grp` 11) i wir (`archonT2`/`darchnT2`, 15 klatek). `ScProtoss.Stack` składa je w jeden kierunkowy GRP.
  Archon: stój/chód zestawy 10–13 (ping-pong), atak 0–9 (strzał w 5). Dark Archon: stój/chód 0–9, atak 10. Bez cienia, śmierć = gasnący wir.
- Pojazdy: Reaver chodzi przez zestawy 1–8 i 0 (cień `ptrShad`). Lotnicy mają jeden zestaw ciała, Scout i Arbiter mają zestaw „strzału” 1,
  a Corsair zestawy ataku 1–4. Cień lotników = ich sylwetka (jak u Zergów).
- Dźwięki ataku z iscript: Zealot `pzeHit00`, Dark Templar `Bullet\UZeFir00`, Dragoon/Arbiter `Bullet\DragBull`, Photon Cannon `Bullet\PhoFir00`,
  burza `PTeSto00`, Archony `Bullet\PArFir00` (Dark Archon w moddzie: `feedback.wav`), Reaver `Bullet\pTrFir00`, Scout `Bullet\BlastGn2` +
  `Bullet\HKMISSLE`, Corsair `PCorlasr2`. Carrier w swoim skrypcie nie ma dźwięku (strzelają interceptory), więc dostał `Bullet\BlastCan`.

## Test użytkownika 1 (2026-10-25) i poprawki

- **Zasięg budowania od Pylonów działa** (potwierdzone w grze).
- Brak ikonek w pasku budowy i złe rozmiary budynków (mikre paski HP). Przyczyna: w `build-scprotoss.ps1` (i w skopiowanym
  `build-sczergbase.ps1`) pętla `foreach ($b in $B)`. PowerShell nie rozróżnia wielkości liter, więc zmienna pętli `$b` nadpisała
  listę `$B` ostatnim budynkiem. Blok Art.ini miał tylko Templar Archives, a reszta budynków nie miała `Cameo`, `Foundation`
  (domyślnie 1x1) ani `Buildup`. Poprawka: lista nazywa się `$Bldgs` w obu skryptach. W Art.ini dopisane brakujące sekcje Zergów
  (`SCZHAT`, `SCZEXT`, `SCZPOL`, `SCZEVO`); one też nie miały cameo ani fundamentu.
- `Height=` jak u Terran: Nexus 3, 4x3 i 3x2 = 2, 2x2 = 1.5.
- Pylon: `Storage=100` (silos, jak Supply Depot). Assimilator: `Storage` 40 → 200.
- „Nexus od razu na start”: Vinifera umie to tylko globalnie (`spawn.ini` `PrePlacedConYards=`, w `Create_Units` dla każdego domu
  stawia `DeploysInto` jego `BaseUnit`; `AutoDeployMCV` rozstawia MCV tylko przy liczbie jednostek startowych = 1). Nie ma klucza
  per dom ani per typ. Checkbox `chkAutoDeployMCV` w `SkirmishLobby.ini` jest ukryty i wyłączony. Użytkownik wybrał: zostaje Probe: Nexus.
- HP: zostają; problemem były mikre paski (fundament 1x1), nie wartości.

## Test użytkownika 3 (2026-10-25) i poprawki

- **Interceptory nie wracały do Carriera.** Kod Vinifery (`SpawnManagerClass::AI`, stan `Returning`) przyjmuje samolot z powrotem
  tylko w tej samej komórce i przy `|Z(samolot) − Z(matka)| < 20`. Luźniejszy warunek (`Z(samolot) ≤ Z(matka) + 20`) dotyczy tylko
  matek z `HoverLocomotionClass`. Carrier na lokomotorze Fly wisi na `FlightLevel=450`, a samolot ląduje przy ziemi, więc interceptory
  krążyły bez końca. W logu widać tylko tysiące linii `FLY … MoveTo/Stop` (diagnostyka `patch-flyhover.ps1`).
  **Poprawka:** Carrier jest „poduszkowcem” jak `[HVC]`/`[HVCSAM]` DTA (`Locomotor` = Drive, `SpeedType=Hover`, `MovementZone=Fly`,
  ląd i woda, na wysokości terenu). Sprite jest podniesiony o 60 px, a cień (sylwetka) zostaje na ziemi, żeby dalej wyglądał na
  lecący (`Raise=60` w generatorze). Skutek uboczny: broń tylko przeciwlotnicza (Corsair, Spore) go nie atakuje.
  Zasada dla [[engine/spawners]]: matka lotniskowca musi stać na ziemi (albo mieć Hover).
- **Zealot, Dragoon i Templarzy znowu są piechotą z Gatewaya** (użytkownik: „robotem jest tylko Reaver, archont w sumie jest tankiem,
  fabryka będzie Robotics”). **Archon i Dark Archon zostają pojazdami** i razem z Probe'ami wychodzą z Robotics Facility
  (Archony: `Prerequisite=SCPROB,SCPARC`). Gateway ma znowu `Factory=InfantryType`, a Shuttle `Passengers=8`.
  Śmierć piechoty: klatki w SHP + `VoiceDie`. Ulepszona piechota trafia do `[InfantryTypes]` (generator badań sprawdza listę `PRI`).
- **Archon:** HP 7200 → 21600 (+200%), fala 75 → 113 (+50%), wcześniej na prośbę użytkownika. Teraz rozprysk `CellSpread=2`,
  `PercentAtMax=0.8` (było 1 i 50%) i animacja trafienia z SC (`thingy\emsHit.grp`, obraz broni 70) jako `AnimList=SCPARCHH`.

- **Dragoon (i Arbiter) strzelały natychmiastowo** (`Projectile=Invisible3`, użytkownik: „hitscan”). Teraz lecą prawdziwym pociskiem
  `SCPDragBull`: grafika SC `bullet\dragbull.grp` (5 klatek animowanych przez `AnimLow=0`/`AnimHigh=4`/`AnimRate=1` w Art.ini, wzorzec
  `[PLASMORB]` DTA), `AA=yes`, `AG=yes`, `ROT=12` (naprowadzany, trafia też lotników), `Speed=40`. Trafienie: `SCPPhaseWH`
  (jak `SCPExplosiveWH`) z animacją `SCPDRHIT` z `thingy\HKexplod.grp` (iscript pocisku `dragbull`).

- **Reaver i Photon Cannon też dostały pociski** (test 4). Scarab: `SCPScarabPr` z `protoss\sapper.grp` (jednostka SC 85) jako pocisk
  obracający się z lotem: `Rotates=yes`, 32 kierunki z 17 kierunków SC (`ScProtoss.Rotating`, lustro jak wieżyczki), `ROT=10`, `High=no`,
  tylko ziemia, `Speed=25`. Photon Cannon: `SCPPhotonBall` z `bullet\epbBul.grp` (bronie SC 80/81, 11 klatek). SC rysuje ją przez
  przemapowaną paletę, więc w palecie jednostek wychodziła zielona. `ScProtoss.BlueByLuma` przemalowuje piksele według jasności
  na niebieską rampę.

- **Test 4: Carriery dalej „głupie”, Interceptory zacinały matkę.** Z kodu Vinifery: nowa fala startuje dopiero, gdy wszystkie
  Interceptory są w hangarze albo zniszczone ([[engine/spawners]]). Nasz Interceptor miał `Ammo=4` przy `ROF=30`, więc samolot TS
  krążył na wielu przelotach jako „atakujący”. Teraz ma cykl Horneta DTA: `Ammo=1`, broń `Burst=2`/`ROF=3`/`Range=3.2`/`MinimumRange=1.5`
  (30 obrażeń na strzał), ruch `Speed=14`, `ROT=5`, `GuardRange=30`. Carrier nie jest już „poduszkowcem”, tylko zwykłym pojazdem
  gąsienicowym jak `[CARRTRUK]` (sprite dalej podniesiony o 60 px). **(niezweryfikowane w grze)**

- **Test 5: Carrier nie latał, a Interceptory wisiały wokół niego.** Dwa błędy. (1) W generatorze `$true -eq 'hover'` daje w PowerShellu
  `True`, bo niepusty tekst jest prawdą. Od testu 3 **wszyscy** lotnicy (Shuttle, Observer, Scout, Corsair, Carrier, Arbiter) dostawali
  klucze „poduszkowca” zamiast lokomotora Fly i jeździli po ziemi. Poprawka: porównanie tekstowe `"$fly" -eq 'hover'`.
  (2) Interceptory latają na wysokości przelotowej 450 (`[General] FlightLevel=450`), a naziemny Carrier ma Z = 0, więc dokowanie
  Vinifery (`|dZ| < 20`) nigdy nie zachodziło. Teraz Carrier lata jak okręty Terran (lokomotor Fly, `FlightLevel=450`, łatka wiszenia),
  a Interceptor ma `Landable=no` i `FlightLevel=450`: wisi nad Carrierem na tej samej wysokości i dokuje. **(niezweryfikowane w grze)**

- **Test 6 + łatka (2026-10-26): Interceptory nie wracały, bo silnik nie pozwala samolotowi lecieć do latającej jednostki.**
  Sonda pokazała, że po ataku Interceptor ma `NavCom` = 0 i stoi w miejscu. `Landable=no` (test 5) nie było przyczyną:
  z `Landable=yes` było tak samo. Źródło: `AircraftClass::Assign_Destination` w `game.exe` odrzuca cele `In_Air()`.
  Naprawione łatką `tools/patch-spawnreturn.ps1`, wszystkie łatki naraz: `tools/patch-game.ps1`, zob. [[engine/spawners]].
  Interceptor: `Landable=yes`, `FlightLevel=450`, Carrier: Fly, `FlightLevel=450`. **(niezweryfikowane w grze)**

- **Test 7 (2026-10-26): crash gry** w `AircraftClass::Assign_Destination` przez pierwszą wersję łatki: pytała `What_Am_I` przez
  vtable także komórkę mapy (`CellClass`). Łatka cofnięta, przepisana na jaskinię w `.p_text` z RTTI przez interfejs i ponownie
  zainstalowana (`patch-game.ps1`). Szczegóły: [[engine/spawners]].
- **Test 8 (2026-10-26): Interceptory wracają i dokują**, potwierdzone sondą (297 wylotów i powrotów, brak crasha).
  **Użytkownik potwierdził w grze: „super działa”.**

- **Poświata matrycy psionicznej (2026-10-26, prośba użytkownika).** Nexus i Pylon oświetlają teren na jasnoniebiesko natywnym
  światłem budynków TS (jak latarnie DTA `[BLUELAMP]`): `LightIntensity=0.05`, `LightRedTint=0.03`, `LightGreenTint=0.18`,
  `LightBlueTint=0.45` (zmienna `$matrixLight` w generatorze). Promień `LightVisibility` (leptony, 256 na pole) sięga granicy
  zasięgu budowania liczonej od środka: Pylon 2304 (1 + 8 pól), Nexus 2560 (2 + 8 pól). Światło słabnie ku krawędzi. Brak
  `Powered=`, więc świeci też przy braku prądu. Jasność i kolor do strojenia po teście.
  **Test 9 (użytkownik):** kolor OK. Światło nie dochodziło do granicy zasięgu budowania, bo słabnie liniowo do zera, a zasięg
  jest kwadratem. Sam zasięg był też za duży. Poprawki: zasięg 7 pustych pól od Pylona i od Nexusa (użytkownik wybrał
  jedną wartość dla obu zamiast łatki Vinifery; reszta budynków `Adjacent=7`, Pylon/Nexus `Adjacent=9` do „skakania”).
  Promień światła ok. 1,3× odległości do granicy: Pylon 3072 (12 pól), Nexus 3328 (13 pól), czyli przy granicy zostaje
  ~25% jasności. Rogi kwadratu pozostają ciemniejsze. Zob. [[engine/tech-and-prerequisites]].
  **Test 10 (użytkownik, 2026-10-27):** przy tym świetle zasięg ma być o pole mniejszy, żeby zgadzał się z poświatą. Teraz
  `Adjacent=6` (Pylon i Nexus `8`), światło bez zmian (3072/3328). **(niezweryfikowane w grze)**

## Test użytkownika 2 (2026-10-25) i poprawki

- **Probe'y z Gatewaya** (prośba użytkownika). Budynek TS ma jeden `Factory=`, a zbieracz musi być pojazdem, więc Gateway jest
  teraz stocznią pojazdów (`Factory=UnitType`, `Naval=yes`, `ExclusiveFactory=yes`). **Wszystkie jednostki Gatewaya to pojazdy SHP**
  (`ScBuild.BuildUnit`, 32 kierunki, zestawy chodu i ataku z iscript). Probe: `BuiltAt=SCPGAT,SCPROB`, `Prerequisite=SCPPYL`.
  Skutek: Shuttle nie ma kogo wozić (TS przewozi tylko piechotę), czołgi nie miażdżą Zealotów.
  *(Od 2026-10-27 Shuttle ma `IsVehicleTransport=yes` (klucz DTA), więc pojazdy też wsiadają, zob. [[engine/transports]].)*
- **Śmierć z dźwiękiem:** pojazdy TS ignorują `DieSound=`. Dlatego, jak Terranie (`[SCSCDTH]`), każdy pojazd ma
  `Explosion=<dźwięk>X`, czyli animację z `Report=` dźwięku śmierci z SC. Jednostki Gatewaya używają swoich klatek śmierci z SC
  (`SCPZDTHX`…, Archony: gasnący wir), a pozostałe `Image=FBALL1`.
- **Reaver:** zasięg 20,4 (jak `SCShockCan` Siege Tanka w Siege Mode), wystrzał `pTrFir00/01`. Wybuch Scaraba to animacja
  `SCPSCAEX` z `thingy\psaExplo.grp` i `Bullet\psaHit00` (iscript Scaraba, jednostka SC 85).
- **Carrier i Arbiter się nie pokazywały:** miały `TechLevel=8`, a lobby ma `TechLevel=7` (`spawn.ini`). Teraz 7.
  Carrier jak w SC: 4 interceptory, 8 po Carrier Capacity.
- **Regeneracja „tylko do połowy” i ledwo widoczna:** Vinifera leczy, dopóki HP < `SelfHealingCap` (domyślnie `ConditionYellow` = 50%),
  co `SelfHealingRate` (domyślnie `RepairRate` 0,016 min), o `SelfHealingStep` (domyślnie **1 HP**). Protossi mają `SelfHealingCap=1.0`,
  `SelfHealingStep` = 0,5% HP (budynki 0,25%, też się regenerują jak w SC). Dopisuje to funkcja `Add-ShieldRegen` w generatorze.
  Inne frakcje mają ten sam problem (1 HP na krok, do połowy) **(niezweryfikowane w grze)**.
- **Shield Battery leczy obszarowo** (prośba: „jak skrzynka, która leczy obszarowo”). Skrzynka DTA `Invulnerability` odtwarza
  `AREAHEAL`: jej `TrailerAnim=HEALINIT` (Bouncer, `Damage=1`, `Warhead=AreaHealWH`) przy upadku wywołuje `Particle=AreaHealSys`,
  czyli gaz z `Damage=-8`, który leczy wszystko w nim. Bateria: `ActiveAnim=SCPBATGL` (poświata `pbaGlow`, pętla bez końca)
  z `TrailerAnim=SCPBATTR` (kopia `HEALINIT`, `Warhead=SCPBatWH`) co `TrailerSeperation=60` → `SCPBatSys` (promień 768, 300 klatek)
  → `SCPBatPart` z `Damage=-40`. Leczy też wrogów w zasięgu. Częstotliwość impulsów **(niezweryfikowane w grze)**.
  `UnitRepair=yes` (dok naprawy) usunięte: nie działało.

## Badania (`build-scprotossresearch.ps1`, `ECACHE83.MIX`)

Ten sam wzorzec co [[mods/starcraft-research]] i [[mods/zerg-research]]: badanie kupujesz w zakładce budynków Nexusa i kładziesz na
budynku, który prowadzi je w SC (`PowersUpBuilding`). Badania odblokowują złotą wersję „(Upgraded)” jednostki (ten sam koszt i fabryka).
Koszty z `arr/upgrades.dat` (rasa 2): (minerały + 2 × gaz) × 4 poziomu 1. Poziomy 1–3 broni i pancerza połączone w jedno badanie na klasę.

| ID | Badanie | Budynek | Ikona | Koszt | Działa na |
|---|---|---|---|---|---|
| SCQGWA | Ground Weapons & Armor | Forge | 305 | 1200 | jednostki Gatewaya i Reaver: +30% obrażeń, +25% HP |
| SCQSHD | Plasma Shields | Forge | 310 | 2400 | Archon, Dark Archon: +50% HP |
| SCQAWA | Air Weapons & Armor | Cybernetics Core | 306 | 1200 | lotnicy: +30% obrażeń, +25% HP |
| SCQSIN | Singularity Charge | Cybernetics Core | 281 | 1800 | Dragoon: zasięg ×1,5 |
| SCQLEG | Leg Enhancements | Citadel of Adun | 307 | 1800 | Zealot: prędkość ×1,5 |
| SCQSCA | Scarab Damage | Robotics Support Bay | 314 | 2400 | Reaver (razem z GWA obrażenia ×1,6) |
| SCQRCP | Reaver Capacity | Robotics Support Bay | 315 | 2400 | Reaver: ROF ×0,8 |
| SCQGRD | Gravitic Drive | Robotics Support Bay | 316 | 2400 | Shuttle: prędkość ×1,5 |
| SCQSEN | Sensor Array | Observatory | 317 | 1800 | Observer: wzrok i wykrywanie +3 |
| SCQGRB | Gravitic Boosters | Observatory | 276 | 1800 | Observer: prędkość ×1,5 |
| SCQKHA | Khaydarin Amulet | Templar Archives | 318 | 1800 | High Templar: burza co 0,7 czasu |
| SCQARG | Argus Talisman | Templar Archives | 385 | 1800 | Dark Archon: Maelstrom co 0,7 czasu |
| SCQAPI | Apial Sensors | Fleet Beacon | 319 | 1200 | Scout: wzrok +2 |
| SCQGTH | Gravitic Thrusters | Fleet Beacon | 320 | 2400 | Scout: prędkość ×1,5 |
| SCQCAR | Carrier Capacity | Fleet Beacon | 321 | 1200 | Carrier: 8 interceptorów (`SCPINTC2`, +30% obrażeń) |
| SCQARJ | Argus Jewel | Fleet Beacon | 383 | 1200 | Corsair: ROF ×0,8 |
| SCQKHC | Khaydarin Core | Arbiter Tribunal | 322 | 1800 | Arbiter: ROF ×0,7 (także w polu maskującym `SCPARBD2`) |

Ulepszone wersje (`<ID>2`): Zealot, Dragoon, High Templar, Dark Templar, Archon, Dark Archon, Reaver, Shuttle, Observer, Scout,
Corsair, Carrier (+ `SCPINTC2`), Arbiter (+ `SCPARBD2`, `Image=SCPARBD`). Wymagają wszystkich swoich badań. Bez wersji: Probe.
Pominięte czary SC (`techdata.dat`): Hallucination, Recall, Stasis Field, Disruption Web, Mind Control, Feedback, Maelstrom
(Dark Archon ma Maelstrom jako broń). Psionic Storm High Templar ma od razu. `Upgrades=`: Forge 2, Cyber Core 2, Citadel 1,
Support Bay 3, Observatory 2, Archives 2, Fleet Beacon 4, Tribunal 1. **Po `build-scprotoss.ps1 -Install` uruchom generator badań
ponownie**, bo kopie jednostek się zestarzeją.

## Do sprawdzenia w grze

1. Lobby: pozycja **Protoss** z ikoną GDI; w trybach bez pliku frakcji wyszarzona. Log: `Side 8: ProtossSide`, `SIDEC09.MIX`.
2. Start z „Probe: Nexus”, deploy → Nexus z animacją przywołania. Ikonki wszystkich budynków w pasku, właściwe fundamenty.
3. **Zasięg:** Pylon daleko od Nexusa (do 10 komórek) się da, a Gateway daleko od Pylona (ponad 8) już nie.
4. Robotics Facility i Stargate: produkty pojawiają się obok. Lotnicy wiszą w powietrzu (łatka `patch-flyhover.ps1`) i atakują.
5. Gateway produkuje Probe'y i wszystkie swoje jednostki obok siebie; Zealot i Templar jako pojazdy chodzą i atakują poprawnie.
6. Shield Battery: poświata i co kilka sekund leczący gaz wokół (czy impulsy nie są za rzadkie albo za częste).
7. Archony: wygląd w grze (kula energii przykrywa postać), Dark Archon ogłusza pojazdy (EMP).
8. Observer i Dark Templar niewidzialni; Photon Cannon, Observer i Arbiter wykrywają niewidzialnych.
9. Kontrola: misja z `GDI2` (np. kampania GDI) działa jak wcześniej. Plik frakcji ładuje się tylko w skirmishu.

## Carrier i Arbiter: mechanika z DTA (2026-10-25, po pytaniu użytkownika)

- **Carrier = lotniskowiec GDI z DTA.** `[CARRIER]` (Aircraft Carrier, statek) i `[CARRTRUK]` (Drone Launcher, **pojazd gąsienicowy**)
  mają broń z `Spawner=yes` (`HornetLauncher`: `Damage=1`, `Warhead=Super`, `OmniFire=yes`, zasięg 18–40) oraz klucze Vinifery
  `Spawns=ORCAHORN`/`DLHORNET`, `SpawnsNumber`, `SpawnRegenRate`, `SpawnReloadRate`, `SpawnSpawnRate`, `SpawnLogicRate`,
  `MaxRandomSpawnOffset`. Wypuszczany typ to samolot z `Spawned=yes`, `Ammo=`, `Landable=yes`, `Selectable=no`. Carrier Protossów
  kopiuje to 1:1: `SCPInterceptLauncher` (`Projectile=Invisible3`, więc startuje też na cele powietrzne), 8 × `SCPINTC`
  (odnowienie zestrzelonego co 300 klatek). Interceptor ma `Owner=GDI2` i `TechLevel=-1` (nie do zbudowania z paska).
  Ogólny opis mechanizmu: [[engine/spawners]].
- **Arbiter:** generator niewidzialności TS (`CloakGenerator=yes`, `CloakRadiusInCells=`) jest w DTA tylko na budynku `[SGEN]`
  (Stealth Generator Nod). Dlatego deploy Arbitra zamienia go w 1x1 budynek `SCPARBD` „pole maskujące” (sprite uniesiony o 60 px,
  cień na ziemi, bez Buildup, broń zostaje), a deploy pola przywraca lotnika (`UndeploysInto`). Czy pojazd z lokomotorem Fly
  w ogóle się rozkłada: **(niezweryfikowane)**. Lądujące budynki Terran to pojazdy jumpjet, nie Fly.

## Skrzynki (2026-10-25)

Skrzynka „Unit” zawieszała grę, bo dom `GDI2` nie miał żadnego pojazdu z `CrateGoodie=yes`. Naprawione blokiem
„Crate goodies (SC factions)” (Reaver, Scout, Corsair), zob. [[engine/crates]].

## Zealot reaguje dalej (2026-10-28, prośba użytkownika; niezweryfikowane w grze)

- „Zealoty są trochę ślepe o 2 kratki”: `SCPZEAL` i `SCPZEAL2` mają `GuardRange=3.75` (zasięg ostrzy `SCPPsiBlades` 1.75 + 2; sam zasięg ataku bez zmian). Bez `GuardRange` jednostka w Guard reaguje tylko w zasięgu broni.
- Wpis jest w bloku `; >>> SC balance (user)` w `Terran Faction.ini` (generatory go nie nadpisują); działa też w misjach ARKA z typami skopiowanymi do mapy (ARKA 5).

## Znane ograniczenia

- **AI nie umie grać Protossem** (nie zna Pylona jako elektrowni, `AIBuildThis=no`). Nie dawaj Protossa komputerowi.
- Budynki nie wyłączają się po zniszczeniu pobliskiego Pylona (w SC tak jest); w TS brak prądu tylko spowalnia i wyłącza `Powered=yes`.
- Brak tarcz (zamiast nich regeneracja), brak scalania Templarów w Archona, brak czarów (Hallucination, Recall, Stasis Field,
  Mind Control, Disruption Web).
- Interceptory wyglądają jak małe Orki z Drone Launchera (voxel `ORCAHORNS`), nie jak SC: samolot TS musi być voxelem
  (zob. [[engine/spawners]]).
- Arbiter ukrywa sojuszników tylko po rozłożeniu (stoi w miejscu jako pole maskujące); w ruchu nie.
- Brak ulepszeń z Forge, Cyber Core i reszty (wzorzec badań: [[mods/starcraft-research]]).
- Sidebar i EVA to kopie GDI, nazwa domu w INI to `GDI2`.

## Odinstalowanie

```powershell
# Terran Faction.ini: usunąć blok "; >>> Protoss faction" ... "; <<< Protoss faction", linie ProtossSide=, PRV01-09,
#   ",SCPDNEX" z BaseUnit, ",SCPPROBE" z HarvesterUnit; przywrócić GDI2 w Owner= [TDPROC], [TDPROC_AI], [DEPCARR]
# Art.ini, Sound.ini: bloki "Protoss faction" i [SoundList] 1400-1533; StarCraft.ini: ",SCPNEX" z BuildConst
# GameOptions.ini: Sides= bez ",Protoss"; MPMaps.ini: "4,5,6,7,8" -> "4,5,6,7"
Remove-Item MIX\ECACHE85.MIX, MIX\SideC09.mix, MIX\sidenc09.mix, MIX\Speech09.mix, Resources\protossicon.png, Resources\l600s81.pcx, Resources\l600s82.pcx, Resources\l480s81.pcx, Resources\l480s82.pcx
```

## Dalej

Ulepszenia (Ground Weapons/Armor/Plasma Shields w Forge, Air w Cyber Core, Leg Enhancements w Citadel, Scarab Damage, Carrier Capacity)
według wzorca [[mods/starcraft-research]]; własny voxel Interceptora (wymaga pisarza VXL/HVA); własna ikona, sidebar i EVA Protossów.
