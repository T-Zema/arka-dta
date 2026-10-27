# Creep Zergów: co da się zrobić w silniku

**Wdrożone 2026-10-27 drogą A: [[mods/zerg-creep]].** Poniżej studium wykonalności (2026-10-26). Uwaga: `ToOverlay=` okazał się kluczem Art.ini, nie Rules. Silnik nie ma creepu. Są dwie drogi: **(A) żyły TS** (żywy organizm Veinhole Monster, który sam rozrasta i kurczy żyły) oraz **(B) własny typ Tiberium** z grafiką creepu. Rekomendacja: **A**, bo rozwiązuje harvestery, budowanie i znikanie creepu. Nic nie jest zainstalowane.

Źródła: `INI/Rules.ini` (`[Tiberiums]`, `[Riparius]`…`[Scrap]`, land types `[Clear]`…`[Tunnel]`, `[TIBSPAWN]`, `[VEINS]`, `[VEINHOLE]`, `[VEINTREE]`, `[GRNGEM01]`, `[TRACKS13F]`), `INI/Art.ini` („Invisible Tiberium Spreader”, `[TIBSPRDR3]`…, `[TBSPRD_R4]`, `[TBSHARDR4]`, `[TIBSPAWNI]`), `INI/Theaters.ini`, napisy z `Vinifera.dll` i `game.exe`, deasemblacja `game.exe` (zob. [[engine/veins]]), dokumentacja Vinifery (New-Features-and-Enhancements).

## Wymaganie użytkownika

Z budynków Zergów ma się szerzyć **creep, a nie Tiberium**: nie zielone kryształy, nie surowiec. Użytkownik wskazał żyły jako „organizm”, który to przypomina.

## Droga A: żyły (Veinhole Monster) — rekomendowana

Mechanika i dowody z kodu: [[engine/veins]]. W skrócie:

- Nowy budynek Zergów, np. **Creep Tumor** (jak w SC2): `Wall=yes`, `ToOverlay=VEINHOLE`, fundament 1×1. Po postawieniu zamienia się w Veinhole Monstera, który co `VeinholeGrowthRate` rozrasta żyły.
- Żyły mają land `Weeds`: w DTA `Buildable=yes` (drony mogą na nich budować), harvestery ich nie zbierają (tylko `Weeder=yes`, a takich jednostek w DTA nie ma).
- Gdy potwór obrywa, żyły się kurczą; po jego śmierci znikają, czyli creep cofa się jak w SC.
- Szybkość na creepie: kolumna `[Weeds]` w land types (SpeedType `Creep` jak w drodze B).

Wymagania i wady:
1. **Łatka `game.exe` 1 bajt** (`0x661C89` `7D`→`EB`): w trakcie gry potwór wymaga wysokości ≥ 1, a mapy DTA mają wszędzie 0. Bez łatki budynek zniknie bez efektu.
2. Pole 3×3 musi być płaskie, `Land=Clear` (nie droga, nie Tiberium), a w promieniu 2 komórek nie może być innego potwora.
3. Potwór jest **neutralny**, nie należy do gracza Zergów. Każdy może go zaatakować; ma `Strength=10000` z `[VEINTREE]` (wspólne dla map z żyłami).
4. Żyły **atakują jednostki bez `ImmuneToVeins=yes`**. Klasyczne jednostki DTA są odporne, a większość jednostek SC (drony, Marine, Probe…) nie. Do decyzji: dać odporność wszystkim (czysty creep) albo tylko Zergom (creep szkodzi Terranom i Protossom).
5. Wygląd: żyły i dziura z TS (czerwonobrązowe, organiczne). Podmiana na grafikę creepu SC wymaga klatek w układzie `Get_Vein_Frame` i zmieni też żyły w 9 mapach DTA.
6. Niezweryfikowane: czy `Wall=yes` działa przez `DeploysInto` drona (inaczej Creep Tumor z sidebaru Hatchery) i czy potwór na wysokości 0 rysuje się dobrze (potwory w mapach DTA już tak stoją).

## Droga B: własny typ Tiberium

### Dlaczego „Tiberium” w silniku

