# Mod: StarCraft Marine (opcja skirmisha STARCRAFT, 2026-10-24)

Pierwsza jednostka StarCrafta w DTA: Marine i Upgraded Marine ze stimpackiem pod klawiszem deploy. Dostępni po zaznaczeniu checkboxa **STARCRAFT** w lobby skirmisha, **od 2026-10-25 tylko dla frakcji Terran** (`Owner=GDI1`; wcześniej dla wszystkich, zob. [[mods/starcraft-terran-buildings]]).

Źródła: `INI/Game Options/StarCraft.ini`, `INI/Art.ini` (koniec pliku), `INI/Sound.ini` (`[SoundList]` 700–713 + sekcje na końcu), `Resources/SkirmishLobby.ini`, `MIX/ECACHE99.MIX`, `Modding/tools/build-scmarine.ps1`.
Stan: zainstalowany. **Testy w grze: brak (niezweryfikowane w grze).** Assety pochodzą z legalnej kopii użytkownika i służą wyłącznie do użytku prywatnego.

## Jednostki

| ID | Nazwa | Koszt | HP | Broń (Damage/ROF/zasięg) | Speed | Wymaga |
|---|---|---|---|---|---|---|
| SCMARINE | Marine | 200 | 800 | SCGauss 15/20/5.34 (SA) | 8 | FACTORY |
| SCMARINES | Marine (Stimpack) | – | 533 | SCGaussS 15/**10**/5.34 | 11 | (tylko przez deploy) |
| SCMARINE2 | Upgraded Marine | 300 | 1100 | SCGauss2 20/20/7.34 | 8 | FACTORY,TECH |
| SCMARINE2S | Upgraded Marine (Stimpack) | – | 733 | SCGauss2S 20/**10**/7.34 | 11 | (tylko przez deploy) |

Od 2026-10-27 wszystkie cztery bronie SCGauss* mają Projectile=Invisible3 (AA=yes, AG=yes): Marines strzelają też do lotnictwa, jak w SC. Te same bronie ma piechota z [[mods/sc-infantry-stim]]. **(niezweryfikowane w grze)**

Zmiana 2026-10-24 (użytkownik: „słabe jak kury”): prędkość +50% (5→8, stim 7→11), zasięg ×2 (2.67→5.34, 3.67→7.34),
Sight podniesiony do 6 / 8, żeby marines widzieli cele na swoim nowym zasięgu.

Kalibracja: broń bazowego marine'a = E1 (Minigun 15/20/2.67), broń ulepszonego według specyfikacji użytkownika.
HP podniesione (2026-10-24, decyzja użytkownika): 500→800, 700→1100. To kompensata za to, że marine jako pojazd
nie pada na ziemię, a prawdziwa piechota leżąc dostaje tylko 50% obrażeń od SA/HE/AP/Fire/Super (`ProneDamage=50%`).
Koszty podniesione 2× (100→200, 150→300). Warianty „S” mają ten sam `Cost` dla zwrotu kosztów i punktacji.

## Stimpack

Deploy → `TransformsInto` w wariant „S” (zob. [[engine/transform-deploy]]): 2× ROF, +40% prędkości, ⅔ max HP
(= −⅓ aktualnego HP, bo zachowany jest procent). Wariant S ładuje się (`MaxCharge=660`, pipy). Po naładowaniu ponowny
deploy kończy stimpack (HP proporcjonalnie wraca). Dźwięk: `VoiceDeploy=SCMASTI0,SCMASTI1`. Wariant S ma
czerwonawy odcień (`SCMARSTM.SHP`), żeby było widać, kto jest na stimie.

## Grafika i dźwięk

