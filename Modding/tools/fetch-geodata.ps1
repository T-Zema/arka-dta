# Downloads real-world data for a map design (see GeoData.cs / DesignToDta.cs) into a folder:
#   <Out>\osm\*.osm      OpenStreetMap extracts from api.openstreetmap.org (bbox split until each part < 50k nodes)
#   <Out>\dem15\x_y.png  Terrarium elevation tiles, zoom 15 (s3 elevation-tiles-prod, about 4 m/px here)
#
#   .\fetch-geodata.ps1 -South 36.105 -North 36.172 -West -5.380 -East -5.330 -Out ..\raw\maps\gibraltar-geo
#
# Notes (this machine, 2026-10-26): overpass-api.de and its mirrors fail the TLS handshake from here, the OSM
# API and S3 work. PowerShell 5.1 needs TLS 1.2 switched on. Negative numbers must be passed as -West -5.38
# (named parameter), never as a bare positional "-5.38" (that is parsed as text).
param(
    [Parameter(Mandatory)][double]$South, [Parameter(Mandatory)][double]$North,
    [Parameter(Mandatory)][double]$West, [Parameter(Mandatory)][double]$East,
    [Parameter(Mandatory)][string]$Out,
    [switch]$NoOsm, [switch]$NoDem
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$inv = [Globalization.CultureInfo]::InvariantCulture
New-Item -ItemType Directory -Force "$Out\osm", "$Out\dem15" | Out-Null

function Get-OsmPart([double]$s, [double]$n, [double]$w, [double]$e, [string]$name) {
    $f = "$Out\osm\$name.osm"
    if ((Test-Path $f) -and (Get-Item $f).Length -gt 200) { "  $name cached"; return }
    $bbox = [string]::Format($inv, '{0:F5},{1:F5},{2:F5},{3:F5}', $w, $s, $e, $n)
    try { Invoke-WebRequest -UseBasicParsing "https://api.openstreetmap.org/api/0.6/map?bbox=$bbox" -OutFile $f -TimeoutSec 180 }
    catch {
        if (Test-Path $f) { Remove-Item $f }
        # 400 = too many nodes (or area too big): split into four
        "  $name too big, splitting"
        $ms = ($s + $n) / 2; $mw = ($w + $e) / 2
        Get-OsmPart $s $ms $w $mw "${name}a"; Get-OsmPart $s $ms $mw $e "${name}b"
        Get-OsmPart $ms $n $w $mw "${name}c"; Get-OsmPart $ms $n $mw $e "${name}d"
        return
    }
    "  $name $([Math]::Round((Get-Item $f).Length / 1KB)) KB"
}

function Tile([double]$lat, [double]$lon, [int]$z) {
    $n = [Math]::Pow(2, $z); $r = $lat * [Math]::PI / 180
    @([int][Math]::Floor(($lon + 180) / 360 * $n), [int][Math]::Floor((1 - [Math]::Log([Math]::Tan($r) + 1 / [Math]::Cos($r)) / [Math]::PI) / 2 * $n))
}

if (-not $NoOsm) { "OSM:"; Get-OsmPart $South $North $West $East 'p' }
if (-not $NoDem) {
    $a = Tile $North $West 15; $b = Tile $South $East 15; $got = 0
    for ($x = $a[0]; $x -le $b[0]; $x++) { for ($y = $a[1]; $y -le $b[1]; $y++) {
        $f = "$Out\dem15\${x}_$y.png"
        if (-not (Test-Path $f)) { Invoke-WebRequest -UseBasicParsing "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/15/$x/$y.png" -OutFile $f -TimeoutSec 60; $got++ }
    } }
    "DEM: tiles x $($a[0])..$($b[0]) y $($a[1])..$($b[1]), downloaded $got"
}
