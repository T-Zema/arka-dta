# Assety StarCrafta: Remastered (CASC), GRP, palety, portrety

Skąd brać grafikę i dźwięk ze StarCraft: Remastered użytkownika i w jakim są formacie.

Źródła: instalacja `C:\Program Files (x86)\StarCraft` (build 1.23.10.13515, `.build.info`), `tools/Casc.cs`, `tools/ScBuild.cs`.

## Archiwum CASC

- `Data/config/xx/yy/<BuildKey>`: build config (`root`, `encoding`); `Data/data/*.idx` (v7, 18 B na wpis); `data.00x` (BLTE).
- Root StarCrafta jest **tekstowy**: linie `ścieżka|ckey`, 52 498 plików. Czytnik: `tools/Casc.cs` (`new Casc(dir)`, `.Root`, `.ReadFile(path)`). Obsługuje BLTE N/Z.
- W archiwum są **stare formaty SD** (łatwe) i nowe HD (`anim/*.anim`, `*.dds.grp`, `HD2/`, `Carbot/`, skin Cartooned).

## Przydatne ścieżki

| Co | Ścieżka | Format |
|---|---|---|
| Sprite jednostki | `unit/terran/marine.grp` (też firebat, ghost, medic, scv, vulture, tank…) | GRP SD |
| Cień | `unit/terran/tmashad.grp` (`t??shad.grp`) | GRP |
| Szczątki po śmierci | `unit/terran/tmadeath.grp` | GRP |
| Palety | `TileSet/<tileset>.wpe` (256×RGBA), `game/tunit.pcx` (kolory graczy, 8 na gracza) | |
| Dźwięki | `SD/sound/terran/marine/*.wav`, `SD/sound/bullet/*.wav` | PCM 22 050 Hz 16-bit mono |
| Dźwięki HD | `sound/...wav` | 44,1 kHz stereo (niepotrzebne) |
| Portrety | `HD2/portrait/t<jedn>/t??fid00.webm` (224×240), `SD/portrait/...` (mały), `portrait/...` (HD) | VP9 webm, potrzebny ffmpeg |
| Ikony przycisków | `SD/unit/cmdicons/cmdicons.dds.grp` (32×32 DXT1) | |
| Dane gry | `arr/*.dat`, `arr/images.tbl`, `scripts/iscriptx.bin` | |

## Który dźwięk gra jednostka SC przy ataku (iscript)

Nie zgadywać po nazwie pliku, tylko odczytać z danych SC. Narzędzie: `tools/ScIscript.cs` (sesja frakcji, 2026-10-25).
Ścieżka: `units.dat` (flingy, podjednostka, broń naziemna/powietrzna) → `flingy.dat` → `sprites.dat` → `images.dat`
(GRP w `images.tbl`, iscript ID od offsetu 9990) → `scripts/iscript.bin` (animacje ataku 2/3/5/6 oraz nakładki `imgol`/`sprol`
i pociski broni `attackwith`/`useweapon`) → opkody `playsnd` 0x18, `playsndrand` 0x19, `playsndbtwn` 0x1A,
`attackmelee` 0x1C (dźwięki uderzenia wręcz) → `arr/sfxdata.dat` (u32 na wpis, `len/9` wpisów) → `arr/sfxdata.tbl`.
Wyniki (kontrola: Marine = `Bullet\TMaFir00` ✓):

| Jednostka | Dźwięk ataku SC |
|---|---|
| Zergling | `Zerg\Ultra\zulHit00` (attackmelee; SC używa uderzenia Ultraliska) |
| Hydralisk | `Bullet\SpoogHit` |
| Ultralisk | `zulAtt00–02` (rand, początek ataku) + `zulHit00/01` (attackmelee, uderzenie) |
| Goliath | działko `Bullet\TGoFir00`, rakiety Hellfire `Bullet\HKMISSLE` (+ trafienie `Misc\ExploSm`) |
| Missile Turret | pocisk Longbolt `Bullet\HKMISSLE` (+ `Misc\ExploSm`) |

Ścieżki w CASC są małymi literami: `SD/sound/bullet/hkmissle.wav`, `SD/sound/bullet/spooghit.wav`.

## GRP (SC1)

- Nagłówek: `uint16 klatki, szer, wys`; na klatkę: `x, y, w, h (bajty), uint32 offset`. Linie: tabela offsetów uint16, potem RLE:
  `0x80|n` = n przezroczystych, `0x40|n` + bajt = n powtórzeń, inaczej n bajtów dosłownie.
