# Buduje wersje HTML scenariusza kampanii z wiki. Markdown jest zamieniany na HTML tutaj,
# wiec strona nie potrzebuje JavaScriptu ani bibliotek z sieci (dziala tez offline).
# Obslugiwany podzbior markdowna: naglowki, akapity, listy (zagniezdzone), cytaty, tabele,
# **pogrubienie**, *kursywa*, `kod`, [link](url), linki Obsidiana [[strona]].
# Uzycie: & Modding\tools\build-campaign-html.ps1 [-Source <md>] [-Out <html>]
param(
    [string]$Source = (Join-Path $PSScriptRoot '..\wiki\plans\campaign-arka.md'),
    [string]$Out    = (Join-Path $PSScriptRoot '..\exports\campaign-arka.html')
)
$ErrorActionPreference = 'Stop'

$script:tocItems = New-Object System.Collections.Generic.List[object]
$script:usedIds = @{}

function Get-Slug([string]$text) {
    $plain = [regex]::Replace($text, '<[^>]+>', '')
    $d = $plain.Normalize([System.Text.NormalizationForm]::FormD)
    $sbS = New-Object System.Text.StringBuilder
    foreach ($ch in $d.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sbS.Append($ch) }
    }
    $s = $sbS.ToString().Replace('ł', 'l').Replace('Ł', 'L').ToLowerInvariant()
    $s = [regex]::Replace($s, '[^a-z0-9]+', '-').Trim('-')
    if (-not $s) { $s = 'sekcja' }
    $id = $s; $k = 2
    while ($script:usedIds.ContainsKey($id)) { $id = "$s-$k"; $k++ }
    $script:usedIds[$id] = $true
    return $id
}

