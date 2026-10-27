# Plan: mod z frakcjami ze StarCrafta

Następny projekt: dodanie frakcji StarCrafta (Terran / Protoss / Zerg) do DTA. Czekamy, aż użytkownik pobierze swoją legalną kopię StarCrafta. Assety będą użyte wyłącznie prywatnie.

Źródła: rozmowa z 2026-10-24. Wiedza o formatach StarCrafta i narzędziach konwersji jest ogólna, **jeszcze nie zweryfikowana na plikach użytkownika**.

## Stan (2026-10-24, aktualizacja)

- Użytkownik ma **Remastered** w `C:\Program Files (x86)\StarCraft`. W CASC są też stare GRP SD, więc ścieżka „klasyczna”
  działa bez szukania starych plików (zob. [[engine/starcraft-assets]]).
- Pierwsza jednostka gotowa: [[mods/starcraft-marine]] (Marine + Upgraded Marine, stimpack, portrety, dźwięki), jako
  samodzielna opcja STARCRAFT, nie frakcja. Pipeline: `Modding/tools/build-scmarine.ps1`.
- Druga sesja Claude (dawn-of-the-tiberium-6e) bada „hydraulikę” nowej frakcji: robocza nazwa domu `Terran`,
  strona `TerranSide`, indeks 14, osobny INI. Jednostki SC mają prefiks `SC*`, więc wystarczy dopisać `Terran` do `Owner=`.
  Strony tej sesji: [[plans/new-faction]].
- Poza jednostkami: mapa **The Lost Temple** przeniesiona ze StarCrafta jako mapa skirmisha, zob. [[mods/sc-lost-temple]]
  (konwerter działa dla dowolnej mapy SC).
- Sekcje poniżej to plan pierwotny. Odpowiedzi na pytania 1 i 3 są wyżej.

## Do ustalenia z użytkownikiem

1. Która wersja: StarCraft Remastered (Battle.net, archiwa **CASC**, grafiki HD w `.anim`) czy klasyczny 1.16
   (`StarDat.mpq`/`BrooDat.mpq`, sprite'y **GRP** + palety `.wpe`). Klasyczne GRP są dużo łatwiejsze do konwersji na SHP.
2. Ile ras: na początek jedna (najprościej Terranie, bo czołgi, piechota i budynki mają odpowiedniki w C&C),
   potem kolejne.
3. Osobna strona grywalna w skirmishu czy jednostki SC dodane do istniejących frakcji (jak Super Mod).
   Osobna strona jest dużo większa: `[Sides]`, `[Houses]`, sidebar, kolory UI, EVA, wybór strony w kliencie.
4. Forma moda: kolejna opcja w lobby (zob. [[engine/client-lobby-options]]) czy pełna podmiana.

## Ścieżka techniczna (wstępna)

1. **Ekstrakcja**: CASC Viewer (Remastered) albo MPQ Editor (klasyczny) → GRP, palety, WAV.
2. **Konwersja grafiki**: GRP → klatki PNG → **SHP (TS)** z paletą DTA. Rzeczy do dopilnowania:
   - kierunki: SC ma 17 klatek kierunku z lustrzanym odbiciem (= 32 kierunki), DTA używa `Facings=32`;
   - kolor gracza: zakres remap w palecie TS (do ustalenia, który zakres używa DTA);
   - cień, wieżyczki (np. Siege Tank ma osobny sprite wieży, a TS ma `Turret=yes` z klatkami po korpusie);
   - narzędzia: OS SHP Builder, XCC Utilities albo własny skrypt w Pythonie (PIL), co wygodniejsze.
3. **Art.ini**: nowe sekcje grafik (cameo, sekwencje piechoty `Sequence=`, `Foundation=` i `Buildup=` budynków).
   Art.ini **nie da się rozszerzyć z mapy** (zob. [[engine/adding-new-types]]), więc ten mod będzie musiał
   dopisać sekcje do Art.ini (lub dodatkowego pliku art, jeśli Vinifera to wspiera: do sprawdzenia).
4. **Pliki**: luźne pliki w katalogach z `Vinifera.ini` `SearchPaths` (INI, MIX, SOUNDS, MUSIC, MOVIES, MAPS)
   albo własny `.mix` **(do sprawdzenia, czy silnik czyta luźne SHP)**.
5. **Rules**: nowe typy jak w [[mods/super-mod-v1]] (prefiks np. `SC`), bronie wzorowane na
   [[engine/weapons-and-warheads]] (Marine = karabin, Firebat = miotacz, Siege Tank = rozkładana artyleria
   przez `Deployer`/`DeploysInto`, Wraith = maskowanie, Psionic Storm = supermoc).
6. **Dźwięki**: WAV ze StarCrafta → `Sound.ini` (`VoiceSelect=` itd.).

## Pierwszy krok, gdy assety będą dostępne

Sprawdzić wersję i format plików, przekonwertować **jedną** jednostkę (Marine) end-to-end i potwierdzić w grze,
że wyświetla się, porusza i strzela. Dopiero potem skalować na resztę.
