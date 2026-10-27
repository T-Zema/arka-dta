# Mod: badania StarCrafta (ulepszenia jako ulepszenia budynków)

Ulepszenia z SC jako badania montowane na odpowiednich budynkach i przybudówkach Terran, tak jak Ion Cannon Uplink GDI na Comm Center. Każde badanie odblokowuje ulepszoną wersję jednostek w fabryce. Opcja **STARCRAFT**. Stan: zainstalowany 2026-10-25, **(niezweryfikowane w grze)**.

Źródła: dane SC `arr/upgrades.dat`, `arr/techdata.dat`, `rez/stat_txt.tbl` (numery ikon, nazwy, koszty), `SD/unit/cmdicons/cmdicons.dds.grp`
(ikony, DXT1), kod Vinifery `Has_Prerequisite` / `Who_Can_Build_Me` (zob. [[engine/tech-and-prerequisites]]).

## Pliki

- `Modding/tools/build-scresearch.ps1`: **generator**. Za każdym uruchomieniem odtwarza:
  - blok „StarCraft research” na końcu `INI/Game Options/StarCraft.ini` i `INI/Art.ini`;
  - wpisy `SCR01–SCR11` (badania) i `SCX90` (Siege Mode) w `[BuildingTypes]`, `SCX01–SCX11` w `[VehicleTypes]`;
  - linie `Upgrades=N` u rodziców;
  - `MIX/ECACHE87.MIX` (ikonki badań, puste SHP badań, kopie SHP jednostek, złote cameo). Numer z rejestru w [[engine/shp-graphics]].
    Pierwsza wersja przez pomyłkę pisała do 89 (latające budynki sesji frakcji) i je skasowała. Sesja frakcji odtworzyła je swoim `build-scliftoff.ps1`.
- Jednostki bazowe kopiuje z bloków innych sesji, łącząc sekcje powtórzone w późniejszych „patchach” i `$Inherits`. Ich sekcji nie zmienia.
  **Po każdej zmianie jednostek bazowych (statystyki, grafika) trzeba uruchomić generator ponownie**, bo kopie się zestarzeją.
- Generator czyta i zapisuje cały `StarCraft.ini`. Nie uruchamiaj go, gdy inna sesja akurat edytuje ten plik (raz złapał w locie zmianę zasięgów Zergów i ją zachował).

## Badania

| ID | Badanie (SC) | Budynek | Ikona SC | Koszt | Ulepsza |
|---|---|---|---|---|---|
| SCRINF | Infantry Weapons & Armor | Engineering Bay (`SCEBAY`) | 288 | 1200 | Marine, Firebat, Ghost, Medic |
| SCU238 | U-238 Shells | Academy (`SCACAD`) | 238 | 1800 | Marine |
| SCRCAD | Caduceus Reactor | Academy | 384 | 1800 | Medic |
| SCROCU | Ocular Implants | Covert Ops (`SCCOVO`) | 249 | 1200 | Ghost |
| SCRVEH | Vehicle Weapons & Plating | Armory (`SCARMO`) | 289 | 1200 | Vulture, Siege Tank, Goliath |
| SCRSHP | Ship Weapons & Plating | Armory | 290 | 1200 | Wraith, Valkyrie, Battlecruiser, Science Vessel |
| SCRION | Ion Thrusters | Machine Shop (`SCMSHP`) | 287 | 1200 | Vulture |
| SCRCHA | Charon Boosters | Machine Shop | 380 | 1200 | Goliath |
| SCRCLK | Cloaking Field | Control Tower (`SCCTWR`) | 252 | 1800 | Wraith |
| SCRCOL | Colossus Reactor | Physics Lab (`SCPHYS`) | 285 | 1800 | Battlecruiser |
| SCRTIT | Titan Reactor | Science Facility (`SCSCIF`) | 248 | 1800 | Science Vessel |

Koszt w skali innych sesji: (minerały + 2 × gaz) × 4. Rodzice: `Upgrades=` E-Bay 1, Academy 2, Armory 2, Machine Shop 2, pozostałe 1.

## Spider Mines (2026-10-25, wersja 2: miny tylko w Vulture'ach)

Prośba użytkownika: min nie da się kupić, są tylko w Vulture'ach i pojawiają się po badaniu.
- Badanie **SCRSPM Spider Mines** (Machine Shop, ikona SC 243, 1200 $, Machine Shop `Upgrades=3`). Upgraded Vulture
  (`SCVULT2`) wymaga teraz `SCRVEH + SCRION + SCRSPM` (wszystkie jego ulepszenia z SC) i ma **3 miny**.
