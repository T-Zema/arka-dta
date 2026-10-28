# Żyły i Veinhole Monster

Żywy organizm z TS: Veinhole Monster (dziura w ziemi) rozrasta wokół siebie żyły (`VEINS`), kurczy je, gdy obrywa, i atakuje jednostki bez odporności. W DTA działa (9 map), a w trakcie gry da się go stworzyć z budynku-muru z `ToOverlay=VEINHOLE`. Kandydat na creep Zergów ([[plans/zerg-creep]]).

Źródła: `INI/Rules.ini` (`[General]` linie 236–242, `[CombatDamage] VeinholeWarhead`, `[VeinholeWH]`, `[VEINTREE]`, `[OverlayTypes] 126/167/178`, `[VEINS]`, `[VEINHOLE]`, `[VEINHOLEDUMMY]`, `[Weeds]`), `INI/Art.ini` (`[VEINS]`, `[VEINHOLE]`, `[VEINATAC]`), `INI/Theaters.ini`, `INI/Enhance.ini [Weeds]`, deasemblacja `game.exe` (symbole `Game.pdb`), układ pól z `Vinifera.pdb`.

## Elementy

| Element | Klucze | Uwagi |
|---|---|---|
| Parametry globalne | `[General] VeinholeGrowthRate=300`, `VeinholeShrinkRate=100`, `MaxVeinholeGrowth=2000`, `VeinDamage=5`, `VeinholeTypeClass=VEINTREE` | wspólne dla wszystkich potworów |
| Ciało potwora | `[VEINTREE]` (TerrainType, `IsVeinhole=true`, `Strength=10000`, `Image=None`) | cel do ataku; obrażenia kurczą żyły (`Build_Shrinking_Queue`), śmierć: `Destroy_Monster` |
| Dziura | nakładka nr **167** `VEINHOLE` (`IsVeinholeMonster=true`, `Land=Rock`) + 8× nr **178** `VEINHOLEDUMMY` dookoła (3×3) | numery wpisane na sztywno w `game.exe` |
| Żyły | nakładka nr **126** `VEINS` (`IsVeins=true`, `Land=Weeds`) | klatka zależy od sąsiadów (`Get_Vein_Frame`), jak mury |
| Gaz potwora | `VeinholeMonsterClass::AI`: gdy coś stoi w promieniu 2 komórek (`MapClass::Is_Something_Nearby`), potwór gra atak i w klatce ataku wypuszcza cząstkę `GasCloudM1` (nazwa na sztywno, `0x7118CC`) → `GasCloud1` (`Damage=50`, `Warhead=Gas`) | gaz **nie** patrzy na `ImmuneToVeins` (szósty test 2026-10-27: ginęły pojazdy obok dziur); `patch-veins.ps1` miejsce 8 (`0x661612` `jne` → `jmp`) wyłącza go zawsze. **(niezweryfikowane w grze)** |
| Atak żył | `[CombatDamage] VeinholeWarhead=VeinholeWH` (1000% na każdy pancerz), anim `VEINATAC`, `[General] VeinDamage` (Rules +0xCC) | każdy obiekt techno w komórce dojrzałych żył (`OverlayData ≥ 0x30`) bez `ImmuneToVeins=yes` (TechnoType +0x441), **także budynki** (`0x45C5C0`, `0x4166C0`; piąty test 2026-10-27: creep niszczył budynki) |
| Teatry | `Theaters.ini`: `IsVeinGrowthEnabled=true` w DESERT, TEMPERATE, SNOW | Vinifera: `AllowVeins=` na kaflu (domyślnie tak) |

Land type `[Weeds]` w DTA: `Buildable=yes` (zmienione z `no`), prędkości jak na `[Clear]` poza `Creep=59%`. Żyły zbierają tylko jednostki z `Weeder=yes`, a w Rules DTA nie ma żadnej, więc zwykłe harvestery ich nie ruszają. `ImmuneToVeins=yes` jest w Rules.ini tylko 50 razy: 431 z 516 typów jednostek (klasycznych i SC) go nie miało, co policzył `tools/build-sczergcreep.ps1` (wcześniejsza wersja tej strony błędnie podawała, że klasyczne jednostki są prawie wszystkie odporne).

