# All binary patches of game.exe (TS 2.03 + DTA) in one go, e.g. after a DTA client update replaced game.exe.
# Every patch checks the original bytes first, so a different game.exe version is refused instead of corrupted, and running
# this again is harmless ("already patched"). Close the game first. Backup: game.exe.bak (original, made by the first patch).
#   patch-flyhover.ps1     Fly-locomotor vehicles hover instead of landing (Terran warships, Protoss flyers)  engine/fly-locomotor
#   patch-buildup.ps1      buildups longer than ~81 ticks (Zerg morph times)                                engine/buildup-timing
#   patch-spawnreturn.ps1  aircraft may fly to a flying unit (Interceptors return to the Protoss Carrier)    engine/spawners
#   patch-freescv.ps1      FreeUnit=SCSCV gives two SCVs (Terran Refinery)                                    mods/sc-workers
#   patch-veins.ps1        Veinhole Monsters can appear during the game (Zerg creep: Creep Tumor, spreaders) mods/zerg-creep
#   patch-infdeploy.ps1    infantry deploy: type X <-> X_D on the D key (SC stimpacks on real infantry)       engine/transform-deploy
#   patch-flyertarget.ps1  anti-air units auto-acquire flying Fly-locomotor vehicles (Mutalisks...) on guard engine/fly-locomotor
#   patch-zergbuild.ps1    only Zergs build on creep, Zerg buildings need creep (Is_Clear_To_Build wrapper)  mods/zerg-creep
#   patch-overlordstorage.ps1  vehicles with Storage= (Overlord) raise the silo capacity; pairs with Vinifera.dll
#                          patch-vinifera-overlord.ps1                                                       plans/overlord-storage
#   patch-airboard.ps1     infantry boards a transport hovering above its cell (Fly Dropship/Shuttle)        engine/transports
# Usage: patch-game.ps1 [-Revert] [-FlyDebug] [-Exe <copy>]. -FlyDebug installs the fly patch in its -Debug (logging) variant
# (installed since 2026-10-25; tools/dta-restore.ps1 passes it when tools/dta-sync.json says so). Without it an installed -Debug
# variant is kept, but a pristine game.exe gets the plain one.
# -Exe patches a copy (test, or tools/dta-restore.ps1 checking a new DTA version); the game may run meanwhile.
param([switch]$Revert, [switch]$FlyDebug, [string]$Exe = "")
$ErrorActionPreference = 'Stop'
if (-not $Exe -and (Get-Process -Name game -ErrorAction SilentlyContinue)) { throw "game.exe is running: close the game first" }
$order = @('patch-flyhover.ps1', 'patch-buildup.ps1', 'patch-spawnreturn.ps1', 'patch-freescv.ps1', 'patch-veins.ps1', 'patch-infdeploy.ps1', 'patch-flyertarget.ps1', 'patch-zergbuild.ps1', 'patch-overlordstorage.ps1', 'patch-airboard.ps1')
if ($Revert) { [array]::Reverse($order) }
$common = @{}; if ($Revert) { $common.Revert = $true }; if ($Exe) { $common.Exe = $Exe }
foreach ($p in $order) {
    try {
        $variant = @{}; if ($FlyDebug -and $p -eq 'patch-flyhover.ps1') { $variant.Debug = $true }
        $out = & "$PSScriptRoot\$p" @common @variant
        "{0,-22} {1}" -f $p, (($out | Select-Object -Last 1) -as [string])
    } catch {
        $msg = $_.Exception.Message
        # the fly patch may be installed in its -Debug (logging) variant: then the plain bytes do not match, which is fine
        if ($p -eq 'patch-flyhover.ps1') {
            try {
                $dbg = & "$PSScriptRoot\$p" @common -Debug
                "{0,-22} (-Debug variant) {1}" -f $p, (($dbg | Select-Object -Last 1) -as [string]); continue
            } catch { }
        }
        "{0,-22} FAILED: {1}" -f $p, $msg
    }
}
