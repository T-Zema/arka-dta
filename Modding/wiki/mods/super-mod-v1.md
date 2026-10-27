# Mod: Super Mod v1 (opcja skirmisha, 2026-10-24)

Checkbox **SUPER MOD** w lobby skirmisha: 8 nowych jednostek dla każdej frakcji i 2× szybsze budowanie dla wszystkich.

Źródła: `INI/Game Options/Super Mod.ini`, `Resources/SkirmishLobby.ini`.
Archiwum: `Modding/archive/super-mod-v1_2026-10-24/` + `.zip` (razem z [[mods/frostbite-cheats]]).
Stan: zainstalowany. Testy w grze: **brak** (niezweryfikowane w grze).

## Zawartość `Super Mod.ini`

- `[General] BuildSpeed=.4` (Rules ma `.8`).
- Wszystkie jednostki: `Owner=GDI,Nod,Allies,Soviet`, `TechLevel=1`, grafika pożyczona przez `Image=`.

| ID | Nazwa | Image | Wymaga | Koszt | Broń |
|---|---|---|---|---|---|
| SMFLYMAM | Flying Mammoth | 4TNK | FACTORY,TECH | 3000 | 120mmRA + MammothTuskRA, lokomotor jumpjet |
| SMATOMTNK | Atomic Tank | 3TNK | FACTORY,TECH | 2500 | `SMAtomCannon` → `SMAtomWH` (CellSpread 2.5, ATOMSFX), limit 3 |
| SMTESLAMAM | Tesla Mammoth | HTNK | FACTORY,TECH | 2800 | `SMTeslaCannon` (TeslaWH) + MammothTuskRA, 7000 HP |
| SMPRISM | Prism Tank | 2TNK | FACTORY,RADAR | 1400 | `SMPrismLaser` (niebieski laser, Super) |
| SMGHOST | Ghost Tank | STNK | FACTORY,RADAR | 1600 | `SMGhostRail`, `Cloakable=yes` |
| SMTESLACMD | Tesla Commando | SHOK | BARRACKS,TECH | 1500 | `SMTeslaBolt`, 3000 HP, SelfHealing |
| SMSKYTROOP | Sky Trooper | JUMPJET | BARRACKS,RADAR | 1000 | `SMSkyBolt`, jumpjet |
| SMLASERTRP | Laser Trooper | E1 | BARRACKS,RADAR | 500 | `SMLaserRifle` |

## Zmiany w lobby

- `$CC34=chkSuperMod:GameLobbyCheckBox` + sekcja `[chkSuperMod]` (`CustomIniPath=INI/Game Options/Super Mod.ini`,
  `MapScoringMode=DenyWhenChecked`).
- `chkIngameAllying`: dodane `Visible=False`, bo nowy checkbox stoi na jego miejscu (zob. [[engine/client-lobby-options]]).

## Co zgłaszać / testować

- Czy Flying Mammoth lata i strzela poprawnie (wieża w trybie jumpjet).
- Balans obrażeń na głowicach `Super`/`TeslaWH` (×10).
- AI nie buduje tych jednostek (korzysta z AI.ini).

## Instalacja / odinstalowanie

Zob. `README.md` w archiwum: skopiuj `modified/` albo `original/` na katalog gry. Przy odinstalowaniu usuń też `Super Mod.ini`.