## Gdzie rosną żyły

`CellClass::Can_Place_Veins` (`0x45B0D0`): rampa ≤ 4, land nie Water/Rock/Beach/Ice, w komórce i 4 sąsiadach brak nakładki albo nakładka z `IsVeins`. **Bez warunku wysokości**, więc rosną na płaskich mapach DTA.

## Tworzenie potwora w trakcie gry

`OverlayClass::Mark` (`0x58B5E0`): przy położeniu nakładki nr 167 woła test `0x661C10`, a gdy przejdzie, wpisuje 8× `VEINHOLEDUMMY` dookoła i tworzy `new VeinholeMonsterClass(cell)`. Kładzenie nakładki 126 poza wczytywaniem mapy woła `CellClass::Place_Veins`.

Test `0x661C10` przy wczytywaniu mapy (`ScenarioInit > 0`) zawsze przechodzi. W trakcie gry wymaga:
- brak innego potwora w odległości < 3 komórek (w obu osiach),
- środek: `Height >= 1` (`CellClass+0x93`),
- całe 3×3: `Ramp == 0` (+0x94), `Land == Clear` (+0x78), ta sama wysokość co środek.

Warunek `Land == Clear` (`0x661CD3`) blokował dziury pod budynkami Zergów stojącymi na innym terenie (piąty test 2026-10-27: Hatchery i kolonie na zielonej wyżynie bez creepu, guzy na równinie działały). Miejsce 7 łatki (jaskinia `0x86CEE0`) przepuszcza Clear (0), Road (1), Rough (7) i Weeds (11), maska bitowa `0x883`. **(niezweryfikowane w grze)**

**Mapy DTA mają wszędzie `Level=0`** ([[engine/map-format]]), więc w trakcie gry test zawsze odpada na warunku wysokości. Łatka jednobajtowa: `0x661C89` `7D 0A` (`jge`) → `EB 0A` (`jmp`) usuwa ten warunek (część `tools/patch-veins.ps1`).

**Sam test to za mało (crash 2026-10-27).** Warunek wysokości chronił „wykop”. Konstruktor `VeinholeMonsterClass` (`0x660C00`) poza wczytywaniem mapy (`[0x7E4394] == 0`, `0x660D05`) przerabia teren 3×3: kafel iso (`CellClass+0x28`) = `[0x804434] + tabela(0x711709) − 1`, podkafel (+0x92) = 0, `Height` (+0x93) − 1. Na płaskiej mapie DTA dawało to zepsute kafle i crash renderu w `CellClass::Cell_Render_Rect` (`0x4561F2`, `mov ecx,[eax+esi*4+10h]`, śmieciowy rozmiar obrazka kafla). Łatka `0x660D0B` `0F 85 A6 00 00 00` (`jne 0x660DB7`) → `E9 A7 00 00 00 90` (`jmp`) pomija wykop zawsze, więc potwór stoi na płaskim terenie. `Destroy_Monster` kafli nie przywraca, więc nic innego od wykopu nie zależy. Przy wczytywaniu mapy ten kod i tak był pomijany (kafle wykopu są zapisane w mapie). Ta sama formuła kafla jest w generatorze map losowych (`0x5F9390`). **(niezweryfikowane w grze)**

### Czym położyć nakładkę 167: budynek-mur

`BuildingClass::Unlimbo` (`0x429E20`, ścieżka od `0x42A014`): gdy typ ma `IsWall` (BuildingType +0x809, klucz Rules `Wall=yes`), budynek tworzy obiekt nakładki `ToOverlay` (+0x4CC), kładzie go w swojej komórce (`Unlimbo` nakładki → `Mark`) i usuwa siebie. **`ToOverlay=` jest kluczem Art.ini** (sekcja obrazka budynku, jak `[SBAG]` w Art.ini), nie Rules. Budynek z `Wall=yes` + art `ToOverlay=VEINHOLE` zamienia się więc w Veinhole Monstera. Kod rozstawiania jednostki (`UnitClass`) nie sprawdza `IsWall`, więc droga przez `DeploysInto` drona powinna działać. Wdrożone w [[mods/zerg-creep]]. **(niezweryfikowane w grze)**

