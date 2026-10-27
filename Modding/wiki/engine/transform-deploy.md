# Rozstawianie i zamiana jednostek (TransformsInto, ładowanie)

Co da się zrobić klawiszem „deploy” i jak z tego zbudować umiejętność (np. stimpack).

Źródła: kod Vinifera `src/extensions/unit/unitext_hooks.cpp` (`Create_Transform_Unit`, hooki 0x00650BAE, 0x00656017), `src/extensions/unittype/unittypeext.cpp`, `INI/Rules.ini` `[CTNK]`, `[CTNKT]`, ciągi znaków w `game.exe`.

## Fakty

- **Piechota w TS nie ma deploy.** `game.exe` nie zna sekwencji `Deploy`/`Deployed` ani klucza `Deployer`.
  W DTA nie ma żadnej rozstawialnej piechoty. **Od 2026-10-27 łatka `tools/patch-infdeploy.ps1`:** klawisz D zamienia
  piechotę `X` w typ `X_D` i z powrotem (zamiana typu w miejscu, koszt 1/4 HP w stronę `_D`), zob. [[mods/sc-infantry-stim]].
  Powód w kodzie: `Can_Deploy_Now` odmawia piechocie bez pasażerów, a `EVENT_DEPLOY` daje tylko `MISSION_UNLOAD`. **(niezweryfikowane w grze)**
- Pojazdy: `DeploysInto=<budynek>` (MCV, Termite), albo **Vinifera `TransformsInto=<UnitType>`**, czyli zamiana w inny pojazd.
  Działa tylko dla `UnitClass`.
- `TransformRequiresFullCharge=yes` + `IsMobileEMP=true` + `MaxCharge=` + `StartCharge=` + `PipScale=Charge`:
  zamiana jest możliwa dopiero po naładowaniu, a pipy pokazują postęp. Wzorzec: Chrono Tank (`[CTNK]`, `MaxCharge=2700`).
- Przy zamianie Vinifera kopiuje: dom, tag, grupę, kierunki, weterana (ActLike), biasy, EMP, amunicję, cel ataku.
  **HP: `Strength = HealthRatio × nowe MaxStrength`**, czyli zachowany jest procent życia, nie wartość bezwzględna.
- Nowa jednostka powstaje przez `Create_One_Of`, więc `TechLevel` docelowego typu nie ma znaczenia (może być `-1`).
- `VoiceDeploy=` (Vinifera) gra dźwięk przy rozstawieniu.

## Wzorzec „umiejętności z kosztem HP” (stimpack)

1. Jednostka A (`TransformsInto=B`, bez wymogu ładowania).
2. Jednostka B: `MaxStrength = ⅔ × A`. Przez zachowanie procentu oznacza to −⅓ aktualnego HP.
   Do tego B ma lepszą broń (ROF/2) i prędkość, `IsMobileEMP=true`, `MaxCharge=660`, `StartCharge=0`,
   `TransformRequiresFullCharge=yes`, `TransformsInto=A`.
3. Ograniczenia:
   - pasek życia **nie spada wizualnie**, bo procent zostaje ten sam;
   - po powrocie do A HP wraca proporcjonalnie;
   - nie ma automatycznego końca efektu, gracz sam rozstawia ponownie po naładowaniu.
4. Samoleczenie Vinifery (`SelfHealingStep/Rate/Cap`) **nie nadaje się** do „krwawienia”: ujemny krok nie ma
   zabezpieczenia przed zejściem HP poniżej zera.

## Tryb stacjonarny (np. Siege Mode): budynek, nie pojazd ze `Speed=0`

Pojazd ze `Speed=0` (cel `TransformsInto`) **zamarza po rozkazie ruchu** i nie reaguje na nic (test Siege Tanka, 2026-10-25).
Tryb nieruchomy robimy jako **budynek**: `DeploysInto=<budynek>` na pojeździe i `UndeploysInto=<pojazd>` na budynku (jak MCV ↔ ConYard).
Budynek dostaje broń, `Turret=yes` + `TurretAnim=` (wpis w `Rules.ini [Animations]`), `Unsellable=yes`, `Capturable=false`, a jako
`Buildup=` animację rozkładania (przy składaniu gra puszcza ją od tyłu). Składanie budynku w skirmishu wymaga opcji
„Re-Deployable MCV” (`SpawnIniOption=MCVRedeploy`) **(niezweryfikowane)**. Wzorzec: `SCSIEGB` w [[mods/starcraft-terran-units]].

