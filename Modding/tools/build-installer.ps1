# Builds the installer of our mods: Modding\dist\DTA-SCMod-Setup.exe (one file; it leaves an uninstaller in <game>\SCMod\).
# Wiki: workflow/installer.
#   1. assets (Modding\installer\assets, only when missing or -Assets), all from the local StarCraft: SD glue screens
#      (DDS -> PNG), SC1 bitmap fonts, UI sounds (CASC) and the icon of StarCraft.exe
#   2. the program: tools\ScModSetup.cs compiled with the csc of .NET Framework 4, assets as resources
#   3. the payload: every file of Modding\dta\state.json as it is on disk (files/<path>) + the pristine DTA copy of each
#      modified/patched file (base/<path>, for a clean uninstall even where our file was already in place) + manifest.json
#   4. exe = program + zip + int64 zip length + "SCMODPK1"
# Usage: build-installer.ps1 [-Assets] [-NoPayload] [-Version 2026.10.28] [-Out <exe>]
#   -NoPayload: only the program (= the uninstaller), for trying the window: <exe> /shot <png> [idle|busy|ask|done|hover] uninstall
param([switch]$Assets, [switch]$NoPayload, [string]$Version = (Get-Date -Format 'yyyy.MM.dd'), [string]$Out = '')
. "$PSScriptRoot\dta-common.ps1"

$assetDir = Join-Path $DtaRoot 'Modding\installer\assets'
$work = Join-Path $DtaCache 'installer'
if (-not $Out) { $Out = Join-Path $DtaRoot 'Modding\dist\DTA-SCMod-Setup.exe' }
New-Item -ItemType Directory -Force $assetDir, $work, (Split-Path $Out) | Out-Null
$scDir = 'C:\Program Files (x86)\StarCraft'