Jeśli test potwora nie przejdzie, `Mark` usuwa obiekt nakładki i nic nie zostaje w komórce, a budynek i tak znika (pieniądze przepadają).

### Droga przez animację (wymaga łatki)

`AnimClass::AI` (+0x623): animacja z `TiberiumSpawnType=` (AnimType +0x1C0) przechodzi pętlą po `TiberiumSpreadRadius` (+0x1C4). Przy promieniu 0 bierze komórkę **na północ** od siebie (tabela kierunków `0x761148`) i sprawdza ją przez `CellClass::Can_Tiberium_Germinate(nullptr)` (`0x4596C0`: w mapie, bez nakładki, rampa ≤ 4, land pozwala na Tiberium, bez zwykłego budynku). Potem kładzie nakładkę o numerze **typ + `Random(0,3)`** (`0x4154C9`–`0x4154F2`), a na koniec wpisuje komórce `OverlayData = Random(0,2)` (`0x415519`). Dla `VEINHOLE` losowanie dałoby w 3 na 4 przypadków sąsiednie nakładki 168–170 (`CORPSE`, `PAVLAT1/2`). Wariant `dummy164` (losuje 164–167) też odpada, bo 166 to `TELP` (stary „Teleporter”, `Tiberium=yes`, `Land=Tunnel`). Działa dla Tiberium, bo jego warianty leżą obok siebie.

Łatka `tools/patch-veins.ps1` (zainstalowana razem z warunkiem wysokości i pominięciem wykopu, [[mods/zerg-creep]]):
- `0x4154EC` (`8B 91 24 01 00 00 03 D0` = `mov edx,[ecx+0x124]; add edx,eax`) → jaskinia `0x86C380`, która pomija `add edx,eax`, gdy indeks typu = `0xA7` (167).
- `0x415519` (`mov [edi+0x96],al`) → jaskinia `0x86C3A0`, która dla komórki z nakładką 167 wpisuje 0, tak jak robi to `Mark`.

- `0x41548D` (`mov edi,eax; push 0; mov ecx,edi; call Can_Tiberium_Germinate`) → jaskinia `0x86CE00`: dla `VEINHOLE` cofa przesunięcie o `AdjacentCoord[0]` (komórka = komórka animacji, nie jej północny sąsiad) i wymaga tylko `Overlay == -1`. Bez tego nie da się siać pod budynkiem: `Can_Tiberium_Germinate` odrzuca komórkę z widocznym budynkiem (`0x459710`: typ bez `IsInvisible` +0x44A i bez `IsInvisibleInGame` +0x899). Test potwora w `Mark` budynków nie sprawdza.

Pętla `AnimClass::AI` liczy komórkę jako „komórka animacji + `AdjacentCoord[x & 7]`” (`0x41544D`), czyli dla promienia 0 zawsze bierze północnego sąsiada (błąd TS). Dlatego spreadery DTA mają `ActiveAnimX=-24`, `ActiveAnimY=24`.

**Vinifera podmienia `AnimClass::AI` (siódmy test 2026-10-27, sonda pamięci).** Działa `AnimClassExt::_AI` z `Vinifera.dll` (`0x1003D788`), a jej pętla siewu jest kopią kodu gry: `Map[AdjacentCell(komórka, dx & 7)]` (północny sąsiad), `Can_Tiberium_Germinate`, `OverlayTypes[ID + Random(0,3)]`, `OverlayData = Random(0,2)`. Miejsca 2, 3 i 5 łatki `patch-veins.ps1` w `game.exe` **nigdy się nie wykonują**. Sonda `tools/veinprobe.ps1` pokazała:
- dziury z budynków powstawały tylko przy losowym trafieniu 1 na 4, komórkę na północ od celu (`OverlayData` 2);
- pozostałe trafienia zostawiały `CORPSE` (168) albo `PAVLAT`, czyli „zwłoki” przy kolonii;
- siew pod budynkiem nie przechodził `Can_Tiberium_Germinate`.

