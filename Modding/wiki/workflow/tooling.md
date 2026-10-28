# Narzędzia i skrypty do analizy INI

Sprawdzone sposoby przeszukiwania wielkich INI DTA na tym komputerze (Windows, PowerShell 5.1).

Źródła: doświadczenie z sesji 2026-10-23/24.

## Zasady

- Narzędzie Bash bywa przenoszone przez użytkownika w tło, a hook `rtk` przerabia wyjście `grep`.
  Do wyszukiwania używaj narzędzia **Grep**, do skryptów **PowerShell**.
- Rules.ini ma ~31 tys. linii. Szukaj `^\[SEKCJA\]` przez Grep z `-A 40`, nigdy nie czytaj całego pliku.
- INI może mieć sekcje zduplikowane i komentarze po `;` w wartościach. Przy parsowaniu odcinaj `;.*`.
- **PowerShell nie rozróżnia wielkości liter w nazwach zmiennych.** `foreach ($b in $B)` nadpisuje `$B` ostatnim elementem.
  Druga pętla po tej samej liście widzi wtedy jeden element (błąd z 2026-10-25: Art.ini Protossów i Zergów miał tylko ostatni budynek,
  [[mods/protoss-faction]]). Listy nazywaj inaczej niż zmienną pętli (`$Bldgs`/`$b`).
  To samo z parametrem: `param([string]$Dll)` i potem `$dll = …` nadpisuje parametr (2026-10-26: łatka DLL przez to nie zrobiła
  kopii `.bak`). Plik docelowy trzymaj w zmiennej o innej nazwie (`$target`).
- **Sprawdzanie, czy plik jest oryginałem DTA:** plik `version` w katalogu gry ma `nazwa=<MD5>,<KB>`, gdzie MD5 to 16 bajtów
  zapisanych dziesiętnie jeden po drugim (bez separatorów). Tak potwierdzono odtworzony `Vinifera.dll`.
- **Disasemblacja i PDB przez `pixi`:** `pixi exec --spec llvm-tools llvm-pdbutil dump -publics|-types Vinifera.pdb`,
  `pixi exec --spec capstone --spec python python -I vdis.py <pe> <rva> <len>`. W `Vinifera.dll` sekcja `.text` jest pod RVA
  `0x1000` / plikiem `0x400`; adres z `-publics` `0001:X` → RVA `X + 0x1000`.
- **`$true -eq 'tekst'` daje `True`** (prawa strona zamieniana na bool). Porównuj tekstowo (`"$x" -eq 'hover'`) albo sprawdzaj typ (`$x -is [string]`); błąd zrobił z lotników Protossów pojazdy naziemne.
- **Aliasy biją funkcje:** funkcja nazwana `R` się nie wywoła (`R` = `Invoke-History`). Pomocnikom dawaj długie nazwy (`Rep-Rx`).
- **Nigdy nie zamieniaj w skrypcie sekwencji `` `n `` na prawdziwy koniec linii w całym pliku** (2026-10-25: zepsuło 205 miejsc w
  `build-scprotoss.ps1`). Naprawa: `[System.Management.Automation.Language.Parser]::ParseInput` wskazuje tokeny
  `StringExpandable`/`StringLiteral` z końcami linii. W nich przywraca się `` `n ``, a w here-stringach tylko w zagnieżdżonych tokenach.
  Sprawdzenie: porównanie wygenerowanego bloku INI przed naprawą i po niej (różnić się mogą tylko zamierzone zmiany).
- **Przed `-Install` sprawdź, czy `game.exe` działa.** MIX nadpisany pod działającą grą może dać zepsutą grafikę albo crash w tej sesji.

## Parser INI z obsługą `$Inherits` (PowerShell)

