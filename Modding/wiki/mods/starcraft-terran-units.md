# Mod: jednostki Terran ze StarCrafta (wszystkie poza Marine'em)

15 typów jednostek (12 jednostek SC + 3 tryby po deploy) i 4 addony jako „ulepszenia” odblokowujące. Ten sam checkbox **STARCRAFT**, dostępne dla GDI/Nod/Allies/Soviet i frakcji Terran (`GDI1`). Stan: zainstalowany 2026-10-24, **(niezweryfikowane w grze)**.

Źródła: CASC StarCraft: Remastered (`unit/terran/*.grp`, `*.lol`, `SD/sound/terran/*`, `SD/sound/bullet/*`), `INI/Rules.ini`
(wzorce: `InfFlamethrower`, `Sniper`/`HollowPoint`, `Heal`/`Organic`, `EMPulseWeapon`/`EMPuls`, `LaserFire`, `105mm`, `AAHeatSeeker`,
`MslHEAA`, `ScrinPlasmaPr`, `[TRANV]` jumpjet, `[MEDIC]`), `INI/Art.ini` (`[SCMARINE]`, `[4TNK]`, `[FBALL1]`), `Vinifera.dll` (napisy kluczy).

## Pliki

| Plik | Co |
|---|---|
| `MIX/ECACHE97.MIX` | 157 plików: SHP jednostek, cameo `<ID>I.SHP`, śmierci `SCGHDTH`/`SCMEDTH`, 128 dźwięków AUD |
| `Modding/tools/build-scunits.ps1`, `ScUnits.cs` | budowa grafiki i dźwięku (`UnitBuilder`: warstwy GRP, przesunięcia LO, cienie z sylwetki) |
| `INI/Game Options/StarCraft.ini` | blok „StarCraft Terran units” na końcu, `SCT10–SCT24` w `[VehicleTypes]`, `SCB15–SCB18` w `[BuildingTypes]` |
| `INI/Art.ini` | blok „StarCraft Terran units” na końcu |
| `INI/Sound.ini` | `[SoundList]` 720–847 (po `713=`) + sekcje głośności dźwięków śmierci |
| `INI/Rules.ini` | 12 animacji śmierci w `[Animations]` (pod `SCNUKE_A3D`) |
| `MIX/ECACHE98.MIX` | + addony `SCMSHP`, `SCCTWR`, `SCPHYS`, `SCCOVO` (`build-scterran.ps1`) |

## Jednostki

| ID | Jednostka | Wymaga | Funkcja | Koszt / HP |
|---|---|---|---|---|
| SCSCV | SCV | SCCC | harvester (`Dock=` SC i DTA rafinerie, `Storage=10`) | 300 / 1200 |
| SCFIRE / SCFIRES | Firebat | SCBARR, SCACAD | miotacz (`Fire1`); deploy = stimpack jak Marine | 400 / 1000 |
| SCGHOST | Ghost | + SCCOVO | `Cloakable`, karabin C-10 tylko vs piechota, **Lockdown** (EMP 30 s) vs pojazdy | 700 / 900 |
| SCMEDIC | Medic | SCBARR, SCACAD | leczy `Armor=none` (głowica `Organic`): piechotę SC-pojazdy i DTA | 400 / 1200 |
| SCVULT | Vulture | SCFACT | szybki (14), granaty vs piechota | 300 / 1600 |
| SCSIEGE / SCSIEGS | Siege Tank | SCFACT, SCMSHP | obracana wieża; deploy = Siege Mode (zasięg 12, `MinimumRange=2`, splash `HE`, Speed 1) | 1400 / 3000 |
| SCGOLI | Goliath | SCFACT, SCARMO | wieża; działka vs ziemia, Hellfire AA (`AAHeatSeeker`); od 2026-10-25 rakiety grają `SCHKMISL` = `Bullet\HKMISSLE` (oryginał SC, sesja frakcji, zob. [[mods/starcraft-terran-buildings]] „Dźwięki ataku”) | 800 / 2500 |
| SCWRAF | Wraith | SCSTAR | lokomotor Fly, laser vs ziemia (`SCBurstLaser` ROF 38, od 2026-10-25 −20% szybkości), Gemini AA, `Cloakable=no` | 1400 / 2400 |
| SCDROP | Dropship | SCSTAR, SCCTWR | od 2026-10-27 lokomotor Fly (wisi jak okręty), ze Starportu, `Passengers=8` + `IsVehicleTransport=yes`: piechota i pojazdy wsiadają do wiszącego transportu ([[engine/transports]]). Wcześniej jumpjet (lądował, gdy stał), tylko prawdziwa piechota, War Factory | 1200 / 3000 |
| SCVESF | Science Vessel | + SCSCIF | lokomotor Fly, `Sensors=yes` (wykrywa niewidzialnych), EMP Shockwave (`Spread=3`) | 2200 / 4000 |
| SCBCF | Battlecruiser | + SCPHYS | lokomotor Fly, laser `SCATSLaser` + Yamato `SCYamato` (2. broń na pojazdy i budynki) | 4000 / 10000 |
| SCVALF | Valkyrie | + SCARMO | lokomotor Fly, tylko AA, salwa rakiet `SCHalo` | 2000 / 4000 |

