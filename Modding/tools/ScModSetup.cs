// Installer and uninstaller of our DTA mods (StarCraft factions, units, maps, ARKA campaign...) in the look of the 1998
// StarCraft installer: a 640x480 glue screen with the title logo, the menu in the SC1 bitmap font, glue popups and UI sounds,
// all taken from the local StarCraft (tools/build-installer.ps1). One source, two modes:
//   payload appended to the exe (tools/build-installer.ps1) -> setup: install / repair / update / uninstall
//   no payload (the copy the setup leaves in <game>\SCMod\) -> uninstaller
// Install: every file of the package (= Modding/dta/state.json) is written; a DTA file it replaces is first copied to
// <game>\SCMod\backup\ (for a file already ours, the pristine DTA copy from the package goes there). <game>\SCMod\install.json
// records what was created or replaced; uninstall restores the backups and deletes what was created, but only files that
// still hold our version (a file changed later, e.g. by a DTA update, is left alone).
// Silent: <exe> /install "<game>" | /uninstall "<game>"  -> exit code 0 ok, 1 warnings, 2 error; log in %TEMP%\DTA-SCMod-setup.log.
// Preview: <exe> /shot <png> [idle|busy|ask|done|finished|details|about|hover] [uninstall] [pl|en]  renders the window into a
// PNG (960x720). Language: English by default, Polish from the menu (saved in HKCU\Software\DTA-SCMod\Language).
// C# 5 (csc of .NET Framework 4, no SDK). Wiki: workflow/installer.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.IO.Compression;
using System.Media;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

namespace ScModSetup
{
    // ---- package manifest (manifest.json in the payload) and install record (<game>\SCMod\install.json) ----
    public class PkgFile { public string path { get; set; } public string kind { get; set; } public string ours { get; set; } public string @base { get; set; } public long size { get; set; } }
    public class PkgManifest
    {
        public string name { get; set; } public string title { get; set; } public string version { get; set; }
        public string dtaVersion { get; set; } public string built { get; set; } public List<PkgFile> files { get; set; }
    }
    // action: "created" (did not exist, or was already ours) or "replaced" (orig = hash of the file we backed up)
    public class RecEntry { public string path { get; set; } public string kind { get; set; } public string action { get; set; } public string ours { get; set; } public string orig { get; set; } }
    public class InstallRecord
    {
        public string name { get; set; } public string title { get; set; } public string version { get; set; } public string dtaVersion { get; set; }
        public string installed { get; set; } public List<RecEntry> entries { get; set; } public List<string> dirs { get; set; }
    }

    // A window into the exe file: the zip appended after the program.
    class SubStream : Stream
    {
        Stream s; long start, len, pos;
        public SubStream(Stream s, long start, long len) { this.s = s; this.start = start; this.len = len; }
        public override bool CanRead { get { return true; } }
        public override bool CanSeek { get { return true; } }
        public override bool CanWrite { get { return false; } }
        public override long Length { get { return len; } }
        public override long Position { get { return pos; } set { pos = value; } }
        public override int Read(byte[] b, int o, int c)
        {
            if (pos >= len) return 0;
            if (c > len - pos) c = (int)(len - pos);
            s.Position = start + pos;
            int n = s.Read(b, o, c); pos += n; return n;
        }
        public override long Seek(long off, SeekOrigin or) { pos = (or == SeekOrigin.Begin ? 0 : or == SeekOrigin.Current ? pos : len) + off; return pos; }
        public override void Flush() { }
        public override void SetLength(long v) { throw new NotSupportedException(); }
        public override void Write(byte[] b, int o, int c) { throw new NotSupportedException(); }
        protected override void Dispose(bool d) { if (d) s.Dispose(); base.Dispose(d); }
    }

    // exe layout: [program][zip][int64 zip length][8 bytes Magic]
    class Pkg : IDisposable
    {
        public const string Magic = "SCMODPK1";
        public long StubLength; public PkgManifest Manifest; public long TotalBytes;
        string exe; ZipArchive zip;

        public static Pkg Open(string exe)
        {
            FileStream fs = new FileStream(exe, FileMode.Open, FileAccess.Read, FileShare.Read);
            byte[] t = new byte[16];
            if (fs.Length < 16) { fs.Dispose(); return null; }
            fs.Seek(-16, SeekOrigin.End); fs.Read(t, 0, 16);
            if (Encoding.ASCII.GetString(t, 8, 8) != Magic) { fs.Dispose(); return null; }
            long zl = BitConverter.ToInt64(t, 0);
            Pkg p = new Pkg(); p.exe = exe; p.StubLength = fs.Length - 16 - zl;
            p.zip = new ZipArchive(new SubStream(fs, p.StubLength, zl), ZipArchiveMode.Read);
            using (StreamReader r = new StreamReader(p.zip.GetEntry("manifest.json").Open(), Encoding.UTF8))
                p.Manifest = Json.Parse<PkgManifest>(r.ReadToEnd());
            foreach (PkgFile f in p.Manifest.files) p.TotalBytes += f.size;
            return p;
        }
        public void Extract(string entry, string dest)
        {
            ZipArchiveEntry e = zip.GetEntry(entry);
            if (e == null) throw new Exception(L.T("pakiet nie zawiera ", "the package lacks ") + entry);
            Directory.CreateDirectory(Path.GetDirectoryName(dest));
            if (File.Exists(dest)) File.SetAttributes(dest, FileAttributes.Normal);
            using (Stream i = e.Open()) using (FileStream o = new FileStream(dest, FileMode.Create, FileAccess.Write)) i.CopyTo(o, 1 << 16);
        }
        // the program without the payload = the uninstaller
        public void WriteStub(string dest)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(dest));
            using (FileStream i = new FileStream(exe, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (FileStream o = new FileStream(dest, FileMode.Create, FileAccess.Write))
            {
                byte[] buf = new byte[1 << 16]; long left = StubLength;
                while (left > 0) { int n = i.Read(buf, 0, (int)Math.Min(buf.Length, left)); if (n <= 0) break; o.Write(buf, 0, n); left -= n; }
            }
        }
        public void Dispose() { if (zip != null) zip.Dispose(); }
    }

    // the language of the window and the log: English unless the user switched to Polish in the menu (saved)
    static class L
    {
        public static bool En = true;
        public static string T(string pl, string en) { return En ? en : pl; }
        public static void Init()
        {
            string s = null;
            try { using (RegistryKey k = Registry.CurrentUser.OpenSubKey(Engine.RegApp)) if (k != null) s = k.GetValue("Language") as string; }
            catch (Exception) { }
            En = s != "pl";
        }
        public static void Save()
        {
            try { using (RegistryKey k = Registry.CurrentUser.CreateSubKey(Engine.RegApp)) k.SetValue("Language", En ? "en" : "pl"); }
            catch (Exception) { }
        }
    }

    static class Json
    {
        static JavaScriptSerializer js = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        public static T Parse<T>(string s) { return js.Deserialize<T>(s); }
        public static string Write(object o) { return js.Serialize(o); }
    }