## Budynki składane (UndeploysInto) w kodzie Vinifery

Źródło: `src/extensions/building/buildingext_hooks.cpp`, `src/extensions/tactical/tacticalext_hooks.cpp` (Vinifera develop).
- Składanie działa dla **każdego** budynku z `UndeploysInto=`, nie tylko ConYardu. Przykłady w DTA: `DBFRT`→`BFRT`, `DMSA`, `DTERM`.
- **Zaznaczanie ramką** (`Vinifera_Bandbox_Select`) łapie budynki z `UndeploysInto`, chyba że są ConYardem albo `IsMobileWar`.
  Wiele składanych budynków = ramka przez bazę zaznacza też budynki.
- AI składa (`MISSION_DECONSTRUCTION`) **uzbrojone** budynki z `UndeploysInto`, gdy strzela do nich coś spoza ich zasięgu
  (hak 0x0042C624, issue #1049). Ten sam rozkaz bez `UndeploysInto` oznaczałby sprzedaż, a Vinifera to blokuje.
- Przy składaniu budynek szuka wolnej komórki obok (`Nearby_Location` wg `SpeedType` jednostki). ConYard gracza ma awaryjnie środek budynku.
- Zastosowanie: latające budynki Terran ([[mods/starcraft-terran-buildings]]), w których jednostką jest pojazd jumpjet.
  Czy pojazd jumpjet może się z powrotem rozłożyć w budynek: **(niezweryfikowane w grze)**.

## Jeden kanał radiowy na budynek: czego nie łączyć

Źródło: `BuildingClassExt::_Receive_Message` w `src/extensions/building/buildingext_hooks.cpp`.
Budynek jest w kontakcie radiowym tylko z **jednym** obiektem naraz. Rafineria (dokowanie zbieracza), naprawa, lądowisko i
construction yard korzystają z tego samego kanału:
- ConYard przy każdym stawianym budynku dostaje `RADIO_BUILDING` (misja `REPAIR`, kontakt z budową), a potem `RADIO_COMPLETE` (misja `GUARD`).
- Rafineria odmawia dokowania (`RADIO_NEGATIVE`), gdy `In_Radio_Contact()` z kimś innym. Zadokowany zbieracz traci kontakt, gdy ConYard zacznie budowę.
- **Bez łatki ConYard nie może być rafinerią**: test 2026-10-25 (`SCCC` z `Refinery=yes`), w którym zbieracze stali na CC i blokowali się.
  Magazyn (`Storage=`) radia nie używa, więc ConYard może być silosem.
- Kto zabiera kanał (2026-10-26): `HouseClassExtension::Place_Object` (Vinifera, `houseext.cpp`) przy każdym postawionym budynku
  woła `builder->Transmit_Message(RADIO_HELLO, tech)` i `tech->Transmit_Message(RADIO_COMPLETE, builder)`, gdzie `builder` to
  fabryka budynków z `Who_Can_Build_Me` (dowolny budynek z `Factory=BuildingType`, nie tylko ConYard). Łatka
  `tools/patch-vinifera-workers.ps1` pomija obie wiadomości, gdy budowniczy jest rafinerią. Doki w CC/Nexusie/Hatchery użytkownik wycofał
  tego samego dnia, a łatka została (bez rafinerii-budowniczego nic nie robi), zob. [[mods/sc-workers]].

## Konsekwencje dla „piechoty” na bazie pojazdu

Jednostka musi być `UnitType`, więc: buduje się w **War Factory**, zajmuje całe pole, nie da się jej rozjechać,
nie wsiada do APC. `Armor=none` zachowuje podatność na broń przeciwpiechotną.
- **Nie pada na ziemię.** Prawdziwa piechota leżąc dostaje 50% obrażeń (`ProneDamage=50%` w SA/HE/AP/Fire/Super), więc przy
  tym samym HP „pojazdowa piechota” wytrzymuje ok. połowę. Kompensacja: ok. 1,6× HP (marine: 800 zamiast 500).
- Odporna na Tiberium, naprawiana przez Service Depot i MRV, **nie leczy jej medyk**.
