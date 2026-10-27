# Katalog: ukryte i międzyfrakcyjne jednostki w Rules.ini

Jednostki, które istnieją w Rules.ini, ale są wyłączone (`TechLevel=-1`) albo należą do innej frakcji. Wszystkie mają ikonkę, chyba że zaznaczono inaczej.

Źródła: `INI/Rules.ini`, `INI/Art.ini` (skan skryptem z [[workflow/tooling]], 2026-10-23).

## Ukryte pojazdy (TechLevel=-1, mają cameo)

| ID | Nazwa | Pierwotny Owner | Koszt | Uwagi |
|---|---|---|---|---|
| TNKD | Tank Destroyer | Allies | 1200 | |
| TNKN | Railgun Tank | Allies | 2000 | limit 1, cameo TNKD |
| TTNKMSL | Missile Tank | Allies | 1800 | `$Inherits=CTNK` |
| 2TNKMSL | Missile Tank | wszyscy | 1800 | |
| CTNKT | Chrono Tank (wariant) | Allies | 2400 | limit 1 |
| PTNK | Phase Tank | Allies | 800 | maskowanie, limit 1 |
| BFRT | Enforcer | Allies | 2500 | 28 000 HP, produkuje piechotę po rozstawieniu, limit 1 |
| MFLAK | Anti-Aircraft Truck | Allies | 500 | |
| HVCT | Flak Hovercraft | Allies | 320 | |
| O279 | Object 279 | Soviet | 1100 | |
| BEHEMOTH | Behemoth Tank | Soviet | 2300 | `Buildability=HumanOnly`, limit 1 |
| BEHEPLSM | Beluminator | Soviet | 2300 | limit 1 |
| SHILKA | Quad Tank | Soviet | 550 | |
| GTNK | Gatling Tank | wszyscy | 550 | |
| XO | X-O Power Suit | GDI | 2000 | railgun, limit 1 |
| SMECH | Wolverine | GDI | 500 | |
| HVCSAM | Hover MLRS | wszyscy | 1300 | |
| PLSM | Illuminator | Nod | 2500 | plazma, limit 1 |
| SCRINTNK | Harbinger | Nod | 2300 | Scrin, limit 1 |
| ILHEMOTH | Ilhemoth | Nod | 2500 | limit 1 |
| SSM | SSM Launcher | Nod | 2000 | limit 1 |
| TERMITE | Termite | Nod | 1150 | laser |
| MWAVE | Microwave Tank | Nod | 975 | |
| RAIDER | Heavy Raider | Nod | 800 | |
| STAPC | Stealth APC | Nod | 950 | |
| HTNKARTY | Mammoth Artillery | wszyscy | 1700 | |
| LTNKCRUS | Heavy Artillery | wszyscy | 1500 | |
| UTNK | Devil's Tongue | wszyscy | 750 | miotacz ognia |
| MRV | Mobile Repair Vehicle | wszyscy | 975 | |
| MSA | Mobile Sensor Array | wszyscy | 950 | |
| MHQ | Mobile HQ | wszyscy | 600 | |
| JEEPPTNK, HVC, HVR, MWAVEMSAM | hum-vee rakietowy, hovercrafty, mobilny SAM | wszyscy | 500–1300 | |
| okręty: DD, DDFLAK, FLAKCORV, COASTGRD, COASTARTY, SSS, CSS, CMSUB, SMSUB, SP941, TORPCAT, SCARAB | | różni | | wymagają stoczni i wody |

**Bez cameo** (tylko do stawiania na mapie): BRIG Battle Rig (40 000 HP), HTNKMSAM Disruptor, dinozaury-pojazdy JP*, mrówki ANT*/QANT, wizceroidy, cywilne auta/pociągi/statki.

## Ukryta piechota

| ID | Nazwa | Koszt | Uwagi |
|---|---|---|---|
| MGI | Machine-Gunner | 700 | Allies, 2700 HP |
| THIEF | Thief | 500 | Allies, kradnie kasę |
| CYBORG | Cyborg | 650 | Nod |
| CYP | Cyborg Prototype | 2000 | Nod, limit 1, `Image=ECYP` |
| JUMPJET | Jumpjet Infantry | 600 | GDI |
| GRENL | Grenade Launcher | 650 | GDI |
| HIJACK | Hijacker | 800 | Nod, limit 1 |
| D1/D2 | Medic | 500 | GDI/Nod |
| TREX, RAPT, STEG, TRIC | dinozaury | 500–750 | mają cameo, brak Owner |

## Ukryte samoloty i budynki

- Samoloty: CARRY Carryall, BADGER Badger Bomber (desant), A10 (wymaga pasa ASTRP), DSHP Dropship.
  Śmigłowce ORCA/APACHE/HIND mają w `Dock=` wszystkie lądowiska, w tym `AHPAD`.
- Budynki: SGEN Stealth Generator, COMM1 Ion Cannon Uplink, RAIRON Iron Curtain (bez supermocy), NUK2O,
  LSRPOST (laserowy płot), ART/RAPARTY (artyleria), BIO, BIOE, MISS, ASTRP.

## Standardowe jednostki innych frakcji (warte pożyczenia)

4TNK, TTNK, V2RL, QTNK (M.A.D.), DTRK (ciężarówka atomowa), STNK, FTNK, DISCARTY, CARRTRUK, SHOK, VOLKOV,
RMBO, budynki OBLI, ATWR, RATSLA, TMPL (+ Chemical Missile).
