# Kod mapy frakcji SC: łańcuch warstw `BasedOn`

Reguły frakcji skirmisha (Terran `GDI1`, Zerg `Nod1`, Protoss `GDI2`) to nie jeden plik, tylko łańcuch warstw w `INI/Map Code/SC Factions/`, który klient scala w jeden kod mapy. Od 2026-10-28; wcześniej był to jeden plik `Terran Faction.ini` (11,7 tys. linii, 13 bloków).

Źródła: `Resources/clientdx.exe` (refleksja: `DTAClient.Domain.Multiplayer.GameMode`, pole `mapCodeININame : String`, metoda `GetMapRulesIniFile` = `new IniFile("INI/Map Code/" + mapCodeININame)`), `Resources/Binaries/Rampastring.Tools.dll` (test `BasedOn` na plikach próbnych), `INI/Map Code/AI Discounts Enhanced.ini` (DTA sama używa `BasedOn`), `INI/MPMaps.ini`, `Modding/tools/MapCode.ps1`.

## Jak to działa

- `INI/MPMaps.ini` (`[Default]`, `[Custom Map]`): `MapCodeININame=Terran Faction.ini`. Klient trzyma tę nazwę jako **jeden string**, lista po przecinku nie działa.
- Klient ładuje ten plik przez `Rampastring.Tools.IniFile`, a `IniFile` obsługuje `[INISystem] BasedOn=<plik>`: najpierw wczytuje plik bazowy (ścieżka względem folderu bieżącego pliku), potem kładzie na niego bieżący. Działa rekurencyjnie. Sprawdzone 2026-10-28 na bibliotece klienta: `[A] X=1 Y=1` ← `[A] Y=2 W=3` ← `[A] W=4` daje `X=1 Y=2 W=4`, a sekcje list (`[L] 1=AA` + `[L] 2=BB`) się sumują.
- Wynik jest więc taki sam jak jeden plik z warstwami ułożonymi od dołu. Późniejsza (wyższa) warstwa wygrywa, kolejność kluczy w listach (`[Sides]`, `[VehicleTypes]`) idzie od dołu łańcucha.
- `[INISystem]` trafia do `spawnmap.ini`, ale gra tej sekcji nie czyta. Tak samo jest w mapach DTA, które używają `BasedOn`.
- **Brakujący plik z `BasedOn` klient pomija po cichu** (test 2026-10-28: `IniFile` wczytuje resztę bez błędu). Gdyby zabrakło warstwy, Zergi czy Protossi zniknęliby ze skirmisha bez żadnego komunikatu. Dlatego folder `SC Factions/` musi zawsze iść razem z `Terran Faction.ini` (git, `state.json`, instalator), a `MapCode.ps1` przy brakującym pliku rzuca błąd.

## Warstwy (od dołu)

| Plik w `INI/Map Code/SC Factions/` | Kto pisze | Zawartość |
|---|---|---|
| `000 Terran faction.ini` | ręcznie | dom `GDI1` = Terran, `[TerranSide]`, klony `Owner=` Aliantów, `SCMCVT`; **wspólne** `[General] BaseUnit=`/`HarvesterUnit=` (dopisują do nich generatory Zergów i Protossów), `Owner=` `TDPROC`/`TDPROC_AI`/`DEPCARR` |
| `010 Zerg faction.ini` | `build-sczergbase.ps1 -Install` | strona i dom Zergów, `[Sides] ZergSide`, `ZRB/ZRG/ZRI`, wszystkie typy i bronie ([[mods/zerg-faction]]) |
| `020 Protoss faction.ini` | `build-scprotoss.ps1 -Install` | strona i dom Protossów, `[Sides] ProtossSide`, `PRB/PRV/PRI/PRC`, `[AI] BuildConst` ([[mods/protoss-faction]]) |
| `030 Zerg heroes.ini` | `build-sczergheroes.ps1 -Install` | [[mods/zerg-heroes]] |
| `040 Zerg research.ini` | `build-sczergresearch.ps1` | [[mods/zerg-research]] |
| `050 SC building select sounds.ini` | `build-scbldgsounds.ps1 -Install` | `VoiceSelect=` budynków Zergów i Protossów ([[mods/sc-building-sounds]]) |
| `060 SC workers.ini` | `build-scworkers.ps1 -Install` | `Image=`/`UnloadingClass=` dronów i Probe ([[mods/sc-workers]]) |
| `070 Protoss research.ini` | `build-scprotossresearch.ps1` | badania Protossów |
| `080 Zerg creep.ini` | `build-sczergcreep.ps1` | creep, `ImmuneToVeins=yes` dla wszystkich typów ([[mods/zerg-creep]]) |
| `090 Zerg death sounds.ini` | `build-sczergdeath.ps1` | `Explosion=` z dźwiękiem śmierci ([[mods/zerg-faction]]) |
| `100 SC air armor.ini` | `build-scairarmor.ps1` | pancerze lotników SC ([[engine/air-armor]]) |
| `900 Hand edits.ini` | ręcznie | **na samej górze**: bloki „Crate goodies” ([[engine/crates]]), „Worker capacity”, „SC balance (user)” (balans na życzenie użytkownika); wygrywają z każdym generatorem |

`INI/Map Code/Terran Faction.ini` to tylko punkt wejścia: komentarz z tą listą i `BasedOn=SC Factions/900 Hand edits.ini`. Każda warstwa ma na górze nagłówek (kto ją pisze) i `[INISystem] BasedOn=<warstwa niżej>`, pod nim swój blok `; >>> X` … `; <<< X`.