Skala: HP = HP z SC × 20, koszt = (minerały + 2 × gaz) × 4. Pojazdy i pojazdo-piechota budowane w War Factory.
**Okręty (od 2026-10-25): tylko ze Starportu**, jako pojazdy z lokomotorem samolotu (`SCF01–SCF04`, blok „StarCraft flyers” na końcu
`StarCraft.ini`/`Art.ini`, grafika `MIX/ECACHE90.MIX`), wymagają łatki `game.exe` z [[engine/fly-locomotor]]. Wersje-piechota z koszar
(`SCWRAI`, `SCVALK`, `SCVESS`, `SCBC`, sekwencja `SCJJSequence`) usunięte na prośbę użytkownika. Ich SHP zostały w `ECACHE97.MIX`
(`build-scunits.ps1`, funkcja `JJ`), bo te same wywołania budują cameo `SCWRAII`/`SCVALKI`/`SCVESSI`/`SCBCI` używane przez okręty Fly.

## Patch 2 (2026-10-25): uwagi użytkownika po teście

| Zgłoszenie | Zmiana |
|---|---|
| Ghost +40% zasięgu | `SCC10` 7 → 9.8, `SCLockdown` 8 → 11.2, Sight 9 → 12 |
| Siege Tank +70% zasięgu | `SCArclite` 7 → 11.9, `SCShockCan` 12 → 20.4 (`MinimumRange=3`), Sight 8/10 → 12/16 |
| Siege Tank +20% HP, +50% obrażeń, lekki splash | 3000 → 3600; 60 → 90 i 150 → 225; tryb czołgu: głowica `SCTankWH` (kopia `AP` ze `Spread=12`), Siege Mode: `HE` |
| Siege Mode jeździ | `SCSIEGS Speed=0` (wcześniej 1), `ROT=6`, żeby wieża obracała się normalnie |
| Goliath odrobinę mocniej w piechotę | `SCGoliWH` = `AP` z `Modifier.none` 190% → 260% |
| **Okręty strzelają raz i siadają na ziemi** | zob. niżej: okręty jako piechota `JumpJet=yes` |
| Bohater | `SCHERO`/`SCHEROS`: Edmund Duke, złoty Siege Tank, `BuildLimit=1`, 32 400 HP (9× Siege Tanka, patch 6) + `SelfHealing=yes`, zasięg +30% (15.5 / 26.5), tryb czołgu: mini-atomówki (`SCMiniNukeWH`, anim `TWLT100`), Siege Mode: atomówka (`SCHeroNukeWH` jak `AtomicWH`, `CellSpread=7`, 1800 dmg, anim `ATOMSFX`, `MinimumRange=8`; patch 6). Wymaga SCFACT + SCMSHP + SCNUKE, koszt 6000. Głosy Duke'a z `SD/sound/terran/duket/udt*` (`SCDKWHT0-3`, `SCDKYES0-3`, Sound.ini 848–856) |

### Patch 3 (2026-10-25): Siege Mode jako budynek, Duke ×2, silos bez prądu

