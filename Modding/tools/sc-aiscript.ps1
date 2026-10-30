# Decodes StarCraft's AI scripts (scripts/aiscript.bin and bwscript.bin from the CASC of StarCraft: Remastered) into text:
# one "=== ID [name]" header per script (name from rez/stat_txt.tbl), then the reachable commands with their L<offset>
# labels (build orders, attack waves attack_add/attack_prepare/attack_do, defensebuild/defenseuse, expansions).
# Format and the 114 opcodes follow PyMS FileFormats/AIBIN.py (header u32 -> table of 16-byte entries ID, offset, string,
# flags; bwscript entries are 8 bytes). Campaign scripts: Ter1..T12x, Zer*, Pro*; melee: TMCx/ZMCx/PMCx.
# Example: Ter8 = AI of "The Trump Card" (ARKA 7 terrain). Wiki: engine/starcraft-assets, engine/advanced-ai.
# Usage: sc-aiscript.ps1 [-StarCraft <install dir>] [-Out <txt>]
param([string]$StarCraft = 'C:\Program Files (x86)\StarCraft', [string]$Out = "$env:TEMP\sc-aiscript.txt")
$tools = $PSScriptRoot
Add-Type -Path "$tools\Casc.cs"
$casc = New-Object Casc $StarCraft

function Read-Tbl([byte[]]$b) {
    $n = [BitConverter]::ToUInt16($b, 0); $s = New-Object string[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $o = [BitConverter]::ToUInt16($b, 2 + 2 * $i); $e = $o
        while ($e -lt $b.Length -and $b[$e] -ne 0) { $e++ }
        $s[$i] = ([Text.Encoding]::GetEncoding(28591).GetString($b, $o, $e - $o)) -replace '[\x00-\x1f]', ''
    }
    , $s
}
$tbl = Read-Tbl $casc.ReadFile('rez/stat_txt.tbl')
$upg = $casc.ReadFile('arr/upgrades.dat'); $tec = $casc.ReadFile('arr/techdata.dat')
function UnitName($id) { if ($id -lt 228) { $tbl[$id] -replace '\*$', '' } else { "unit$id" } }
function UpgName($id) { $l = [BitConverter]::ToUInt16($upg, 976 + 2 * $id); if ($l -gt 0) { $tbl[$l - 1] } else { "upg$id" } }
function TechName($id) { $l = [BitConverter]::ToUInt16($tec, 616 + 2 * $id); if ($l -gt 0) { $tbl[$l - 1] } else { "tech$id" } }

$cmds = @'
goto:block|notowns_jump:unit,block|wait:word|start_town:|start_areatown:|expand:byte,block|build:byte,unit,byte|upgrade:byte,upgrade,byte|tech:tech,byte|wait_build:byte,unit|wait_buildstart:byte,unit|attack_clear:|attack_add:byte,unit|attack_prepare:|attack_do:|wait_secure:|capt_expand:|build_bunkers:|wait_bunkers:|defensebuild_gg:byte,unit|defensebuild_ag:byte,unit|defensebuild_ga:byte,unit|defensebuild_aa:byte,unit|defenseuse_gg:byte,unit|defenseuse_ag:byte,unit|defenseuse_ga:byte,unit|defenseuse_aa:byte,unit|defenseclear_gg:|defenseclear_ag:|defenseclear_ga:|defenseclear_aa:|send_suicide:byte|player_enemy:|player_ally:|default_min:byte|defaultbuild_off:|stop:|switch_rescue:|move_dt:|debug:block,string|fatal_error:|enter_bunker:|value_area:|transports_off:|check_transports:|nuke_rate:byte|max_force:word|clear_combatdata:|random_jump:byte,block|time_jump:byte,block|farms_notiming:|farms_timing:|build_turrets:|wait_turrets:|default_build:|harass_factor:word|start_campaign:|race_jump:block,block,block|region_size:byte,block|get_oldpeons:byte|groundmap_jump:block|place_guard:unit,byte|wait_force:byte,unit|guard_resources:unit|call:block|return:|eval_harass:block|creep:byte|panic:block|player_need:byte,unit|do_morph:byte,unit|wait_upgrades:|multirun:block|rush:byte,block|scout_with:unit|define_max:byte,unit|train:byte,unit|target_expansion:|wait_train:byte,unit|set_attacks:byte|set_gencmd:|make_patrol:|give_money:|prep_down:byte,byte,unit|resources_jump:word,word,block|enter_transport:|exit_transport:|sharedvision_on:byte|sharedvision_off:byte|nuke_location:|harass_location:|implode:|guard_all:|enemyowns_jump:unit,block|enemyresources_jump:word,word,block|if_dif:byte,byte,block|easy_attack:byte,unit|kill_thread:|killable:|wait_finishattack:|quick_attack:|junkyard_dog:|fake_nuke:|disruption_web:|recall_location:|set_randomseed:dword|if_owned:unit,block|create_nuke:|create_unit:unit,word,word|nuke_pos:word,word|help_iftrouble:|allies_watch:byte,block|try_townpoint:byte,block|if_towns:
'@.Trim() -split '\|' | ForEach-Object { $n, $p = $_ -split ':'; [pscustomobject]@{ Name = $n; P = @($p -split ',' | Where-Object { $_ }) } }
$ends = 'goto', 'stop', 'return', 'kill_thread'