Jedyny mechanizm, w którym nakładka na komórkach mapy pojawia się i rośnie wokół obiektu, to system Tiberium. „Tiberium” to tylko silnikowa nazwa klasy: ruda (`Ore`), złom (`Scrap`) i klejnoty w DTA też są typami z `[Tiberiums]`. Creep byłby kolejnym typem z własną grafiką i zerowymi parametrami. W grze wygląda i działa jak creep, nie jak Tiberium.

- Vinifera pozwala dodawać typy: `[Tiberiums]` w DTA ma już 7 pozycji (0–6), każdy z kluczem `Overlay=` (pierwsza nakładka) i `Variety=` (liczba wariantów).
- Typ creepu: `Value=0`, `Power=0`, `DamageToInfantry=0`, `Spread=`/`SpreadPercentage=0` (bez samorozrostu, rośnie tylko od budynków), `Growth` dowolne (stadia = gęstość creepu), własny kolor na radarze i pip.
- Nakładki: nowe `[OverlayTypes]` z `Tiberium=yes` i grafiką creepu ze SC (tileset SC ma kafle creepu; narzędzia cv5/vx4ex z [[engine/starcraft-maps]]). Potrzebne SHP na każdy teatr (Vinifera: `Theater=`).

### Jak siać creep z budynku (wzorzec DTA)

DTA ma niewidzialne budynki-spreadery `TIBSPRDR3/R4/R6` (Art.ini, sekcja „Invisible Tiberium Spreader”):

```ini
[TIBSPRDR4]                ; art budynku
ActiveAnim=TBSPRD_R4
ActiveAnimPowered=yes      ; bez prądu nie sieje
ActiveAnimX=-24
ActiveAnimY=24             ; bez tego obszar jest przesunięty o komórkę na NE

[TBSPRD_R4]                ; pętla, co TrailerSeperation zrzuca odłamek
Image=CLRANIM
LoopStart=0
LoopEnd=1
LoopCount=-1
TrailerAnim=TBSHARDR4
TrailerSeperation=200      ; większe = wolniej

[TBSHARDR4]                ; niewidzialny odłamek: leci losowo i sieje w miejscu lądowania
Image=CLRANIM
Bouncer=yes
MaxXYVel=55.0              ; zasięg (55 ≈ 4 komórki, 80 ≈ 6, 200 ≈ 5 dla innego MinZVel)
IsTiberium=true
TiberiumSpawnType=RTIB01   ; pierwsza nakładka typu do zasiania
TiberiumSpreadRadius=0     ; 9 = od razu łata wokół punktu
```

Dla Zergów: `ActiveAnim` (albo `ActiveAnimTwo`, jeśli pierwsza jest zajęta) na Hatchery/Lair/Hive i Creep Colony, odłamek z `TiberiumSpawnType=<nakładka creepu>`. Losowe rzuty dają nieregularną plamę, która gęstnieje z czasem, czyli podobnie do rozlewania się creepu. **(niezweryfikowane w grze)**

### Co creep może dawać

| Efekt | Jak | Status |
|---|---|---|
| Wygląd i rozrost wokół budynków | typ + spreader jak wyżej | wykonalne, wzorzec działa w DTA |
| Zergi szybsze na creepie (jak w SC2) | SpeedType `Creep` (istnieje, używają go tylko `C2`, Visceroidy, `TIBSPAWN`) na jednostkach naziemnych Zergów + kolumna `Creep=` w land type creepu wyższa niż w `[Clear]`/`[Road]` | wykonalne, zmienia też Visceroidy i `C2`; >100% nieznane |
| Leczenie na creepie | `TiberiumHeal=yes` na jednostkach (tempo globalne `[General] TiberiumHeal=.02`) | niepewne, jeśli creep dostanie `Land=Weeds` |
| Budowanie tylko na creepie | brak klucza; deploy drona nie sprawdza nawet `Adjacent=` ([[mods/zerg-faction]]) | tylko łatką `game.exe` |
| Znikanie creepu po śmierci budynku | Tiberium zostaje; ewentualnie `DeathWeapon` z głowicą niszczącą Tiberium | niezweryfikowane |

