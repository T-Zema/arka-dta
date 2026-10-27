# Łatanie game.exe (binarnie, odtwarzalnie)

Jak bezpiecznie zmieniać kod `game.exe` (TS 2.03 + DTA), gdy INI i Vinifera nie wystarczą: narzędzia, wolne miejsce na kod,
zajęte adresy, zasady wywołań wirtualnych i szablon skryptu, który da się puścić ponownie po aktualizacji gry.

Źródła: `game.exe`, `Game.pdb`, `Vinifera.pdb` (w katalogu gry), `tools/patch-*.ps1`, crash 2026-10-26 (`Debug/`), sonda
`tools/spawnprobe.ps1`. Łatki: [[engine/fly-locomotor]], [[engine/buildup-timing]], [[engine/spawners]].

## Zainstalowane łatki (stan 2026-10-26)

| Skrypt | Co zmienia | Kod | Strona |
|---|---|---|---|
| `patch-flyhover.ps1` | pojazdy Fly wiszą zamiast lądować (wariant `-Debug` loguje `FLY …` do `DEBUG_*.LOG`) | jaskinie `0x6C9A40`–`0x6C9FBF` (`.text`) | [[engine/fly-locomotor]] |
| `patch-buildup.ps1` | Buildup dłuższy niż ~81 ticków (morfy Zergów) | jaskinia `0x6C9FC0`–`0x6C9FFF` (`.text`) | [[engine/buildup-timing]] |
| `patch-spawnreturn.ps1` | samolot może lecieć do latającej jednostki (Interceptory → Carrier), **działa w grze** | hook `0x40E1C5`, jaskinia `0x86CF00` (`.p_text`, 32 B) | [[engine/spawners]] |
| `patch-freescv.ps1` | `FreeUnit=SCSCV` daje 2 SCV (Refinery Terran) | hooki `0x42E8D6`, `0x42E909`; jaskinie `0x86C300`–`0x86C35B` (`.p_text`), flaga `0x86E400` (`.p_data`) | [[mods/sc-workers]] |
| `patch-veins.ps1` | Veinhole Monster w trakcie gry (creep Zergów): bez warunku wysokości, bez wykopu terenu (crash renderu), bez losowego +0–3 dla nakładki 167, `VEINHOLE` z animacji we własnej komórce i pod budynkiem, pierścień żył i kolejka wzrostu dla potwora z gry (`Place_Veins`, `Place_Monsters(false)`), test potwora przepuszcza Clear/Road/Rough/Weeds, potwór nie wypuszcza gazu, zasięg 8 pól, dziura ginie z budynkiem `SCZ*` | bajty `0x661C89`, `0x660D0B`, `0x661612`; hooki `0x661F1B`, `0x661420` (jaskinia `0x86C900`, źródło `patch-veins-growth.asm`); hooki `0x4154EC`, `0x415519`, `0x41548D`, `0x58B71A`, `0x661CD3`; jaskinie `0x86C380`–`0x86C394`, `0x86C3A0`–`0x86C3B5`, `0x86CE00`–`0x86CE5B`, `0x86CE60`–`0x86CEDB` (źródło: `patch-veins-cave4.asm`), `0x86CEE0`–`0x86CEFB` (`.p_text`) | [[engine/veins]], [[mods/zerg-creep]] |
| `patch-infdeploy.ps1` | piechota się rozstawia: D zamienia typ `X` ↔ `X_D` (stimpack SC: koszt 1/4 HP, dźwięk z Sound.ini, koniec po 30 s) | hooki `0x494C04` (`EVENT_DEPLOY`), `0x4E9482` (komenda D), `0x4D4EB0` (`InfantryClass::AI`, licznik stimu), `0x632265` (martwy przez Viniferę); jaskinia `0x86C400`–`0x86C637` w oknie do `0x86C6FF` (`.p_text`, v6; v5 sięgała do `0x86C723`, skrypt czyści ten ogon), źródło `patch-infdeploy.asm`; licznik w wyrównaniu `InfantryClass+0x36E` | [[mods/sc-infantry-stim]] |
| `patch-zergbuild.ps1` | na creepie budują tylko Zergi (typy `SCZ*`), budynki Zergów wymagają creepu (poza Hatchery/Lair/Hive/ICC, Extractorem, zakopanym Lurkerem); kratki fundamentu przy kursorze deployu | hook `0x452250` (owijka `Is_Clear_To_Build`), wywołania `0x611ADC`, `0x611B65` (`Draw_Placement`); jaskinie `0x86CD00`–`0x86CD9B`, `0x86CA00`–`0x86CB2D` (`.p_text`), źródła `patch-zergbuild.asm`, `patch-zergbuild-grid.asm` | [[mods/zerg-creep]] |
| `patch-overlordstorage.ps1` | pojazd z `Storage=`, który nie zbiera, podnosi `House->Capacity` (Overlord jako silos); w parze z `patch-vinifera-overlord.ps1` | hooki `0x4C457B` (`Tracking_Active_Remove`, gałąź jednostki), `0x4C46D9` (`Tracking_Active_Add`); jaskinie `0x86CC80`–`0x86CCB0`, `0x86CCC0`–`0x86CCF0` (`.p_text`) | [[mods/overlord-storage]] |
| `patch-flyertarget.ps1` | jednostki z bronią AA same celują w latające pojazdy Fly (Mutaliski, lotnicy Protossów) | 5 bajtów w miejscu pod `0x62DF2F` (`Greatest_Threat`, test RTTI w pętli warstwy TOP), bez jaskini | [[engine/fly-locomotor]] |