- `SCMARINE.SHP` / `SCMARSTM.SHP`: 768 klatek 64×64 (postój 32, chód 32×9, strzał 32×2, cienie). Zob. [[engine/shp-graphics]].
- `SCMADTH.SHP`: animacja śmierci (11 klatek, `AltPalette=yes`, dźwięk `SCMADTH0`).
- `SCMARICON.SHP` (portret HD2 marine'a), `SCMAR2ICON.SHP` (portret + złota ramka i szewrony = wersja ulepszona).
- Dźwięki (AUD): `SCMAWHT0-3` (wybór), `SCMAYES0-3` (rozkazy), `SCMASTI0-1` (stim), `SCMADTH0-1`, `SCMARDY0`, `SCMAFIRE`.

## Pierwszy test użytkownika (2026-10-24) i poprawki

| Problem | Przyczyna | Poprawka |
|---|---|---|
| Upgraded Marine niewidoczny | Art.ini `Image=` ignorowane dla jednostek | osobne `SCMARIN2.SHP` / `SCMARST2.SHP` w ECACHE99; jawne klucze w Art.ini zamiast `$Inherits` |
| Brak animacji i dźwięku śmierci | (1) `SCMADTH` dodany tylko w opcji gry, po wczytaniu obrazów animacji; (2) **główna przyczyna:** opcja „Scrap Debris” podmienia `Explosion` na `ScrapExplosion`, którego nie było | (1) `SCMADTH=SCMADTH` + `SCMADTH2=SCMADTH2` w `Rules.ini [Animations]` (bajtowo); (2) `ScrapExplosion=SCMADTH,SCMADTH2` we wszystkich 4 typach |
| „Daj głośne umieranko” | – | 2 animacje śmierci losowo (`SCMADTH` → krzyk `SCMADTH0`, `SCMADTH2` → `SCMADTH1`), AUD wzmocnione 2×, Sound.ini `Priority=40`, `Range=14`, `Limit=4` |
| Brak dźwięku stimpacka | prawdopodobnie deploy klawiszem D nie wywołuje `VoiceDeploy` | do sprawdzenia: deploy kliknięciem myszą |

Stan: poprawki wgrane, **czekają na ponowny test**.

## Badania (ulepszenia jak w SC) – 2026-10-25

- Użytkownik chciał ulepszeń jak w StarCrafcie, bez zaśmiecania paska. Silnik nie ma ulepszeń globalnych ani wymagań negatywnych
  (zob. [[engine/tech-and-prerequisites]]). Użytkownik zaproponował wzorzec GDI „ulepszenie montowane na budynku”.
- **`SCU238` U-238 Shells**: ulepszenie budynku na **Academy** (`SCACAD`, dopisane `Upgrades=1` w bloku budynków), koszt 500.
  Odblokowuje **Upgraded Marine** (`Prerequisite=FACTORY,SCU238`, wcześniej `FACTORY,TECH`). Ikonka: SC cmdicons #325
  w złotym odcieniu + napis (`SCU238IC.SHP`). Samo ulepszenie nie ma rysunku (`SCU238.SHP` pusty).
- Stara wersja marine'a zostaje w pasku, tak jak wcześniej (2 ikonki). **Niezweryfikowane w grze.**
- 2026-10-25: rozszerzone na cały Terran, zob. [[mods/starcraft-research]]. `SCU238` jest teraz generowane przez
  `build-scresearch.ps1` (ikona poprawiona na właściwą **#238** z `upgrades.dat`, wcześniej zgadnięte #325), koszt 1800,
  a Upgraded Marine wymaga `SCRINF` (Engineering Bay) + `SCU238`.

## Kompromisy

- Marine jest technicznie **pojazdem** (jedyna droga do deploy-umiejętności), więc: buduje się w War Factory, zajmuje
  całe pole, nie da się go rozjechać, nie wsiada do transporterów.
- Pasek HP nie pokazuje kosztu stimpacka, bo procent się nie zmienia.
- Stimpack nie kończy się sam.
- AI (Advanced AI) może samo budować te jednostki, bo wybiera po wartości **(niezweryfikowane)**.

## Lobby

`chkStarCraft` w prawej kolumnie pod Super Weapons. Panel opcji powiększony 266 → 289, `MapPreviewBox $Y` 316 → 339.

## Przebudowa assetów

`powershell -File Modding/tools/build-scmarine.ps1 -FFmpeg <ścieżka do ffmpeg.exe>`. Bez ffmpeg ikonka powstaje z powiększonego sprite'a.

## Odinstalowanie

Przywróć `INI/Art.ini.bak`, `INI/Sound.ini.bak`, `INI/Rules.ini.bak` (uwaga: inne sesje mogły od tego czasu dopisać swoje bloki), `Resources/SkirmishLobby.ini` (wersja z archiwum super-mod-v1
albo `.bak` + ponowne dodanie SUPER MOD), usuń `INI/Game Options/StarCraft.ini` i `MIX/ECACHE99.MIX`.