```powershell
function Parse($f){ $d=[ordered]@{}; $sec=''
  foreach($l in Get-Content -LiteralPath $f){
    if($l -match '^\[([^\]]+)\]'){ $sec=$matches[1]; if(-not $d.Contains($sec)){$d[$sec]=@{}} }
    elseif($sec -and $l -match '^([A-Za-z0-9_.$]+)\s*=\s*([^;]*)'){ $d[$sec][$matches[1]]=$matches[2].Trim() } }
  $d }
$r=Parse "INI\Rules.ini"
function Val($s,$k){ $seen=@{}; while($s -and -not $seen[$s]){ $seen[$s]=1
  if($r[$s] -and $r[$s].ContainsKey($k)){ return $r[$s][$k] }; $s=$r[$s].'$Inherits' }; $null }
```
Zastosowania z tej sesji:
- lista ukrytych jednostek: przejdź po wartościach `[VehicleTypes]`/`[InfantryTypes]`/`[AircraftTypes]`, filtr `TechLevel=-1`, pomiń `Buildability=AIOnly` i ID `AI*`, dołącz `Cameo` z Art.ini przez `Image`;
- typy dodane przez mapy: porównaj listy typów w `Maps/**/*.map` z rejestrem z Rules;
- wyciąganie definicji z zależnościami: BFS po wartościach kluczy, które są nazwami sekcji w tej samej mapie
  (broń → głowica → pocisk). Uważaj na filtr nazw domów: regex `\w+[12]` wyciął kiedyś `ALLUNIT1`/`GANG1`;
- siatka zajętości mapy do stawiania jednostek: `[Structures]` + `Foundation=WxH` z Art.ini, `[Units]`, `[Infantry]`, `[Terrain]` (klucz komórki = `y*1000+x`).
  Uwaga: część budynków dziedziczy `Foundation` przez `$Inherits` w Art.ini (np. `AWEAP` → `RAWEAP`).

## Narzędzia C# w `Modding/tools/`

Brak Pythona i .NET SDK, jest tylko runtime 8 i PowerShell 5.1. Dlatego kod C# 5 kompiluje się w locie przez
`Add-Type -Path Casc.cs,ModTools.cs,ScBuild.cs -ReferencedAssemblies System.Drawing`.
- `Casc.cs`: odczyt CASC StarCraft: Remastered (zob. [[engine/starcraft-assets]]).
- `ModTools.cs`: `Mix` (czytanie, zapis, ID), `MixSet` (szukanie po wszystkich MIX-ach), `Shp` (odczyt, zapis z kompresją 3),
  `Grp` (SC1), `Aud` (WAV → AUD IMA ADPCM), `Pal` (palety TS/WPE, najbliższy kolor, PNG, arkusze podglądu, PCX).
- `ScBuild.cs`: konwersja GRP → SHP pojazdu (32 kierunki, lustro, cienie, remap), animacje, cameo z portretu.
- `build-scmarine.ps1`: buduje `MIX/ECACHE77.MIX` dla marine'a (do 2026-10-27 `ECACHE99`). Wzorzec dla kolejnych jednostek SC.
- Podgląd: generuj PNG (`Pal.Sheet`) i otwieraj narzędziem Read. Tak ustalono kierunki DTA (`2TNK.SHP`).
- ffmpeg (do portretów webm) nie jest zainstalowany. Wersję przenośną pobrano do scratchpada sesji.

### Piechota SC (Zergi)

- `ScInfantry.cs`: GRP → SHP **piechoty** TS (8 kierunków N, NW, W…, bloki postój/chód/atak/śmierć, cienie, ciasny kadr)
  + `InfantryLayout.Sequence()` (tekst sekwencji do Art.ini) + `Cameo()` (skalowanie do 64×48 w obie strony).
- `build-sczerg.ps1 [-Install]`: Zergi → `ECACHE80.MIX`; z `-Install` idempotentne bloki INI między znacznikami
  `; >>>`/`; <<<` i wpisy list (`[InfantryTypes]`, `[SoundList]`) z własnymi kluczami. Edycja w Latin-1, zachowuje CRLF/LF.
  Wzorzec do kolejnych jednostek-piechoty. Numery MIX-ów: rejestr w [[engine/shp-graphics]].

### Mapy (StarCraft → DTA)

