# Deploy piechoty i stimpack na prawdziwej piechocie SC

Łatka `game.exe`, która pozwala piechocie się rozstawiać (klawisz D = zamiana w typ-partnera), oraz testowe jednostki Terran, które z tego korzystają: Marine i Firebat jako prawdziwa piechota ze stimpackiem. Zainstalowane 2026-10-27 (łatka na `game.exe`, `ECACHE81.MIX`, bloki INI). **(niezweryfikowane w grze)**

Źródła: `game.exe` + `Game.pdb` (`DeployCommandClass::Execute` 0x4E9400, `EventClass::Execute` 0x494280 z tablicą skoków 0x49511C, `TechnoClass::Can_Deploy_Now` 0x632070, `InfantryTypeClass::From_Name` 0x4DA5E0, `HouseClass::Tracking_Remove/Add` 0x4C2060/0x4C2190), `Vinifera.pdb` (przesunięcia pól), źródło Vinifery `unitext_hooks.cpp` (wzór zamiany pojazdów), `tools/patch-infdeploy.asm`, `tools/patch-infdeploy.ps1`, `tools/build-scinfstim.ps1`, CASC (`unit/terran/marine.grp`, `firebat.grp`, `tmashad`, `tfbshad`, `tmadeath`).

## Pliki

| Plik | Co |
|---|---|
| `tools/patch-infdeploy.ps1` | łatka `game.exe` (4 haki + jaskinia 568 B w oknie `0x86C400`–`0x86C6FF`, wersja 6; v4 i v5 rozpoznawane i zastępowane), `-Revert`, `-Exe <kopia>`; w `tools/patch-game.ps1` |
| `tools/patch-infdeploy.asm` | źródło jaskini z komentarzami (nasm: `pixi exec --spec nasm nasm -f bin …`) |
| `tools/build-scinfstim.ps1` | grafiki → `MIX/ECACHE81.MIX`, `-Install` = bloki „SC infantry stim” w `INI/Game Options/StarCraft.ini`, `INI/Art.ini`, `INI/Sound.ini` (+ 2 wpisy w `[SoundList]`) (kopie `.bak` przy pierwszej instalacji) |

## Jak działa deploy piechoty

- **Reguła bez listy:** typ piechoty `X` rozstawia się w typ piechoty o nazwie `X_D`, a `X_D` wraca w `X`. Typ bez partnera zachowuje się jak dotąd. Nazwy z wielkim `_D` (porównanie końcówki jest czułe na wielkość liter, szukanie typu już nie).
- **Klawisz D** (`DeployCommandClass`). Kliknięcie piechoty na niej samej nic nie robi: kursor deploy dla piechoty to osobny hak (`InfantryClass::What_Action`), na razie niezrobiony.
- **Koszt:** `X` → `X_D` zabiera 1/4 maksymalnego HP `X` (przy HP ≤ 1/4 odmowa, nic się nie dzieje). Reszta zachowuje proporcję do max HP nowego typu. Powrót `X_D` → `X`: proporcja bez kosztu.
- **Zamiana w miejscu:** ten sam obiekt dostaje nowy wskaźnik typu (`InfantryClass+0x350`). Dom przelicza typy przez `Tracking_Remove` (stary typ) i `Tracking_Add` (nowy). Zostają: zaznaczenie, grupa Ctrl+N, weteran, tag triggera, pozycja, cel ataku (stim w trakcie walki strzela dalej) i drużyna AI. Tak samo działa „Convert” w Ares (YR).
- **Multiplayer:** zamiana dzieje się w obsłudze zdarzenia sieciowego `EVENT_DEPLOY`, które wykonuje się u wszystkich graczy w tej samej klatce.
- AI tego nie używa (nie wydaje rozkazu deploy piechocie).

### Szczegóły silnika (2026-10-27)