function Decode([byte[]]$b, [int]$start, $sb) {
    # disassemble reachable code from $start (follow blocks), label addresses
    $todo = New-Object System.Collections.Generic.Queue[int]; $todo.Enqueue($start); $seen = @{}; $lines = @{}
    while ($todo.Count) {
        $pc = $todo.Dequeue()
        while ($pc -lt $b.Length -and -not $seen.ContainsKey($pc)) {
            $seen[$pc] = 1; $at = $pc; $op = $b[$pc]; $pc++
            if ($op -ge $cmds.Count) { $lines[$at] = "?? op $op"; break }
            $c = $cmds[$op]; $args = @()
            foreach ($t in $c.P) {
                switch ($t) {
                    'byte' { $args += $b[$pc]; $pc++ }
                    'word' { $args += [BitConverter]::ToUInt16($b, $pc); $pc += 2 }
                    'dword' { $args += [BitConverter]::ToUInt32($b, $pc); $pc += 4 }
                    'block' { $a = [BitConverter]::ToUInt16($b, $pc); $pc += 2; $args += ('L{0:X4}' -f $a); $todo.Enqueue($a) }
                    'unit' { $args += (UnitName ([BitConverter]::ToUInt16($b, $pc))); $pc += 2 }
                    'upgrade' { $args += (UpgName ([BitConverter]::ToUInt16($b, $pc))); $pc += 2 }
                    'tech' { $args += (TechName ([BitConverter]::ToUInt16($b, $pc))); $pc += 2 }
                    'string' { $e = $pc; while ($b[$e] -ne 0) { $e++ }; $args += '"' + [Text.Encoding]::ASCII.GetString($b, $pc, $e - $pc) + '"'; $pc = $e + 1 }
                }
            }
            $lines[$at] = "$($c.Name)($($args -join ', '))"
            if ($ends -contains $c.Name) { break }
        }
    }
    foreach ($k in ($lines.Keys | Sort-Object)) { [void]$sb.AppendLine(('  L{0:X4}: {1}' -f $k, $lines[$k])) }
}

$sb = New-Object Text.StringBuilder
foreach ($file in 'scripts/aiscript.bin', 'scripts/bwscript.bin') {
    $b = $casc.ReadFile($file); $tab = [BitConverter]::ToUInt32($b, 0); $p = $tab
    [void]$sb.AppendLine("######## $file")
    $isBw = $file -like '*bwscript*'
    while ($p + 4 -le $b.Length -and [BitConverter]::ToUInt32($b, $p) -ne 0) {
        $id = [Text.Encoding]::ASCII.GetString($b, $p, 4); $off = [BitConverter]::ToUInt32($b, $p + 4)
        if ($isBw) { $p += 8; $name = '' } else { $si = [BitConverter]::ToUInt32($b, $p + 8); $fl = [BitConverter]::ToUInt32($b, $p + 12); $p += 16; $name = if ($si -gt 0) { $tbl[$si - 1] } else { '' } }
        [void]$sb.AppendLine("=== $id  [$name]  off=$off flags=$fl")
        if ($off -ne 0) { Decode $b ([int]$off) $sb }
    }
}
[IO.File]::WriteAllText($Out, $sb.ToString())
"written $Out ($((Get-Item $Out).Length) bytes)"