**Po aktualizacji DTA (nowy `game.exe`): `tools/patch-game.ps1`.** Nakłada wszystkie siedem, odmawia przy działającej grze,
jest idempotentny, `-Revert` cofa w odwrotnej kolejności. `patch-flyhover.ps1 -FromBackup` startuje od czystego `.bak`, więc
po nim zawsze `patch-game.ps1`. Osobno: `Vinifera.dll` łata `tools/patch-vinifera-workers.ps1` ([[mods/sc-workers]]), a po niej `tools/patch-vinifera-veins.ps1` ([[mods/zerg-creep]]). Ta druga trzyma jaskinie w `.scdock+0x100` (robotnicy mają pierwsze `0x100` B), więc cofa się ją pierwszą. Trzecia, `tools/patch-vinifera-overlord.ps1` ([[mods/overlord-storage]]), dokłada własną sekcję `.scstor` za `.scdock` (`.scdock` jest pełna) i cofa się ją przed dwiema poprzednimi.

## Narzędzia

- Symbole: `pixi exec --spec llvm-tools llvm-pdbutil dump -publics Game.pdb` (adresy funkcji), `-types Vinifera.pdb`
  (układ klas, sloty vtable, przesunięcia pól).
- Deasemblacja: capstone, `pixi exec --spec python --spec capstone python -I vdis.py <pe> <rva hex> <len hex>` (skrypt w scratchpadzie
  sesji; przelicza RVA przez tabelę sekcji). `ImageBase` `game.exe` = `0x400000`, więc RVA = VA − `0x400000`.
- Asembler do dłuższych jaskiń: `pixi exec --spec nasm nasm -f bin -o x.bin x.asm` z `org <VA jaskini>`, wtedy `call`/`jmp`
  na adresy gry liczą się same. Źródło `.asm` leży obok skryptu, a skrypt niesie gotowe bajty (działa bez nasm). Wzór:
  `tools/patch-infdeploy.asm`. Wynik zawsze zdeasemblować capstone i porównać skoki powrotne.
- Typy pól i sloty vtable bez zgadywania: `llvm-pdbutil dump -types Vinifera.pdb` (pola z `offset = N`), sloty vtable przez
  odczyt `??_7<Klasa>@@6B@` z `game.exe` i dopasowanie adresów do symboli `Game.pdb`.
- **Pułapka PowerShella:** pomocnik nazwany `Rd` to alias `Remove-Item`. Nazwy pomocników zawsze długie (`Read-U32`).
- Stan w działającej grze: sondy `ReadProcessMemory` (`tools/spawnprobe.ps1`, `nukeprobe.ps1`, `morphprobe.ps1`), tylko odczyt.
  Gdy zachowania nie da się wyjaśnić statycznie, sonda wcześnie, a nie kolejne rundy zgadywania ([[engine/superweapons]]).

## Sekcje i wolne miejsce

| Sekcja | VA | VirtualSize | Plik (raw) | Raw size | Uwagi |
|---|---|---|---|---|---|
| `.text` | `0x401000` | `0x2C8A0D` | `0x1000` | `0x2C9000` | ogon `0x6C9A0D`–`0x6CA000` **cały zajęty** (fly + buildup) |
| `.p_text` | `0x869000` | `0x32F0` | `0x348000` | `0x4000` | wykonywalna (`0x60500020`); ogon `0x86C2F0`–`0x86D000` (3344 B) był zerowy, zajęte: `0x86C300`–`0x86C35B` freescv, `0x86C380`–`0x86C3B5` veins, `0x86C400`–`0x86C6FF` okno infdeploy (v6 zajmuje do `0x86C637`), `0x86CE00`–`0x86CE5B` veins (przeniesione z `0x86C700`, gdy infdeploy v5 urosło), `0x86CE60`–`0x86CEDB` veins, `0x86CEE0`–`0x86CEFB` veins, `0x86C900`–`0x86C9D4` veins (miejsca 9–10), `0x86CA00`–`0x86CB2D` i `0x86CD00`–`0x86CD9B` zergbuild, `0x86CC80`–`0x86CCF0` overlordstorage, od `0x86CF00` spawnreturn; wolne `0x86C700`–`0x86C8FF`, `0x86C9E0`–`0x86C9FF`, `0x86CB30`–`0x86CC7F`, `0x86CDA0`–`0x86CDFF`. Kilka sesji łata równolegle: przed wyborem miejsca zrzuć bajty z bieżącego `game.exe`, nie ufaj samej tabeli |
| `.p_data` | `0x86E000` | `0x1CC` | `0x34D000` | `0x1000` | zapisywalna (`0xC0600040`); flagi łatek za `VirtualSize`, w tej samej stronie: `0x86E400` freescv |