Te same trzy poprawki nakłada `tools/patch-vinifera-veins.ps1` w `Vinifera.dll`: hooki `0x1003DDBA`, `0x1003DE13`, `0x1003DE5A`, jaskinie w `.scdock+0x100` (źródło `patch-vinifera-veins.asm`). **(niezweryfikowane w grze)**

Inne animacje siejące Tiberium działają bez zmian. Budynek z `ActiveAnim` → `TrailerAnim` z `TiberiumSpawnType=VEINHOLE` co jakiś czas próbuje postawić potwora we wskazanej komórce, także pod sobą. Gdy potwór już stoi w promieniu 2 komórek, próba odpada, a po jego śmierci powstaje nowy.

Rysowanie: `Tactical::Render` woła `VeinholeMonsterClass::Draw_All` (`0x611AE1`) przed `Render_Objects_On_Layers`, więc budynek stojący na potworze go zasłania.

### Kiedy potwór rozrasta żyły

`VeinholeMonsterClass::AI` (`0x661420`) co `[General] VeinholeGrowthRate` klatek (Rules +0xC0, DTA 300) woła `Grow` (`0x661D60`), który dodaje 1–5 komórek z kolejki wzrostu. `Grow` kończy się od razu, gdy:
- scenariusz ma `VeinGrowthEnabled=no` (`Scen+0x1D83`, klucz `[Basic] VeinGrowthEnabled` w mapie, `0x5E040A`; domyślnie zostaje poprzednia wartość). **357 map DTA ma `no`**, 21 ma `yes`, więc potwór postawiony w trakcie gry zwykle stoi bez żył;
- potwór ma już ponad `MaxVeinholeGrowth − 40` komórek (Rules +0xBC, DTA 2000);
- **kolejka wzrostu (+0x50) jest pusta.** Buduje ją tylko `Build_Growth_Queue` (`0x6626F0`), wołane wyłącznie z `Place_Monsters` (`0x6623F0`), a to gra woła przy wczytaniu mapy (`0x5DDB04`) i w generatorze map losowych (`0x53D6D8`). Potwór utworzony w trakcie gry ma więc pustą kolejkę i nigdy nie rośnie (trzeci test 2026-10-27: dziura z obrzeżem 3×3 i nic więcej, mimo `VeinGrowthEnabled=yes`). Łatka `patch-veins.ps1` (miejsce 6): w `OverlayClass::Mark` za konstruktorem potwora (`0x58B71A`) woła `Place_Monsters(false)`, gdy `ScenarioInit == 0`. Z `false` funkcja nie realokuje danych: zeruje mapę właścicieli żył (`0x80FBF0`), buduje kolejki wszystkich potworów i usuwa nakładki `VEINS`, których żaden potwór nie posiada.
- **`Build_Growth_Queue` startuje tylko od istniejących żył.** Przegląda pole 5×5 wokół potwora i bierze do kolejki komórki z nakładką `VEINS` (126), a dalej wypełnia połączone żyły. Potwór z mapy ma żyły dookoła, a generator map losowych (`MapSeedClass::Generate_Veinholes`, `0x54FAA7`–`0x54FB16`) po utworzeniu potwora sam kładzie żyły na pierścieniu 5×5 (`CellClass::Place_Veins` `0x45B760` + `Recalc_Attributes(-1)` `0x453240`). Potwór z gry ma tylko `VEINHOLEDUMMY` 3×3, więc kolejka dalej była pusta (czwarty test 2026-10-27: dalej sama dziura). Jaskinia miejsca 6 (v2, `tools/patch-veins-cave4.asm`) robi to samo co generator: pierścień żył, potem `Place_Monsters(false)`. `VEINHOLEDUMMY` ma `IsVeins=true`, więc nie blokuje `Can_Place_Veins` na pierścieniu. **(niezweryfikowane w grze)**
- `Grow` zdejmuje komórkę z kolejki: `OverlayData < 0x30` → `Place_Veins` (żyła rośnie o klatkę), w przeciwnym razie dokłada do kolejki wolnych sąsiadów (`Can_Place_Veins`, bez właściciela, różnica wysokości < 2).

