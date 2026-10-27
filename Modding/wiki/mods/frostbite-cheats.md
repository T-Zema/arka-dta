# Mod: Frostbite cheats (2026-10-23/24)

Zestaw ułatwień i ukrytych jednostek wpisany bezpośrednio do misji Frostbite. Działa tylko w tej misji.

Źródła: `Maps/Missions/FRSTBITE.MAP` (wersja zmodowana), archiwum `Modding/archive/super-mod-v1_2026-10-24/`.
Stan: zainstalowany. Testy w grze: **brak potwierdzenia** (użytkownik nie zgłaszał problemów).

## Zmiany (wszystkie w FRSTBITE.MAP)

**Ekonomia i baza**
- `[Allies] Credits=10000` (1 000 000 $), `BuildTime=0.5` (2× szybsza produkcja gracza).
- Dodane i usunięte na prośbę użytkownika: `Firepower=1.5`, `Armor=1.5` (nie chciał tego).
- `[AMCV] TechLevel=7, Prerequisite=AWEAP`: MCV do kupienia, czyli budowa bazy i Tech Centera.
- `[AWEAP] SuperWeapon=IonCannonSpecial`: działo jonowe od startu.

**Odblokowane w War Factory** (`TechLevel=3`, `Prerequisite=AWEAP`): 2TNK (zdjęta blokada RAFCOM), TNKD, HTNK
(`Owner=GDI,Allies`), CTNK, PTNK, BFRT, TNKN, TTNKMSL, MFLAK, BEHEMOTH, O279, HTNKARTY, MRV, UTNK, 4TNK, TTNK, V2RL,
QTNK, DTRK, STNK, FTNK, TERMITE, SSM, PLSM, SCRINTNK, XO, DISCARTY, CARRTRUK. Dla jednostek innych frakcji `Owner` = oryginał + Allies.

**Koszary** (`Prerequisite=RATENT`): MGI, THIEF, TREX, RAPT, SHOK, VOLKOV, RMBO, CYP, JUMPJET.

**Helipad** (`Prerequisite=AHPAD`): ORCA, APACHE, HIND.

**Budynki** (wymagają MCV, `Prerequisite=RADOME`): OBLI, ATWR, RATSLA, TMPL (Chemical Missile), SGEN.

**Nowe typy skopiowane z innych map** (zob. [[catalog/custom-units-from-maps]]), z prefiksem `FB`:
- do budowania: FBNUKEL (SS-22N), FBCHEMMAM, FBBEAM, FBCMD (Railgun Commando, 3000 $), FBFLMCMD (2000 $), FBYARV,
  budynki FBROBLI (5000 $), FBSUPATWR (2000 $);
- postawione na starcie (bez cameo, `TechLevel=-1`): FBBRIGCHEM (93,89), FBBUNZILLA (86,90), 2× FBLASERBUN (86,89),
  FBMUTBUN (85,91), FBEMPBUN (86,91).

## Świadomie pominięte

BRIG (brak cameo, dany jako FBBRIGCHEM na mapie), okręty (niepewna ilość wody), gangsterzy (nic ciekawego),
AirstrikeSpecial (w tej misji byłby atomowy).

## Ryzyka

- Zmiana `Prerequisite` sowieckich typów (TTNK, V2RL, 4TNK, RATSLA, SHOK) na alianckie budynki. AI misji używa
  wersji `AI*`, więc wpływu nie powinno być **(niezweryfikowane w grze)**.
- Updater klienta może przywrócić oryginalną mapę.
