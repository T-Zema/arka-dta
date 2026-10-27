# Mod: EVA i sidebar Zergów (`Speech08.mix`, `SideC08.mix`)

Własny głos doradcy i kolorystyka sidebara dla frakcji [[mods/zerg-faction]] (dom `Nod1`, strona 7) zamiast kopii plików Nod. Stan: **zainstalowane 2026-10-25** (po zamknięciu gry, kopie `Speech08.mix.bak`, `SideC08.mix.bak`), **(niezweryfikowane w grze)**.

Źródła: `MIX/Speech08.mix`, `MIX/SideC08.mix`, `MIX/sidenc08.mix` (kopie Nod z `build-sczergbase.ps1`), tablica `Speech[]` w `game.exe`
(wskaźniki pod offsetem pliku `0x311D14`), kod Vinifery `src/audio/audio_vox.cpp` (`EvaNames[]`, `One_Time`, `Get_Sound_Name`),
`src/audio/audio_hooks.cpp` (`Read_Speech_Ini`), `docs/New-Features-and-Enhancements.md` („EVA Speech”, „Hardcoded Speeches”),
CASC StarCrafta `SD/sound/zerg/advisor/*.wav`, generator `Modding/tools/build-sczergside.ps1`.

## Jak gra wybiera linie EVA

- DTA **nie ma `EVA.INI`** (ani w `INI/`, ani w żadnym MIX-ie, sprawdzone po CRC nazwy). Vinifera pisze wtedy „EVA.INI not found!” i woła
  `AudioVoxClass::One_Time()`: wpis nr *i* dostaje nazwę `EvaNames[i]` i plik `Speech[i]` z `game.exe`.
- Plik (`00-I018` itd.) jest szukany w `SPEECH%02d.MIX` strony gracza (zob. [[engine/sides-and-houses]]), więc podmiana pliku w `Speech08.mix`
  zmienia głos tylko Zergom.
- Mapa slot → plik (wybór): `00-I018` ConstructionComplete, `00-I022` InsufficientFunds, `00-I024` LowPower, `00-I044` SilosNeeded,
  `00-I068/070/080` UnitArmor/Firepower/SpeedUpgraded, `00-I076` UnitReady, `00-I082` BaseUnderAttack, `00-I090` HarvesterUnderAttack,
  `00-I150` MissileLaunchDetected, `00-I154` ClusterMissileReady (w DTA mówi „Nuclear weapon available”), `00-I156` IonCannonReady,
  `00-I216` Building, `00-I218` OnHold, `00-I220` Canceled, `00-I074` UnitLost, `00-I016` CannotDeployHere. `00-n018` i `00-n160` nie są
  w tablicy (nie grają same z siebie).
- Treść linii DTA potwierdzona rozpoznawaniem mowy Windows (`System.Speech`, gramatyka z listą fraz): low power, silos needed,
  unit lost, unit ready, base under attack, ion cannon ready, nuclear weapon available, on hold, canceling, building itd.

## Mapowanie (linie doradcy Zergów z SC)

W CASC jest tylko 8 linii doradcy Zergów (SD): `ZAdErr00/01/02/06`, `ZAdUpd00/01/02/04`. Znaczenie z nazewnictwa SC (Err/Upd, te same
numery u Terran i Protossów) i z rozpoznawania mowy (słabsze dla zniekształconego głosu Zergów).

