# Mod: bohaterowie i budynki specjalne Zergów

Brakujące jednostki i budynki Zergów z SC (bohaterowie i budynki z kampanii) dla frakcji Zerg ([[mods/zerg-faction]], dom `Nod1`). Stan: zainstalowany 2026-10-25, **(niezweryfikowane w grze)**.

Źródła: dane SC z CASC (`arr/units.dat`: HP, pancerz, koszt, rozmiary, dźwięki „what/yes/pss”; `arr/weapons.dat`; `images.dat`/`images.tbl`:
GRP i cienie; `scripts/iscript.bin`: zestawy klatek Kerrigan i Durana), `unit/zerg/*.grp`, `unit/neutral/kerrChry.grp`, `unit/terran/ghost.grp`,
`SD/sound/zerg/zergkerri`, `zergduran`; wzorce [[mods/zerg-faction]] (morf z kokonu, drony), [[mods/starcraft-terran-units]] (złoci bohaterowie),
[[engine/superweapons]] (unikalna `Action`), [[engine/ini-layering]] (scalanie sekcji).

## Drzewko

```
Lair ── Overmind ─┬─ Cerebrate ─┬─ wszyscy bohaterowie
                  │             ├─ (+Hive) Cerebrate Daggoth ── Torrasque, Unclean One, Kukulza (Guardian)
                  │             └─ (+Queen's Nest) Mature Chrysalis ── Infested Kerrigan
                  └─ (+Hive) Overmind (Shelled): supermoc Overmind's Wrath
Cerebrate + Infested Command Center ── Infested Duran
```

## Budynki (dron z `DeploysInto`, kokon SC, jak reszta Zergów)

| ID | Budynek (SC) | GRP / cień | Fund. | Koszt | HP | Morf | Rola |
|---|---|---|---|---|---|---|---|
| SCZOVM | Overmind (bez pancerza, SC 148) | Over2 / zo2shad | 5x3 | 4000 | 20000 | 150 s SC | `Sight`/`SensorsSight` 20, wymóg Cerebrate |
| SCZOVS | Overmind (Shelled, SC 147) | Over1 / zo1shad | 5x3 | 8000 | 40000 heavy | 180 s SC | supermoc `SCZWrathSpecial` |
| SCZCRB | Cerebrate (SC 151) | UCereb / zucShad | 3x2 | 2000 | 12000 | 80 s SC | wymóg bohaterów, wykrywanie 12 |
| SCZDAG | Cerebrate Daggoth (SC 152) | UCereb (złoty) | 3x2 | 4000 | 24000 heavy | 100 s SC | wymóg 3 bohaterów, wykrywanie 16 |
| SCZCHR | Mature Chrysalis (SC 150) | neutral\kerrChry / nkoShad | 2x2 | 2400 | 2000 | 60 s SC | wymóg Infested Kerrigan |

Drony `SCZDOVM`, `SCZDOVS`, `SCZDCRB`, `SCZDDAG`, `SCZDCHR` (koszt 200 + budynek). Drony Overmindów, Daggotha i Chrysalis mają `BuildLimit=1`:
limit liczy drony, a nie budynki, więc po rozłożeniu drona da się zbudować kolejnego (silnik nie ma limitu dla budynków z deployu).
Wszystkie budynki: `Repairable=no`, regeneracja do pełna (0,2% HP na krok), `Unsellable=yes`.

**Supermoc `SCZWrathSpecial` „Overmind's Wrath”** (w `Rules.ini`, wzór `SCNukeSpecial`): `Type=IonCannon` (uderza od razu w dowolne miejsce,
budynek nie potrzebuje animacji startu), `Action=NuclearStrike3` (jedyna wolna akcja z kursorem celownika; `NuclearStrike2` ma nuka Terran),
`IsPowered=false`, `RechargeTime=8.5`, ikona `SCZWRATH` (Overmind w pancerzu). Wygląd i obrażenia jak Ion Cannon GDI.

## Bohaterowie (złoci, `BuildLimit=1`)

HP = HP bohatera z SC × 20 × 2, obrażenia = broń bazowej jednostki Zergów × (bohater SC / jednostka SC) × 1,5. Sekcje to kopie jednostek z bloku
„Zerg faction” (czytane przy generowaniu), z własnym `Image=`, złotą grafiką (`ScUnits.TintMap` jak Duke) i złotą ramką cameo.

| ID | Bohater (SC) | Baza | Skąd | Wymaga | HP | Broń | Koszt |
|---|---|---|---|---|---|---|---|
| SCZHDO | Devouring One | Zergling | Pool | Cerebrate | 7200 | ×3, zasięg ×1,3 (2,28), prędkość 10 | 1500 |
| SCZHHK | Hunter Killer | Hydralisk | Pool | Cerebrate | 6400 | ×3, zasięg ×1,25 | 2500 |
| SCZHTQ | Torrasque | Ultralisk | Pool | + Daggoth | 32000 | ×3,75 | 6000 |
| SCZHUO | Unclean One | Defiler | Pool | + Daggoth | 12000 | Plaga ×2,5 jako pocisk `SCZUOProj` (płonący bełt) → chmura `SCZUOHIT`, rozprysk 2 | 2000 |
| SCZHKE | Infested Kerrigan | (`uikerr.grp`) | Pool | + Mature Chrysalis | 64000 | pazury 293 × ROF 20, zasięg 2,1, burza psi `SCZHKPSI` przy trafieniu (rozprysk 1, bez własnych) | 4000 |
| SCZHDU | Infested Duran | (`terran\ghost.grp`) | Pool | + Infested CC | 12000 | C-10 98 × ROF 29, zasięg 9, ziemia + powietrze; **stale zamaskowany** (`Cloakable=yes`, `DecloakToFire=no`) | 3000 |
| SCZHKM | Kukulza (Mutalisk) | Mutalisk | Hatchery | Cerebrate | 12000 | ×3, glave wurm | 4000 |
| SCZHKG | Kukulza (Guardian) | Guardian | Hatchery | + Daggoth | 16000 | ×3, kwasowa spora jak Guardian (`SCZGAcidProj`) | 5000 |
| SCZHMA | Matriarch | Queen | Hatchery | Cerebrate | 12000 | ×2,5, ROF ×0,75 | 4000 |
| SCZHYG | Yggdrasill | Overlord | Hatchery | Cerebrate | 40000 | brak; prędkość ×2,5, wzrok +4, wykrywanie +6 | 2000 |