function Convert-Inline([string]$t) {
    $codes = New-Object System.Collections.Generic.List[string]
    $t = [regex]::Replace($t, '`([^`]+)`', {
        param($m)
        $codes.Add('<code>' + [System.Net.WebUtility]::HtmlEncode($m.Groups[1].Value) + '</code>')
        '@@C' + ($codes.Count - 1) + '@@'
    })
    $t = [regex]::Replace($t, '&(?!#?\w+;)', '&amp;')
    $t = $t.Replace('<', '&lt;')
    $t = [regex]::Replace($t, '\[\[([^\]]+)\]\]', '<span class="wl" title="strona wiki">$1</span>')
    $t = [regex]::Replace($t, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $t = [regex]::Replace($t, '(?<![\*\w])\*(?![\s\*])(.+?)(?<![\s\*])\*(?![\*\w])', '<em>$1</em>')
    $t = [regex]::Replace($t, '\[([^\]]+)\]\(([^)\s]+)\)', '<a href="$2">$1</a>')
    $t = [regex]::Replace($t, '@@C(\d+)@@', { param($m) $codes[[int]$m.Groups[1].Value] })
    return $t
}

function Test-BlockStart([string]$l) {
    return ($l -match '^#{1,6}\s' -or $l -match '^>' -or $l -match '^([-*]|\d+\.)\s' -or $l -match '^\|')
}

function Split-Row([string]$row) {
    $r = $row.Trim()
    if ($r.StartsWith('|')) { $r = $r.Substring(1) }
    if ($r.EndsWith('|')) { $r = $r.Substring(0, $r.Length - 1) }
    return ,($r.Split('|') | ForEach-Object { $_.Trim() })
}

function Convert-Blocks([string[]]$ls) {
    $sb = New-Object System.Text.StringBuilder
    $i = 0
    $n = $ls.Count
    while ($i -lt $n) {
        $l = $ls[$i]
        if ($l.Trim() -eq '') { $i++; continue }

        $hm = [regex]::Match($l, '^(#{1,6})\s+(.*)$')
        if ($hm.Success) {
            $lvl = $hm.Groups[1].Length
            $inner = Convert-Inline $hm.Groups[2].Value.Trim()
            $id = Get-Slug $inner
            if ($lvl -eq 2 -or $lvl -eq 3) { $script:tocItems.Add(@($lvl, $id, [regex]::Replace($inner, '<[^>]+>', ''))) }
            [void]$sb.Append("<h$lvl id=`"$id`">$inner</h$lvl>`n")
            $i++; continue
        }

        if ($l -match '^\|' -and ($i + 1) -lt $n -and $ls[$i + 1] -match '^\|[\s:\-|]+$') {
            [void]$sb.Append("<div class=`"table-wrap`"><table>`n<thead><tr>")
            foreach ($c in (Split-Row $l)) { [void]$sb.Append('<th>' + (Convert-Inline $c) + '</th>') }
            [void]$sb.Append("</tr></thead>`n<tbody>`n")
            $i += 2
            while ($i -lt $n -and $ls[$i] -match '^\|') {
                [void]$sb.Append('<tr>')
                foreach ($c in (Split-Row $ls[$i])) { [void]$sb.Append('<td>' + (Convert-Inline $c) + '</td>') }
                [void]$sb.Append("</tr>`n")
                $i++
            }
            [void]$sb.Append("</tbody></table></div>`n")
            continue
        }

        if ($l -match '^>') {
            $q = New-Object System.Collections.Generic.List[string]
            while ($i -lt $n -and $ls[$i] -match '^>') { $q.Add(($ls[$i] -replace '^>\s?', '')); $i++ }
            [void]$sb.Append('<blockquote>' + (Convert-Blocks $q.ToArray()) + "</blockquote>`n")
            continue
        }

        $lm = [regex]::Match($l, '^([-*]|\d+\.)\s+')
        if ($lm.Success) {
            $ordered = $lm.Groups[1].Value -match '^\d'
            $tag = 'ul'; if ($ordered) { $tag = 'ol' }
            [void]$sb.Append("<$tag>`n")
            while ($i -lt $n) {
                $im = [regex]::Match($ls[$i], '^([-*]|\d+\.)(\s+)(.*)$')
                if (-not $im.Success) { break }
                if (($im.Groups[1].Value -match '^\d') -ne $ordered) { break }
                $w = $im.Groups[1].Length + $im.Groups[2].Length
                $item = New-Object System.Collections.Generic.List[string]
                $item.Add($im.Groups[3].Value)
                $loose = $false
                $i++
                while ($i -lt $n) {
                    $nx = $ls[$i]
                    if ($nx.Trim() -eq '') {
                        $j = $i
                        while ($j -lt $n -and $ls[$j].Trim() -eq '') { $j++ }
                        if ($j -lt $n -and $ls[$j] -match '^\s{2,}\S') {
                            $item.Add(''); $loose = $true; $i = $j; continue
                        }
                        break
                    }
                    if ($nx -match '^\s{2,}\S') {
                        $ind = $nx.Length - $nx.TrimStart().Length
                        $item.Add($nx.Substring([Math]::Min($ind, $w)))
                        $i++; continue
                    }
                    break
                }
                $li = Convert-Blocks $item.ToArray()
                if (-not $loose) {
                    $li = [regex]::Replace($li, '^<p>(.*?)</p>\n?', '$1', [System.Text.RegularExpressions.RegexOptions]::Singleline)
                }
                [void]$sb.Append("<li>$li</li>`n")
                # pusta linia miedzy punktami tej samej listy
                if ($i -lt $n -and $ls[$i].Trim() -eq '') {
                    $j = $i
                    while ($j -lt $n -and $ls[$j].Trim() -eq '') { $j++ }
                    $nm = $null
                    if ($j -lt $n) { $nm = [regex]::Match($ls[$j], '^([-*]|\d+\.)\s+') }
                    if ($nm -and $nm.Success -and (($nm.Groups[1].Value -match '^\d') -eq $ordered)) { $i = $j } else { break }
                }
            }
            [void]$sb.Append("</$tag>`n")
            continue
        }

        # akapit: kazda linia zrodla to osobna linia (dialogi)
        $para = New-Object System.Collections.Generic.List[string]
        while ($i -lt $n -and $ls[$i].Trim() -ne '' -and ($para.Count -eq 0 -or -not (Test-BlockStart $ls[$i]))) {
            $para.Add((Convert-Inline $ls[$i].Trim())); $i++
        }
        $text = [string]::Join("<br>`n", $para.ToArray())
        $cls = ''
        if ($text.StartsWith('Źródła:')) { $cls = ' class="sources"' }
        [void]$sb.Append("<p$cls>$text</p>`n")
    }
    return $sb.ToString()
}

# --- wczytanie i podzial na tytul, streszczenie, tresc ---
$mdText = [System.IO.File]::ReadAllText((Resolve-Path $Source), [System.Text.Encoding]::UTF8)
$allLines = $mdText -split "`r?`n"
$titleIdx = -1
for ($x = 0; $x -lt $allLines.Count; $x++) { if ($allLines[$x] -match '^#\s') { $titleIdx = $x; break } }
$leadIdx = -1
for ($x = $titleIdx + 1; $x -lt $allLines.Count; $x++) { if ($allLines[$x].Trim() -ne '') { $leadIdx = $x; break } }
$leadHtml = Convert-Inline $allLines[$leadIdx].Trim()
$bodyLines = New-Object System.Collections.Generic.List[string]
for ($x = 0; $x -lt $allLines.Count; $x++) { if ($x -ne $titleIdx -and $x -ne $leadIdx) { $bodyLines.Add($allLines[$x]) } }
$bodyHtml = Convert-Blocks $bodyLines.ToArray()

$tocSb = New-Object System.Text.StringBuilder
foreach ($t in $script:tocItems) {
    [void]$tocSb.Append("<li class=`"lvl$($t[0])`"><a href=`"#$($t[1])`">$($t[2])</a></li>`n")
}

$template = @'
<title>ARKA: Błąd znaku</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Saira+Condensed:wght@500;600;700&family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,600;1,8..60,400&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
/* Uklad: odprawa sztabowa. Pasek skokow w czasie u gory, spis tresci z boku, tekst kampanii w jednej kolumnie. */
:root {
  --bg: #edf1ee;
  --surface: #fbfcfb;
  --fg: #17201c;
  --muted: #56645d;
  --line: #cbd5cf;
  --accent: #2b8a3c;      /* zielen Tyberium */
  --accent-2: #2b5a8c;    /* blekit Aliantow */
  --quote-bg: #e2ebe5;
  --code-bg: #e4e9e6;
  --f-display: "Saira Condensed", "Arial Narrow", "Roboto Condensed", sans-serif;
  --f-body: "Source Serif 4", Georgia, "Times New Roman", serif;
  --f-mono: "JetBrains Mono", Consolas, "Courier New", monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #0d1311; --surface: #141c19; --fg: #e2eae5; --muted: #93a49b; --line: #26322d;
    --accent: #66d276; --accent-2: #80b1e6; --quote-bg: #13221a; --code-bg: #1b2521;
    color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #0d1311; --surface: #141c19; --fg: #e2eae5; --muted: #93a49b; --line: #26322d;
  --accent: #66d276; --accent-2: #80b1e6; --quote-bg: #13221a; --code-bg: #1b2521;
  color-scheme: dark;
}
body { background: var(--bg); color: var(--fg); font: 400 1.0625rem/1.65 var(--f-body); margin: 0; }
a { color: var(--accent-2); }
a:focus-visible, summary:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; border-radius: 2px; }

.band { background: var(--surface); border-bottom: 1px solid var(--line); }
.wrap { max-width: 1180px; margin: 0 auto; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
.hero { padding-block: 2.5rem 2rem; display: grid; gap: 1.25rem; }
.eyebrow { font: 600 0.8rem/1.2 var(--f-mono); letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); margin: 0; }
h1 { font: 700 clamp(2.4rem, 6vw, 4rem)/1 var(--f-display); letter-spacing: 0.01em; margin: 0; text-wrap: balance; }
h1 .sign { color: var(--accent); }
.lead { max-width: 65ch; margin: 0; font-size: 1.15rem; }

.jumps { list-style: none; margin: 0.5rem 0 0; padding: 0; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); border: 1px solid var(--line); border-radius: 4px; overflow: hidden; }
.jumps li { padding: 0.85rem 1rem; border-left: 1px solid var(--line); display: grid; gap: 0.15rem; min-width: 0; }
.jumps li:first-child { border-left: 0; }
.jumps li.ghost { background: repeating-linear-gradient(135deg, transparent 0 8px, var(--quote-bg) 8px 9px); }
.jumps .yr { font: 700 1.9rem/1 var(--f-display); font-variant-numeric: tabular-nums; }
.jumps .place { font-size: 0.95rem; }
.jumps .delta { font: 600 0.78rem/1.3 var(--f-mono); color: var(--muted); }
.jumps .delta b { color: var(--accent); font-weight: 600; }
@media (max-width: 720px) {
  .jumps { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .jumps li:nth-child(3) { border-left: 0; }
  .jumps li:nth-child(n+3) { border-top: 1px solid var(--line); }
}

.layout { display: grid; grid-template-columns: 230px minmax(0, 1fr); gap: 3rem; padding-block: 2rem 4rem; align-items: start; }
.toc { position: sticky; top: calc(env(safe-area-inset-top, 0px) + 1rem); max-height: calc(100vh - 2rem); overflow: auto; font-size: 0.9rem; }
.toc summary { font: 600 0.8rem/1.2 var(--f-mono); letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); cursor: pointer; padding-block: 0.25rem; }
.toc ol { list-style: none; margin: 0.5rem 0 0; padding: 0; display: grid; gap: 0.15rem; }
.toc a { color: var(--fg); text-decoration: none; display: block; padding: 0.2rem 0 0.2rem 0.6rem; border-left: 2px solid transparent; line-height: 1.35; }
.toc a:hover { border-left-color: var(--accent); }
.toc .lvl3 a { padding-left: 1.4rem; color: var(--muted); font-size: 0.85rem; }
@media (max-width: 960px) {
  .layout { grid-template-columns: minmax(0, 1fr); gap: 1.5rem; }
  .toc { position: static; max-height: none; border: 1px solid var(--line); border-radius: 4px; padding: 0.5rem 0.75rem; background: var(--surface); }
}

article { max-width: 72ch; min-width: 0; }
article h2 { font: 700 1.9rem/1.15 var(--f-display); text-transform: uppercase; letter-spacing: 0.02em; margin: 3rem 0 0.75rem; padding-top: 0.75rem; border-top: 2px solid var(--fg); text-wrap: balance; scroll-margin-top: 1rem; }
article h3 { font: 600 1.35rem/1.2 var(--f-display); letter-spacing: 0.02em; margin: 2rem 0 0.5rem; color: var(--accent-2); text-wrap: balance; scroll-margin-top: 1rem; }
article > p:first-child { margin-top: 0; }
article p, article ul, article ol { margin: 0 0 0.9rem; }
article ul, article ol { padding-left: 1.4rem; }
article li { margin-bottom: 0.35rem; }
article li > ul, article li > ol, article li > blockquote { margin-top: 0.4rem; }
article strong { font-weight: 600; }
article code { font: 400 0.85em/1 var(--f-mono); background: var(--code-bg); padding: 0.12em 0.35em; border-radius: 3px; overflow-wrap: anywhere; }
article .sources { font-size: 0.85rem; color: var(--muted); border-left: 2px solid var(--line); padding-left: 0.75rem; }

/* Kwestie postaci jako komunikaty radiowe */
article blockquote { margin: 0 0 1rem; padding: 0.6rem 1rem; background: var(--quote-bg); border-left: 3px solid var(--accent); border-radius: 0 4px 4px 0; }
article blockquote p { margin: 0 0 0.4rem; line-height: 1.75; }
article blockquote p:last-child { margin-bottom: 0; }
article blockquote strong { font: 600 0.8rem/1 var(--f-mono); letter-spacing: 0.06em; text-transform: uppercase; color: var(--accent); }

.table-wrap { overflow-x: auto; margin: 0 0 1.25rem; border: 1px solid var(--line); border-radius: 4px; }
article table { border-collapse: collapse; width: 100%; font-size: 0.93rem; }
article th, article td { text-align: left; vertical-align: top; padding: 0.55rem 0.75rem; border-bottom: 1px solid var(--line); }
article th { font: 600 0.78rem/1.2 var(--f-mono); letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); background: var(--surface); }
article tr:last-child td { border-bottom: 0; }
article td:first-child { font-variant-numeric: tabular-nums; font-weight: 600; min-width: 4.5rem; }

.wl { font: 400 0.82em/1 var(--f-mono); color: var(--accent-2); border-bottom: 1px dotted currentColor; }
</style>

<header class="band">
  <div class="wrap hero">
    <p class="eyebrow">Kampania mashup · Red Alert × StarCraft × Tiberian Dawn</p>
    <h1>ARKA: Błąd znaku<span class="sign"> ±</span></h1>
    <p class="lead">{{LEAD}}</p>
    <ol class="jumps" aria-label="Skoki ARKI w czasie">
      <li><span class="yr">1953</span><span class="place">Gibraltar</span><span class="delta">start ARKI · cel: 1946</span></li>
      <li><span class="yr">2499</span><span class="place">Mar Sara</span><span class="delta">miało być −7 · wyszło <b>+546</b></span></li>
      <li class="ghost"><span class="yr">1995</span><span class="place">nad Tybrem</span><span class="delta">tylko przystanek · „…znowu <b>plus</b>”</span></li>
      <li><span class="yr">2047</span><span class="place">Sarajewo</span><span class="delta"><b>+52</b> · tym razem celowo</span></li>
    </ol>
  </div>
</header>

<div class="wrap layout">
  <nav class="toc" aria-label="Spis treści">
    <details open>
      <summary>Spis treści</summary>
      <ol>
{{TOC}}      </ol>
    </details>
  </nav>
  <article>
{{BODY}}  </article>
</div>
'@

$page = $template.Replace('{{LEAD}}', $leadHtml).Replace('{{TOC}}', $tocSb.ToString()).Replace('{{BODY}}', $bodyHtml)
$outDir = Split-Path $Out -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
[System.IO.File]::WriteAllText($Out, $page, (New-Object System.Text.UTF8Encoding $false))
Write-Output "Zapisano: $((Resolve-Path $Out).Path) ($([math]::Round($page.Length / 1KB, 1)) KB, $($script:tocItems.Count) pozycji spisu)"
