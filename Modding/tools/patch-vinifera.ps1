# All binary patches of Vinifera.dll in one go, e.g. after a DTA client update replaced Vinifera.dll (counterpart of
# patch-game.ps1). Every patch checks the original bytes first, so a different Vinifera build is refused instead of corrupted,
# and running this again is harmless ("already patched"). Close the game first. Backup: Vinifera.dll.bak (made by the first patch).
#   patch-vinifera-workers.ps1   SC workers: refinery-ConYard keeps its radio, harvest animation only while harvesting  mods/sc-workers
#   patch-vinifera-veins.ps1     Zerg creep spreaders in AnimClassExt::_AI (caves in .scdock + 0x100)                   mods/zerg-creep
#   patch-vinifera-overlord.ps1  harvested tiberium respects Overlord storage (own section .scstor)                     plans/overlord-storage
#   patch-vinifera-navalai.ps1   AI queues Naval=yes Probe/MCV in the naval queue, classic AI: water only if WaterBound (.scai)  mods/protoss-ai
#   patch-vinifera-siegeai.ps1   AI deploys units (Siege Tank) only with a target in range; Terran AI folds idle ones (.scsiege)  mods/terran-ai
# Order matters (sections are appended); -Revert runs it backwards. Wiki: engine/game-exe-patching.
# Usage: patch-vinifera.ps1 [-Revert] [-Dll <copy>]. -Dll patches a copy (test, or tools/dta-restore.ps1 checking a new DTA version).
param([switch]$Revert, [string]$Dll = "")
$ErrorActionPreference = 'Stop'
if (-not $Dll -and (Get-Process -Name game -ErrorAction SilentlyContinue)) { throw "game.exe is running: close the game first" }
$order = @('patch-vinifera-workers.ps1', 'patch-vinifera-veins.ps1', 'patch-vinifera-overlord.ps1', 'patch-vinifera-navalai.ps1', 'patch-vinifera-siegeai.ps1')
if ($Revert) { [array]::Reverse($order) }
$common = @{}; if ($Revert) { $common.Revert = $true }; if ($Dll) { $common.Dll = $Dll }
foreach ($p in $order) {
    try {
        $out = & "$PSScriptRoot\$p" @common
        "{0,-28} {1}" -f $p, (($out | Select-Object -Last 1) -as [string])
    } catch {
        "{0,-28} FAILED: {1}" -f $p, $_.Exception.Message
    }
}