Kerrigan i Duran mają głosy z SC (`UKi*`, `ZDn*`, też kwestie „pss” przy zaznaczeniu) i dźwięk ataku (`UKiFir00`, `TGhFir00`), `Sound.ini` 1700+.
Pozostali używają głosów swojej bazowej jednostki (w SC też tak jest). Zestawy klatek z iscript: Kerrigan stoi w zestawie 8, chodzi 9–15 + 8,
atakuje 0–7 i z powrotem; Duran = obraz Ghosta: stoi 3, chodzi 4–11, strzela 0, 1, 2, 12, śmierć 221–228 + `tghDeath`.

## Rebalans 2026-10-25 (prośba użytkownika; niezweryfikowane w grze)

- Devouring One: prędkość −30% (15 → 10), HP +50% (4800 → 7200), zasięg +30%. Unclean One: koszt −50%, HP +20%, prawdziwy pocisk.
  Kerrigan: HP +300%, obrażenia +50%, zasięg +20%, koszt −50%, efektowne trafienie. Duran: koszt −40%, stałe maskowanie.
- **Stałe maskowanie:** Vinifera ma klucz `DecloakToFire=` (domyślnie `yes`, `technotypeext.cpp`; napis jest w zainstalowanym `Vinifera.dll`).
  Z `no` jednostka nie odsłania się przy strzale; widzą ją tylko wykrywacze (`Sensors`).
- **Pociski i efekty z SC** (MIX `ECACHE82`): glave wurm Mutaliska = obraz broni SC 48 `bullet\spores` (10 klatek) + trafienie `thingy\SporeHit`
  (dźwięk `ZQuHit02`); bełt Unclean One = `thingy\consume` 2–8 + chmura `thingy\Ensnare`; trafienie Kerrigan = `thingy\psiStorm` (`Translucent=yes`).
  Animacje trafień w `Rules.ini [Animations]` (`SCZMGHIT`, `SCZUOHIT`, `SCZHKPSI`).
- **Wszystkie Mutaliski** (też zwykły i ulepszony) strzelają teraz glave wurmami: blok „Zerg heroes” powtarza sekcję `[SCZFGlave]` z bloku
  „Zerg faction” (`Projectile`, `Speed`, `Warhead`), a klient ją scala. Jeśli sesja Zergów zmieni broń Mutaliska u siebie, to ta nadpiska wygrywa.
  Po zmianie uruchom `build-sczergresearch.ps1` (kopia `SCZFGlaveU`).

## Pliki

- `Modding/tools/build-sczergheroes.ps1` (bez parametru: `MIX/ECACHE82.MIX` + podglądy w `%TEMP%\sczergheroes-preview`; `-Install`: też INI).
- Bloki `; >>> Zerg heroes` … `; <<< Zerg heroes` w warstwie `INI/Map Code/SC Factions/030 Zerg heroes.ini` ([[engine/map-code-layers]]; własne `[BuildingTypes] ZHB01–05`,
  `[InfantryTypes] ZHI01–06`, `[VehicleTypes] ZHV01–09`; klient scala), `INI/Art.ini`, `INI/Sound.ini`, `INI/Rules.ini` (supermoc;
  `[SuperWeaponTypes]` dostaje pierwszy wolny numer, 11).
- **Po `build-sczergbase.ps1 -Install` uruchom ponownie** (kopie jednostek bazowych się zestarzeją). Skrypty z `Add-Type` w osobnych procesach.

## Do sprawdzenia w grze

1. Drony nowych budynków pojawiają się po Lair/Overmindzie/Cerebrate, morf działa (duże fundamenty 5x3).
2. Overmind (Shelled) daje ikonę supermocy; kursor celownika, strzał jak Ion Cannon.
3. Bohaterowie: tylko po jednym, złoci, Kerrigan i Duran z głosami; Duran strzela też w powietrze.
4. Wygląd Overminda (czy Over1 to wersja z pancerzem, a Over2 bez) i Chrysalis (grafika z katalogu `neutral`).

## Odinstalowanie

Usunąć warstwę `INI/Map Code/SC Factions/030 Zerg heroes.ini` i w warstwie nad nią (`040 Zerg research.ini`) ustawić
`BasedOn=020 Protoss faction.ini`. Usunąć bloki „Zerg heroes” z `Art.ini`, `Sound.ini` i `Rules.ini` (w `Rules.ini` także wpis `11=SCZWrathSpecial` w `[SuperWeaponTypes]`), wpisy `17xx=SCKI*/SCDU*`
z `[SoundList]`, plik `MIX/ECACHE82.MIX`.
