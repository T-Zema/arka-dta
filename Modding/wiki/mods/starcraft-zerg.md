# Mod: Zergi w koszarach (opcja STARCRAFT, 2026-10-25)

Zergling, Hydralisk i Ultralisk ze StarCrafta jako **prawdziwa piechota**, trenowana w dowolnych koszarach (GDI, Nod,
Alianci, Sowieci, SC Barracks). Prośba użytkownika: „dodaj do baraków zergi”. Ten sam checkbox **STARCRAFT** co jednostki
Terran. Stan: zainstalowany, **niezweryfikowany w grze**.

Źródła: CASC StarCraft: Remastered (`unit/zerg/zergling|hydra|ultra.grp`, cienie `zzeshad|zhyshad|zulshad`, szczątki
`zzedeath|zhydeath|zuldeath`, `SD/sound/zerg/*`, `SD/sound/bullet/zdrhit00|zhyfir00`), `INI/Art.ini` (`E1Sequence`, `DogSequence`),
`MIX` (`E1.SHP` do ustalenia kierunków), wzorce sesji Terran ([[mods/starcraft-terran-units]]).

## Pliki

| Plik | Co |
|---|---|
| `MIX/ECACHE80.MIX` | 37 plików: `SCZLING/SCHYDRA/SCULTRA.SHP`, cameo `<ID>I.SHP`, 31 dźwięków AUD |
| `Modding/tools/build-sczerg.ps1`, `ScInfantry.cs` | budowa (`-Install` = też bloki INI); konwerter GRP → SHP piechoty TS |
| `INI/Game Options/StarCraft.ini` | `SCZ01–SCZ03` w `[InfantryTypes]` + blok „StarCraft Zerg units” na końcu (jednostki, bronie, głowice) |
| `INI/Art.ini` | blok „StarCraft Zerg units” na końcu: sekcje graficzne i sekwencje `<ID>Sequence` |
| `INI/Sound.ini` | `[SoundList]` 950–980 (po `874=`) + blok na końcu (głośniejsze śmierci, `Limit=6` dla ataku zerglinga) |

Bloki INI są między `; >>> StarCraft Zerg units` i `; <<< StarCraft Zerg units`, a w listach mają własne klucze
(`SCZ0n`, `950–980`). Ponowne `build-sczerg.ps1 -Install` podmienia je zamiast dublować.
Kopie sprzed instalacji: scratchpad sesji mapowej (`zerg/pre-install`); w grze są starsze `.bak` innych sesji.

## Jednostki

| ID | Jednostka | Wymaga | HP / pancerz | Broń | Speed | Koszt |
|---|---|---|---|---|---|---|
| SCZLING | Zergling | BARRACKS | 700 / none | `SCZClaw` 13 × ROF 11, zasięg 1.75 (wręcz; było 1.25: nie sięgał części celów) | 12 | 100 |
| SCHYDRA | Hydralisk | BARRACKS | 1600 / none | `SCNeedleSpine` 33 × ROF 20, zasięg 7.8, **ziemia + powietrze** (`Invisible3`), Sight 8 | 8 | 500 |
| SCULTRA | Ultralisk | BARRACKS, TECH | 10 000 / heavy | `SCKaiserBlade` 120 × ROF 20, zasięg 2.5 (było 1.5 → 3 → 2.5), głowica `SCKaiserWH`: rozprysk `CellSpread=1`, `PercentAtMax=0.5`, `AffectsAllies=no` (Vinifera, nie rani swoich) | 10 | 2400 |

- Skala jak u Terran: HP = HP z SC × 20, koszt = (minerały + 2 × gaz) × 4 (zergling = połowa pary za 50).
- Głowice: `SCZClawWH` (SC „normal”: 1000/600/700/500/400% dla none/wood/medium/heavy/concrete),
  `SCSpineWH` (SC „explosive”: 600/700/900/1000/500%, słabiej w piechotę, mocniej w pancerz).