    static class Dta
    {
        public static bool IsGameFolder(string d)
        {
            return !string.IsNullOrEmpty(d) && File.Exists(Path.Combine(d, "game.exe")) && File.Exists(Path.Combine(d, "version"));
        }
        public static string Version(string d)
        {
            try { foreach (string l in File.ReadAllLines(Path.Combine(d, "version"))) if (l.StartsWith("Version=")) return l.Substring(8).Trim(); }
            catch (IOException) { }
            return "?";
        }
        // the game or the client started from THIS folder
        public static bool GameRunning(string d)
        {
            string root = Path.GetFullPath(d).TrimEnd('\\') + "\\";
            foreach (string n in new[] { "game", "DTA", "DTAClient", "clientdx", "clientogl", "clientxna" })
                foreach (Process p in Process.GetProcessesByName(n))
                {
                    try { if (p.MainModule.FileName.StartsWith(root, StringComparison.OrdinalIgnoreCase)) return true; }
                    catch (Exception) { }
                }
            return false;
        }
        // MD5 as the DTA manifest writes it: the 16 bytes as decimal numbers, concatenated (same as Modding/dta/state.json)
        public static string Hash(string path)
        {
            using (MD5 m = MD5.Create())
            using (FileStream s = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 1 << 16))
            {
                StringBuilder sb = new StringBuilder();
                foreach (byte b in m.ComputeHash(s)) sb.Append(b.ToString());
                return sb.ToString();
            }
        }
        public static string HashOrNull(string path) { return File.Exists(path) ? Hash(path) : null; }
        public static string ShortId(string s)
        {
            using (MD5 m = MD5.Create()) return BitConverter.ToString(m.ComputeHash(Encoding.UTF8.GetBytes(s.ToLowerInvariant())), 0, 4).Replace("-", "");
        }
    }

    // ---- the install / uninstall work (UI-free; runs on a worker thread) ----
    class Engine
    {
        public const string ModDir = "SCMod", RecordFile = "install.json", UninstallerName = "Odinstaluj SC Mod.exe";
        public const string RegApp = @"Software\DTA-SCMod";
        public int Warnings;
        public Action<string> OnFile;   // the file being worked on (for the window)
        Pkg pkg; string game; Action<int, string> log; Action<double> progress;

        public Engine(Pkg pkg, string game, Action<int, string> log, Action<double> progress)
        { this.pkg = pkg; this.game = Path.GetFullPath(game).TrimEnd('\\'); this.log = log; this.progress = progress; }

        public static string RecordPath(string game) { return Path.Combine(game, ModDir, RecordFile); }
        public static InstallRecord LoadRecord(string game)
        {
            string p = RecordPath(game);
            if (!File.Exists(p)) return null;
            InstallRecord r = Json.Parse<InstallRecord>(File.ReadAllText(p, Encoding.UTF8));
            if (r.entries == null) r.entries = new List<RecEntry>();
            if (r.dirs == null) r.dirs = new List<string>();
            return r;
        }
        void SaveRecord(InstallRecord r) { File.WriteAllText(RecordPath(game), Json.Write(r), new UTF8Encoding(false)); }
        public static string UninstallKey(string game) { return @"Software\Microsoft\Windows\CurrentVersion\Uninstall\DTA-SCMod-" + Dta.ShortId(Path.GetFullPath(game).TrimEnd('\\')); }

        string Full(string rel) { return Path.Combine(game, rel.Replace('/', '\\')); }
        string Backup(string rel) { return Path.Combine(game, ModDir, "backup", rel.Replace('/', '\\')); }
        void Warn(string s) { Warnings++; log(2, s); }
        static string GameRunningMsg() { return L.T("Klient DTA albo gra działa z tego folderu. Zamknij ją i spróbuj ponownie.", "The DTA client or the game is running from this folder. Close it and try again."); }
        static void CopyOver(string src, string dst)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(dst));
            if (File.Exists(dst)) File.SetAttributes(dst, FileAttributes.Normal);
            File.Copy(src, dst, true);
        }
        // creates the folder of a file and remembers every folder it had to create (removed again on uninstall)
        void EnsureDir(string dir, List<string> dirs)
        {
            List<string> missing = new List<string>();
            for (string d = dir; d != null && d.Length > game.Length && !Directory.Exists(d); d = Path.GetDirectoryName(d)) missing.Add(d);
            Directory.CreateDirectory(dir);
            foreach (string d in missing)
            {
                string rel = d.Substring(game.Length + 1).Replace('\\', '/');
                if (!dirs.Contains(rel)) dirs.Add(rel);
            }
        }

        public int Install()
        {
            if (Dta.GameRunning(game)) throw new Exception(GameRunningMsg());
            PkgManifest m = pkg.Manifest;
            string dtaVer = Dta.Version(game);
            try { Directory.CreateDirectory(Path.Combine(game, ModDir, "backup")); }
            catch (UnauthorizedAccessException) { throw new Exception(L.T("Brak uprawnień do zapisu w folderze gry. Uruchom instalator jako administrator.", "No permission to write to the game folder. Run the installer as administrator.")); }

            InstallRecord prev = LoadRecord(game);
            Dictionary<string, RecEntry> prevMap = new Dictionary<string, RecEntry>(StringComparer.OrdinalIgnoreCase);
            if (prev != null) foreach (RecEntry e in prev.entries) prevMap[e.path] = e;
            InstallRecord rec = new InstallRecord
            {
                name = m.name, title = m.title, version = m.version, dtaVersion = dtaVer,
                installed = DateTime.Now.ToString("yyyy-MM-dd HH:mm"), entries = new List<RecEntry>(),
                dirs = prev != null ? prev.dirs : new List<string>()
            };
            log(0, prev == null ? string.Format(L.T("Instalacja {0} {1} w {2}", "Installing {0} {1} to {2}"), m.title, m.version, game)
                                : string.Format(L.T("Naprawa / aktualizacja: {0} -> {1}", "Repair / update: {0} -> {1}"), prev.version, m.version));
            if (dtaVer != m.dtaVersion) Warn(string.Format(L.T("DTA w folderze: {0}, pakiet zbudowany dla {1}.", "DTA in the folder: {0}, the package is built for {1}."), dtaVer, m.dtaVersion));

            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            long done = 0; int written = 0, same = 0, n = 0;
            try
            {
                foreach (PkgFile f in m.files)
                {
                    if (OnFile != null) OnFile(f.path);
                    string full = Full(f.path);
                    string cur = Dta.HashOrNull(full);
                    RecEntry pe; prevMap.TryGetValue(f.path, out pe);
                    RecEntry e = pe ?? new RecEntry { path = f.path, kind = f.kind };
                    e.ours = f.ours;
                    if (cur == f.ours)
                    {
                        if (pe == null)
                        {
                            if (f.kind == "new") e.action = "created";
                            else
                            {   // already ours, the pristine DTA file comes from the package
                                pkg.Extract("base/" + f.path, Backup(f.path));
                                e.action = "replaced"; e.orig = f.@base;
                            }
                        }
                        seen.Add(f.path); rec.entries.Add(e); same++;
                    }
                    else
                    {
                        if (pe == null)
                        {
                            if (cur == null) e.action = "created";
                            else
                            {
                                CopyOver(full, Backup(f.path));
                                e.action = "replaced"; e.orig = cur;
                                if (f.kind != "new" && cur != f.@base)
                                    Warn(f.path + string.Format(L.T(": inna wersja niż w DTA {0} (kopia w SCMod\\backup), zastąpiona wersją moda.",
                                        ": differs from DTA {0} (backed up to SCMod\\backup), replaced with the mod's version."), m.dtaVersion));
                                else if (f.kind == "new")
                                    log(0, f.path + L.T(": istniejący plik o tej nazwie przeniesiony do kopii.", ": an existing file of this name was moved to the backup."));
                            }
                        }
                        else if (pe.action == "replaced" && cur != null && cur != pe.orig)
                        {   // DTA (update or file repair) put another file here since the install: it is the new original
                            CopyOver(full, Backup(f.path)); e.orig = cur;
                            Warn(f.path + L.T(": DTA zmieniła ten plik od instalacji; nowa wersja DTA trafia do kopii, wraca wersja moda.",
                                ": DTA changed this file since the install; the new DTA version goes to the backup, the mod's version is back."));
                        }
                        seen.Add(f.path); rec.entries.Add(e);   // recorded before writing: a half-done install stays undoable
                        EnsureDir(Path.GetDirectoryName(full), rec.dirs);
                        pkg.Extract("files/" + f.path, full);
                        if (Dta.Hash(full) != f.ours) throw new Exception(f.path + L.T(": zapisany plik ma zły skrót (uszkodzony pakiet?)", ": the written file has a wrong hash (damaged package?)"));
                        written++;
                    }
                    done += f.size; progress(pkg.TotalBytes > 0 ? (double)done / pkg.TotalBytes : 1);
                    if (++n % 40 == 0) { log(0, string.Format(L.T("{0} / {1} plików", "{0} / {1} files"), n, m.files.Count)); SaveRecord(rec); }
                }
            }
            finally
            {
                if (prev != null) foreach (RecEntry e in prev.entries) if (!seen.Contains(e.path)) rec.entries.Add(e);
                SaveRecord(rec);
            }

            string un = Path.Combine(game, ModDir, UninstallerName);
            pkg.WriteStub(un);
            try
            {
                using (RegistryKey k = Registry.CurrentUser.CreateSubKey(UninstallKey(game)))
                {
                    k.SetValue("DisplayName", m.title + " (DTA)");
                    k.SetValue("DisplayVersion", m.version);
                    k.SetValue("Publisher", "Zema");
                    k.SetValue("InstallLocation", game);
                    k.SetValue("DisplayIcon", un);
                    k.SetValue("UninstallString", "\"" + un + "\"");
                    k.SetValue("EstimatedSize", (int)(pkg.TotalBytes / 1024), RegistryValueKind.DWord);
                    k.SetValue("NoModify", 1, RegistryValueKind.DWord);
                    k.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                }
                using (RegistryKey k = Registry.CurrentUser.CreateSubKey(RegApp)) k.SetValue("GamePath", game);
            }
            catch (Exception ex) { Warn(L.T("Wpis w Panelu sterowania nie powstał: ", "Could not add the Control Panel entry: ") + ex.Message); }
            log(1, string.Format(L.T("Zapisano {0} plików, {1} już było aktualnych. Deinstalator: {2}\\{3}", "Wrote {0} files, {1} were already up to date. Uninstaller: {2}\\{3}"),
                written, same, ModDir, UninstallerName));
            return Warnings > 0 ? 1 : 0;
        }

        // runningFromModDir: this exe is <game>\SCMod\...: the folder is removed by a helper after the program exits
        public int Uninstall(bool runningFromModDir)
        {
            if (Dta.GameRunning(game)) throw new Exception(GameRunningMsg());
            InstallRecord rec = LoadRecord(game);
            if (rec == null) throw new Exception(string.Format(L.T("Brak {0}\\{1}: mod nie był instalowany tym instalatorem.", "No {0}\\{1}: the mod was not installed with this installer."), ModDir, RecordFile));
            log(0, string.Format(L.T("Deinstalacja {0} {1} z {2}", "Uninstalling {0} {1} from {2}"), rec.title, rec.version, game));
            int restored = 0, deleted = 0, left = 0;
            for (int i = rec.entries.Count - 1; i >= 0; i--)
            {
                RecEntry e = rec.entries[i];
                if (OnFile != null) OnFile(e.path);
                string full = Full(e.path), cur = Dta.HashOrNull(full);
                if (e.action == "created")
                {
                    if (cur == null) { }
                    else if (cur == e.ours) { File.SetAttributes(full, FileAttributes.Normal); File.Delete(full); deleted++; }
                    else { left++; Warn(e.path + L.T(": zmieniony po instalacji, zostawiony.", ": changed after the install, left in place.")); }
                }
                else
                {
                    string bak = Backup(e.path);
                    if (cur == e.orig) { }
                    else if (!File.Exists(bak)) { left++; Warn(e.path + string.Format(L.T(": brak kopii w {0}\\backup, zostawiony.", ": no backup in {0}\\backup, left in place."), ModDir)); }
                    else if (cur == null || cur == e.ours) { CopyOver(bak, full); restored++; }
                    else { left++; Warn(e.path + L.T(": zmieniony po instalacji (aktualizacja DTA?), zostawiony.", ": changed after the install (DTA update?), left in place.")); }
                }
                progress((double)(rec.entries.Count - i) / rec.entries.Count);
            }
            List<string> dirs = new List<string>(rec.dirs);
            dirs.Sort(delegate(string a, string b) { return b.Length.CompareTo(a.Length); });   // deepest first
            foreach (string d in dirs)
            {
                string full = Full(d);
                try { if (Directory.Exists(full) && Directory.GetFileSystemEntries(full).Length == 0) Directory.Delete(full); }
                catch (IOException) { }
            }
            try
            {
                Registry.CurrentUser.DeleteSubKeyTree(UninstallKey(game), false);
                using (RegistryKey k = Registry.CurrentUser.OpenSubKey(RegApp, true))
                    if (k != null && string.Equals(k.GetValue("GamePath") as string, game, StringComparison.OrdinalIgnoreCase)) k.DeleteValue("GamePath", false);
            }
            catch (Exception ex) { Warn(L.T("Rejestr: ", "Registry: ") + ex.Message); }
            string modDir = Path.Combine(game, ModDir);
            Directory.Delete(Path.Combine(modDir, "backup"), true);
            File.Delete(RecordPath(game));
            if (!runningFromModDir) Directory.Delete(modDir, true);
            log(1, string.Format(L.T("Przywrócono {0} oryginałów DTA, usunięto {1} plików modu{2}.", "Restored {0} DTA originals, deleted {1} mod files{2}."), restored, deleted,
                left > 0 ? string.Format(L.T(", {0} zostawionych", ", {0} left in place"), left) : ""));
            return Warnings > 0 ? 1 : 0;
        }
    }

    static class Res
    {
        public static Stream Open(string name) { return Assembly.GetExecutingAssembly().GetManifestResourceStream(name); }
        public static Bitmap Img(string name)
        {
            Stream s = Open(name);
            if (s == null) return null;
            using (s) using (Image i = Image.FromStream(s)) return new Bitmap(i);
        }
        public static byte[] Bytes(string name)
        {
            Stream s = Open(name);
            if (s == null) return null;
            using (s) using (MemoryStream m = new MemoryStream()) { s.CopyTo(m); return m.ToArray(); }
        }
    }

    // A StarCraft 1 bitmap font (SD/font/*.fnt from CASC): "FONT", first char, last char, max width, height, a u32 offset per
    // char (0 = none), per char w, h, x, y + RLE bytes (skip << 3 | shade). Shade 1 is the brightest, 4 the darkest, 7 the drop
    // shadow; a ramp turns shades into colours (as glue\*\tfont.pcx does). The font is Latin-1: Polish letters are built from
    // the base letter + the acute of é/É, the cedilla of ç/Ç mirrored (ogonek), the '.' (ż) or a drawn stroke (ł).
    class Fnt
    {
        class Gl { public int W; public byte[] P; public Gl(int w, int h) { W = w; P = new byte[w * h]; } }
        public readonly int H;
        readonly Dictionary<char, Gl> gl = new Dictionary<char, Gl>();

        public Fnt(byte[] b)
        {
            int lo = b[4], hi = b[5]; H = b[7];
            for (int c = lo; c <= hi; c++)
            {
                int o = BitConverter.ToInt32(b, 8 + (c - lo) * 4);
                if (o == 0) continue;
                int w = b[o], h = b[o + 1], x = b[o + 2], y = b[o + 3];
                Gl g = new Gl(x + w, H);
                for (int q = 0, k = o + 4; q < w * h; )
                {
                    int v = b[k++]; q += v >> 3;
                    if (q >= w * h) break;
                    int py = y + q / w;
                    if ((v & 7) != 0 && py < H) g.P[py * g.W + x + q % w] = (byte)(v & 7);
                    q++;
                }
                gl[(char)c] = g;
            }
            Gl n; gl[' '] = new Gl(gl.TryGetValue('n', out n) ? Math.Max(3, n.W / 2) : 4, H);
            if (Has("eEcC.éÉçÇaAsSzZlLnN")) Polish();
        }
        bool Has(string cs) { foreach (char c in cs) if (!gl.ContainsKey(c)) return false; return true; }

        // ---- Polish letters ----
        Rectangle Box(Gl g, bool shadow)
        {
            int l = g.W, t = H, r = -1, bt = -1;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < g.W; x++)
                {
                    int v = g.P[y * g.W + x];
                    if (v == 0 || (v == 7 && !shadow)) continue;
                    l = Math.Min(l, x); r = Math.Max(r, x); t = Math.Min(t, y); bt = Math.Max(bt, y);
                }
            return r < 0 ? Rectangle.Empty : Rectangle.FromLTRB(l, t, r + 1, bt + 1);
        }
        static int Cx2(Rectangle r) { return r.Left + r.Right; }   // twice the centre
        // the part of `with` above (or below) the ink of `without`: the accent of é, the cedilla of ç
        Gl Mark(char with, char without, bool above)
        {
            Gl a = gl[with]; Rectangle bb = Box(gl[without], above);   // below: from the ink, a short cedilla shares the shadow row
            Gl m = new Gl(a.W, H);
            for (int y = 0; y < H; y++)
                if (above ? y < bb.Top : y >= bb.Bottom) Array.Copy(a.P, y * a.W, m.P, y * a.W, a.W);
            return m;
        }
        Gl Copy(char c, int pad)
        {
            Gl s = gl[c], d = new Gl(s.W + 2 * pad, H);
            for (int y = 0; y < H; y++) Array.Copy(s.P, y * s.W, d.P, y * d.W + pad, s.W);
            return d;
        }
        Gl Mirror(Gl m)
        {
            Gl d = new Gl(m.W, H);
            for (int y = 0; y < H; y++) for (int x = 0; x < m.W; x++) d.P[y * m.W + m.W - 1 - x] = m.P[y * m.W + x];
            return d;
        }
        void Stamp(Gl dst, Gl m, int dx, int dy)
        {
            for (int y = 0; y < H; y++)
                for (int x = 0; x < m.W; x++)
                {
                    int v = m.P[y * m.W + x], X = x + dx, Y = y + dy;
                    if (v == 0 || X < 0 || Y < 0 || X >= dst.W || Y >= H) continue;
                    if (v != 7 || dst.P[Y * dst.W + X] == 0) dst.P[Y * dst.W + X] = (byte)v;
                }
        }
        void Polish()
        {
            Gl acL = Mark('é', 'e', true), acU = Mark('É', 'E', true);
            Gl ogL = Mirror(Mark('ç', 'c', false)), ogU = Mirror(Mark('Ç', 'C', false));
            int eC = Cx2(Box(gl['e'], false)), EC = Cx2(Box(gl['E'], false));
            foreach (string p in new[] { "śs", "ćc", "ńn", "źz" }) Accent(p[0], p[1], acL, eC);
            foreach (string p in new[] { "ŚS", "ĆC", "ŃN", "ŹZ" }) Accent(p[0], p[1], acU, EC);
            Dot('ż', 'z', acL); Dot('Ż', 'Z', acU);
            foreach (string p in new[] { "ąa", "ęe" }) Ogonek(p[0], p[1], ogL);
            foreach (string p in new[] { "ĄA", "ĘE" }) Ogonek(p[0], p[1], ogU);
            Stroke('ł', 'l'); Stroke('Ł', 'L');
        }
        void Accent(char to, char from, Gl acc, int refC2)
        {
            Gl g = Copy(from, 0); Stamp(g, acc, (Cx2(Box(g, false)) - refC2) / 2, 0); gl[to] = g;
        }
        void Dot(char to, char from, Gl acc)
        {
            Gl g = Copy(from, 0), dot = Copy('.', 0); Rectangle db = Box(dot, false);
            Stamp(g, dot, (Cx2(Box(g, false)) - Cx2(db)) / 2, Box(acc, false).Bottom - db.Bottom); gl[to] = g;
        }
        void Ogonek(char to, char from, Gl og)
        {
            Gl g = Copy(from, 0);
            Stamp(g, og, Box(g, false).Right - Box(og, false).Right, 0); gl[to] = g;
        }
        void Stroke(char to, char from)
        {
            Gl g = Copy(from, 1); Rectangle b = Box(g, false);
            int l = b.Left, r = l, my = b.Top + b.Height / 2 + 1;   // the stem: the leftmost run of ink on the stroke's row
            while (r + 1 < g.W && g.P[my * g.W + r + 1] != 0 && g.P[my * g.W + r + 1] != 7) r++;
            foreach (Point p in new[] { new Point(l - 1, my + 1), new Point(r + 1, my - 1), new Point(r + 2, my - 2) })
            {
                if (p.X < 0 || p.X >= g.W || p.Y < 0 || p.Y >= H) continue;
                g.P[p.Y * g.W + p.X] = 1;
                if (p.X + 1 < g.W && p.Y + 1 < H && g.P[(p.Y + 1) * g.W + p.X + 1] == 0) g.P[(p.Y + 1) * g.W + p.X + 1] = 7;
            }
            gl[to] = g;
        }

        // ---- text ----
        public static string Norm(string s)
        {
            return s.Replace('—', '-').Replace('–', '-').Replace("…", "...").Replace("→", "->").Replace('„', '"').Replace('”', '"').Replace('“', '"').Replace('’', '\'');
        }
        Gl Get(char c) { Gl g; return gl.TryGetValue(c, out g) || gl.TryGetValue('?', out g) ? g : gl[' ']; }
        public int Width(string s, int spacing)
        {
            int w = 0; foreach (char c in Norm(s)) w += Get(c).W + spacing;
            return w;
        }
        public int Width(string s) { return Width(s, 0); }
        // the text 2 px larger than its cells: a 1 px dark outline all around (outline = false: transparent)
        public Bitmap Render(string s, int[] ramp, int spacing, bool outline)
        {
            s = Norm(s);
            int w = Math.Max(1, Width(s, spacing)) + 2, h = H + 2, x0 = 1;
            int[] px = new int[w * h];
            foreach (char c in s)
            {
                Gl g = Get(c);
                for (int y = 0; y < H; y++)
                    for (int x = 0; x < g.W; x++) { int v = g.P[y * g.W + x]; if (v != 0) px[(y + 1) * w + x0 + x] = ramp[v]; }
                x0 += g.W + spacing;
            }
            if (outline)
            {
                int[] o = (int[])px.Clone(), dx = { -1, 0, 1, -1, 1, -1, 0, 1 }, dy = { -1, -1, -1, 0, 0, 1, 1, 1 };
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                    {
                        if (px[y * w + x] != 0) continue;
                        for (int k = 0; k < 8; k++)
                        {
                            int X = x + dx[k], Y = y + dy[k];
                            if (X >= 0 && Y >= 0 && X < w && Y < h && px[Y * w + X] != 0) { o[y * w + x] = unchecked((int)0xA0000000); break; }
                        }
                    }
                px = o;
            }
            Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            BitmapData d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            Marshal.Copy(px, 0, d.Scan0, px.Length); bmp.UnlockBits(d);
            return bmp;
        }
        // shortened with "..." at the end (or at the start: a path keeps its tail)
        public string Fit(string s, int maxW, bool keepEnd)
        {
            if (Width(s) <= maxW) return s;
            for (int n = s.Length - 1; n > 0; n--)
            {
                string t = keepEnd ? "..." + s.Substring(s.Length - n) : s.Substring(0, n) + "...";
                if (Width(t) <= maxW) return t;
            }
            return "...";
        }
        public List<string> Wrap(string text, int maxW)
        {
            List<string> lines = new List<string>();
            foreach (string para in text.Split('\n'))
            {
                string line = "";
                foreach (string word in para.Split(' '))
                {
                    string t = line.Length == 0 ? word : line + " " + word;
                    if (Width(t) <= maxW) { line = t; continue; }
                    if (line.Length > 0) lines.Add(line);
                    line = word;
                    while (Width(line) > maxW && line.Length > 1)   // a path longer than the line
                    {
                        int n = line.Length - 1; while (n > 1 && Width(line.Substring(0, n)) > maxW) n--;
                        lines.Add(line.Substring(0, n)); line = line.Substring(n);
                    }
                }
                lines.Add(line);
            }
            return lines;
        }
    }

    // colour ramps of the glue text: shades 1 (bright) .. 4 (dark), 7 shadow; Gold/Lit/Off = the installer menu
    static class Ramp
    {
        static int[] Mk(int s1, int s2, int s3, int s4, int shadow)
        {
            int a = unchecked((int)0xFF000000);
            return new[] { 0, a | s1, a | s2, a | s3, a | s4, a | s1, a | s1, a | shadow };
        }
        public static readonly int[] Gold = Mk(0xECDC48, 0xBCA82C, 0x847018, 0x4A3C0C, 0x0C0800);
        public static readonly int[] Lit = Mk(0xFFFCC8, 0xFCEC78, 0xD0BC40, 0x806C1C, 0x141000);
        public static readonly int[] Off = Mk(0x7C7864, 0x5E5A4A, 0x423E32, 0x24221C, 0x080804);
        public static readonly int[] Grey = Mk(0xD4D4D8, 0xA4A4B0, 0x747484, 0x302C44, 0x080810);
        public static readonly int[] Green = Mk(0x84E050, 0x54BC2C, 0x409020, 0x285C18, 0x082808);
        public static readonly int[] Orange = Mk(0xF8A834, 0xC87C20, 0x8C5414, 0x462A0A, 0x100800);
        public static readonly int[] Red = Mk(0xFC4830, 0xC41400, 0x840800, 0x400000, 0x100000);
        public static readonly int[] Steel = Mk(0xE4EAFC, 0xA8B8F4, 0x7884B4, 0x3C4468, 0x080C18);
        public static readonly int[] Moss = Mk(0x648A3A, 0x4C6C2C, 0x36501E, 0x1E3010, 0x060A02);
    }

    class Item { public string Text; public bool Big, Enabled = true; public Action Click; public RectangleF R; }
    class LogLine { public int Level; public string Text; }

    // The window: a StarCraft installer of the 1998 kind. 640x480 glue screen (SD/glue/palnl/backgnd) with the logo of the
    // title screen, the menu as glue text on the left, popups on the glue popup panel. Everything is laid out in 640x480 and
    // the window is that scaled by S (at most 1.5: larger, the bitmap font turns blocky). Technical details (paths, file
    // counts, the log) stay out of the way: the log is behind "Details" once the work is done.
    class MainForm : Form
    {
        const int W = 640, H = 480, X0 = 40, Y0 = 204, LogRows = 5;
        static readonly Rectangle LogoRect = new Rectangle(0, 0, 640, 126), BroodWar = new Rectangle(124, 92, 356, 30), Blizz = new Rectangle(552, 420, 88, 60);
        static readonly Rectangle Bar = new Rectangle(X0, Y0 + 56, 430, 12);

        bool uninstallMode, ok, workspace; Pkg pkg; string exePath, game = "", dtaVer = "", status = "";
        int[] statusRamp = Ramp.Grey;
        InstallRecord rec;
        float S = 1f; Bitmap scene, cache, popup;
        Fnt fBig, fMid, fSmall;
        Dictionary<string, Bitmap> texts = new Dictionary<string, Bitmap>();
        List<Item> items = new List<Item>(), ask = new List<Item>();
        Item hot, pressed;
        List<string> askLines = new List<string>(); bool askOn; RectangleF askBox;
        List<LogLine> logs = new List<LogLine>(); object lk = new object(); int logScroll, warnCount;
        bool progressView, details, busy, installRun, selfDelete; int result; double prog; string heading = "", subline = "", errText = "";
        Dictionary<string, byte[]> wav = new Dictionary<string, byte[]>(); SoundPlayer player;
        System.Windows.Forms.Timer timer;

        public MainForm(string exePath, Pkg pkg, string gameArg, bool forShot)
        {
            this.exePath = exePath; this.pkg = pkg; uninstallMode = pkg == null;
            FormBorderStyle = FormBorderStyle.FixedSingle; MaximizeBox = false; StartPosition = FormStartPosition.CenterScreen;
            DoubleBuffered = true; BackColor = Color.Black; KeyPreview = true;
            try { using (Stream s = Res.Open("app.ico")) if (s != null) Icon = new Icon(s); } catch (Exception) { }

            fBig = new Fnt(Res.Bytes("font16x.fnt")); fMid = new Fnt(Res.Bytes("font16.fnt")); fSmall = new Fnt(Res.Bytes("font14.fnt"));
            popup = PreparePopup(Res.Img("glue_popup.png"));
            scene = BuildScene(Res.Img("glue_bg.png"), Res.Img("glue_title.png"));
            foreach (string w in new[] { "click", "hover", "done", "error", "open" }) { byte[] b = Res.Bytes(w + ".wav"); if (b != null) wav[w] = b; }

            game = FindGame(gameArg);
            LoadState();

            if (!forShot)
            {
                Rectangle wa = Screen.FromPoint(Cursor.Position).WorkingArea;
                foreach (float s in new[] { 1.5f, 1.25f, 1f })
                    if (W * s <= wa.Width - 32 && H * s + 48 <= wa.Height) { S = s; break; }
                ClientSize = new Size((int)(W * S), (int)(H * S));
                timer = new System.Windows.Forms.Timer { Interval = 100 };
                timer.Tick += delegate { if (busy) Invalidate(); };
                timer.Start();
            }
        }

        // ---- the static picture ----
        // the glue art darkened where the logo and the menu go, the StarCraft logo of the title screen ("Brood War" taken
        // out) and the Blizzard logo, added with "lighten" as they sit on black; the titles under the logo are drawn live
        Bitmap BuildScene(Bitmap bg, Bitmap title)
        {
            Bitmap s = new Bitmap(W, H, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(s))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                if (bg != null) g.DrawImage(bg, 0, 0, W, H); else g.Clear(Color.Black);
                using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, -1, W, 192), Color.FromArgb(240, 0, 0, 0), Color.FromArgb(0, 0, 0, 0), 90f))
                    g.FillRectangle(b, 0, 0, W, 190);
                using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(-1, 0, 452, H), Color.FromArgb(200, 0, 0, 0), Color.FromArgb(0, 0, 0, 0), 0f))
                    g.FillRectangle(b, 0, 0, 450, H);
            }
            if (title != null) { Lighten(s, title, LogoRect, true); Lighten(s, title, Blizz, false); }
            return s;
        }

        static int[] Pixels(Bitmap b, Rectangle r, out BitmapData d, ImageLockMode mode)
        {
            d = b.LockBits(r, mode, PixelFormat.Format32bppArgb);
            int[] p = new int[r.Width * r.Height];
            for (int y = 0; y < r.Height; y++) Marshal.Copy(new IntPtr(d.Scan0.ToInt64() + (long)y * d.Stride), p, y * r.Width, r.Width);
            return p;
        }

        static void Lighten(Bitmap dst, Bitmap src, Rectangle r, bool logo)
        {
            BitmapData dd, sd;
            int[] dp = Pixels(dst, r, out dd, ImageLockMode.ReadWrite), sp = Pixels(src, r, out sd, ImageLockMode.ReadOnly);
            for (int i = 0; i < dp.Length; i++)
            {
                int x = r.X + i % r.Width, y = r.Y + i / r.Width, c = sp[i];
                int R = (c >> 16) & 255, G = (c >> 8) & 255, B = c & 255;
                if (logo)
                {
                    float f = y < 106 ? 1f : Math.Max(0f, 1f - (y - 106) / 20f);
                    if (BroodWar.Contains(x, y) && G > R + 6 && G > B + 6) f *= Math.Min(1f, 24f / G);   // green "BROOD WAR" -> the haze around it
                    R = (int)(R * f); G = (int)(G * f); B = (int)(B * f);
                }
                int o = dp[i];
                dp[i] = unchecked((int)0xFF000000) | (Math.Max(R, (o >> 16) & 255) << 16) | (Math.Max(G, (o >> 8) & 255) << 8) | Math.Max(B, o & 255);
            }
            for (int y = 0; y < r.Height; y++) Marshal.Copy(dp, y * r.Width, new IntPtr(dd.Scan0.ToInt64() + (long)y * dd.Stride), r.Width);
            dst.UnlockBits(dd); src.UnlockBits(sd);
        }

        // the glue popup panel: its red lines in the installer's gold, its own button slot cleared (we draw ours)
        static Bitmap PreparePopup(Bitmap p)
        {
            if (p == null) return null;
            Rectangle r = new Rectangle(0, 0, p.Width, p.Height); BitmapData d;
            int[] px = Pixels(p, r, out d, ImageLockMode.ReadWrite);
            for (int i = 0; i < px.Length; i++)
            {
                int x = i % r.Width, y = i / r.Width, c = px[i];
                if (x >= 8 && y >= 8 && x < r.Width - 8 && y < r.Height - 8) { px[i] = unchecked((int)0xFF000400); continue; }
                int R = (c >> 16) & 255, G = (c >> 8) & 255, B = c & 255;
                if (R > 120 && G < 70 && B < 60) px[i] = unchecked((int)0xFF000000) | (R * 150 / 255 << 16) | (R * 126 / 255 << 8) | (R * 44 / 255);
            }
            for (int y = 0; y < r.Height; y++) Marshal.Copy(px, y * r.Width, new IntPtr(d.Scan0.ToInt64() + (long)y * d.Stride), r.Width);
            p.UnlockBits(d);
            return p;
        }

        // ---- state ----
        string FindGame(string arg)
        {
            if (uninstallMode)   // <game>\SCMod\<this exe>
                return Path.GetDirectoryName(Path.GetDirectoryName(Path.GetFullPath(exePath)));
            List<string> c = new List<string>();
            if (!string.IsNullOrEmpty(arg)) c.Add(arg);
            string here = Path.GetDirectoryName(Path.GetFullPath(exePath));
            c.Add(here); c.Add(Path.GetDirectoryName(here) ?? here);
            try { using (RegistryKey k = Registry.CurrentUser.OpenSubKey(Engine.RegApp)) if (k != null && k.GetValue("GamePath") is string) c.Add((string)k.GetValue("GamePath")); }
            catch (Exception) { }
            c.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "Dawn of the Tiberium Age"));
            c.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Desktop", "Dawn of the Tiberium Age"));
            c.Add(@"C:\Games\Dawn of the Tiberium Age"); c.Add(@"C:\Dawn of the Tiberium Age");
            foreach (string d in c) if (Dta.IsGameFolder(d)) return Path.GetFullPath(d).TrimEnd('\\');
            return "";
        }

        // the folder's state; only what needs the user's attention becomes a status line
        void LoadState()
        {
            Text = uninstallMode ? L.T("StarCraft Mod — deinstalator", "StarCraft Mod — Uninstall") : L.T("StarCraft Mod — instalator", "StarCraft Mod — Setup");
            ok = Dta.IsGameFolder(game);
            rec = null;
            try { if (ok) rec = Engine.LoadRecord(game); }
            catch (Exception ex) { AddLog(3, "install.json: " + ex.Message); }
            dtaVer = ok ? Dta.Version(game) : "";
            string want = pkg != null ? pkg.Manifest.dtaVersion : (rec != null ? rec.dtaVersion : "");
            // the modding workspace itself (git repo + capture state): the mods are already there, uninstall would delete them
            workspace = ok && rec == null && Directory.Exists(Path.Combine(game, ".git")) && File.Exists(Path.Combine(game, @"Modding\dta\state.json"));
            status = ""; statusRamp = Ramp.Orange;
            if (!ok) status = L.T("Nie znaleziono Dawn of the Tiberium Age: wskaż folder gry.", "Dawn of the Tiberium Age not found: choose the game folder.");
            else if (workspace) status = L.T("To folder roboczy moda: wskaż inną kopię DTA.", "This is the mod's working folder: choose another copy of DTA.");
            else if (uninstallMode && rec == null) status = L.T("Mod nie jest zainstalowany w tym folderze.", "The mod is not installed in this folder.");
            else if (dtaVer != want) status = string.Format(L.T("Twoja DTA to {0}, a mod jest zrobiony dla {1}.", "Your DTA is {0}, the mod is made for {1}."), dtaVer, want);
            Layout();
        }

        void Layout()
        {
            items.Clear(); hot = null;
            if (progressView)
            {
                if (!busy)
                {
                    if (installRun && result != 2 && File.Exists(Path.Combine(game, "DTA.exe"))) Add(L.T("Uruchom DTA", "Start DTA"), false, 358, delegate { StartDta(); Close(); }, true);
                    Add(details ? L.T("Ukryj szczegóły", "Hide details") : L.T("Szczegóły", "Details"), false, 382, delegate { details = !details; logScroll = 0; Layout(); }, true);
                    Add(L.T("Powrót do menu", "Back to menu"), false, 406, BackToMenu, true);
                    Add(uninstallMode ? L.T("Zakończ", "Exit") : L.T("Zakończ instalator", "Exit installer"), false, 430, Close, true);
                }
            }
            else if (uninstallMode)
            {
                Add(L.T("Odinstaluj StarCraft Mod", "Uninstall StarCraft Mod"), true, Y0, OnUninstall, ok && rec != null);
                Add(L.T("Język: polski", "Language: English"), false, 406, ToggleLanguage, true);
                Add(L.T("Zakończ", "Exit"), false, 430, Close, true);
            }
            else
            {
                string main = rec == null ? L.T("Zainstaluj StarCraft Mod", "Install StarCraft Mod")
                    : rec.version == pkg.Manifest.version ? L.T("Napraw StarCraft Mod", "Repair StarCraft Mod") : L.T("Aktualizuj StarCraft Mod", "Update StarCraft Mod");
                Add(main, true, Y0, OnInstall, ok && !workspace);
                Add(L.T("Folder gry...", "Game folder..."), false, Y0 + 60, OnBrowse, true);
                Add(L.T("Odinstaluj StarCraft Mod", "Uninstall StarCraft Mod"), false, Y0 + 132, OnUninstall, ok && rec != null);
                Add(L.T("O modzie", "About"), false, Y0 + 158, OnAbout, true);
                Add(L.T("Język: polski", "Language: English"), false, Y0 + 184, ToggleLanguage, true);
                Add(L.T("Zakończ instalator", "Exit installer"), false, 430, Close, true);
            }
            Invalidate();
        }

        void Add(string text, bool big, float y, Action click, bool enabled)
        {
            float k = big ? 1.5f : 1f;
            items.Add(new Item { Text = text, Big = big, Enabled = enabled, Click = click, R = new RectangleF(X0 - 6, y - 3, fBig.Width(text) * k + 12, fBig.H * k + 4) });
        }

        void ToggleLanguage() { L.En = !L.En; L.Save(); LoadState(); }
        void BackToMenu() { progressView = false; details = false; LoadState(); }

        void AddLog(int level, string text)
        {
            lock (lk)
            {
                logs.Add(new LogLine { Level = level, Text = text });
                if (logs.Count > 400) logs.RemoveAt(0);
                if (level == 2) warnCount++;
            }
        }

        void Play(string name)
        {
            byte[] b;
            if (!wav.TryGetValue(name, out b)) return;
            try { player = new SoundPlayer(new MemoryStream(b)); player.Play(); } catch (Exception) { }
        }

        // a glue popup: text and one or two buttons
        void Ask(string text, string yes, string no, Action onYes, Action onNo)
        {
            const float w = 440, bw = 160;
            askLines = fMid.Wrap(text, (int)w - 56);
            float h = 34 + askLines.Count * 15 + 62;
            askBox = new RectangleF((W - w) / 2, Math.Max(150, (H - h) / 2 + 30), w, h);
            ask.Clear();
            float by = askBox.Bottom - 44;
            ask.Add(new Item { Text = yes, Click = delegate { askOn = false; Layout(); if (onYes != null) onYes(); } });
            if (no != null) ask.Add(new Item { Text = no, Click = delegate { askOn = false; Layout(); if (onNo != null) onNo(); } });
            for (int i = 0; i < ask.Count; i++)
                ask[i].R = new RectangleF(ask.Count == 1 ? askBox.X + (w - bw) / 2 : askBox.X + w / 2 + (i == 0 ? -bw - 12 : 12), by, bw, 26);
            askOn = true; hot = null; Invalidate();
        }

        // ---- actions ----
        void OnBrowse()
        {
            using (FolderBrowserDialog d = new FolderBrowserDialog())
            {
                d.Description = L.T("Folder z Dawn of the Tiberium Age (game.exe, DTA.exe)", "The Dawn of the Tiberium Age folder (game.exe, DTA.exe)");
                if (Directory.Exists(game)) d.SelectedPath = game;
                if (d.ShowDialog(this) != DialogResult.OK) return;
                if (!Dta.IsGameFolder(d.SelectedPath))
                {
                    Play("error");
                    Ask(L.T("To nie jest folder Dawn of the Tiberium Age:\n", "This is not a Dawn of the Tiberium Age folder:\n") + d.SelectedPath, "OK", null, null, null);
                    return;
                }
                game = Path.GetFullPath(d.SelectedPath).TrimEnd('\\');
                LoadState();
            }
        }

        void OnInstall()
        {
            if (dtaVer != pkg.Manifest.dtaVersion)
            {
                Play("open");
                Ask(string.Format(L.T("Ten mod jest zrobiony dla DTA {0}, a w folderze jest DTA {1}.\n\nMod podmieni część plików gry swoimi wersjami. Powinien działać, ale poprawki Twojej wersji DTA w tych plikach wrócą dopiero po odinstalowaniu moda.",
                    "This mod is made for DTA {0}, but the folder has DTA {1}.\n\nThe mod replaces some game files with its own versions. It should work, but the fixes of your DTA version in those files come back only after you uninstall the mod."),
                    pkg.Manifest.dtaVersion, dtaVer), L.T("Instaluj", "Install"), L.T("Anuluj", "Cancel"), delegate { Run(true); }, null);
            }
            else Run(true);
        }

        void OnUninstall()
        {
            Play("open");
            Ask(string.Format(L.T("Odinstalować StarCraft Mod z folderu\n{0}?\n\nOryginalne pliki gry wrócą na miejsce, pliki moda zostaną usunięte.",
                "Uninstall StarCraft Mod from\n{0}?\n\nThe original game files will be restored and the mod's files removed."), game),
                L.T("Odinstaluj", "Uninstall"), L.T("Anuluj", "Cancel"), delegate { Run(false); }, null);
        }

        void OnAbout()
        {
            Play("open");
            Ask(string.Format(L.T("StarCraft Mod {0}\ndla Dawn of the Tiberium Age\n\nStrony Terran, Zerg i Protoss w skirmishu (opcja STARCRAFT), jednostki i budynki ze StarCrafta, kampania ARKA: Błąd znaku, mapy i edytor map.\n\nOryginalne pliki gry są zachowywane i wracają po odinstalowaniu moda.\n\nAutor: Zema",
                "StarCraft Mod {0}\nfor Dawn of the Tiberium Age\n\nTerran, Zerg and Protoss sides in skirmish (STARCRAFT option), StarCraft units and buildings, the ARKA: Sign Error campaign (in Polish), maps and a map editor.\n\nThe original game files are kept and come back when you uninstall the mod.\n\nAuthor: Zema"),
                pkg.Manifest.version), "OK", null, null, null);
        }

        void Run(bool install)
        {
            progressView = true; details = false; busy = true; installRun = install; result = 0; prog = 0; logScroll = 0; errText = "";
            heading = install ? L.T("Instalowanie...", "Installing...") : L.T("Odinstalowywanie...", "Uninstalling...");
            subline = install ? L.T("Kopiowanie plików moda...", "Copying the mod's files...") : L.T("Przywracanie oryginalnych plików gry...", "Restoring the original game files...");
            lock (lk) { logs.Clear(); warnCount = 0; }
            LoadState();
            bool fromModDir = exePath.StartsWith(Path.Combine(game, Engine.ModDir) + "\\", StringComparison.OrdinalIgnoreCase);
            string g = game;
            Thread t = new Thread(delegate()
            {
                int code; string err = null;
                Engine en = new Engine(pkg, g, delegate(int l, string s) { AddLog(l, s); }, delegate(double p) { prog = p; });
                try { code = install ? en.Install() : en.Uninstall(fromModDir); }
                catch (Exception ex) { err = ex.Message; AddLog(3, ex.Message); code = 2; }
                BeginInvoke((Action)delegate { Done(install, code, err, fromModDir); });
            });
            t.IsBackground = true; t.Start();
        }

        void Done(bool install, int code, string err, bool fromModDir)
        {
            busy = false; result = code; errText = err ?? ""; if (code != 2) prog = 1;
            heading = install ? (code != 2 ? L.T("Instalacja zakończona", "Installation complete") : L.T("Instalacja przerwana", "Installation stopped"))
                              : (code != 2 ? L.T("Deinstalacja zakończona", "Uninstall complete") : L.T("Deinstalacja przerwana", "Uninstall stopped"));
            subline = code == 2 ? "" : install ? L.T("StarCraft Mod jest gotowy do gry.", "StarCraft Mod is ready to play.") : L.T("Oryginalne pliki gry są z powrotem.", "The original game files are back.");
            string logPath = Path.Combine(Path.GetTempPath(), "DTA-SCMod-setup.log");
            try
            {
                lock (lk)
                    using (StreamWriter w = new StreamWriter(logPath, false, new UTF8Encoding(false)))
                        foreach (LogLine l in logs) w.WriteLine((l.Level == 1 ? "OK   " : l.Level == 2 ? "WARN " : l.Level == 3 ? "ERR  " : "     ") + l.Text);
            }
            catch (Exception) { }
            LoadState();
            Play(code == 2 ? "error" : "done");
            string warn = code == 1 ? string.Format(L.T("\n\nUwagi: {0} (zobacz Szczegóły).", "\n\nNotes: {0} (see Details)."), warnCount) : "";
            if (code == 2)
                Ask((install ? L.T("Instalacja przerwana:\n", "The installation stopped:\n") : L.T("Deinstalacja przerwana:\n", "The uninstall stopped:\n")) + err
                    + (install ? L.T("\n\nMożesz spróbować ponownie albo odinstalować to, co już zostało zapisane.", "\n\nYou can try again or uninstall what has been written so far.") : ""), "OK", null, null, null);
            else if (install)
                Ask(L.T("StarCraft Mod zainstalowany.", "StarCraft Mod is installed.") + warn
                    + L.T("\n\nSkirmish: strony Terran, Zerg, Protoss i opcja STARCRAFT.\nKampania ARKA (alfa, misje #0-#5): New Mission.\n\nModa odinstalujesz tym instalatorem albo w Panelu sterowania (Programy i funkcje).",
                          "\n\nSkirmish: the Terran, Zerg and Protoss sides and the STARCRAFT option.\nARKA campaign (alpha, missions #0-#5): New Mission.\n\nTo uninstall, run this installer again or use Control Panel (Programs and Features)."),
                    L.T("Uruchom DTA", "Start DTA"), "OK", delegate { StartDta(); Close(); }, null);
            else
            {
                selfDelete = uninstallMode && fromModDir;
                Ask(L.T("StarCraft Mod odinstalowany. Oryginalne pliki gry są z powrotem na miejscu.", "StarCraft Mod is uninstalled. The original game files are back in place.") + warn,
                    uninstallMode ? L.T("Zamknij", "Close") : "OK", null, uninstallMode ? (Action)Close : null, null);
            }
        }

        void StartDta()
        {
            string dta = Path.Combine(game, "DTA.exe");
            try { if (File.Exists(dta)) Process.Start(new ProcessStartInfo(dta) { WorkingDirectory = game }); }
            catch (Exception ex) { MessageBox.Show(ex.Message); }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (busy) { e.Cancel = true; return; }
            base.OnFormClosing(e);
        }
        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            base.OnFormClosed(e);
            if (selfDelete)   // the uninstaller removes its own folder once it has exited
            {
                string dir = Path.Combine(game, Engine.ModDir);
                Process.Start(new ProcessStartInfo("cmd.exe", "/c ping 127.0.0.1 -n 3 >nul & rmdir /s /q \"" + dir + "\"")
                { CreateNoWindow = true, UseShellExecute = false, WorkingDirectory = game });
            }
        }

        // ---- input ----
        List<Item> Active() { return askOn ? ask : items; }
        Item HitTest(Point p)
        {
            PointF d = new PointF(p.X / S, p.Y / S);
            foreach (Item b in Active()) if (b.Enabled && b.R.Contains(d)) return b;
            return null;
        }
        protected override void OnMouseMove(MouseEventArgs e)
        {
            Item b = HitTest(e.Location);
            if (b != hot) { hot = b; if (b != null) Play("hover"); Invalidate(); }
            Cursor = b != null ? Cursors.Hand : Cursors.Default;
        }
        protected override void OnMouseLeave(EventArgs e) { hot = null; Invalidate(); }
        protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) pressed = HitTest(e.Location); }
        protected override void OnMouseUp(MouseEventArgs e)
        {
            Item b = HitTest(e.Location);
            if (e.Button == MouseButtons.Left && b != null && b == pressed) { Play("click"); b.Click(); }
            pressed = null; Invalidate();
        }
        protected override void OnMouseWheel(MouseEventArgs e)
        {
            if (!details) return;
            int n; lock (lk) n = logs.Count;
            logScroll = Math.Max(0, Math.Min(Math.Max(0, n - LogRows), logScroll + (e.Delta > 0 ? 1 : -1)));
            Invalidate();
        }
        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Escape)
            {
                if (askOn) ask[ask.Count - 1].Click();
                else if (progressView && !busy) BackToMenu();
                else if (!busy) Close();
            }
            else if (e.KeyCode == Keys.Enter)
            {
                if (askOn) ask[0].Click();
                else if (hot != null) hot.Click();
                else if (items.Count > 0 && items[0].Enabled) items[0].Click();
            }
        }

        // ---- drawing ----
        protected override void OnPaint(PaintEventArgs e)
        {
            if (cache == null || cache.Width != ClientSize.Width) { if (cache != null) cache.Dispose(); cache = BuildCache(ClientSize.Width, ClientSize.Height); }
            e.Graphics.DrawImageUnscaled(cache, 0, 0);
            e.Graphics.ScaleTransform(S, S);
            DrawDynamic(e.Graphics);
        }

        Bitmap BuildCache(int w, int h)
        {
            Bitmap b = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
            using (Graphics g = Graphics.FromImage(b))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(scene, 0, 0, w, h);
            }
            return b;
        }

        // glue text at k times its pixel size. 1:1 on screen: as it is; otherwise blown up to the next whole size and
        // smoothed down to the exact one, so the letters stay sharp without the blocky look
        void Txt(Graphics g, Fnt f, int[] ramp, string s, float x, float y, float k, int spacing)
        {
            if (string.IsNullOrEmpty(s)) return;
            float e = k * S;
            int up = Math.Abs(e - 1) < 0.01 ? 1 : (int)Math.Ceiling(e - 0.01);
            string key = f.GetHashCode() + "|" + ramp.GetHashCode() + "|" + spacing + "|" + up + "|" + s;
            Bitmap b;
            if (!texts.TryGetValue(key, out b))
            {
                if (texts.Count > 600) { foreach (Bitmap o in texts.Values) o.Dispose(); texts.Clear(); }
                using (Bitmap t = f.Render(s, ramp, spacing, true))
                {
                    b = new Bitmap(t.Width * up, t.Height * up, PixelFormat.Format32bppPArgb);
                    using (Graphics bg = Graphics.FromImage(b))
                    {
                        bg.InterpolationMode = InterpolationMode.NearestNeighbor; bg.PixelOffsetMode = PixelOffsetMode.Half;
                        bg.DrawImage(t, 0, 0, b.Width, b.Height);
                    }
                }
                texts[key] = b;
            }
            g.InterpolationMode = up == 1 ? InterpolationMode.NearestNeighbor : InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = up == 1 ? PixelOffsetMode.Half : PixelOffsetMode.HighQuality;
            g.DrawImage(b, x - k, y - k, b.Width * k / up, b.Height * k / up);
        }
        void Txt(Graphics g, Fnt f, int[] ramp, string s, float x, float y, float k) { Txt(g, f, ramp, s, x, y, k, 0); }
        void Centered(Graphics g, Fnt f, int[] ramp, string s, float y, float k, int spacing)
        {
            Txt(g, f, ramp, s, (float)Math.Round(320 - f.Width(s, spacing) * k / 2), y, k, spacing);
        }

        void DrawDynamic(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.None;
            // under the logo: where "Brood War" was, then the campaign and what this is
            Centered(g, fBig, Ramp.Moss, "TIBERIUM AGE", 109, 1.25f, 9);
            Centered(g, fBig, Ramp.Steel, L.T("ARKA: BŁĄD ZNAKU", "ARKA: SIGN ERROR"), 136, 1.5f, 2);
            Centered(g, fSmall, Ramp.Grey, "DTA & SC mashup", 167, 1f, 1);
            if (progressView) DrawProgress(g);
            else DrawMenu(g);
            foreach (Item it in items)
                Txt(g, fBig, !it.Enabled ? Ramp.Off : !askOn && it == hot ? Ramp.Lit : Ramp.Gold, it.Text, it.R.X + 6, it.R.Y + 3, it.Big ? 1.5f : 1f);
            if (askOn) DrawAsk(g);
        }

        void DrawMenu(Graphics g)
        {
            string ver = !uninstallMode
                ? string.Format(L.T("Wersja {0}", "Version {0}"), pkg.Manifest.version) + (rec != null ? "  ·  " + string.Format(L.T("zainstalowana: {0}", "installed: {0}"), rec.version) : "")
                : rec != null ? string.Format(L.T("Zainstalowana wersja {0}", "Installed version {0}"), rec.version) : "";
            Txt(g, fSmall, Ramp.Grey, ver, X0, Y0 + 32, 1);
            float y = uninstallMode ? Y0 + 52 : Y0 + 84;
            Txt(g, fSmall, game.Length > 0 ? Ramp.Grey : Ramp.Off, fSmall.Fit(game.Length > 0 ? game : L.T("(nie wybrano folderu)", "(no folder chosen)"), 560, true), X0, y, 1);
            Txt(g, fSmall, statusRamp, fSmall.Fit(status, 560, false), X0, y + 16, 1);
        }

        void DrawProgress(Graphics g)
        {
            Txt(g, fBig, Ramp.Gold, heading, X0, Y0, 1.5f);
            Txt(g, fSmall, Ramp.Grey, subline, X0, Y0 + 34, 1);
            // the bar: a dark slot with a gold rim, filled with a gold gradient
            double p = Math.Max(0, Math.Min(1, prog));
            using (SolidBrush b = new SolidBrush(Color.FromArgb(225, 0, 0, 0))) g.FillRectangle(b, Bar);
            using (Pen pen = new Pen(Color.FromArgb(132, 112, 40))) g.DrawRectangle(pen, Bar.X - 1, Bar.Y - 1, Bar.Width + 1, Bar.Height + 1);
            float fw = (float)((Bar.Width - 4) * p);
            if (fw >= 1)
                using (LinearGradientBrush lb = new LinearGradientBrush(new RectangleF(0, Bar.Y + 1, 10, Bar.Height - 2), Color.FromArgb(252, 240, 120), Color.FromArgb(150, 124, 24), 90f))
                    g.FillRectangle(lb, Bar.X + 2, Bar.Y + 2, fw, Bar.Height - 4);
            Txt(g, fSmall, Ramp.Gold, string.Format("{0:0}%", p * 100), Bar.Right + 10, Bar.Y - 1, 1);
            if (busy) return;
            if (!details)
            {
                if (result == 2) foreach (string l in fSmall.Wrap(errText, 560)) { Txt(g, fSmall, Ramp.Red, l, X0, Y0 + 80, 1); break; }
                else if (result == 1) Txt(g, fSmall, Ramp.Orange, string.Format(L.T("Gotowe. Uwagi: {0} (zobacz Szczegóły).", "Done. Notes: {0} (see Details)."), warnCount), X0, Y0 + 80, 1);
                else Txt(g, fSmall, Ramp.Green, L.T("Gotowe.", "Done."), X0, Y0 + 80, 1);
                if (installRun && result != 2)
                    Txt(g, fSmall, Ramp.Grey, L.T("Możesz już zagrać w kampanię ARKA (wersja alfa): New Mission.", "You can now play the ARKA campaign (alpha version): New Mission."), X0, Y0 + 98, 1);
                return;
            }
            // the log: newest at the bottom, the wheel scrolls back
            List<LogLine> view; lock (lk) view = new List<LogLine>(logs);
            int first = Math.Max(0, view.Count - LogRows - logScroll);
            for (int i = first; i < Math.Min(view.Count, first + LogRows); i++)
            {
                LogLine l = view[i];
                int[] r = l.Level == 1 ? Ramp.Green : l.Level == 2 ? Ramp.Orange : l.Level == 3 ? Ramp.Red : Ramp.Grey;
                Txt(g, fSmall, r, fSmall.Fit(l.Text, 560, false), X0, Y0 + 80 + (i - first) * 14, 1);
            }
        }

        void DrawAsk(Graphics g)
        {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(150, 0, 0, 0))) g.FillRectangle(b, 0, 0, W, H);
            if (popup != null) NineSlice(g, popup, askBox, 8);
            else using (SolidBrush b = new SolidBrush(Color.Black)) g.FillRectangle(b, askBox);
            for (int i = 0; i < askLines.Count; i++)
                Txt(g, fMid, Ramp.Grey, askLines[i], (float)Math.Round(askBox.X + (askBox.Width - fMid.Width(askLines[i])) / 2), askBox.Y + 24 + i * 15, 1);
            foreach (Item b in ask)
            {
                bool h = b == hot;
                using (GraphicsPath p = Round(b.R, 4))
                {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    g.FillPath(Brushes.Black, p);
                    using (Pen pen = new Pen(h ? Color.FromArgb(236, 220, 72) : Color.FromArgb(150, 126, 44))) g.DrawPath(pen, p);
                    g.SmoothingMode = SmoothingMode.None;
                }
                Txt(g, fBig, h ? Ramp.Lit : Ramp.Gold, b.Text, (float)Math.Round(b.R.X + (b.R.Width - fBig.Width(b.Text)) / 2), b.R.Y + 4, 1);
            }
        }

        static GraphicsPath Round(RectangleF r, float rad)
        {
            GraphicsPath p = new GraphicsPath(); float d = rad * 2;
            p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure(); return p;
        }

        // the panel stretched to any size: corners as they are, edges and middle stretched
        static void NineSlice(Graphics g, Bitmap img, RectangleF d, int m)
        {
            g.InterpolationMode = InterpolationMode.NearestNeighbor; g.PixelOffsetMode = PixelOffsetMode.Half;
            int sw = img.Width, sh = img.Height;
            float[] dx = { d.X, d.X + m, d.Right - m, d.Right }, dy = { d.Y, d.Y + m, d.Bottom - m, d.Bottom };
            int[] sx = { 0, m, sw - m, sw }, sy = { 0, m, sh - m, sh };
            for (int i = 0; i < 3; i++)
                for (int j = 0; j < 3; j++)
                    g.DrawImage(img, RectangleF.FromLTRB(dx[i], dy[j], dx[i + 1], dy[j + 1]), RectangleF.FromLTRB(sx[i], sy[j], sx[i + 1], sy[j + 1]), GraphicsUnit.Pixel);
        }

        // /shot: the window in a given state at scale 1.5 (960x720), for checking the design without clicking through it
        public void Shot(string png, string state)
        {
            S = 1.5f;
            if (state == "busy" || state == "done" || state == "details" || state == "finished")
            {
                progressView = true; busy = state == "busy"; installRun = true; prog = state == "busy" ? 0.62 : 1;   // set by hand: never run the engine here
                heading = L.T("Instalowanie...", "Installing..."); subline = L.T("Kopiowanie plików moda...", "Copying the mod's files...");
                lock (lk) { logs.Clear(); warnCount = 0; }
                AddLog(0, "Instalacja StarCraft mod 2026.10.28 w C:\\Games\\Dawn of the Tiberium Age");
                AddLog(0, "40 / 322 plików"); AddLog(0, "80 / 322 plików");
                AddLog(2, "INI/Rules.ini: inna wersja niż w DTA 16.2.3 (kopia w SCMod\\backup), zastąpiona wersją moda.");
                AddLog(0, "120 / 322 plików"); AddLog(0, "160 / 322 plików"); AddLog(0, "200 / 322 plików");
                if (state != "busy")
                {
                    AddLog(1, "Zapisano 322 plików, 0 już było aktualnych. Deinstalator: SCMod\\Odinstaluj SC Mod.exe");
                    Done(true, 1, null, false);
                    if (state == "details") { askOn = false; details = true; Layout(); }
                    else if (state == "finished") { askOn = false; Layout(); }   // the done screen after the popup is closed
                }
                else Layout();
            }
            if (state == "ask") OnUninstall();
            if (state == "about") OnAbout();
            if (state == "hover") hot = items.Count > 0 ? items[0] : null;
            using (Bitmap b = new Bitmap((int)(W * S), (int)(H * S)))
            using (Graphics g = Graphics.FromImage(b))
            {
                Bitmap c = BuildCache(b.Width, b.Height);
                g.DrawImageUnscaled(c, 0, 0); c.Dispose();
                g.ScaleTransform(S, S);
                DrawDynamic(g);
                b.Save(png, ImageFormat.Png);
            }
        }
    }

    static class Program
    {
        [STAThread]
        static int Main(string[] args)
        {
            string exe = Assembly.GetExecutingAssembly().Location;
            L.Init();
            Pkg pkg = null;
            try { pkg = Pkg.Open(exe); }
            catch (Exception ex) { MessageBox.Show(L.T("Uszkodzony pakiet instalatora: ", "Damaged installer package: ") + ex.Message, "StarCraft Mod"); return 2; }

            if (args.Length >= 2 && (args[0] == "/install" || args[0] == "/uninstall"))
                return Silent(exe, pkg, args[0] == "/install", args[1]);

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            if (args.Length >= 2 && args[0] == "/shot")
            {
                List<string> opt = new List<string>(args).GetRange(2, args.Length - 2);
                if (opt.Contains("en")) L.En = true; else if (opt.Contains("pl")) L.En = false;
                using (MainForm f = new MainForm(exe, opt.Contains("uninstall") ? null : pkg, null, true))
                    f.Shot(args[1], opt.Count > 0 ? opt[0] : "idle");
                return 0;
            }
            Application.Run(new MainForm(exe, pkg, args.Length >= 1 ? args[0] : null, false));
            return 0;
        }

        static int Silent(string exe, Pkg pkg, bool install, string game)
        {
            string logPath = Path.Combine(Path.GetTempPath(), "DTA-SCMod-setup.log");
            using (StreamWriter w = new StreamWriter(logPath, false, new UTF8Encoding(false)))
            {
                Action<int, string> log = delegate(int l, string s) { w.WriteLine((l == 1 ? "OK   " : l == 2 ? "WARN " : l == 3 ? "ERR  " : "     ") + s); };
                try
                {
                    if (!Dta.IsGameFolder(game)) throw new Exception("not a DTA folder: " + game);
                    if (install && pkg == null) throw new Exception("this exe has no payload (it is the uninstaller)");
                    Engine en = new Engine(pkg, game, log, delegate(double p) { });
                    string modDir = Path.Combine(Path.GetFullPath(game).TrimEnd('\\'), Engine.ModDir) + "\\";
                    bool fromModDir = exe.StartsWith(modDir, StringComparison.OrdinalIgnoreCase);
                    int code = install ? en.Install() : en.Uninstall(fromModDir);
                    if (!install && fromModDir)
                        Process.Start(new ProcessStartInfo("cmd.exe", "/c ping 127.0.0.1 -n 3 >nul & rmdir /s /q \"" + modDir.TrimEnd('\\') + "\"")
                        { CreateNoWindow = true, UseShellExecute = false, WorkingDirectory = game });
                    return code;
                }
                catch (Exception ex) { log(3, ex.ToString()); return 2; }
            }
        }
    }
}