- **Zasięg (miejsce 9):** `Grow` dokłada sąsiada do kolejki tylko w promieniu ok. 8 pól od `MonsterCell` (dx² + dy² ≤ 72, hook `0x661F1B` przed `Can_Place_Veins`). Kandydat leży pod `[esp+14h]`, potwór w `esi`. **(niezweryfikowane w grze)**
- **Śmierć z budynkiem (miejsce 10, hook na początku `AI` `0x661420`):**
  - potwór, na którego `MonsterCell` stoi budynek `SCZ*`, dostaje słowo `'ZG'` w bajtach wyrównania `+9Eh`/`+9Fh` (`Vinifera.pdb`: po `IsToPuffGas` `+9Dh`, przed `field_A0`);
  - świeży obiekt ma tam śmieci, dlatego znacznik to 2-bajtowa stała;
  - gdy budynku już nie ma, potwór umiera jak w `Take_Damage` przy `RESULT_DESTROYED` (`0x661BF5`): `[+6Ch] = 3` i `Detach_This_From_All` (`0x6489B0`, fastcall, `dl=0`). Animacja śmierci kończy się `Destroy_Monster`.

  **(niezweryfikowane w grze)**

### Własność żył i kurczenie (deasemblacja 2026-10-28)

- **Własność.** Globalna mapa bajtów `0x80FBF0` (1 = pole ma właściciela), flaga `0x80000` w `CellClass+0xA4` (pole zajęte w tym przebiegu) i mapa każdego potwora `+64h` (bajt na pole). `Place_Monsters` (`0x6623F0`) zeruje mapę globalną i flagi, potem idzie po potworach **od ostatniego** (najnowszego): żywy dostaje `Build_Growth_Queue` (`0x6626F0`), kurczący się `Build_Shrinking_Queue`. Na końcu każda nakładka `VEINS` bez bajtu w mapie globalnej znika od razu (`Overlay = -1`, bez `Recalc_Attributes`). Robi to też przy wczytaniu mapy.
- **`Build_Growth_Queue`:**
  - bierze żyły z pola 5×5, potem zalewa sąsiadów (8 kierunków, `Adjacent_Cell`), którzy mają `VEINS` i nie mają flagi `0x80000`, **bez limitu odległości** (hook `0x6629AC`);
  - pole dojrzałe (`OverlayData` 30h–34h) idzie tylko do zalewu, niedojrzałe (po `Can_Place_Veins`) zostaje węzłem wzrostu;
  - stykające się creepy należały więc w całości do jednego potwora.
- **Śmierć:**
  - `AI` w stanie 3 przy końcu animacji woła `Destroy_Monster` (`0x662DE0`);
  - `Destroy_Monster` kładzie żyły na środku i 4 polach prostopadłych, czyści przekątne, robi `Place_Veins` na 5×5, woła `Build_Shrinking_Queue` (`0x662BA0`) i ustawia `IsToShrink` (+9Ch);
  - `Build_Shrinking_Queue` przegląda całą mapę i bierze tylko **dojrzałe** żyły z mapy `+64h` tego potwora, z priorytetem `1000 − odległość`.
- **Kurczenie:**
  - `AI` co `VeinholeShrinkRate + Random(0, Rate/2)` klatek (Rules +0xC4, DTA 100) zdejmuje 1–4 pola z kolejki przez `Reduce_Veins_At` (`0x6633C0`);
  - przy 100 to ok. 1 pole na sekundę: sonda 2026-10-28 dała 23–41 pól na 1480 klatek, a Hive miał 565 pól;
  - martwego potwora nie widać: `Draw_It` (`0x661A30`) wychodzi przy `IsToShrink`;
  - `Update_All` (`0x6613C0`, druga pętla = wkompilowane `Remove_Dead`) kasuje potwora z `IsToShrink` i pustą kolejką.