- `DeployCommandClass::Execute` wysyła `EVENT_DEPLOY` (nr 9) dla każdego zaznaczonego technika, jeśli `Can_Player_Move` albo `Can_Player_Fire`, a do tego `Can_Attack_Now` (dla piechoty zawsze prawda) i `Can_Deploy_Now`.
- `Can_Deploy_Now` dla obiektów niebędących pojazdami odmawia, gdy typ ma `Passengers=0`. Dlatego piechota nigdy nie wysyłała rozkazu. **Vinifera podmienia tę funkcję w pamięci** własną `TechnoClassExt::_Can_Deploy_Now` (ta sama reguła: `Max_Passengers() == 0` = odmowa), więc hak `0x632265` w oryginale w grze się nie wykonuje (test 2026-10-27: „nie mają deploya”). Działa hak 3 w samej komendzie D: `DeployCommandClass::Execute` `0x4E9482`, gdzie piechota z partnerem pomija pytanie o `Can_Deploy_Now` i od razu wysyła `EVENT_DEPLOY`. Hak `0x632265` został (nieszkodliwy, zadziała, gdyby Vinifera przestała podmieniać funkcję). Lekcja: przed łataniem funkcji w `game.exe` sprawdzić w `Vinifera.pdb`, czy nie ma `_<Nazwa>@<Klasa>Ext` (zastępnik) albo haka `_hk__0x00<adres>`.
- `EVENT_DEPLOY` (case 9, 0x494B04) sprawdza obiekt (aktywny, nie w limbo, nie samolot, misja ≠ budowa/rozbiórka), czyści cel i woła `Assign_Mission(15 = MISSION_UNLOAD)`. Piechota tej misji nie obsługuje. Hak `0x494C04` (przed czyszczeniem celu) robi zamianę i wychodzi z obsługi.
- Przesunięcia: obiekt `+0x28` Strength, `+0x30` IsSelected, `+0x24` Tag, `+0xE4` Group, `+0xEC` House; typ `+0x14` IniName[24], `+0x68` MaxStrength; vtable `+0x2C` Fetch_RTTI (piechota = `0x0F`), `+0x88` Class_Of. Wektor typów piechoty: `0x7E4014`, liczba `0x7E4020`.

## Jednostki testowe (Terran, dom `GDI1`, opcja STARCRAFT)

| Typ | Nazwa | Broń | HP | Prędkość | Gdzie |
|---|---|---|---|---|---|
| `SCMARI` | Marine (infantry) | `SCGauss` (ROF 20) | 500 | 8 | Terran Barracks, 200 |
| `SCMARI_D` | Marine (Stimpack) | `SCGaussS` (ROF 10) | 500 | 11 | tylko przez D |
| `SCFIRI` | Firebat (infantry) | `SCFlamer` (ROF 30) | 625 | 8 | Barracks + Academy, 400 |
| `SCFIRI_D` | Firebat (Stimpack) | `SCFlamerS` (ROF 15) | 625 | 11 | tylko przez D |

- **Marine strzela też do lotnictwa** (2026-10-27, prośba użytkownika): SCGauss/SCGaussS/SCGauss2/SCGauss2S w StarCraft.ini mają Projectile=Invisible3 (Rules: AA=yes, AG=yes) zamiast Invisible (bez AA). Broń jest wspólna, więc dotyczy też Marines z fabryki ([[mods/starcraft-marine]]). **(niezweryfikowane w grze)**
- HP = wersja pojazdowa / 1,6, bo prawdziwa piechota pada na ziemię i dostaje wtedy połowę obrażeń ([[engine/transform-deploy]]).
- To **prawdziwa piechota**: Barracks zamiast War Factory, leczy ją medyk, wsiada do transporterów, da się ją rozjechać. Pojazdowe Marines/Firebaty (`SCMARINE`, `SCFIRE` i ulepszenia z [[mods/starcraft-research]]) zostają bez zmian, więc obie wersje są naraz w menu. O ewentualnej podmianie decyduje użytkownik po teście.
- Grafika: `ScInfantry.Build` z GRP SC (8 kierunków). Marine: stoi 0, celuje 2, strzela 3 (błysk), chodzi 4–12, śmierć 221–228 + `tmadeath`. Firebat: stoi 0, ogień 1, chodzi 2–9. Jego GRP ma płótno 32×32 i nie ma klatek śmierci, więc przesuwam go na 64×64, a jako śmierć dostaje szczątki Marine'a. Wersja `_D`: ta sama mapa ramek z czerwonym odcieniem 0,35 (jak `SCMARSTM`). Sekwencje `SCMARISequence` i `SCFIRISequence` są wspólne dla `X` i `X_D`.
- Dźwięki z istniejącego Sound.ini (`SCMA*`, `SCFB*`). Dźwięk stimpacka przy zamianie gra łatka od v5 (niżej).