- Wszystkie: `SelfHealing=yes` (regeneracja Zergów), `Fearless=yes`, `NotHuman=yes`, `Crushable=no`, `Category=Soldier`,
  `Locomotor={4A582744-9839-11d1-B709-00A024DDAFD1}`, `MovementZone=Infantry`, `Owner=GDI1`
  (od 2026-10-25 bez klasycznych frakcji, zob. [[mods/starcraft-terran-buildings]]; frakcja Zerg `Nod1` ma od pełnej wersji własne kopie
  tych jednostek z wymaganiami jak w SC, zob. [[mods/zerg-faction]]. Wcześniej `Nod1` był tu dopisany: szkoli je Spawning Pool, który jest w grupie `BARRACKS`, a Evolution Chamber w `RADAR` i `TECH`, zob. [[mods/zerg-faction]]).
  Medyk Terran ich leczy (`Armor=none`), a Ultraliska nie (heavy).

2026-10-26: `SCZLING` `Speed` 12 → 10 (−20%, prośba użytkownika: zacinał się po skosie), blok `SC balance (user)` na końcu
`StarCraft.ini`, zob. [[mods/zerg-faction]].

## Poprawka 1 (2026-10-25): brak lokomotora piechoty

Test użytkownika: Zergi stojąc **kręciły się non stop**, nie atakowały i „teleportowały się”. Przyczyna (diagnoza i poprawka
sesji frakcji): w sekcjach nie było `Locomotor=` ani `MovementZone=`. Nowy typ z opcji gry nie dziedziczy ich po niczym,
więc silnik brał domyślny lokomotor (najpewniej pojazdów), który celuje w środek komórki zamiast w pozycje piechoty
w komórce. Dopisane po `Category=Soldier` w `StarCraft.ini` i w `$common` w `build-sczerg.ps1`. Czeka na ponowny test.
**Zasada:** każda nowa piechota musi mieć `Locomotor={4A582744-…}` i `MovementZone=Infantry` (jak `E1`, `DOG`, `RAPT`).

## Poprawka 2 (2026-10-25, sesja frakcji): oryginalne dźwięki ataku, balans