- **Łatka (miejsca 11–13 `patch-veins.ps1`, `patch-veins-shrink.asm`, jaskinia `0x86C700`–`0x86C7D2`, [[mods/zerg-creep]]):**
  - 11: potwór utworzony w grze dostaje słowo `'ZC'` w `+9Eh` (z mapy: 0). Hook `0x58B71A`, `eax` = nowy potwór z konstruktora (`ret 4`, `mov eax,esi`);
  - 12: potwór `'ZC'`/`'ZG'` zalewa tylko pola z dx² + dy² ≤ 72, a jego dojrzałe pola stają się też węzłami wzrostu (`0x662A28`), więc po przebudowie odrasta w luki;
  - 13: po skasowaniu martwego potwora (`0x661408`) `Place_Monsters(false)` buduje kolejki od nowa, a żyły bez właściciela znikają;
  - w INI `VeinholeShrinkRate=5`;
  - 14 (2026-10-28, ARKA 5): promień na misję. Miejsca 9 i 12 zamiast `add eax,edx / cmp eax,72` wołają jaskinię `0x86C7E0` (`patch-veins-radius.asm`). Dla potwora `'ZC'` limit to `[General] VeinholeMonsterStrength`², gdy klucz ma 1–100, a dla reszty 72. TS czyta klucz do Rules `+0B8h` (`0x5CC05B`), domyślnie 10000 (konstruktor `0x5C4450`), i nigdzie go nie używa (Rules.ini: „no longer used”, siła potwora jest w `[VEINTREE]`). Mapa ustawia go w swoim `[General]`. Pola scenariusza z `[VariableNames]` się nie nadały, bo Vinifera trzyma zmienne lokalne we własnym `ScenarioClassExtension` (+153084, 500 × 44 B).

  Potwory z map DTA (słowo 0) zachowują się jak dotąd. **(niezweryfikowane w grze)**

Pola `VeinholeMonsterClass` (`Vinifera.pdb`): `+4Ch` liczba komórek, `+50h` `VeinCellQueue`, `+54h` `VeinCellNodes`, `+68h` stan, `+6Ch` następny stan, `+70h` klatka, `+94h` `MonsterCell`, `+98h` `ShapeFrame`, `+9Ch` `IsToShrink`, `+9Dh` `IsToPuffGas`, `+A0h` licznik dojrzałych.

`[Basic]` i `[General]` da się nadpisać z pliku Map Code (klient dokleja go do mapy), tak robi [[mods/zerg-creep]].

### Budowanie na żyłach

`CellClass::Is_Clear_To_Build` (`0x452250`) przy nakładce w komórce skacze do łatki DTA (`0x4525A2` → `0x86C0F0`): nakładka z `IsWall` (+0x138) blokuje, nakładka z `IsInsignificant` (ObjectType +0xCB, klucz `Insignificant=yes`) przepuszcza do testu landu (`[Weeds] Buildable=yes`), każda inna blokuje. Dlatego na zwykłych żyłach nie da się budować, a blok [[mods/zerg-creep]] daje `VEINS` i `VEINHOLEDUMMY` `Insignificant=yes`. Typy nakładek da się nadpisać z pliku mapy/Map Code: `Read_Scenario_INI` woła `RulesClass::Process` → `Objects`.

## Inne wejścia

- Akcja wyzwalacza `VEIN_GROWTH` (`TActionClass::Do_VEIN_GROWTH`), tylko w mapach z wyzwalaczami.
- Generator map losowych (`IsGenerateVeinholesInRMG`).
- Mapy z potworami: `Maps/Default/tiber.map`, `renegade_war.map`, misje `se05`, `se06`, `tte2a`, `tte4a–d`.