### Ryzyka do sprawdzenia testem

1. **Harvestery** innych frakcji i AI mogą traktować creep jako złoże (wartość 0, marnują kursy). Vinifera łata `FootClass::Search_For_Tiberium_Weighted`, więc waga zależy od wartości; wyszukiwanie „bliskie” może nie patrzeć na wartość.
2. **Budowanie na creepie:** nakładka Tiberium ma land `Tiberium`, a `[Tiberium] Buildable=no`, więc dron mógłby nie móc postawić budynku na creepie (odwrotnie niż w SC). Pomysł: nakładka creepu z `Land=Weeds` (`[Weeds] Buildable=yes`, DTA tak robi z torami `TRACKS13F`; klejnoty mają jawne `Land=Tiberium`, więc klucz jest per nakładka). Może przy okazji ukryć creep przed harvesterami, ale może też wyłączyć `TiberiumHeal`.
3. **Dodanie typu z pliku mapy/opcji:** nowe `[Tiberiums]` i `[OverlayTypes]` dopisane w `Terran Faction.ini` zamiast Rules.ini; czy silnik je przyjmie, trzeba sprawdzić (dla jednostek działa, [[engine/adding-new-types]]).

## Odrzucone mechanizmy

- **Żyły przez animację** (`TiberiumSpawnType=VEINS`/`VEINHOLE`): silnik dodaje losowo 0–3 do numeru nakładki, więc trafiałby w sąsiednie nakładki ([[engine/veins]]). Pierwsza wersja tej strony uznała żyły za niepodpinalne pod budynek; to było błędne, bo jest droga `Wall=yes` + `ToOverlay=`.
- **Smudge (kratery, osmalenia):** losowe z głowic (`ScorchChance`), bez kontroli typu i rozrostu.
- **Sam podkład pod budynkiem** (`BibShape=` w art, jak `[CRATER]`): działa i jest najprostszy, ale to statyczna dekoracja bez rozrostu i bez efektów. Plan B.

### Decyzje użytkownika (2026-10-26)

- **Odporność na żyły dla wszystkich** (`ImmuneToVeins=yes` na wszystkich jednostkach SC; klasyczne DTA już ją mają). Creep nikomu nie szkodzi. Najlepiej osobnym blokiem na końcu `StarCraft.ini` i `Terran Faction.ini`, który przetrwa generatory.
- Źródła creepu: **Creep Tumor, Hatchery, Lair, Hive, Creep Colony, Sunken Colony, Spore Colony** (jak w SC: kolonie z Creep Colony dalej szerzą creep). Inne budynki nie.

### Projekt źródeł

- **Creep Tumor:** `Wall=yes` + `ToOverlay=VEINHOLE`; budynek staje się potworem.
- **Hatchery/Lair/Hive i kolonie** zostają budynkami. Mają niewidzialną `ActiveAnim` (wzorzec spreadera DTA) z odłamkiem `TiberiumSpawnType=VEINHOLE`, który co kilkadziesiąt sekund próbuje postawić potwora na wolnym polu obok. Wymaga drugiej łatki `game.exe` (`0x4154EC`, bez losowego +0–3 dla nakładki 167, [[engine/veins]]). Skutek: przy budynku stoi neutralna „dziura”, a po jej zniszczeniu odrasta.
- Ograniczenie: między potworami musi być co najmniej 3 komórki odstępu, więc ciasno postawione budynki dzielą jedno źródło.

## Proponowany prototyp (droga A)

Łatka `0x661C89` dopisana do `tools/patch-game.ps1`, budynek `Creep Tumor` (`Wall=yes`, `ToOverlay=VEINHOLE`) dla Zergów (dron z `DeploysInto` albo sidebar Hatchery), `ImmuneToVeins=yes` dla Zergów. Test w skirmishu: (1) czy powstaje potwór i rosną żyły, (2) wygląd na wysokości 0, (3) czy dron stawia budynki na żyłach, (4) kurczenie i znikanie żył po zniszczeniu potwora. Droga B zostaje jako zapas.