Zgłoszenie użytkownika: dźwięki ataku „jakieś inne”, Ultralisk za słaby, Hydralisk ma mieć +30% zasięgu i obrażeń.
Dźwięki ustalone z danych SC (iscript, zob. [[engine/starcraft-assets]]), zmienione w `build-sczerg.ps1`, a potem
`build-sczerg.ps1 -Install` (zmieniło się tylko 6 wartości w `StarCraft.ini` i 2 wpisy w `Sound.ini`):
- `SCZLATK`: `bullet/zdrhit00` (uderzenie Drone'a) → `zerg/ultra/zulhit00`. `SCHYFIRE`: `bullet/zhyfir00` → `bullet/spooghit`.
- Nowe `SCULHIT0/1` (`zulhit00/01`, Sound.ini 981–982). `SCKaiserBlade Report=SCULHIT0,SCULHIT1` (wcześniej ryki `SCULATK0–2`, które zostają w MIX-ie).
- Ultralisk: HP 8000 → **10 000**, `SCKaiserBlade` 60 → **120**. Hydralisk: `SCNeedleSpine` 25 → **33**, zasięg 6 → **7.8**, `Sight` 7 → 8.
  Tabela wyżej ma już nowe wartości. **(niezweryfikowane w grze)**
- Zergling: zasięg `SCZClaw` 1.25 → **1.75** (użytkownik: „nie atakują każdych jednostek”). Piechota stoi na pozycjach w obrębie komórki,
  więc do pojazdu po skosie albo dużego celu jest ponad 1.4 pola. 1.75 wciąż wygląda na walkę wręcz. Nie atakują lotnictwa (jak w SC).

## Jednostki TEST (2026-10-25, sesja frakcji; użytkownik: „kolejne jednostki naziemne Zergów, testowo z baraków”)

Wszystkie jako piechota (`SCZ04–SCZ08`), więc szkoli je każdy barak z grupy `BARRACKS`. Zestawy klatek odczytane ze skryptów SC
(`tools/ScIscript.cs` → `Anim()`, `playfram` = zestaw×17+kierunek; sprawdzone na Zerglingu, wychodzi to samo co w arkuszu).
Dźwięki ataku także z iscript (zob. [[engine/starcraft-assets]]).

| ID | Jednostka | Wymaga | HP / pancerz | Broń | Speed | Koszt | Grafika (stanie / chód / atak) |
|---|---|---|---|---|---|---|---|
| SCDRONE | Drone | BARRACKS | 800 / none | `SCDroneSpit` 13 × ROF 29, zasięg 1.75, dźwięk SpoogHit | 9 | 200 | 0 / 0–4 / 0; cień = ciało |
| SCBROOD | Broodling | BARRACKS | 600 / none | `SCBroodBite` 10 × ROF 20, zasięg 1.93 (było 1.75, +10%), `zbrAtt00` | 12 | 75 | 1 / 0–6 / 7–11 |
| SCINFT | Infested Terran (**pojazd**, War Factory, zob. Poprawka 3) | BARRACKS, RADAR | 1200 / none | `SCInfestBlast` 800, **`Suicide=yes`**, zasięg 1.5, `SCInfestWH` CellSpread 2 | 7 | 800 | pojazd SHP 32 kierunki: postój 0, chód zestawy 0–7, strzał 0 |
| SCLURK | Lurker | BARRACKS, RADAR | 2500 / medium | `SCLurkerSpine` 50 × ROF 50, zasięg 8.5, splash 1 (atakuje bez zakopywania) | 8 | 1500 | 0 / 0–6 / 0; cień `zzluShad` |
| SCDEFIL | Defiler | BARRACKS, TECH | 1600 / none | `SCPlague` 30 × ROF 60, zasięg 5, splash 1.5, każdy pancerz 800% | 7 | 1400 | 0 / 0–7 / 0–2; cień = ciało |

- Drone **nie zbiera** surowców (zbieracz w TS musi być pojazdem). Lurker nie zakopuje się: TS nie ma deploy dla piechoty.
  Defiler zamiast czarów ma obszarową „Plagę”.
- Dźwięki Zergów przeniesione na **[SoundList] 1100+** (950–997 było za ciasne), regex własnych wpisów:
  `^(9[5-9]\d|1[1-9]\d\d)=SC(ZL|HY|UL|DN|BL|IT|LK|DF)`, a dla `[InfantryTypes]` `^SCZ\d+=`. Przedrostki dźwięków: Drone `SCDN`
  (`SCDR` zajmuje Dropship), Broodling `SCBL`, Infested `SCIT`, Lurker `SCLK`, Defiler `SCDF`.
- Wszystko **(niezweryfikowane w grze)**, zwłaszcza cień-ciało Drone'a i Defilera oraz splash Lurkera.

## Poprawka 3 (2026-10-25, sesja mapowa): crash przez Infested Terrana

Test użytkownika: gra wywala się `EXCEPTION_ACCESS_VIOLATION` przy ataku Infested Terrana. EIP `004D8A62`, `mov edx,[esi]`
z `ESI=0`, stos: `InfantryClass::AI+0x161` ← `InfantryClass::Ready_To_Commence+0x4C`.
- **Przyczyna (kod Vinifery `_TechnoClass_Fire_At_Suicide_Patch` @ `0x0063039B`):** przy `Suicide=yes` hak robi
  `Take_Damage(MaxStrength, C4Warhead)` na strzelcu i oddaje sterowanie `Fire_At`, żeby pocisk poleciał. Piechota ginie
  w środku własnego ataku, śmierć czyści jej cel, a `InfantryClass::AI` dalej obsługuje strzał i sięga po pusty cel.
  Samoloty Vinifera wprost pomija („crash”), piechoty nie. W DTA `Suicide=yes` mają tylko pojazdy (`DTRK`, `VMINE`, `SEAMINE`, `BLDCNSTU`).
- **Poprawka:** `SCINFT` jest teraz **pojazdem SHP** (`[VehicleTypes] SCZV01`, układ klatek jak `SCMARINE`: postój 0–31,
  chód 32–287 po 8 na kierunek, strzał 288–351, cienie z `zbgshad`), lokomotor pojazdu jak Marine (`{4A582741-…}`, `SpeedType=Track`, `MovementZone=Normal`), `Explosion/ScrapExplosion=FBALL1`.
  Buduje się w **War Factory** (nie w koszarach), wymagania bez zmian. `SCZ06` usunięte z `[InfantryTypes]`. Zasięg 1.5,
  bo pojazd nie wjedzie do komórki celu. Medyk go nie leczy, za to regeneruje się (`SelfHealing`).
- **Zasada:** `Suicide=yes` tylko dla pojazdów (zob. [[engine/weapons-and-warheads]]).
- (niezweryfikowane w grze) czy po samobójczym „strzale” pocisk zadaje 800 obrażeń. `DTRK` ma broń `Damage=0` i obrażenia
  z wybuchu śmierci. Jeśli wybuch nic nie rani, to plan B: `Damage=0` w broni i obrażenia z `Explodes=yes`/`DeathWeapon`.

## Poprawka 4 (2026-10-25): „zacinanie” przy ataku = za krótka animacja strzału

Zgłoszenie: „jak daję atak, jednostki się zacinają” (wszystkie jednostki SC). Sonda `tools/morphprobe.ps1 -TraceInfantry`
(pola `InfantryClass` z `Vinifera.pdb`: `Doing` +0x354, misja +0x4C, cel +0x11C) na grze Protossami pokazała, że TS gra klatki
`FireUp` po **1 ticku na klatkę**. Animacja strzału trwała 5–10 klatek, a odstęp między strzałami 31–115 klatek (Zealot 5/31,
Dragoon 8/44), więc przez 80% czasu jednostka stała w pozie stania i przeskakiwała do pozy ataku przy każdym strzale.
Postoje w marszu (1–2 klatki `doing 0` na granicy komórki) są normalne. Poprawka w `build-sczerg.ps1`: listy `Fire` według
iscriptu SC (anim 2) z czasem SC, czyli każda klatka 2× (1 tick SC ≈ 2 ticki TS przy 45 FPS) plus klatki powrotne, a `FireFrame` w punkcie
`ATTACK`/`melee`. Hydralisk 20 klatek (strzał na 10.), Zergling 10 (4.), Broodling 10 (4.), Ultralisk 19 (7., skalowany do `ROF 20`),
Defiler 12. Frakcja Zerg dostaje to przez `Image=`. **Ta sama metoda dla Protossów** (`build-scprotoss.ps1`, `Fire = 0..4` itd.) i Terran.
(niezweryfikowane w grze)

## Grafika (zob. [[engine/shp-graphics]], piechota)

| Jednostka | Kadr SHP | Postój | Chód | Atak | Śmierć |
|---|---|---|---|---|---|
| Zergling | 86×60 | zestaw 5 | zestawy 5–11 (7) | 0–4 (5), `FireUp=2` | klatki 289–295 + `zzedeath` 0–4 |
| Hydralisk | 74×68 | zestaw 0 | 5–11 (7) | 0–4 (5), `FireUp=3` | `zhydeath` 0,0,1,1,2,3 (hydra.grp nie ma krwi) |
| Ultralisk | 108×110 | zestaw 0 | 0–8 (9) | 9–14 (6), `FireUp=3` | 255–264 + `zuldeath` 0–4 |

Zestawy GRP (17 kierunków każdy) ustalone na arkuszach klatek. Zergling i hydra: 12–16 to zakopywanie się (burrow), nieużyte.
Kierunek TS `f` → kierunek SC (32) `[0,28,24,20,16,12,8,4][f]`, ponad 16 z lustrem. Cameo: klatka postoju w kierunku SE,
przeskalowana do 64×48 (`ScInfantry.Cameo`). Rozmiar sprite'ów jak w SC (ultralisk jest naprawdę duży).

## Do sprawdzenia w grze

1. Widać je (z zaznaczonym STARCRAFT) tylko u Terran (Barracks) i Zergów (Spawning Pool); Ultralisk dopiero z Science Facility / Evolution Chamber.
2. Animacje: chodzą w dobrą stronę (kolejność kierunków piechoty), atakują wręcz, hydra strzela też w lotnictwo.
3. Śmierć: krwawa eksplozja i znikające szczątki, krzyk.
4. Kilka zerglingów w jednej komórce (pozycje podkomórkowe piechoty), regeneracja HP.
5. Balans (wartości to pierwsze przybliżenie).

## Pominięte / pomysły

Burrow, Lurker, Defiler, Infested Terran, latające Zergi (Mutalisk itd.), ulepszenia (Metabolic Boost, Adrenal Glands),
pary zerglingów z jednego zakupu, budynki Zergów.
