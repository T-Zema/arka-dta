# Katalog: unikalne jednostki zdefiniowane w mapach DTA

Typy, których nie ma w Rules.ini, bo autorzy map dodali je dla pojedynczych misji. Można je kopiować do innych map (z zależnościami: broń → głowica → pocisk).

Źródła: skan `Maps/**/*.map` i `INI/Game Options/Extreme AI.ini` (2026-10-23), skrypt z [[workflow/tooling]].

## Najciekawsze

| ID | Nazwa | Mapa źródłowa | Image | Cameo? | Broń / cecha |
|---|---|---|---|---|---|
| BUNZILLAM/E/H/B | Bunzilla | `Maps/Co-Op/bunny_lockdown.map` | BUNZILLA | ✗ | 48 000–192 000 HP, `BunzillaChemM` + `BunzillaShard` |
| LASERBUNNY | Cute Laser-Eyed Bunny | bunny_lockdown | BUNNYBR | ✗ | `BunnyLaserEyes` |
| EMPBUNNY | EMP Bunny | bunny_lockdown | BUNNYBLU | ✗ | `BunnyEMPWeapon` (EMP) |
| MTNTBUNNY | Mutant Bunny | bunny_lockdown | BUNNYARM | ✗ | 20 000 HP |
| CHEMBUNNY, SHARDBUNNY, BOMBBUNNY, ELITEBUNNY, LREGBUNNY, REGBUNNY | króliki | bunny_lockdown, eastermission1 | BUNNY* | ✗ | |
| CIVCMD | Commando (jumpjet) | `Maps/Default/deceptive_wonderland.map` | JUMPJET | ✓ | `EpicRailgun` zasięg 20 |
| CIVE4 | Flamethrower Commando | deceptive_wonderland | E4 | ✓ | `EpicFlamer` zasięg 20 |
| ROBLI | Obelisk of Brightness (budynek) | deceptive_wonderland | OBLI | ✓ | `WhiteLaser` ROF 0, ukrywa jednostki w promieniu 12 pól |
| ALLUNIT1 | SS-22N Nuke Launcher | `Maps/Default/car_park.map` (też dantes_desert, emerald_canyon, tiber) | V2RL | ✓ | `NUKESCUD`, głowica z `ATOMSFX` |
| SOVIETUNIT1 | Chemical Mammoth Tank | `Maps/Default/the_experiment_lab.map` | 4TNK | ✓ | `Chem120mm` |
| NODUNIT1 | Beam Cannon | the_experiment_lab | MHQ | ✓ | `LaserBeamCannon` zasięg 18 |
| ALLIEDUNIT1 | Chrono Ranger | the_experiment_lab | RANG | ✓ | |
| BRIGCHEM | Battle Rig (Chemical-enhanced) | `Maps/Missions/crb16.map` (też crc13, crc16) | BRIG | ✗ | 80 000 HP, `BRig16InchChem` |
| SCRRAMBO | Yarvelja | `Maps/Missions/crb15.map` (też crb14, crc10) | VOLKOV | ✓ | `GyroJetRifle`, leczy się |
| SUPATWR | Super Advanced Guard Tower | `Maps/Missions/se02.map` | ATWR | ✓ | 40 000 HP, `SuperTowerMissile` |
| GANG1/GANG2 | Gangster | `Maps/Missions/se03.map` | ARND / GGI | ✓ | zwykły MG/AMR |
| DP941 | Project 941 (wynurzony) | se09.map | P941 | | okręt |
| CMDR | Commander | tte*.map | E5 | | `XORail` |

## Mniej ciekawe (cywilne i techniczne)

Cywilne wieże i działka (CGUN, CATWR, CTWR, CSAM), cywilne budynki (CHQ, CMISS, CFACT, CSYRD), wraki (DBSS,
WRKCRUIS), wilki (WOLF), atrapy rozkładające się w budynki (DMMY*, DEP*, FAMCV), wersje `*U`/`_AI` budynków.

## Zależności, które trzeba kopiować razem z jednostką

- `RLLine` (projektor laserów AA+AG) nie istnieje w Rules.
- Broń, głowica i pocisk z mapy źródłowej. Animacje (`ATOMSFX`, `TWLT100`, `CRUMUZ_*`, `VEH-HIT3`, `GFIRE*`)
  są w Art.ini, więc działają wszędzie.
- **Nie kopiuj** nadpisań typów z Rules zrobionych przez mapę źródłową (np. `[LLine] AA=yes`, `[Shard] Wall=yes`),
  bo zmieniają globalnie inne bronie.
