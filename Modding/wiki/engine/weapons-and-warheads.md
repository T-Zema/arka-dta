# Bronie, głowice i efekty (laser, tesla, railgun, atom)

Jak zbudowane są bronie w DTA i jakie klucze dają które efekty. Wartości pochodzą z istniejących broni.

Źródła: `INI/Rules.ini` (`[120mm]`, `[LaserFire]`, `[XORail]`, `[TTankZap]`, `[PortaTesla]`, `[Super]`, `[TeslaWH]`, `[MammothTusk]`), mapy z rozdziału [[catalog/custom-units-from-maps]].

## Obrażenia

Faktyczne obrażenia = `Damage` broni × `Modifier.<pancerz>` głowicy.
- Pancerze: `none`, `wood`, `medium`, `heavy`, `concrete`.
- Nowa składnia (Vinifera): `Modifier.heavy=120%`. Stara, nadal działająca: `Verses=a%,b%,c%,d%,e%` (kolejność jw.).
- Rozrzut: nowa składnia `CellSpread=2.5` + `PercentAtMax=25%`, stara `Spread=` (w leptonach, 256 = 1 pole).
- **Głowica `Super` ma 1000% na wszystko** (×10). Laser obeliska `Damage=200` daje 2000 na strzał.
  Skalując własne bronie na `Super`/`TeslaWH`, licz od razu ×10.

## Efekty

| Efekt | Klucze | Wzorzec |
|---|---|---|
| Laser | `IsLaser=true`, `Projectile=LLine`, `LaserInnerColor`, `LaserOuterColor`, `LaserOuterSpread`, `LaserDuration`, opcj. `IsBigLaser=true`; `Charges=no` dla broni bez ładowania | `[LaserFire]` |
| Tesla | `IsRailgun=true`, `Projectile=Invisible`, `AttachedParticleSystem=TeslaSys` (piechota: `PortaTeslaSys`), `Warhead=TeslaWH` | `[TTankZap]`, `[PortaTesla]` |
| Railgun | `Damage=0`, `AmbientDamage=150`, `IsRailgun=true`, `Warhead=RailShot`, `AttachedParticleSystem=SmallRailgunSys` | `[XORail]` |
| Atomowy wybuch | głowica z `AnimList=ATOMSFX`, `Rocker=yes`, `Bright=yes`, duży `CellSpread` | `[NUKESCUDWH]` (car_park.map) |
| Chemia | `Particle=GasCloudSys` w głowicy, `Tiberium=yes` | `[ChemAP]` |
| EMP | `EMEffect=yes` w głowicy | `[BunnyEMPWarhead]` |
| Rakiety plot | `Projectile=AGHeatSeeker2`, `MinimumRange=2` | `[MammothTusk]` |
| Maskowanie jednostki | `Cloakable=yes`, `CloakingSpeed=5` (w jednostce) | `[STNK]` |

## Broń samobójcza (`Suicide=yes`, Vinifera)

- `Suicide=yes` w broni: strzelec ginie przy strzale (`Take_Damage(MaxStrength)` w haku `Fire_At` @ `0x0063039B`), a pocisk leci dalej.
  `DeleteOnSuicide=yes`: jednostka znika zamiast ginąć (jak terrorysta z RA2).
- **Tylko dla pojazdów.** Piechota z `Suicide=yes` wywala grę w `InfantryClass::AI` (pusty cel tuż po `Ready_To_Commence`;
  test Infested Terrana 2026-10-25, [[mods/starcraft-zerg]]). Samoloty Vinifera sama pomija. W DTA używają jej `DTRK`
  (broń `[Suicide]`, `Damage=0`, obrażenia z `Explodes=yes`), miny `VMINE`/`SEAMINE` (`[MineSuicide]`) i `BLDCNSTU` (`[RangedSuicide]`).

## Pociski i projektory

- `TracerM`: pocisk czołgowy (używany przez `120mm`).
- `LLine`: linia lasera. `RLLine` (AA+AG, niewidoczna) jest zdefiniowana tylko w mapach, trzeba ją skopiować.
- `Invisible`, `Invisible2`: dla broni natychmiastowych.
- `FROG`: rakieta balistyczna (V2).

## Dźwięki, które istnieją

`OBELRAY1`, `OBELRAY2`, `TESLA1`, `SHKTROP1`, `XORAIL`, `XOLASER`, `LASTUR1`, `TNKFIRE6`, `CANNON1A`, `ROCKET1`, `ROCKET2`, `ICBM1`, `FLAMER2`.
