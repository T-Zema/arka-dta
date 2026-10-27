# Misja: Frostbite (M_FROSTBITE)

Aliancka misja dodatkowa autorstwa Rampastringa. Trzeba zniszczyć sowiecki silos atomowy, zanim odpali.

Źródła: `INI/Battle.ini` (`[M_FROSTBITE]`), `Maps/Missions/FRSTBITE.MAP.bak` (stan oryginalny), `spawn.ini`.

## Dane

- Plik: `Maps/Missions/FRSTBITE.MAP` (oryginał: `FRSTBITE.MAP.bak`), `Side=2` (Allies), kategoria `CAT_SA`,
  poziomy trudności NORMAL/HARD/BRUTAL. Użytkownik gra na **Brutal**.
- `[Map] Theater=Temperate`, `[INISystem] BasedOn=../../INI/Map Code/AI Discounts Enhanced.ini`.
- Gracz: `[Allies]` `Credits=80` (8 000 $), `TechLevel=10`.
- Baza startowa gracza (bez Construction Yardu): AWEAP, RAPROC, RATENT, RAFIX, 2× RAAPWR, RADOME, 2× RAPOWR,
  AHPAD, mury BRIK, działka RAGUN, bunkry RAHBOX/RAPBOX. Wnętrze bazy to ok. x 80–95, y 78–93.
- Jednostki startowe: 7× 2TNK, 2× RANG, harvester, piechota E1A/E3A.

## Ograniczenia autora (oryginał)

- `[2TNK] Prerequisite=AWEAP,RAFCOM`: Medium Tank zablokowany (RAFCOM nieosiągalny).
- `[AMCV]`/`[SMCV] TechLevel=-1`: brak MCV, czyli brak budowania bazy.
- Do zbudowania zostają: Ranger, Light Tank, artyleria, APC.

## Wrogowie

`Soviet` i `Soviet2` z AI3TNK, AITTNK, AIV2RL, AI4TNK, MiG-ami i Shock Trooperami. Ataki falami według triggerów czasowych.
Nadpisane `[MultiLauncher]` (głowica atomowa) i `[NewAtomicWH]`.

Moje zmiany w tej misji: [[mods/frostbite-cheats]].