- **Błąd:** Siege Mode jako pojazd ze `Speed=0` po rozkazie ruchu zamarzał na stałe (misja ruchu, której nie da się wykonać).
  **Poprawka:** `SCSIEGE DeploysInto=SCSIEGB`, `SCSIEGB UndeploysInto=SCSIEGE` (jak MCV ↔ Construction Yard). `SCSIEGB` to
  budynek 1×1: kadłub `stank` klatka 5, wieża `TurretAnim=SCSIEGBT` (32 kierunki z `stankt` 0–16), buildup `SCSIEGMK` = prawdziwa
  animacja rozkładania SC (`stank` 0–5 + `stankt` 17/34/51/68/85/101), odtwarzana od tyłu przy składaniu. `Unsellable=yes`,
  `Capturable=false`, broń `SCShockCan`. Hero: `SCHEROB`/`SCHEROBT`/`SCHEROMK` z `SCHeroNuke`. Animacje wież globalnie w `Rules.ini`.
  `SCSIEGS` i `SCHEROS` wyrejestrowane. **Składanie wymaga opcji lobby „Re-Deployable MCV”** (`MCVRedeploy`) **(niezweryfikowane w grze)**.
- Duke w trybie czołgu: `SCHeroShell` 180 → 360 (prośba użytkownika: 2× mocniej przed deployem).
- Nuclear Silo: w logu są 2× `SPECIAL_PLACE` bez startu rakiety. `SCNUKE Powered=no`, żeby niedobór prądu nie blokował
  startu (hipoteza, **niezweryfikowane**). Jeśli dalej nie leci: sprawdzić, czy przy odpaleniu otwierają się zbiorniki (`SpecialAnim`).
- **Test 2026-10-25: dalej nie działa, silos się nie otwiera** (czyli `Mission_Missile` w ogóle nie startuje; to nie animacja ani prąd).
  Klucze porównane 1:1 z działającym `RAMSLO` (Rules + Enhance + Art): różniły się tylko `Powered` (przywrócone `yes`), `Nominal`,
  Art `Normalized=no` + `ActiveAnimFour=BIB22` (dodane) oraz `Image=`. Dodane też `IsTemple=yes` jak w `TMPL` (drugi działający silos).
  Vinifera łata `BuildingClass::Mission_Missile` (INITIAL / DOOR_OPENING / LAUNCH_DOWN), a w `game.exe` jest `SuperWeaponTypeClass::AuxBuilding`.
  **Plan B, jeśli dalej nie leci:** jedyna pozostała różnica strukturalna to to, że `SCNUKE` powstaje z opcji gry, a nie z `Rules.ini`.
  Wtedy zarejestrować `SCNUKE` w `Rules.ini [BuildingTypes]` (na końcu listy, `TechLevel=-1`) i włączać go dopiero w `StarCraft.ini`.

### Patch 4 (2026-10-25): bohater Jim Raynor, więcej głosów Duke'a