- Bajty za `VirtualSize`, ale w obrębie danych pliku, **są w pamięci**: loader mapuje całą stronę z pliku. Potwierdzone w grze
  dla jaskiń fly (`.text`) i spawnreturn (`.p_text`).
- Inne krótkie luki w `.text` (wypełnienie `CC`/`90`, ≥ 48 B): `0x4BADE2` (62 B), `0x651D10` (231 B), `0x6C8E01` (63 B).
  Nieużyte. Przed użyciem sprawdź, czy nic tam nie skacze (to wyrównanie między funkcjami).
- Nowa łatka: **wybierz miejsce, które nie koliduje z tabelą wyżej, i dopisz je do tej tabeli.** Skrypt ma sprawdzać, że jaskinia
  jest zerowa; wtedy kolizja kończy się czytelnym błędem, a nie zepsutym exe.

## Vinifera podmienia funkcje w pamięci

Vinifera przy starcie wpina własne wersje części funkcji gry (np. `TechnoClass::Can_Deploy_Now` → `TechnoClassExt::_Can_Deploy_Now`, `Can_Player_Move`) i haki Syringe (`_hk__0x00<adres>`). Łatka w środku takiej funkcji w `game.exe` **nigdy się nie wykona** (deploy piechoty, 2026-10-27). Przed łataniem: `Select-String vinpdb_publics.txt -Pattern "_<Funkcja>@\w+Ext|_hk__0x00<adres>"`. Bezpieczne miejsca: wywołujący, których Vinifera nie rusza. Całe funkcje podmienione przez Viniferę (`Patch_Jump` na `<Klasa>Ext::_<Funkcja>`, np. `AnimClassExt::_AI`) trzeba łatać w `Vinifera.dll`: łatki animacji z `patch-veins.ps1` przez to nie działały (2026-10-27, [[engine/veins]]). Szukaj: `Select-String vinpdb_publics.txt -Pattern "<Klasa>Ext@@"`.

## Zasady wywołań (lekcja z crasha 2026-10-26)

- Na wskaźniku `AbstractClass*` (cel ruchu/ataku: `NavCom`, `TarCom`, argument `Assign_Destination`) wolno wołać **tylko sloty
  vtable `AbstractClass`**, np. `+0x58` `In_Air`. Celem bywa **`CellClass`** (vtable `0x6CCE98`), która nie jest `ObjectClass`.
- `What_Am_I` przez vtable `+0x78` działa tylko dla `ObjectClass` i pochodnych. Na komórce slot `+0x78` to śmieci: crash z EIP
  `0x66666666`.
- RTTI dowolnego obiektu bezpiecznie: interfejs `IRTTITypeInfo` pod `[obj+4]`, `mov ecx,[edi+4] / lea eax,[edi+4] / push eax /
  call [ecx+0Ch]` (stdcall, sam zdejmuje argument). Wynik: `RTTI_UNIT=1`, `RTTI_AIRCRAFT=2`, `RTTI_BUILDING=6` …
  Najlepiej skopiować wywołanie, którego oryginalna funkcja już używa obok.
- Metody klas: `thiscall` (`ecx` = this). W jaskini zachowuj `ebx`, `esi`, `edi`, `ebp` i równowagę stosu; `eax`, `ecx`, `edx`
  można niszczyć, jeśli kod za skokiem powrotnym ich nie czyta (sprawdź deasemblacją).
- Nadpisuj całe instrukcje: hook `E9 rel32` (5 B) + `90` do granicy instrukcji. Przesunięte instrukcje (np. oryginalne `call`)
  powtórz w jaskini.
- Wskazówka w raporcie crasha: EIP o wartości „wzorcowej” (`0x66666666`, `0xCCCCCCCC`) oznacza skok przez zły slot vtable.
  Pozycja z `Call Stack` (np. `AircraftClass::Assign_Destination 0x0040E1C8`) to adres powrotu tuż za złym `call`.

## Szablon skryptu łatki

Wzór: `tools/patch-spawnreturn.ps1` (najkrótszy). Każda łatka:
1. `param([switch]$Revert, [string]$Exe)`: `-Exe` pozwala testować na kopii.
2. VA → offset w pliku **przez tabelę sekcji** (nie zakładaj `.text`).
3. Lista miejsc `@{ VA; Orig; New }`, opcjonalnie `Legacy` (bajty starej, błędnej wersji, które wolno nadpisać).
4. Nic do zrobienia → „already patched”. Inne bajty niż `Orig`/`Legacy` → wyjątek, nic nie zapisane (inna wersja `game.exe`).
5. `game.exe.bak` tylko, jeśli jeszcze nie istnieje (to oryginał sprzed pierwszej łatki).
6. Dopisz skrypt do `$order` w `patch-game.ps1`.

Test przed instalacją: kopia → łatka → druga łatka („already patched”) → deasemblacja hooka i jaskini → `-Revert` → hash
równy oryginałowi. Dopiero potem prawdziwy `game.exe`, przy zamkniętej grze. Na koniec test w grze z sondą.
