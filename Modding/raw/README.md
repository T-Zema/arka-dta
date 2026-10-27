# Raw sources

Warstwa surowa wiki: tylko do odczytu. LLM czyta, nigdy nie edytuje.

## Źródła zewnętrzne (kopie w `sources/`)

- `sources/karpathy-llm-wiki.md`: wzorzec, według którego prowadzona jest ta wiki.

## Źródła w plikach gry (nie kopiujemy, bo są duże i aktualizuje je klient)

| Plik | Co zawiera |
|---|---|
| `INI/Rules.ini` | wszystkie typy jednostek, budynków, broni, głowic, supermocy, stron (~750 KB) |
| `INI/Art.ini` | grafiki: `Cameo=`, `Foundation=`, sekwencje piechoty, animacje |
| `INI/AI.ini`, `INI/AIE.ini` | zespoły AI, TaskForces, AITriggerTypes |
| `INI/Battle.ini` | lista misji, np. `[M_FROSTBITE]` → `Scenario=Maps/Missions/FRSTBITE.MAP` |
| `INI/Map Code/*.ini` | wspólny kod dołączany do map przez `[INISystem] BasedOn=` |
| `INI/Game Options/*.ini` | opcje skirmisha, które klient dokleja do mapy |
| `Maps/Missions/*.map` | misje (kampanie/single), `Maps/Default/*.map` (skirmish), `Maps/Co-Op/*.map` |
| `Resources/SkirmishLobby.ini` | układ lobby skirmisha w kliencie (checkboxy, dropdowny) |
| `spawn.ini`, `spawnmap.ini` | generowane przy każdym starcie gry: ustawienia i scalona mapa |
| `Debug/DEBUG_*.LOG`, `EXCEPT_*.TXT`, `CRASHDUMP_*.DMP` | logi silnika i crashe |

Gdy użytkownik dostarczy nowe materiały (np. assety StarCrafta), opisz je tutaj albo w `sources/`.