- **Mechanizm:** TS nie ma stawiania min ani startowego ładunku, a spawner Vinifery tworzy tylko samoloty. Dlatego
  **deploy Vulture'a = `DeploysInto` budynek-mina**, a ten budynek ma **`FreeUnit=`** (mechanizm rafinerii z TS) = ten sam
  Vulture z jedną miną mniej, który pojawia się obok: `SCVULT2` (3) → `SCSPMB3` + `SCVULT2B` (2) → `SCSPMB2` + `SCVULT2C` (1)
  → `SCSPMB1` + `SCVULT2D` (0, bez deploy). Wersje B/C/D mają `TechLevel=-1` (nie do kupienia).
- Budynek-mina jak lądowa mina DTA `VMINE`: 1×1, `Cloakable=yes`, `Selectable=no`, broń `MineSuicide` (`Suicide=yes`),
  wybuch `Explosion`/`ScrapExplosion=MINEBOMB` (250 dmg, `MINEWH`: ×10 na ciężki pancerz), `GuardRange=3`, `DeploySound=SCSPMIN0`.
  Grafika: zakopany pająk (`spider.grp` klatka 11), kanwa 48×72 (środek kanwy = górny wierzchołek rombu, pająk na środku pola).
- Wersja 1 (miny-piechota kupowane w koszarach i wożone jako pasażerowie) usunięta, razem z liniami `Passengers`/`PipScale` w `[SCVULT]`.
- **(niezweryfikowane w grze)**: czy `FreeUnit` działa dla budynku powstałego z deploy (u rafinerii działa przy budowie),
  gdzie pojawia się nowy Vulture, czy `Suicide=yes` działa dla budynku (`VMINE` w DTA ma `TechLevel=-1`, więc nie jest
  pewne, że ktoś go ostatnio testował). Skutki uboczne: nowy Vulture ma pełne HP, traci weterana i zaznaczenie.
## Ulepszone jednostki (max 2 ikonki na jednostkę)

Każda jednostka ma jedną ulepszoną wersję (`<ID>2`, złota ramka i szewrony na cameo). Wymaga wszystkich badań, które w SC ją poprawiają:

| Wersja | Wymaga (oprócz wymagań bazy) | Zmiany |
|---|---|---|
| SCMARINE2 (blok marine'a) | SCRINF + SCU238 | (istniejąca: zasięg 7.34, 20 dmg, 1100 HP) |
| SCFIRE2 / SCFIRE2S | SCRINF | HP ×1,25, obrażenia ×1,3 (stimpack zachowany) |
| SCGHOST2 | SCRINF + SCROCU | HP ×1,25, obrażenia ×1,3, wzrok +3, zasięg ×1,15 |
| SCMEDIC2 | SCRINF + SCRCAD | HP ×1,25, leczenie co 0,7 czasu |
| SCVULT2 | SCRVEH + SCRION | HP ×1,25, obrażenia ×1,3, prędkość 14 → 21 |
| SCSIEGE2 + SCSIEGB2 | SCRVEH | HP ×1,25, obrażenia ×1,3, własny Siege Mode (`SCSIEGB2`, rozkłada się z powrotem w `SCSIEGE2`) |
| SCGOLI2 | SCRVEH + SCRCHA | HP ×1,25, obrażenia ×1,3, Hellfire AA zasięg +3 |
| SCWRAF2 | SCRSHP + SCRCLK | HP ×1,25, obrażenia ×1,3, **maskowanie** |
| SCVALF2 | SCRSHP | HP ×1,25, obrażenia ×1,3 |
| SCBCF2 | SCRSHP + SCRCOL | HP ×1,25, obrażenia ×1,3, Yamato co 0,6 czasu |
| SCVESF2 | SCRSHP + SCRTIT | HP ×1,25, EMP co 0,6 czasu |

Bronie ulepszonych wersji to kopie z sufiksem `U` (np. `SCHellfireU`).

## Odstępstwa od SC (ograniczenia silnika)

- Badanie **nie ulepsza istniejących jednostek**, tylko odblokowuje ulepszoną wersję w fabryce. Silnik nie ma ulepszeń globalnych.
- **Starej wersji nie da się ukryć** (brak wymagań negatywnych). W pasku są 2 ikonki na jednostkę.
- Poziomy 1–3 Weapons/Armor/Plating połączone w jedno badanie na klasę (piechota / pojazdy / statki).
- Pominięte, bo jednostki bazowe już to mają albo nie istnieje mechanika: Stim Packs, Siege Mode, Lockdown, Personnel Cloaking,
  Yamato Gun, EMP Shockwave (bazy mają te zdolności od razu), Spider Mines, Irradiate, Restoration, Optical Flare, Apollo, Moebius.
- Bohaterowie (Raynor, Duke), SCV i Dropship nie mają ulepszonych wersji.
- Badanie liczy się tylko przy zasilanym budynku-rodzicu (`IsOn`).