- **Kierunki: 17 klatek (N → S przez E, co 11,25°)**, strona zachodnia to lustro. Na 32 kierunki DTA:
  `kierunek ≤ 16 → klatka kierunek`, `> 16 → 32 − kierunek` z odbiciem poziomym.
- Marine: 229 klatek = 13 zestawów × 17 + 8. Zestaw 0 = postój, 1–2 = celowanie, 3 = strzał z błyskiem,
  4–12 = chód (9 faz), 221–228 = śmierć.
- **Kolor gracza: indeksy 8–15** (kolejność jasności wg `tunit.pcx`) → mapujemy na remap DTA 16–31.

## Pliki przesunięć `.lo?` (wieże, nakładki)

`unit/terran/tank.lol` (też `goliath.lol`, `battlecr.lol`, `stank.lol`; budynki `.lof` ogień, `.lod/.lou` kurz przy lądowaniu):
`int32 liczba_klatek, int32 liczba_nakładek, int32 offset[liczba_klatek]`, pod offsetem pary `sbyte x, sbyte y` na nakładkę.
Indeks = klatka **ciała** (zestaw × 17 + kierunek). Dla kierunków lustrzanych x z minusem. Siege Tank: wieża `tankt.grp`
przesunięta o np. (−13,−10) przy kierunku E, czyli siedzi z tyłu kadłuba. Czytnik: `ScVehicle.ReadLo` w `tools/ScBuildings.cs`.

## Budynki Terran (GRP)

Źródło: arkusze klatek wszystkich `unit/terran/*.grp` budynków (sesja budynków Terran, zob. [[mods/starcraft-terran-buildings]]).

- **Klatka 0 = gotowy budynek, klatka 1 = w budowie.** Pozostałe to start/lądowanie (latające: `control`, `tbarrack`,
  `factory`, `starport`, `weaponpl`) albo etapy (`refinery` 1–4). Missile Turret: `missile.grp` 2 = sama podstawa,
  głowica w `missilet.grp` (0–16 = 17 kierunków, 17–33 drugi wariant).
- **Nakładki `<nazwa>t.grp`** (`controlt`, `depott`, `academyt`, `chemlabt`, `weaponpt`, `factoryt`, `starpot`, `researct`,
  `comsatt`, `nukesilt`): światła i ruchome elementy, ten sam środek kanwy co budynek. `comsatt` = obracająca się antena (10 klatek).
  `pillboxt` to błyski strzałów bunkra (17 kierunków), nie nakładka.
- **Sufiks `c`** (`comsatc`, `nukesilc`, `machinec`, `drydockc`, `physicsc`, `genelabc`): łącznik addonu z budynkiem-matką.
- **Rusztowania budowy:** `tbldlrg` (160×128), `tbldmed`, `tbldsml` (96×96), po 3 etapy; cienie `tb2shad`, `tb1shad`, `tb3shad`.
- Mapa nazw: `control` CC, `depot` Supply Depot, `refinery`, `tbarrack` Barracks, `weaponpl` Engineering Bay, `missile` Missile Turret,
  `academy`, `pillbox` Bunker, `factory`, `starport`, `research` Science Facility, `chemlab` Armory, `comsat`, `nukesilo`,
  `machines` Machine Shop, `drydocks` Control Tower, `physics` Physics Lab, `genelab` Covert Ops.
- Cienie: `tccshad` CC, `tdeshad` depot, `treshad` refinery, `tbrshad` barracks, `twpshad` e-bay, `tmishad` turret, `tacshad` academy,
  `tpbshad` bunker, `tfashad` factory, `tspshad` starport, `trlshad` science, `tclshad` armory, `tcsshad` comsat, `tnsshad` silo,
  `tmsshad`, `tddshad`, `tplshad`, `tglshad` addony. Numeracja klatek jak w budynku.
- Rozmiar w pikselach = kafle SC × 32 (CC 4×3 kafle → ok. 128×100 px obrazu).

## Portret na ikonkę

`ffmpeg -i tmafid00.webm -frames:v 1 portrait.png` → przycięcie do 4:3 (224×168 od y=40) → skalowanie HQ do 64×48 →
kwantyzacja do `CAMEO.PAL`. ffmpeg w wersji przenośnej (gyan.dev essentials) siedzi w scratchpadzie sesji. Do kolejnych
jednostek trzeba go pobrać ponownie albo zainstalować na stałe.