## Do sprawdzenia w grze

- Czy D zamienia Marine'a w wersję stim i z powrotem, czy pasek HP spada o 1/4, czy przy niskim HP odmawia.
- Czy po zamianie zostaje zaznaczenie, grupa i cel, i czy nowy typ strzela szybciej i biega szybciej (prędkość może być liczona z typu tylko przy starcie ruchu).
- Czy limit/liczniki domu się zgadzają (np. po zamianie da się dalej budować jednostki).
- Czy grafika piechoty w 8 kierunkach patrzy w dobrą stronę, czy śmierć Firebata wygląda znośnie.
- Ewentualne crashe: raport z `Debug/`, adres w jaskini `0x86C400`–`0x86C637` wskaże łatkę.

## Możliwe dalsze kroki

- Kursor deploy po kliknięciu na siebie (hak w `InfantryClass::What_Action`).
- Podmiana pojazdowych Marines/Firebatów na piechotę w całej frakcji Terran (z modem badań).

## Stan po teście 2026-10-27 i wersja 5

- **Działa w grze** (użytkownik, 2026-10-27): klawisz D zamienia Marine (infantry) w wersję stim i z powrotem. Tylko klawisz D, nie kliknięcie na siebie (kursor deploy dla piechoty nie jest zrobiony).
- **Dźwięk stimpacka:** przy `X` → `X_D` łatka gra wpis Sound.ini o nazwie nowego typu (`VocClass::From_Name` 0x665100 + `Static_Sound` 0x664D10 w pozycji żołnierza z `Center_Coord`). `[SCMARI_D] Sounds=SCMASTI0`, `[SCFIRI_D] Sounds=SCMASTI1` (te same pliki co `VoiceDeploy` pojazdowych). Sound.ini w DTA nie używa list wielu plików w `Sounds=`, więc jeden plik na wpis.
- **Koniec po 30 s czasu gry:** hak na wejściu `InfantryClass::AI` (0x4D4EB0, prolog 6 B). Dla typów z nazwą kończącą się na `_D`: licznik w 2 bajtach wyrównania `InfantryClass+0x36E` (między `WasSelected` 0x36D a `ProneStruggleTimer` 0x370) = młodsze 16 bitów klatki końca (`Frame` 0x7E4924 + 450). Porównanie z zawijaniem (`sub dx,ax` / `js`). Po czasie zamiana z powrotem bez kosztu. Licznik 0 (np. `X_D` postawiony w mapie albo z gry zapisanej przed v5) startuje nowe 30 s. Zapis gry kopiuje cały obiekt, więc licznik przetrwa save/load. **(niezweryfikowane w grze)**
- **Medyk (infantry)** `SCMEDI`: prawdziwa piechota, Barracks + Academy, `SCHealGun` (−150, `Organic`), HP 750 (pojazdowy 1200 / 1,6), `GuardRange=6`, `SpecialThreatValue=1`, głosy `SCMD*`, bez stimu (brak `SCMEDI_D`, więc D nic nie robi). Grafika: zestawy jak `SCMEDIC` (0 stoi, 4–5 leczy, 6–12 chodzi), śmierć 221–229 + `tmeDeath`.
- Historia łatki: v1 (hak w `Can_Deploy_Now`, martwy przez Viniferę), v2 (+ hak klawisza D), v3 (diagnostyka `INFDEP`, crash przez `ret 4`), v4 (poprawka), v5 (dźwięk + 30 s, 804 B: weszła w `0x86C700`, gdzie sesja creepu planowała jaskinię żył; `patch-veins.ps1` odmówił), **v6** (v5 bez diagnostyki `INFDEP` i bez haka `0x4E9400`, 568 B, mieści się przed `0x86C700`; skrypt przywraca oryginalne bajty `0x4E9400` i zeruje ogon v5).