# ---- 1. assets ----
# glue screens of the SD (640x480) StarCraft: uncompressed 32-bit DDS -> PNG
$scImages = [ordered]@{
    'glue_bg.png'    = 'SD/glue/palnl/backgnd.DDS'   # the moon over a rocky plain
    'glue_title.png' = 'SD/glue/title/title.DDS'     # title screen: the logo is cut out of it at run time
    'glue_popup.png' = 'SD/glue/palmm/popopup.DDS'   # popup panel
}
# SC1 bitmap fonts (FONT format with RLE glyphs; the HD ones are DDS atlases)
$scFiles = [ordered]@{
    'font16x.fnt' = 'SD/font/font16x.fnt'; 'font16.fnt' = 'SD/font/font16.fnt'; 'font14.fnt' = 'SD/font/font14.fnt'
    'click.wav' = 'SD/sound/misc/button.wav'; 'hover.wav' = 'SD/sound/glue/mouseover.wav'
    'done.wav' = 'SD/sound/glue/scorefillend.wav'; 'error.wav' = 'SD/sound/misc/buzz.wav'; 'open.wav' = 'SD/sound/glue/swishin.wav'
}
$need = $Assets -or @(@($scImages.Keys) + @($scFiles.Keys) + 'app.ico' | Where-Object { -not (Test-Path (Join-Path $assetDir $_)) }).Count -gt 0
if ($need) {
    "assets: StarCraft glue screens, fonts, sounds and icon"
    Add-Type -Path "$PSScriptRoot\Casc.cs" -ReferencedAssemblies System.IO.Compression
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.IO;
using System.Runtime.InteropServices;
public static class ScAsset {
    // DDS with an uncompressed 32-bit pixel format (channel masks at 92..104) -> PNG
    public static void DdsToPng(byte[] b, string png) {
        if (BitConverter.ToInt32(b, 88) != 32) throw new Exception("not an uncompressed 32-bit DDS");
        int h = BitConverter.ToInt32(b, 12), w = BitConverter.ToInt32(b, 16);
        uint[] m = { BitConverter.ToUInt32(b, 92), BitConverter.ToUInt32(b, 96), BitConverter.ToUInt32(b, 100), BitConverter.ToUInt32(b, 104) };
        int[] px = new int[w * h];
        for (int i = 0; i < px.Length; i++) {
            uint v = BitConverter.ToUInt32(b, 128 + i * 4);
            px[i] = (int)(((m[3] == 0 ? 255 : Ch(v, m[3])) << 24) | (Ch(v, m[0]) << 16) | (Ch(v, m[1]) << 8) | Ch(v, m[2]));
        }
        using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
            BitmapData d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            Marshal.Copy(px, 0, d.Scan0, px.Length); bmp.UnlockBits(d); bmp.Save(png, ImageFormat.Png);
        }
    }
    static uint Ch(uint v, uint m) { if (m == 0) return 0; int s = 0; while (((m >> s) & 1) == 0) s++; return (v & m) >> s; }

    // the first icon group of an exe as an .ico file
    [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint flags);
    [DllImport("kernel32")] static extern bool FreeLibrary(IntPtr h);
    delegate bool EnumProc(IntPtr h, IntPtr type, IntPtr name, IntPtr l);
    [DllImport("kernel32", CharSet = CharSet.Unicode)] static extern bool EnumResourceNames(IntPtr h, IntPtr type, EnumProc cb, IntPtr l);
    [DllImport("kernel32", CharSet = CharSet.Unicode)] static extern IntPtr FindResource(IntPtr h, IntPtr name, IntPtr type);
    [DllImport("kernel32")] static extern IntPtr LoadResource(IntPtr h, IntPtr r);
    [DllImport("kernel32")] static extern IntPtr LockResource(IntPtr r);
    [DllImport("kernel32")] static extern uint SizeofResource(IntPtr h, IntPtr r);
    static byte[] Res(IntPtr m, IntPtr name, int type) {
        IntPtr r = FindResource(m, name, (IntPtr)type);
        if (r == IntPtr.Zero) return null;
        byte[] b = new byte[SizeofResource(m, r)]; Marshal.Copy(LockResource(LoadResource(m, r)), b, 0, b.Length); return b;
    }
    public static byte[] ExeIcon(string exe) {
        IntPtr m = LoadLibraryEx(exe, IntPtr.Zero, 0x22);   // as datafile + image resource
        if (m == IntPtr.Zero) return null;
        byte[] ico = null;
        EnumProc cb = delegate(IntPtr h, IntPtr t, IntPtr name, IntPtr l) {
            byte[] grp = Res(m, name, 14);   // RT_GROUP_ICON: 6-byte header + 14-byte entries (.., nID)
            if (grp == null) return true;
            int n = BitConverter.ToUInt16(grp, 4); List<byte[]> img = new List<byte[]>();
            for (int i = 0; i < n; i++) img.Add(Res(m, (IntPtr)BitConverter.ToUInt16(grp, 6 + i * 14 + 12), 3));
            MemoryStream ms = new MemoryStream(); BinaryWriter w = new BinaryWriter(ms);
            w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)n);
            int off = 6 + 16 * n;
            for (int i = 0; i < n; i++) { w.Write(grp, 6 + i * 14, 8); w.Write((uint)img[i].Length); w.Write((uint)off); off += img[i].Length; }
            foreach (byte[] b in img) w.Write(b);
            ico = ms.ToArray(); return false;
        };
        EnumResourceNames(m, (IntPtr)14, cb, IntPtr.Zero);
        FreeLibrary(m);
        return ico;
    }
}
'@
    $casc = New-Object Casc $scDir
    foreach ($k in $scImages.Keys) { [ScAsset]::DdsToPng($casc.ReadFile($scImages[$k]), (Join-Path $assetDir $k)) }
    foreach ($k in $scFiles.Keys) { [IO.File]::WriteAllBytes((Join-Path $assetDir $k), $casc.ReadFile($scFiles[$k])) }
    $ico = [ScAsset]::ExeIcon((Join-Path $scDir 'x86_64\StarCraft.exe'))
    if ($ico) { [IO.File]::WriteAllBytes((Join-Path $assetDir 'app.ico'), $ico) }
    else { Write-Warning 'no icon in StarCraft.exe, using the DTA client icon'; Copy-Item (Join-Path $DtaRoot 'Resources\mainclienticon.ico') (Join-Path $assetDir 'app.ico') -Force }
}