| Slot EVA | Plik | Linia SC |
|---|---|---|
| `EVA_InsufficientFunds` | `00-i022.aud` | `ZAdErr00` „We require more minerals” |
| `EVA_LowPower` | `00-i024.aud` | `ZAdErr02` „Spawn more Overlords” (odpowiednik „brak zaplecza”) |
| `EVA_BaseUnderAttack` | `00-i082.aud` | `ZAdUpd00` „The hive cluster is under attack” |
| `EVA_HarvesterUnderAttack` | `00-i090.aud` | `ZAdUpd01` „Our forces are under attack” |
| `EVA_ConstructionComplete` | `00-i018.aud` | `ZAdUpd02` „Evolution complete” (badania z [[mods/zerg-research]] kończą się w sidebarze) |
| `EVA_Unit{Armor,Firepower,Speed}Upgraded` | `00-i068/070/080.aud` | `ZAdUpd02` „Evolution complete” |
| `EVA_MissileLaunchDetected` | `00-i150.aud` | `ZAdUpd04` „Nuclear launch detected” |
| pozostałe 36 wpisów | — | zostają z Nod |

Nieużyte: `ZAdErr01` („more vespene gas”, w DTA nie ma gazu; „silos needed” znaczy „magazyn pełny”), `ZAdErr06` („not enough energy”).
AUD: 22 050 Hz, 16 bit, mono, IMA ADPCM jak oryginały ([[engine/sounds-aud]]); głośność dopasowana do RMS zastępowanej linii.

## Sidebar

- `sidebar.pal` w `SideC08.mix`: czerwone akcenty Nod (tło logo na radarze, ikony zakładek) → fiolet Zergów, szary „kamień” → ciemny,
  organiczny brąz. Bez zmian: indeks 0 (przezroczysty), 12 (czarny), segmenty paska mocy (`powerp.shp`: 141/143 zielony,
  187/188 żółty, 122/124 czerwony, 10/11 niebieski) i linie siatki radaru 224–247.
- Elementy okien `*.pcx` (`bar_*`, `bde_*`, `bue_*`, `trof*`, `sbgrip*`, strzałki) mają własne palety i dostały ten sam przekolor.
- Kształt logo na radarze to nadal skorpion Nod (tylko w fiolecie). Pełne przerysowanie poza zakresem.
- `sidenc08.mix` nie ma grafiki sidebara (czcionki, globus kampanii, dźwięki ekranu wyniku), więc zostaje bez zmian.
- Kolor tekstu w sidebarze to klucze strony Vinifery (`UIColor` itd. w `[ZergSide]`, zob. [[engine/sides-and-houses]]), nie paleta; nieruszane.

## Generator i instalacja

```
powershell -NoProfile -ExecutionPolicy Bypass -File Modding\tools\build-sczergside.ps1            # podgląd
powershell -NoProfile -ExecutionPolicy Bypass -File Modding\tools\build-sczergside.ps1 -Install   # do MIX\
```

- Podgląd w `scratchpad\zergside\`: `Speech08.mix`, `SideC08.mix`, `sidebar_preview.png` (Nod vs Zerg), `eva_mapping.csv`,
  `wav\<plik>_nod.wav` / `_zerg.wav` do odsłuchu.
- MIX przebudowany po ID (z `local mix database.dat`), kontrola: ta sama liczba wpisów (46 / 67), niezmienione wpisy bajt w bajt,
  ponowne zdekodowanie AUD (korelacja ≥ 0,997, próg w skrypcie 0,98).
- `-Install` kopiuje oba MIX-y do `MIX\` po zrobieniu `<plik>.bak` (tylko gdy kopii nie ma) i odmawia, gdy działa `game.exe`.
  Generator zawsze startuje z `.bak`, jeśli istnieje, więc ponowne uruchomienie nie nakłada zmian dwa razy.
- `build-sczergbase.ps1` kopiuje pliki strony tylko, gdy ich brak, więc nie nadpisze wersji Zergów.

## Odinstalowanie

`Copy-Item MIX\Speech08.mix.bak MIX\Speech08.mix -Force`, to samo dla `SideC08.mix`.

## Do sprawdzenia w grze

1. Czy w meczu Zergiem słychać nowe linie (np. „We require more minerals” przy braku kasy, „Evolution complete” po badaniu).
2. Czy sidebar i radar są fioletowo-brązowe, a pasek mocy zachował kolory.
3. Głośność linii SC względem reszty EVA.
