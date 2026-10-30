# Budynki neutralne StarCrafta (Power Generator, Starbase, Psi Disrupter, Ion Cannon, Stasis Cell)

Neutralne budynki SC z własną grafiką jako budynki DTA, do stawiania przez mapy (miasta, kolonie, garnizony). Prośba użytkownika 2026-10-30: wykorzystać podgląd `sc_neutral.png` (zrobiły go sesje misji 6 i 7), zwłaszcza Starbase i Power Generator. Stan: **zbudowane, użyte w misji 3, niezweryfikowane w grze**.

Źródła: CASC `unit/neutral/*.grp`, `arr/units.dat` (pole placement box od bajtu 11284, `u16 w, u16 h` na jednostkę), `arr/flingy.dat`, `arr/sprites.dat`, `arr/images.dat` + `images.tbl` (nazwa GRP, a cień to obraz zaraz po nim), arkusze `%TEMP%\arka06-mission\sc_neutral.png` i scratchpad sesji misji 7 `sc_neutral_sheet.png`, [[missions/arka-07-zdrada]] („Budynki neutralne SC”), `Modding/tools/build-scneutral.ps1`.

## Budynki

| ID | Budynek SC | GRP / cień | Fundament | Uwagi |
|---|---|---|---|---|
| `SCNGEN` | Power Generator (jednostka 200) | `Generate` / `tgnShad` | 4×3 | cywilna elektrownia Terran z dwiema turbinami; GRP ma 7 klatek, użyta klatka 0 |
| `SCNSTB` | Starbase (nieużywany w SC) | `starbase` / brak | 3×3 | niebieska stacja; żadna jednostka SC jej nie używa, w `images.tbl` jej nie ma |
| `SCNPSI` | Psi Disrupter (190) | `PsiDisr` / `tpdShad` | 5×3 | |
| `SCNION` | Ion Cannon (127) | `ion` / brak | 4×3 | pole SC to tylko 3×2, a kopuła wystaje, więc 4×3 |
| `SCNSTA` | Stasis Cell (168) | `stasis` / brak | 4×3 | komora z uwięzionym stworzeniem |

Pozostałe neutralne obiekty SC (Cantina, Independent CC/Starport, Jump Gate, Ruins) w `units.dat` mają grafikę Scouta, czyli są puste. Domy i sklepy badlands to doodady terenu, nie budynki, zob. [[missions/arka-07-zdrada]].

## Pliki

- `Modding/tools/build-scneutral.ps1`: GRP → SHP przez `ScBuildingShape` (jak budynki Terran, [[mods/starcraft-terran-buildings]]): klatka 0 normalna, 1 uszkodzona, 2–3 cienie. Paleta i kolor gracza jak w `build-scterran.ps1`, `Remapable=yes` (fiolet na podglądzie to kolor domu). Bez buildupu i bez cameo, bo nikt tego nie buduje. `-WhatIf` robi tylko podglądy w `%TEMP%\scneutral-preview\fit_<ID>.png`.
- `MIX/ECACHE75.MIX` (5 SHP, rejestr w [[engine/shp-graphics]]).
- `INI/Art.ini`, blok `; >>> SC neutral buildings`: `Foundation`, `Height`, `Remapable=yes`, `NewTheater=no`. Skrypt podmienia własny blok.

## Użycie w mapie

Reguły są w mapie, bo misje kampanii nie czytają opcji gry. Sekcja nazywa się jak grafika, więc `Image=` nie jest potrzebny:

```ini
[BuildingTypes]
ARKA3B04=SCNGEN
[SCNGEN]
Name=Generator miejski Antigi
Strength=1500
Armor=concrete
TechLevel=-1
Power=0
Capturable=false
ThreatPosed=0
```

Wzór: `build-arka03-mission.ps1` (`$neutralSc`), gdzie skrypt rzuca błąd, gdy w Art.ini nie ma sekcji (najpierw `build-scneutral.ps1`).

| Gdzie | Co |
|---|---|
| [[missions/arka-03-sygnal]] | przedmieścia Antigi: `SCNSTB` (stacja kosmiczna, środek miasta), `SCNGEN` (generator miejski); garnizon Konfederacji: `SCNION` (działo jonowe, ozdoba bez broni) |
| [[missions/arka-06-ogien-z-nieba]] | kolonia Antioch na wyspie SE (dom `Neutral`, `build-arka06-mission.ps1`): 2 × `SCNGEN` (przy administracji i dzielnicy górniczej), `SCNSTB` (przy porcie kosmicznym) |
| [[missions/arka-07-zdrada]] | miasto Dominium: do decyzji sesji misji 7 |

Pomysły na dalsze misje: `SCNPSI` (Psi Disrupter z SC) do misji 10–11, `SCNSTA` do laboratorium agenta Nod (misja 9).

## Do sprawdzenia w grze

- Czy budynki stoją na fundamencie (podglądy `fit_*` pasują, ale render CNCMaps nie zastępuje gry).
- Czy kolor domu (fioletowe piksele) wygląda dobrze na budynkach `Neutral` (szary).