## Zasady pracy

- **Warstwa generowana:** zmieniaj generator i uruchom go ponownie, nie plik. Ręczna zmiana w bloku zniknie przy następnym uruchomieniu.
- **Ręczny balans** (prośba użytkownika „zmień X”): dopisz do bloku „SC balance (user)” w `900 Hand edits.ini`, ze starą wartością w komentarzu. Wygra z warstwami niżej, także po ponownym uruchomieniu generatorów.
- **Nowa warstwa** (nowy generator): `New-MapCodeLayer -Name 'X' -Header '...'` z `MapCode.ps1` wstawia plik pod `900 Hand edits.ini` (numer w połowie przerwy) i przepina `BasedOn` warstwy wyżej. Potem generator pisze swój blok przez `Set-Block`/`Set-MapCodeBlock`. Opisz warstwę w komentarzu punktu wejścia i w tabeli wyżej, potem `dta-capture.ps1`: `.gitignore` wylicza warstwy z nazwy, bez tego git (i instalator) nowej warstwy nie zobaczy.
- **Kolejność ma znaczenie** tylko przy tych samych kluczach i w listach: `[Sides]` = indeks strony (`TerranSide` 6 w warstwie 000, `ZergSide` 7 w 010, `ProtossSide` 8 w 020), więc warstwy Zergów i Protossów nie mogą zamienić się miejscami.
- **Usuwanie modu:** usuń jego warstwę i w warstwie nad nią ustaw `BasedOn=` na warstwę pod nią. Zostają ewentualne wpisy w `000` (`BaseUnit`/`HarvesterUnit`).
- **Narzędzia czytające reguły frakcji** (generatory, misje ARKA) nie czytają pliku wejścia, tylko łańcuch: `. "$tools\MapCode.ps1"` (po ustawieniu `$game`), potem
  - `Get-MapCodeLayer 'Zerg faction'`: ścieżka warstwy po nazwie (bez numeru, więc warstwy można przenumerować),
  - `Get-MapCodeLayers`: wszystkie warstwy od dołu,
  - `Read-MapCodeText [-Exclude <warstwa>]`: wszystkie warstwy jako jeden tekst INI (tak, jak widzi je klient),
  - `Set-MapCodeBlock <warstwa> <blok>`: podmienia blok, zostawia nagłówek z `BasedOn`.
- Kopie `.bak` warstw (generatory robią je same) i `Terran Faction.ini.bak` (stan sprzed Zergów i Protossów, etap 0 Terran) git ignoruje.

## Weryfikacja podziału (2026-10-28)

- Scalony wynik łańcucha (klientowym `IniFile`) = scalony stary plik: 9023 linie, kolejność ta sama. Jedyna różnica: `[SCZDTUM] SelfHealingStep` 3 → 2. Stary blok creepu leżał w pliku pod balansem i nadpisywał wpis z „SC balance (user)” (`SelfHealingStep=2 ; was 3`, Zergi leczą się o 40% wolniej). Teraz ręczne poprawki są na górze i działają zgodnie z intencją.
- Przy okazji uporządkowane splątania: `ZRI01–05` (piechota Zergów) leżały w sekcji bloku „Zerg research”, a `ZergSide`, `ZRG*` i `PRV*` w nagłówku pliku Terran. Teraz są we własnych warstwach frakcji.
- Generatory w dwóch piaskownicach (kopie gry poza folderem roboczym, bazowe MIX-y jako hardlinki): stary kod (`git archive HEAD`) na starym pliku i nowy kod na warstwach, wszystkie dziesięć generatorów po kolei, jak w [[workflow/tools-catalog]]. `Sound.ini`, `Rules.ini`, `StarCraft.ini`, `MPMaps.ini`, `GameOptions.ini`, łatane binarki i wszystkie MIX-y wyszły identyczne, `Art.ini` różni się jednym komentarzem. Nowy kod po pełnej regeneracji daje scalony wynik równy obecnemu (+1 klucz `GuardRange=` w kopii jednostki z badań, stary kod robi to samo).
- Stary układ miał przy tym błąd: generatory bohaterów i badań przenosiły swój blok na koniec pliku, więc po ponownym uruchomieniu ich wartości wygrywały z „SC balance (user)” (np. `SCZOVS SelfHealingStep` wracał z 48 na 80). W łańcuchu warstwy mają stałe miejsca, a ręczne poprawki są na górze.
- Wykryte przy teście, **istniało już wcześniej** (stary i nowy kod tak samo): `build-scairarmor.ps1` przerywa (`[SCZHKM] Armor=sc_air_light already`), jeśli przed nim uruchomiono generatory bohaterów lub badań. Kopie jednostek biorą wartości z warstw nad sobą (pancerz z „SC air armor”, `ImmuneToVeins`, `Explosion=` z „Zerg death sounds”), więc pliki ich warstw „dryfują”, choć wynik scalania jest ten sam. Do naprawy: generatory kopii powinny czytać tylko warstwy pod sobą (`Read-MapCodeText` z limitem), a `build-scairarmor.ps1` powinien pomijać typy, które już mają pancerz `sc_*`.
- W grze **(niezweryfikowane w grze)**: lobby z frakcjami Zerg i Protoss po zmianie nie było jeszcze uruchomione.

Zob. też: [[engine/ini-layering]] (kolejność Rules → mapa → opcje gry), [[engine/sides-and-houses]], [[mods/terran-faction]].