# ---- 2. program ----
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$manifestXml = Join-Path $work 'app.manifest'
[IO.File]::WriteAllText($manifestXml, @'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.0.0.0" name="DTA.SCMod.Setup"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2"><security><requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
    <requestedExecutionLevel level="asInvoker" uiAccess="false"/>
  </requestedPrivileges></security></trustInfo>
  <application xmlns="urn:schemas-microsoft-com:asm.v3"><windowsSettings>
    <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true</dpiAware>
  </windowsSettings></application>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1"><application>
    <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/><supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
  </application></compatibility>
</assembly>
'@)
$stub = Join-Path $work 'stub.exe'
$resArgs = Get-ChildItem $assetDir -File | ForEach-Object { "/resource:$($_.FullName),$($_.Name)" }
$cscArgs = @('/nologo', '/target:winexe', '/optimize+', '/codepage:65001', "/win32icon:$assetDir\app.ico", "/win32manifest:$manifestXml",
    '/r:System.dll', '/r:System.Core.dll', '/r:System.Drawing.dll', '/r:System.Windows.Forms.dll', '/r:System.IO.Compression.dll',
    '/r:System.Web.Extensions.dll', "/out:$stub") + $resArgs + @("$PSScriptRoot\ScModSetup.cs")
$o = & $csc @cscArgs 2>&1
if ($LASTEXITCODE) { $o; throw "csc failed ($LASTEXITCODE)" }
"program: $([math]::Round((Get-Item $stub).Length / 1MB, 1)) MB"
if ($NoPayload) { Copy-Item $stub $Out -Force; "-> $Out (no payload: uninstaller mode)"; return }

# ---- 3. payload ----
$cfg = Read-DtaSyncConfig
$state = Read-DtaState
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zipPath = Join-Path $work 'payload.zip'
Remove-Item $zipPath -ErrorAction SilentlyContinue
$files = New-Object System.Collections.Generic.List[object]
$stored = '\.(mp4|wmv|avi|png|jpg|webm|ogg|wma|zip)$'
$zs = [IO.File]::Open($zipPath, 'Create')
$za = New-Object IO.Compression.ZipArchive($zs, [IO.Compression.ZipArchiveMode]::Create)
function Add-ZipFile([string]$Name, [string]$Src) {
    $lvl = if ($Name -match $stored) { [IO.Compression.CompressionLevel]::NoCompression } else { [IO.Compression.CompressionLevel]::Optimal }
    $en = $za.CreateEntry($Name, $lvl); $os = $en.Open(); $is = [IO.File]::OpenRead($Src)
    try { $is.CopyTo($os) } finally { $is.Close(); $os.Close() }
}
try {
    foreach ($e in $state.files) {
        $full = Get-DtaFull $e.path
        if (-not (Test-Path -LiteralPath $full)) { throw "$($e.path) is in the state but missing on disk" }
        $h = Get-DtaHash $full
        if ($h -ne $e.ours) { Write-Warning "$($e.path): differs from the last capture (packed as it is on disk; run dta-capture.ps1)" }
        $base = $null
        if ($e.kind -ne 'new') {
            $base = $e.base
            $p = Find-DtaPristine $e.path $e.base $cfg -NoDownload
            if (-not $p) { throw "$($e.path): no pristine DTA copy (Modding\dta\base, .bak, .dta-cache)" }
            Add-ZipFile "base/$($e.path)" $p
        }
        Add-ZipFile "files/$($e.path)" $full
        $files.Add([ordered]@{ path = $e.path; kind = $e.kind; ours = $h; base = $base; size = (Get-Item -LiteralPath $full).Length })
    }
    $man = [ordered]@{ name = 'dta-scmod'; title = 'StarCraft mod'; version = $Version; dtaVersion = $state.dtaVersion
                       built = (Get-Date -Format 'yyyy-MM-dd HH:mm'); files = $files }
    $en = $za.CreateEntry('manifest.json'); $w = New-Object IO.StreamWriter($en.Open(), (New-Object Text.UTF8Encoding $false))
    $w.Write(($man | ConvertTo-Json -Depth 4 -Compress)); $w.Close()
} finally { $za.Dispose(); $zs.Close() }
$zipLen = (Get-Item $zipPath).Length
$total = 0L; foreach ($f in $files) { $total += $f.size }
"payload: $($files.Count) files, $([math]::Round($total / 1MB)) MB -> zip $([math]::Round($zipLen / 1MB)) MB"

# ---- 4. exe = program + zip + trailer ----
$fo = [IO.File]::Open($Out, 'Create')
try {
    foreach ($src in $stub, $zipPath) { $fi = [IO.File]::OpenRead($src); $fi.CopyTo($fo); $fi.Close() }
    $t = [BitConverter]::GetBytes([long]$zipLen) + [Text.Encoding]::ASCII.GetBytes('SCMODPK1')
    $fo.Write($t, 0, $t.Length)
} finally { $fo.Close() }
"-> $Out ($([math]::Round((Get-Item $Out).Length / 1MB)) MB), version $Version for DTA $($state.dtaVersion)"