`SCRAYN`/`SCRAYNS` (`SCT27`/`SCT28`): złoty Marine (`marine.grp` z `TintMap` 1.35/1.15/0.45, w stimie 1.6/0.9/0.35), układ klatek
jak `SCMARINE`. 4000 HP (5× Marine), `SCRaynGun` 45 dmg (3×), zasięg 6.94 (+30%), ROF 20 (w stimie 10, HP 2667), koszt 2000,
`BuildLimit=1`, wymaga SCBARR + SCACAD. Głosy `SD/sound/terran/raynorm/ura*` (`SCRAWHT0-3`, `SCRAYES0-3`, `SCRAPSS0-3`),
śmierć `SCRADTH` = Art `Image=SCMADTH` (animacja Marine'a) z krzykiem `SCRADTH0`, wpis w `Rules.ini [Animations]`.
Duke: `VoiceSelect` + 5 kwestii `udtpss00-04` (`SCDKPSS0-4`), `VoiceDeploy=SCDKYES0`. Sound.ini 857–874.

### Patch 5 (2026-10-25): lufy Siege Mode, trafienie natychmiastowe, ogień z luf

Zgłoszenie: po deployu lufy mają zły offset, działa powinny trafiać natychmiast (hitscan), ogień ma wychodzić z luf.
- **Przyczyna offsetu (2 błędy w `SCSIEGBT`/`SCHEROBT`):** (1) klatki `TurretAnim` budynku idą **przeciwnie do wskazówek
  zegara** (sprawdzone na `ART_A`: klatka 4 = NW), a były zbudowane jak wieża pojazdu (zgodnie z zegarem), więc działo było
  odbite lustrzanie względem celu; (2) przy odbijaniu klatek zachodnich skrypt odbijał też punkt mocowania (`stank.lol` −9,−16),
  choć kadłub w Siege Mode się nie obraca, więc działo skakało o 18 px przy przejściu przez N/S. Poprawione w `SiegeBuilding`
  (i w nieużywanym `SiegeMode`).
- **Hitscan:** `SCArclite`, `SCShockCan`, `SCHeroShell`, `SCHeroNuke`: `Projectile=Invisible` (wcześniej `TracerM`/`Lobbed`).
- **Ogień z luf:** 64 nowe animacje `SCSFL00–31` (Siege Mode, `unit/thingy/esifire.grp`: 7 faz × 17 kierunków, pozycja =
  mocowanie + `stankt.loa`) i `SCTFL00–31` (tryb czołgu, `ettflash.grp`, wylot już wpisany w GRP). Kolory z tablicy
  `TileSet/jungle/ofire.pcx` (SC rysuje ognie przez remap: wiersz = indeks GRP − 1, kolumna = tło; tu tło czarne).
  Broń dostaje listę 32 animacji (indeks = kierunek zgodnie z zegarem od N, jak `FTNKFLM00–31`), a `PrimaryFireFLH=0,0,0`,
  bo animacja ma przesunięcie lufy wpisane w SHP. Wpisy w `Rules.ini [Animations]` (pod `SCHEROBT`), sekcje w Art.ini
  (`AltPalette=yes`, `YSortAdjust=300`). Kopia `MIX/ECACHE97.MIX.bak`. **(niezweryfikowane w grze)**: kierunek działa,
  czy ogień nie chowa się pod wieżą, kolejność listy 32 animacji.
- **Test 2026-10-25:** offset naprawiony, ale lufa po deployu „jakby zanika”. Hipoteza: bufor głębi ucina wysoką wieżę
  (`TurretAnimZAdjust=-30` jak niski `GUN`; wysoki `OBLI` ma `-100`). Zmiana: `SCSIEGB`/`SCHEROB` `TurretAnimZAdjust=-120`,
  `[SCSFL00] ZAdjust=-120`. **Potwierdzone w grze 2026-10-25: działa** (lufa cała, bez offsetu; ogień i hitscan bez uwag).

### Patch 6 (2026-10-25): Duke jako uber czołg, szybszy Goliath

Prośba: atak Duke'a w Siege Mode ma być szerszy i 3× mocniejszy, Goliath o 20% szybszy.
- `SCHeroNuke` (broń `SCHEROB`): `Damage` 600 → 1800, `MinimumRange` 5 → 8 (wybuch nie sięga samego Duke'a).
- `SCHeroNukeWH`: `CellSpread` 3 → 5 → **7** (druga prośba użytkownika), `PercentAtMax` 33% → 50% (brzeg wybuchu też boli).
  Uwaga: wybuch 7 komórek rani też własne jednostki blisko celu. Limit tabeli zasięgu wybuchu w silniku TS to 11 komórek.
- `SCGOLI` i ulepszony `SCGOLI2`: `Speed` 7 → 8. Silnik czyta `Speed` jako liczbę całkowitą: 8.4 → 8 (+14%), następny krok 9 (+29%).
  **(niezweryfikowane w grze)**
- Duke „za słaby”, prośba o pancerz Enforcera: Enforcer `BFRT` ma **ten sam** `Armor=heavy`. Jego wytrzymałość to
  `Strength=28000` + `SelfHealing=yes`. Dlatego `SCHERO`/`SCHEROS`/`SCHEROB`: `Strength` 10 800 → **32 400** (3×, 9× Siege Tanka)
  i `SelfHealing=yes` jak Enforcer. Samonaprawa na budynku `SCHEROB` **(niezweryfikowane w grze)**.
- **Siege Mode nie zbierał XP:** budynki domyślnie nie są `Trainable`, a doświadczenie za zabicie dostaje tylko typ z
  `IsTrainable` (Vinifera `technoext_hooks.cpp`, `Made_A_Kill`). `SCSIEGB`/`SCSIEGB2`/`SCHEROB` dostały `Trainable=yes` oraz
  `VeteranAbilities`/`EliteAbilities` jak czołg. Przeniesienie rangi działa w obie strony już w silniku: deploy
  (`UnitClass`, `0x00650F36`) i składanie (`BuildingClass`, `0x00430A59`) kopiują `Crew` (`TechnoClass+0xA8`, 8 bajtów).
  **(niezweryfikowane w grze)**

### Okręty jako latająca piechota (przyczyna błędu)

Pojazd z lokomotorem jumpjet (`UnitType`) **ląduje**, gdy nie ma rozkazu ruchu. Na ziemi nie może się obrócić do celu
(obrót robi tylko lokomotor w locie), więc po pierwszym strzale przestaje strzelać. **Piechota z `JumpJet=yes` wisi w powietrzu**
(sekwencja `Hover` w `JumpjetSequence`) i strzela z lotu (`FireFly`). Dlatego Wraith, Valkyrie, Science Vessel i Battlecruiser są teraz
`[InfantryTypes]` (`SCI01–SCI04`) z sekwencją `SCJJSequence` (8 klatek = 8 kierunków, wszystkie stany na tej samej klatce, cienie 8–15).
Konsekwencje: **budowane w koszarach** (dowolne `Factory=InfantryType`, w tym SC Barracks), 8 kierunków zamiast 32.
Battlecruiser nie może już przełączać się w tryb Yamato (`TransformsInto` działa tylko dla pojazdów), więc ma dwie bronie:
laser (`SCBCLaserWH`: lepszy na piechotę i lotnictwo) i Yamato (`SCYamatoWH`: 0% na piechotę, 2000% na resztę, ROF 150).
Silnik sam wybiera Yamato na pojazdy i budynki **(niezweryfikowane w grze)**. `SCBCY` usunięty. Dropship zostaje pojazdem
(tylko pojazd przewozi pasażerów), więc nadal ląduje, gdy stoi. *(Nieaktualne od 2026-10-27: Dropship jest pojazdem Fly i wisi, zob. [[engine/transports]].)*

### Test 2026-10-25: okręty jako pojazdy z lokomotorem samolotu (Fly)

Użytkownik po teście: piechota jumpjet „nie działa genialnie” (szczegóły nieznane). Analiza alternatyw:
- **Nowy jumpjet Vinifery** (`NewJumpjetLocomotionClass`, źródło na GitHubie) to wierna kopia starego: w `Process_Hover`
  jednostka schodzi do lądowania, gdy dotarła do celu i `TarCom == nullptr`. Nie ma odpowiednika `BalloonHover`. Odpada.
- **Prawdziwe samoloty** (`[AircraftTypes]`): w TS muszą być wokselami (SHP się nie rysują); bezczynne lądują na lądowisku
  albo na ziemi, a `Landable=no` robi z nich „pożyczkę” (`IsALoaner`, odlatuje z mapy, kod Vinifery `AircraftClassExt::_Unlimbo`). Odpada na razie.
- **Pojazd z lokomotorem Fly** `{4A582746-…}`: tak działa Hunter-Seeker z TS (`[HUNTSEEK1]` w Rules.ini: `VehicleType`,
  `FlightLevel=400` per typ, `MovementZone=Fly`). Pojazd SHP = 32 kierunki, brak logiki lądowania samolotu. **Testowane teraz.**

Warianty testowe (obok wersji piechoty, do porównania w jednej grze): `SCWRAF`, `SCVALF`, `SCVESF`, `SCBCF`
(`[VehicleTypes]` `SCF01–SCF04`, nazwy „… (TEST Fly)”, wymagania jak oryginały). Grafika
`MIX/ECACHE90.MIX` z `Modding/tools/build-scflyers.ps1` (32 kierunki + cienie-sylwetki, cameo z ECACHE97). Blok
„StarCraft flyers TEST” na końcu `StarCraft.ini` i `Art.ini`.

**Pułapka: numery `ECACHE91–95` zajmuje klient.** `Resources/OptionsWindow.ini` przy starcie kopiuje `Resources/ECache91–95.mix`
do `MIX/` (opcje klienta; 95 = „Use Red Alert radar online/offline sounds”). Pierwsza wersja testu była w `ECACHE95.MIX`, klient ją
nadpisał i okręty Fly **nie miały grafiki** (niewidzialne). Teraz `ECACHE90.MIX`. Wolne numery na mody: 90 i niżej (poza 00–05 z gry).

**Test 1 (gry 02:05 i 02:23): z War Factory „nie wychodzą”, a potem są niewidzialne i „lawirują” przy ataku.** Błędna pierwsza
diagnoza: `Adding event PLACE` jest w każdym logu (to stawianie budynków przez AI), więc nie dowodzi zablokowanej fabryki.
Jednostka najpewniej wychodziła, tylko była niewidzialna (brak SHP, patrz wyżej). Okręty-piechota też były u gracza niewidzialne,
a u AI (Sowieci) widoczne: testowano Wraithy, a `Cloakable=yes` w TS to stałe maskowanie (pojazd SHP gracza po zamaskowaniu
prawie znika, odsłania się tylko na strzał). **Obie wersje Wraitha mają teraz `Cloakable=no`** (Ghost zostaje z maskowaniem).
„Lawirowanie” przy ataku to prawdopodobnie zachowanie lokomotora Fly (krąży jak samolot) **(niezweryfikowane)**.
Starport i tak zostaje fabryką okrętów: Starport jest fabryką w stylu stoczni Vinifery (jak `[GSYRD]`:
`Factory=UnitType`, `WeaponsFactory=yes`, `Naval=yes`, do tego `ExclusiveFactory=yes`), a okręty mają `Naval=yes` + `BuiltAt=SCSTAR`.
Hak Vinifery `_BuildingClass_Exit_Object_Naval_Patch` (`Unlimbo_Naval_Helper`) stawia produkt od razu na wolnej komórce obok
budynku (`Nearby_Location` wg `SpeedType` jednostki), bez wyjazdu przez drzwi. `ExclusiveFactory` blokuje statki DTA w Starporcie.
**(niezweryfikowane w grze)**: pojawianie się przy Starporcie, start, wiszenie bez rozkazu, obrót do celu, ciągły ogień, trafianie przez AA.

**Test 2 (2026-10-25):** okręty ze Starportu są widoczne i według użytkownika najlepsze (wersja-piechota z koszar „to kupa”),
ale **siadają bez rozkazu i lawirują przy ataku**. Przyczyna i łatka `game.exe` (`tools/patch-flyhover.ps1`, pojazdy Fly wiszą
zamiast lądować): [[engine/fly-locomotor]]. **(niezweryfikowane w grze)**. Po udanym teście wersje-piechota (`SCI01–SCI04`) do usunięcia.

## Technika (zob. też [[engine/starcraft-assets]], [[engine/shp-graphics]], [[engine/transform-deploy]])

- **Piechota = pojazdy SHP** (układ jak `SCMARINE`): postój 0–31, chód (Firebat 8, Ghost 9, Medic 7 faz), strzał 2/kierunek, cienie.
  Zestawy GRP: Firebat 0 postój / 1 strzał / 2–9 chód; Ghost 1–9 chód / 11 celowanie / 12 błysk; Medic 4–5 leczenie / 6–12 chód.
- **Wieże:** `Turret=yes` + Vinifera `StartTurretFrame`/`TurretFacings` (wpisane w Art **i** Rules, bo nie wiadomo, skąd Vinifera je czyta).
  Siege Tank: kadłub 0–127 (z gąsienicami), wieża 128–159. Goliath: kadłub 0–319 (9 faz chodu), wieża 320–351.
  Przesunięcie wieży = średnia z `.lol` po 32 kierunkach (czołg 0,−9; goliath 0,0).
- **`stankt.grp`:** klatki 0–16 = działo oblężnicze w 17 kierunkach, 17–101 = animacja przejścia (stały kierunek SE).
  Sprawdzone na siatce wszystkich 102 klatek (2026-10-25). Wcześniejsze założenia „zestaw × 17” i „kierunek × 6 + faza”
  były błędne. `goliatht`, `tank`, `firebat`… są zestaw-major.
- Science Vessel: okrągła podstawa (1 klatka) + obracana antena `wesselt` wtopiona w kadłub.
- Jednostki latające: jumpjet (`{92612C46-…}`, `MovementZone=Fly`) jak `TRANV`, cień = sylwetka (SC nie ma GRP cieni dla lotnictwa, SCV i Vulture).
- Śmierci: Ghost i Medic mają własne animacje z GRP. Reszta: sekcja Art z `Image=FBALL1` + `Report=` dźwięku śmierci SC.
  Wszystkie zarejestrowane w `Rules.ini [Animations]`.

## Uwaga dla sesji jednostek: badania SC (przekazała sesja frakcji, 2026-10-25)

Sesja badań (Marines, `tools/build-scresearch.ps1`, [[mods/starcraft-research]]) robi ulepszone kopie Waszych jednostek: `SCFIRE2/2S`,
`SCGHOST2`, `SCMEDIC2`, `SCVULT2`, `SCSIEGE2`+`SCSIEGB2`, `SCGOLI2`, `SCWRAF2`, `SCVALF2`, `SCBCF2`, `SCVESF2` (bronie z sufiksem `U`).
Kopiuje Wasze sekcje i SHP z Waszych MIX-ów. **Po zmianie jednostki bazowej uruchomcie `build-scresearch.ps1` ponownie** (albo dajcie znać
sesji Marines). Wpisy `SCX01–SCX11` w `[VehicleTypes]` i `SCR*`/`SCX90` w `[BuildingTypes]` należą do niej. Prefiksów `SCR`/`SCX` nie używać.
Generator przepisuje cały `StarCraft.ini`, więc nie edytujcie pliku w tym samym czasie.
- **Spider Mines v2 (2026-10-25):** `[SCVULT]` jest znowu oryginalny (pierwsza wersja z `Passengers=3` w Vulture została usunięta).
  Miny ma tylko Upgraded Vulture z bloku badań: `SCVULT2` (3 miny) `DeploysInto=SCSPMB3` → budynek-mina (jak `VMINE`) z
  `FreeUnit=SCVULT2B` (2 miny) → `SCSPMB2`/`SCVULT2C` → `SCSPMB1`/`SCVULT2D`. Rejestracje `SCX91–93` (`[BuildingTypes]`) i
  `SCVULT2B/C/D` (`[VehicleTypes]`), wszystko w bloku „StarCraft research”. `FreeUnit=` to jedyny sposób, żeby jeden deploy dał
  budynek + jednostkę **(niezweryfikowane w grze)**. Vinifera `Spawns=` tworzy tylko `AircraftClass`, więc miny naziemne przez `Spawns=` się nie da.

## Do sprawdzenia w grze

1. Czy `StartTurretFrame` działa (wieża Siege Tanka/Goliatha ma się obracać niezależnie, kadłub z animacją gąsienic/chodu).
2. Siege Mode: deploy/undeploy, `Speed=1` (miało być 0 jak w SC, ale bezpieczniej 1), `MinimumRange`.
3. Medic leczy pojazdo-piechotę (Marine'y, Firebaty), Ghost i Wraith się maskują, Lockdown i EMP wyłączają pojazdy.
4. Jednostki jumpjet SHP latają, strzelają i są trafiane przez AA; Dropship zabiera piechotę.
4a. Dropship Fly (2026-10-27): wychodzi ze Starportu, wisi; zatrzymany przyjmuje Marines, czołgi, Goliathy; rozładunek z zawisu.
5. Battlecruiser: przejście w Yamato i z powrotem (`IsMobileEMP` jak w stimpacku Marine'a: czy przy deploy nie odpala EMP).
6. Głosy (`VoiceSelect/Move/Attack`), strzały, krzyki śmierci.

## Pominięte / pomysły

Spider Mines (TS nie ma min), Defensive Matrix, Irradiate, Nuke Ghosta, ulepszenia poziomów broni/pancerza (TS nie ma badań;
tu „ulepszenia” to addony odblokowujące jednostki + tryby deploy), Medic nie leczy prawdziwych pojazdów.