`Add-Type -Path Casc.cs,ModTools.cs,ScMap.cs,TsMap.cs,ScToDta.cs -ReferencedAssemblies System.Drawing`
- `ScMap.cs`: `Mpq` + `Explode` (PKWARE implode), `Chk` (sekcje scenariusza), `ScTileset`/`ScTerrain` (cv5/vf4/vx4ex/vr4, render PNG).
- `TsMap.cs`: `Lzo`, `Format80`, `Pack` (sekcje base64), `IsoMap`, `Ini` (zachowuje kolejność), `Tmp` + `TmpRender`, `Theater` (indeks kafla ↔ plik).
- `ScToDta.cs`: konwerter (klasyfikacja komórek, kontury, łańcuchy klifów A*, woda, LAT, obiekty, kontrole przejezdności).
- `convert-scmap.ps1`: konwersja jednej mapy (log, obrazy debug, `summary.json`, podgląd; renderer z limitem 3 min).
- `port-scmap.ps1`: **pipeline** (lista map, wyszukiwanie po nazwie, kontrole, arkusz `review.png`, instalacja, archiwum),
  zob. [[workflow/scmap-pipeline]].
- `DesignToDta.cs` (2026-10-26): mapa **z projektu zamiast z mapy SC**, np. ze zrzutu prawdziwej mapy. Klasa `Layer`
  (raster etykiet w pikselach projektu: kolor → woda, ciemne piksele, zieleń, wielokąty, grube linie, głosowanie w oknie,
  usuwanie drobnicy) i `DesignToDta : ScToDta` (próbkowanie warstw rodzaj/podłoże/strefa w komórkach, rampy jako
  `LocalWalk`, plaże `Beaches`, `DrownSpecks`, budynki z fundamentem, drzewa w strefach, mury i ruda wzdłuż linii,
  waypointy na najbliższej przejezdnej komórce, kontrola połączeń). `ScToDta` ma do tego drugi konstruktor (bez `Chk`),
  wirtualne `LocalWalk` i przeciążenie `Shores(..., land)`. Regresja: przebudowa Fighting Spirit 1.3 dała sekcje identyczne
  z zainstalowaną mapą. Pierwsze użycie: `build-arka-gibraltar.ps1` ([[missions/arka-00-gibraltar]]).
- `GeoData.cs` + `fetch-geodata.ps1`: dane z prawdziwego świata do map (OSM, DEM Terrarium, dopasowanie projekcji do zrzutu).
  Przepis i pułapki: [[workflow/mission-maps]]. Kompilacja z `-ReferencedAssemblies System.Drawing, System.Xml`.
- Wiedzę o formatach zbierano z **korpusu map DTA**: dekodujesz wszystkie `Maps/**/*.map` i liczysz statystyki
  (bity LAT, klatki murów, reguła łączenia klifów). To pewniejsze niż pamięć o formacie.
- Podgląd mapy: renderer CNCMaps (zob. [[engine/map-format]]). Obrazy wycinaj i oglądaj narzędziem Read.
- C# 5 w `Add-Type`: `sealed` i inne słowa kluczowe nie mogą być nazwami zmiennych, a `goto` nie wskoczy do wnętrza pętli.
- Użytkownik przenosi długie polecenia w tło. Wynik przychodzi wtedy w powiadomieniu, nie trzeba odpytywać.

## Kodowanie plików INI (ważne)

`Rules.ini` (20 bajtów > 127) i `Art.ini` są w **Windows-1252**. Narzędzie Edit odmawia ich edycji. `Get-Content` + `WriteAllLines`
(UTF-8) przekodowuje polskie i specjalne znaki: tak raz zepsuło się Rules.ini, przywrócone z `.bak`. Bezpiecznie:
`$e=[Text.Encoding]::GetEncoding(28591); $t=[IO.File]::ReadAllText($p,$e); …; [IO.File]::WriteAllText($p,$t,$e)`
(Latin-1 = bajt 1:1), albo wstawianie bajtowe. Po edycji porównaj liczbę bajtów > 127 z kopią `.bak`.

## Kopie zapasowe

Przed pierwszą edycją pliku gry: `Copy-Item X X.bak` (tylko jeśli `.bak` jeszcze nie istnieje).
