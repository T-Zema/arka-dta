// Installer and uninstaller of our DTA mods (StarCraft factions, units, maps, ARKA campaign...) in the look of the DTA
// client (main menu background, Classic buttons, DTA greens) with StarCraft portraits and UI sounds. One source, two modes:
//   payload appended to the exe (tools/build-installer.ps1) -> setup: install / repair / update / uninstall
//   no payload (the copy the setup leaves in <game>\SCMod\) -> uninstaller
// Install: every file of the package (= Modding/dta/state.json) is written; a DTA file it replaces is first copied to
// <game>\SCMod\backup\ (for a file already ours, the pristine DTA copy from the package goes there). <game>\SCMod\install.json
// records what was created or replaced; uninstall restores the backups and deletes what was created, but only files that
// still hold our version (a file changed later, e.g. by a DTA update, is left alone).
// Silent: <exe> /install "<game>" | /uninstall "<game>"  -> exit code 0 ok, 1 warnings, 2 error; log in %TEMP%\DTA-SCMod-setup.log.
// Preview: <exe> /shot <png> [idle|busy|ask|done]  renders the window into a PNG (1280x720).
// C# 5 (csc of .NET Framework 4, no SDK). Wiki: workflow/installer.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
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
            if (e == null) throw new Exception("pakiet nie zawiera " + entry);
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
            if (Dta.GameRunning(game)) throw new Exception("Klient DTA albo gra działa z tego folderu. Zamknij ją i spróbuj ponownie.");
            PkgManifest m = pkg.Manifest;
            string dtaVer = Dta.Version(game);
            try { Directory.CreateDirectory(Path.Combine(game, ModDir, "backup")); }
            catch (UnauthorizedAccessException) { throw new Exception("Brak uprawnień do zapisu w folderze gry. Uruchom instalator jako administrator."); }

            InstallRecord prev = LoadRecord(game);
            Dictionary<string, RecEntry> prevMap = new Dictionary<string, RecEntry>(StringComparer.OrdinalIgnoreCase);
            if (prev != null) foreach (RecEntry e in prev.entries) prevMap[e.path] = e;
            InstallRecord rec = new InstallRecord
            {
                name = m.name, title = m.title, version = m.version, dtaVersion = dtaVer,
                installed = DateTime.Now.ToString("yyyy-MM-dd HH:mm"), entries = new List<RecEntry>(),
                dirs = prev != null ? prev.dirs : new List<string>()
            };
            log(0, prev == null ? string.Format("Instalacja {0} {1} w {2}", m.title, m.version, game)
                                : string.Format("Naprawa / aktualizacja: {0} -> {1}", prev.version, m.version));
            if (dtaVer != m.dtaVersion) Warn(string.Format("DTA w folderze: {0}, pakiet zbudowany dla {1}.", dtaVer, m.dtaVersion));

            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            long done = 0; int written = 0, same = 0, n = 0;
            try
            {
                foreach (PkgFile f in m.files)
                {
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
                                    Warn(f.path + ": inna wersja niż w DTA " + m.dtaVersion + " (kopia w SCMod\\backup), zastąpiona wersją moda.");
                                else if (f.kind == "new")
                                    log(0, f.path + ": istniejący plik o tej nazwie przeniesiony do kopii.");
                            }
                        }
                        else if (pe.action == "replaced" && cur != null && cur != pe.orig)
                        {   // DTA (update or file repair) put another file here since the install: it is the new original
                            CopyOver(full, Backup(f.path)); e.orig = cur;
                            Warn(f.path + ": DTA zmieniła ten plik od instalacji; nowa wersja DTA trafia do kopii, wraca wersja moda.");
                        }
                        seen.Add(f.path); rec.entries.Add(e);   // recorded before writing: a half-done install stays undoable
                        EnsureDir(Path.GetDirectoryName(full), rec.dirs);
                        pkg.Extract("files/" + f.path, full);
                        if (Dta.Hash(full) != f.ours) throw new Exception(f.path + ": zapisany plik ma zły skrót (uszkodzony pakiet?)");
                        written++;
                    }
                    done += f.size; progress(pkg.TotalBytes > 0 ? (double)done / pkg.TotalBytes : 1);
                    if (++n % 40 == 0) { log(0, string.Format("{0} / {1} plików", n, m.files.Count)); SaveRecord(rec); }
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
            catch (Exception ex) { Warn("Wpis w Panelu sterowania nie powstał: " + ex.Message); }
            log(1, string.Format("Zapisano {0} plików, {1} już było aktualnych. Deinstalator: {2}\\{3}", written, same, ModDir, UninstallerName));
            return Warnings > 0 ? 1 : 0;
        }

        // runningFromModDir: this exe is <game>\SCMod\...: the folder is removed by a helper after the program exits
        public int Uninstall(bool runningFromModDir)
        {
            if (Dta.GameRunning(game)) throw new Exception("Klient DTA albo gra działa z tego folderu. Zamknij ją i spróbuj ponownie.");
            InstallRecord rec = LoadRecord(game);
            if (rec == null) throw new Exception("Brak " + ModDir + "\\" + RecordFile + ": mod nie był instalowany tym instalatorem.");
            log(0, string.Format("Deinstalacja {0} {1} z {2}", rec.title, rec.version, game));
            int restored = 0, deleted = 0, left = 0;
            for (int i = rec.entries.Count - 1; i >= 0; i--)
            {
                RecEntry e = rec.entries[i];
                string full = Full(e.path), cur = Dta.HashOrNull(full);
                if (e.action == "created")
                {
                    if (cur == null) { }
                    else if (cur == e.ours) { File.SetAttributes(full, FileAttributes.Normal); File.Delete(full); deleted++; }
                    else { left++; Warn(e.path + ": zmieniony po instalacji, zostawiony."); }
                }
                else
                {
                    string bak = Backup(e.path);
                    if (cur == e.orig) { }
                    else if (!File.Exists(bak)) { left++; Warn(e.path + ": brak kopii w " + ModDir + "\\backup, zostawiony."); }
                    else if (cur == null || cur == e.ours) { CopyOver(bak, full); restored++; }
                    else { left++; Warn(e.path + ": zmieniony po instalacji (aktualizacja DTA?), zostawiony."); }
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
            catch (Exception ex) { Warn("Rejestr: " + ex.Message); }
            string modDir = Path.Combine(game, ModDir);
            Directory.Delete(Path.Combine(modDir, "backup"), true);
            File.Delete(RecordPath(game));
            if (!runningFromModDir) Directory.Delete(modDir, true);
            log(1, string.Format("Przywrócono {0} oryginałów DTA, usunięto {1} plików modu{2}.", restored, deleted, left > 0 ? ", " + left + " zostawionych" : ""));
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

    // A StarCraft portrait: idle loop fid00, now and then fidget fid01/fid02, talk loop tlk00 while working (10 fps).
    class Portrait
    {
        public string Name; public Bitmap Icon;
        Dictionary<string, Bitmap[]> clips = new Dictionary<string, Bitmap[]>();
        string clip = "fid00"; int frame; bool talk; Random rnd;
        public Portrait(string name, Bitmap icon, string key, Size size, Random rnd)
        {
            Name = name; Icon = icon; this.rnd = rnd;
            foreach (string c in new[] { "fid00", "fid01", "fid02", "tlk00" })
            {
                Bitmap strip = Res.Img(key + "_" + c + ".jpg");
                if (strip == null) continue;
                int n = strip.Width / 224; Bitmap[] fr = new Bitmap[n];
                for (int i = 0; i < n; i++)
                {
                    fr[i] = new Bitmap(size.Width, size.Height);
                    using (Graphics g = Graphics.FromImage(fr[i]))
                    {
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        g.DrawImage(strip, new Rectangle(0, 0, size.Width, size.Height), new Rectangle(i * 224, 0, 224, 240), GraphicsUnit.Pixel);
                    }
                }
                clips[c] = fr; strip.Dispose();
            }
        }
        public bool Ok { get { return clips.ContainsKey("fid00"); } }
        public Bitmap Current { get { Bitmap[] f = clips[clip]; return f[Math.Min(frame, f.Length - 1)]; } }
        public void SetTalk(bool t) { if (t == talk) return; talk = t; Start(t && clips.ContainsKey("tlk00") ? "tlk00" : "fid00"); }
        void Start(string c) { clip = clips.ContainsKey(c) ? c : "fid00"; frame = 0; }
        public void Tick()
        {
            if (++frame < clips[clip].Length) return;
            if (talk) Start("tlk00");
            else if (clip == "fid00" && rnd.Next(4) == 0) Start(rnd.Next(2) == 0 ? "fid01" : "fid02");
            else Start("fid00");
        }
    }

    class Btn
    {
        public Rectangle R; public string Text; public bool Enabled = true, Visible = true; public Action Click;
        public Btn(int x, int y, int w, int h, string text) { R = new Rectangle(x, y, w, h); Text = text; }
    }

    class LogLine { public int Level; public string Text; }

    class MainForm : Form
    {
        // design space = the DTA client main menu, 1280x720; the window is that scaled by S
        const int W = 1280, H = 720;
        static readonly Color Idle = Color.FromArgb(84, 176, 36), Hover = Color.FromArgb(84, 252, 84), Dim = Color.FromArgb(46, 92, 26);
        static readonly Color Amber = Color.FromArgb(232, 181, 74), Red = Color.FromArgb(235, 90, 80), Steel = Color.FromArgb(58, 74, 85), SteelHi = Color.FromArgb(111, 135, 148);
        static readonly Rectangle InfoBox = new Rectangle(36, 12, 272, 72), PathBox = new Rectangle(345, 338, 480, 30), LogBox = new Rectangle(345, 420, 594, 166);
        static readonly Rectangle Bar = new Rectangle(345, 596, 594, 14), PortL = new Rectangle(24, 392, 190, 204), PortR = new Rectangle(1066, 392, 190, 204);
        static readonly Rectangle AskBox = new Rectangle(372, 318, 540, 250);

        bool uninstallMode; Pkg pkg; string exePath, game = "", dtaVer = "", status1 = "", status2 = ""; Color status1Col, status2Col;
        InstallRecord rec;
        float S = 1f; Bitmap cache;
        Bitmap bg, btnImg, btnHov, lineh, scan; Bitmap[] noise;
        Font fTitle, fSub, fBtn, fText, fSmall, fLog, fName;
        List<Btn> main = new List<Btn>(), ask = new List<Btn>();
        Btn bInstall, bUninstall, bExit, bBrowse, aYes, aNo, hot, pressed;
        string askText; bool askOn; Action askYes, askNo;
        List<LogLine> logs = new List<LogLine>(); object lk = new object();
        double prog; bool busy, showBar, selfDelete;
        Portrait left; Portrait[] right; int rightIdx, staticLeft, tick;
        Random rnd = new Random();
        Dictionary<string, byte[]> wav = new Dictionary<string, byte[]>(); SoundPlayer player;
        System.Windows.Forms.Timer timer;

        public MainForm(string exePath, Pkg pkg, string gameArg, bool forShot)
        {
            this.exePath = exePath; this.pkg = pkg; uninstallMode = pkg == null;
            Text = "StarCraft mod — DTA"; FormBorderStyle = FormBorderStyle.None; StartPosition = FormStartPosition.CenterScreen;
            DoubleBuffered = true; BackColor = Color.Black; KeyPreview = true;
            try { using (Stream s = Res.Open("app.ico")) if (s != null) Icon = new Icon(s); } catch (Exception) { }

            bg = Res.Img("bg.png"); btnImg = Res.Img("btn.png"); btnHov = Res.Img("btn_c.png"); lineh = Res.Img("lineh.png");
            Bitmap ti = Res.Img("terran.png"), zi = Res.Img("zerg.png"), pi = Res.Img("protoss.png");
            fTitle = MkFont("Bahnschrift SemiBold", 40, FontStyle.Regular);
            fSub = MkFont("Bahnschrift", 16, FontStyle.Regular);
            fBtn = MkFont("Bahnschrift", 18, FontStyle.Regular);
            fText = MkFont("Bahnschrift", 15, FontStyle.Regular);
            fSmall = MkFont("Bahnschrift", 13, FontStyle.Regular);
            fName = MkFont("Bahnschrift SemiBold", 13, FontStyle.Regular);
            fLog = new Font("Consolas", 13, FontStyle.Regular, GraphicsUnit.Pixel);
            Size ps = PortL.Size;
            left = new Portrait("JIM RAYNOR", ti, "raynor", ps, rnd);
            right = new[] { new Portrait("SARAH KERRIGAN", zi, "kerrigan", ps, rnd), new Portrait("ZERATUL", pi, "zeratul", ps, rnd) };
            BuildFx();
            foreach (string w in new[] { "click", "hover", "transmission", "done", "error", "open" }) { byte[] b = Res.Bytes(w + ".wav"); if (b != null) wav[w] = b; }

            int by = 630;
            bInstall = new Btn(345, by, 190, 36, "ZAINSTALUJ"); bInstall.Click = OnInstall;
            bUninstall = new Btn(547, by, 190, 36, "ODINSTALUJ"); bUninstall.Click = OnUninstall;
            bExit = new Btn(749, by, 190, 36, "WYJŚCIE"); bExit.Click = Close;
            bBrowse = new Btn(833, 335, 106, 36, "ZMIEŃ"); bBrowse.Click = OnBrowse;
            main.AddRange(new[] { bInstall, bUninstall, bExit, bBrowse });
            aYes = new Btn(AskBox.X + 60, AskBox.Bottom - 54, 190, 36, "TAK"); aNo = new Btn(AskBox.Right - 250, AskBox.Bottom - 54, 190, 36, "NIE");
            aYes.Click = delegate { askOn = false; if (askYes != null) askYes(); };
            aNo.Click = delegate { askOn = false; if (askNo != null) askNo(); };
            ask.AddRange(new[] { aYes, aNo });
            if (uninstallMode)
            {
                bInstall.Visible = false; bBrowse.Visible = false;
                bUninstall.R.X = 446; bExit.R.X = 648;
            }

            game = FindGame(gameArg);
            LoadState(true);

            if (!forShot)
            {
                float dpi; using (Graphics g = CreateGraphics()) dpi = g.DpiX / 96f;
                Rectangle wa = Screen.FromPoint(Cursor.Position).WorkingArea;
                S = Math.Min(dpi, Math.Min((wa.Width - 24) / (float)W, (wa.Height - 24) / (float)H));
                ClientSize = new Size((int)(W * S), (int)(H * S));
                timer = new System.Windows.Forms.Timer { Interval = 100 };
                timer.Tick += delegate { OnTick(); };
                timer.Start();
                Shown += delegate { Play("open"); };
            }
        }

        static Font MkFont(string fam, float px, FontStyle st)
        {
            try { return new Font(new FontFamily(fam), px, st, GraphicsUnit.Pixel); }
            catch (ArgumentException) { return new Font(new FontFamily("Segoe UI"), px, st, GraphicsUnit.Pixel); }
        }

        void BuildFx()
        {
            Size s = PortL.Size;
            noise = new Bitmap[6];
            for (int k = 0; k < noise.Length; k++)
            {
                noise[k] = new Bitmap(s.Width, s.Height, PixelFormat.Format32bppArgb);
                BitmapData d = noise[k].LockBits(new Rectangle(Point.Empty, s), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                int[] px = new int[s.Width * s.Height];
                for (int i = 0; i < px.Length; i++) { int v = rnd.Next(30, 200); px[i] = unchecked((int)0xFF000000) | (v / 3 << 16) | (v << 8) | (v / 3); }
                Marshal.Copy(px, 0, d.Scan0, px.Length); noise[k].UnlockBits(d);
            }
            scan = new Bitmap(s.Width, s.Height, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(scan)) using (Pen p = new Pen(Color.FromArgb(55, 0, 0, 0)))
                for (int y = 0; y < s.Height; y += 2) g.DrawLine(p, 0, y, s.Width, y);
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

        void LoadState(bool initial)
        {
            bool ok = Dta.IsGameFolder(game);
            rec = null;
            try { if (ok) rec = Engine.LoadRecord(game); }
            catch (Exception ex) { AddLog(3, "install.json: " + ex.Message); }
            dtaVer = ok ? Dta.Version(game) : "";
            string want = pkg != null ? pkg.Manifest.dtaVersion : (rec != null ? rec.dtaVersion : "");
            if (!ok) { status1 = "Wskaż folder Dawn of the Tiberium Age (z game.exe)."; status1Col = Amber; }
            else if (dtaVer == want) { status1 = "Wykryto DTA " + dtaVer + (pkg != null ? " — zgodna z pakietem." : "."); status1Col = Idle; }
            else { status1 = "Wykryto DTA " + dtaVer + ", mod jest dla " + want + "."; status1Col = Amber; }
            // the modding workspace itself (git repo + capture state): the mods are already there, uninstall would delete them
            bool workspace = ok && rec == null && Directory.Exists(Path.Combine(game, ".git")) && File.Exists(Path.Combine(game, @"Modding\dta\state.json"));
            if (!ok) { status2 = ""; }
            else if (workspace) { status2 = "To folder roboczy moda (repo git): mod już tu jest, wskaż inną kopię DTA."; status2Col = Amber; }
            else if (rec == null) { status2 = uninstallMode ? "Mod nie jest zainstalowany w tym folderze." : "Mod nie jest jeszcze zainstalowany."; status2Col = uninstallMode ? Amber : Idle; }
            else { status2 = "Zainstalowany: wersja " + rec.version + " (" + rec.installed + ")."; status2Col = Hover; }

            bInstall.Text = rec == null ? "ZAINSTALUJ" : (pkg != null && rec.version == pkg.Manifest.version ? "NAPRAW" : "AKTUALIZUJ");
            bInstall.Enabled = ok && pkg != null && !busy && !workspace;
            bUninstall.Enabled = ok && rec != null && !busy;
            bBrowse.Enabled = !busy; bExit.Enabled = !busy;
            if (initial)
            {
                if (pkg != null)
                {
                    AddLog(0, string.Format("Pakiet {0}: {1} plików ({2:0} MB) dla DTA {3}.", pkg.Manifest.version, pkg.Manifest.files.Count, pkg.TotalBytes / 1048576.0, pkg.Manifest.dtaVersion));
                    AddLog(0, "Podmieniane pliki DTA trafią do SCMod\\backup; deinstalator je przywróci.");
                }
                else AddLog(0, "Deinstalator: przywraca oryginalne pliki DTA i usuwa pliki modu.");
                if (!ok) AddLog(2, "Nie znalazłem DTA. Kliknij ZMIEŃ i wskaż folder gry.");
            }
            Invalidate();
        }

        void AddLog(int level, string text) { lock (lk) { logs.Add(new LogLine { Level = level, Text = text }); if (logs.Count > 400) logs.RemoveAt(0); } }

        void Play(string name)
        {
            byte[] b;
            if (!wav.TryGetValue(name, out b)) return;
            try { player = new SoundPlayer(new MemoryStream(b)); player.Play(); } catch (Exception) { }
        }

        void Ask(string text, string yes, string no, Action onYes, Action onNo)
        {
            askText = text; aYes.Text = yes; aNo.Text = no ?? ""; aNo.Visible = no != null; askYes = onYes; askNo = onNo; askOn = true;
            aYes.R.X = no != null ? AskBox.X + 60 : AskBox.X + (AskBox.Width - aYes.R.Width) / 2;
            hot = null; Invalidate();
        }

        // ---- actions ----
        void OnBrowse()
        {
            using (FolderBrowserDialog d = new FolderBrowserDialog())
            {
                d.Description = "Folder z Dawn of the Tiberium Age (game.exe, DTA.exe)";
                if (Directory.Exists(game)) d.SelectedPath = game;
                if (d.ShowDialog(this) != DialogResult.OK) return;
                if (!Dta.IsGameFolder(d.SelectedPath)) { Play("error"); AddLog(2, "To nie jest folder DTA (brak game.exe albo pliku version): " + d.SelectedPath); return; }
                game = Path.GetFullPath(d.SelectedPath).TrimEnd('\\');
                AddLog(0, "Folder gry: " + game);
                LoadState(false);
            }
        }

        void OnInstall()
        {
            if (dtaVer != pkg.Manifest.dtaVersion)
                Ask(string.Format("Pakiet jest dla DTA {0}, a w folderze jest DTA {1}.\n\nPliki DTA zmieniane przez moda (Rules.ini, game.exe, Vinifera.dll…) zostaną zastąpione wersjami z pakietu. Mod zadziała, ale poprawki nowszej DTA w tych plikach znikną do deinstalacji.", pkg.Manifest.dtaVersion, dtaVer),
                    "INSTALUJ", "ANULUJ", delegate { Run(true); }, null);
            else Run(true);
        }

        void OnUninstall()
        {
            Ask("Odinstalować StarCraft mod z folderu\n" + game + "?\n\nOryginalne pliki DTA wrócą z kopii, pliki modu zostaną usunięte.",
                "ODINSTALUJ", "ANULUJ", delegate { Run(false); }, null);
        }

        void Run(bool install)
        {
            busy = true; showBar = true; prog = 0; LoadState(false);
            left.SetTalk(true); Play("transmission");
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
            busy = false; left.SetTalk(false); prog = code == 2 ? prog : 1;
            LoadState(false);
            Play(code == 2 ? "error" : "done");
            string warn = code == 1 ? "\n\nSą ostrzeżenia, zobacz log." : "";
            if (code == 2)
                Ask((install ? "Instalacja przerwana:\n" : "Deinstalacja przerwana:\n") + err + (install ? "\n\nTo, co już zapisano, jest w SCMod\\install.json: można spróbować ponownie albo odinstalować." : ""), "OK", null, null, null);
            else if (install)
                Ask("Mod zainstalowany." + warn + "\n\nSkirmish: strony Terran, Zerg, Protoss i opcja STARCRAFT.\nKampania ARKA: New Mission.\n\nDeinstalator: SCMod\\" + Engine.UninstallerName + "\nalbo Panel sterowania → Programy i funkcje.",
                    "URUCHOM DTA", "OK", delegate { StartDta(); Close(); }, null);
            else
            {
                selfDelete = uninstallMode && fromModDir;
                Ask("Mod odinstalowany. Oryginalne pliki DTA są z powrotem na miejscu." + warn, uninstallMode ? "ZAMKNIJ" : "OK", null,
                    uninstallMode ? (Action)Close : null, null);
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
        List<Btn> Active() { return askOn ? ask : main; }
        Btn HitTest(Point p)
        {
            Point d = new Point((int)(p.X / S), (int)(p.Y / S));
            foreach (Btn b in Active()) if (b.Visible && b.Enabled && b.R.Contains(d)) return b;
            return null;
        }
        protected override void OnMouseMove(MouseEventArgs e)
        {
            Btn b = HitTest(e.Location);
            if (b != hot) { hot = b; if (b != null) Play("hover"); Invalidate(); }
            Cursor = b != null ? Cursors.Hand : Cursors.Default;
        }
        protected override void OnMouseLeave(EventArgs e) { hot = null; Invalidate(); }
        [DllImport("user32.dll")] static extern bool ReleaseCapture();
        [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);
        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left) return;
            pressed = HitTest(e.Location);
            if (pressed == null) { ReleaseCapture(); SendMessage(Handle, 0xA1, (IntPtr)2, IntPtr.Zero); }   // drag the window by any free spot
        }
        protected override void OnMouseUp(MouseEventArgs e)
        {
            Btn b = HitTest(e.Location);
            if (b != null && b == pressed) { Play("click"); b.Click(); }
            pressed = null; Invalidate();
        }
        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Escape)
            {
                if (askOn && aNo.Visible) aNo.Click(); else if (askOn) aYes.Click(); else if (!busy) Close();
            }
            else if (e.KeyCode == Keys.Enter && askOn) aYes.Click();
        }

        void OnTick()
        {
            tick++;
            left.Tick();
            if (staticLeft > 0) { if (--staticLeft == 3) rightIdx = (rightIdx + 1) % right.Length; }
            else right[rightIdx].Tick();
            if (tick % 140 == 0 && !busy) { staticLeft = 7; Play("hover"); }
            Invalidate();
        }

        // ---- drawing ----
        protected override void OnPaint(PaintEventArgs e)
        {
            if (cache == null || cache.Width != ClientSize.Width) { if (cache != null) cache.Dispose(); cache = BuildCache(ClientSize.Width, ClientSize.Height); }
            e.Graphics.DrawImageUnscaled(cache, 0, 0);
            e.Graphics.ScaleTransform(S, S);
            DrawDynamic(e.Graphics);
        }

        static Graphics Prep(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            return g;
        }

        // everything that never changes, drawn once at the window size
        Bitmap BuildCache(int w, int h)
        {
            Bitmap b = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
            using (Graphics g = Prep(Graphics.FromImage(b)))
            {
                g.ScaleTransform(w / (float)W, h / (float)H);
                if (bg != null) g.DrawImage(bg, 0, 0, W, H); else g.Clear(Color.Black);
                // version box (the client's "Version: 16.2.3" corner)
                using (GraphicsPath p = Round(InfoBox, 6)) { g.FillPath(Brushes.Black, p); using (Pen pen = new Pen(Color.FromArgb(40, 60, 40))) g.DrawPath(pen, p); }
                // title
                string title = "STARCRAFT MOD";
                StringFormat c = new StringFormat { Alignment = StringAlignment.Center };
                using (GraphicsPath tp = new GraphicsPath())
                {
                    tp.AddString(title, fTitle.FontFamily, (int)fTitle.Style, fTitle.Size, new RectangleF(325, 238, 633, 50), c);
                    using (Pen glow = new Pen(Color.FromArgb(90, 20, 60, 10), 7) { LineJoin = LineJoin.Round }) g.DrawPath(glow, tp);
                    using (Pen edge = new Pen(Color.FromArgb(10, 30, 5), 3) { LineJoin = LineJoin.Round }) g.DrawPath(edge, tp);
                    using (LinearGradientBrush lg = new LinearGradientBrush(new Rectangle(0, 242, 10, 44), Color.FromArgb(190, 240, 70), Color.FromArgb(60, 150, 20), 90f)) g.FillPath(lg, tp);
                }
                using (SolidBrush sb = new SolidBrush(Idle))
                    g.DrawString("dla Dawn of the Tiberium Age  ·  kampania ARKA: Błąd znaku", fSub, sb, new RectangleF(325, 288, 633, 22), c);
                if (lineh != null) { g.DrawImage(lineh, 368, 314, 548, 2); g.DrawImage(lineh, 368, 411, 548, 2); }
                using (SolidBrush sb = new SolidBrush(Color.FromArgb(70, 140, 32))) g.DrawString("FOLDER GRY", fSmall, sb, 345, 320);
                Frame(g, PathBox, Color.FromArgb(220, 0, 0, 0));
                Frame(g, LogBox, Color.FromArgb(215, 0, 0, 0));
            }
            return b;
        }

        static GraphicsPath Round(Rectangle r, int rad)
        {
            GraphicsPath p = new GraphicsPath(); int d = rad * 2;
            p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure(); return p;
        }

        // dark box with a steel edge and green corner brackets (DTA green on a StarCraft console frame)
        static void Frame(Graphics g, Rectangle r, Color fill)
        {
            using (SolidBrush b = new SolidBrush(fill)) g.FillRectangle(b, r);
            using (Pen p = new Pen(Steel, 1)) g.DrawRectangle(p, r);
            using (Pen p = new Pen(Idle, 2))
            {
                int c = 10;
                g.DrawLines(p, new[] { new Point(r.Left, r.Top + c), new Point(r.Left, r.Top), new Point(r.Left + c, r.Top) });
                g.DrawLines(p, new[] { new Point(r.Right - c, r.Top), new Point(r.Right, r.Top), new Point(r.Right, r.Top + c) });
                g.DrawLines(p, new[] { new Point(r.Left, r.Bottom - c), new Point(r.Left, r.Bottom), new Point(r.Left + c, r.Bottom) });
                g.DrawLines(p, new[] { new Point(r.Right - c, r.Bottom), new Point(r.Right, r.Bottom), new Point(r.Right, r.Bottom - c) });
            }
        }

        void DrawDynamic(Graphics g)
        {
            Prep(g);
            StringFormat ell = new StringFormat(StringFormatFlags.NoWrap) { Trimming = StringTrimming.EllipsisPath };
            // version box
            using (SolidBrush sb = new SolidBrush(Idle))
            {
                string l1 = pkg != null ? "Wersja moda: " + pkg.Manifest.version : (rec != null ? "Wersja moda: " + rec.version : "Deinstalator SC Mod");
                string l2 = pkg != null ? "Pakiet dla DTA: " + pkg.Manifest.dtaVersion : "Tryb: deinstalacja";
                string l3 = pkg != null ? string.Format("Pliki: {0} ({1:0} MB)", pkg.Manifest.files.Count, pkg.TotalBytes / 1048576.0) : "Pliki w rejestrze: " + (rec != null ? rec.entries.Count.ToString() : "0");
                g.DrawString(l1, fSmall, sb, InfoBox.X + 10, InfoBox.Y + 9);
                g.DrawString(l2, fSmall, sb, InfoBox.X + 10, InfoBox.Y + 28);
                g.DrawString(l3, fSmall, sb, InfoBox.X + 10, InfoBox.Y + 47);
            }
            // folder + status
            using (SolidBrush sb = new SolidBrush(game.Length > 0 ? Hover : Dim))
                g.DrawString(game.Length > 0 ? game : "(nie wybrano)", fText, sb, new RectangleF(PathBox.X + 8, PathBox.Y + 6, PathBox.Width - 16, 20), ell);
            using (SolidBrush sb = new SolidBrush(status1Col)) g.DrawString(status1, fText, sb, 345, 372);
            using (SolidBrush sb = new SolidBrush(status2Col)) g.DrawString(status2, fText, sb, 345, 389);

            // portraits
            DrawPortrait(g, left, PortL, false);
            DrawPortrait(g, right[rightIdx], PortR, staticLeft > 0);

            // log: newest at the bottom
            List<LogLine> view; lock (lk) view = new List<LogLine>(logs);
            int lineH = 16, rows = (LogBox.Height - 12) / lineH, first = Math.Max(0, view.Count - rows);
            for (int i = first; i < view.Count; i++)
            {
                LogLine l = view[i];
                Color col = l.Level == 1 ? Hover : l.Level == 2 ? Amber : l.Level == 3 ? Red : Idle;
                string pre = l.Level == 1 ? "+ " : l.Level == 2 ? "! " : l.Level == 3 ? "X " : "> ";
                using (SolidBrush sb = new SolidBrush(col))
                    g.DrawString(pre + l.Text, fLog, sb, new RectangleF(LogBox.X + 8, LogBox.Y + 6 + (i - first) * lineH, LogBox.Width - 16, lineH), new StringFormat(StringFormatFlags.NoWrap) { Trimming = StringTrimming.EllipsisCharacter });
            }

            // progress: segmented bar
            if (showBar)
            {
                using (SolidBrush sb = new SolidBrush(Color.FromArgb(200, 0, 0, 0))) g.FillRectangle(sb, Bar);
                using (Pen p = new Pen(Steel)) g.DrawRectangle(p, Bar);
                int seg = 7, segs = (Bar.Width - 4) / seg, lit = (int)Math.Round(segs * Math.Max(0, Math.Min(1, prog)));
                for (int i = 0; i < segs; i++)
                {
                    Color c = i < lit ? (i == lit - 1 && busy && tick % 2 == 0 ? Hover : Idle) : Color.FromArgb(18, 34, 12);
                    using (SolidBrush sb = new SolidBrush(c)) g.FillRectangle(sb, Bar.X + 3 + i * seg, Bar.Y + 3, seg - 2, Bar.Height - 6);
                }
                using (SolidBrush sb = new SolidBrush(Idle))
                    g.DrawString(string.Format("{0:0}%", prog * 100), fSmall, sb, Bar.Right - 40, Bar.Y - 18);
            }

            foreach (Btn b in main) DrawButton(g, b, !askOn);

            if (askOn)
            {
                using (SolidBrush sb = new SolidBrush(Color.FromArgb(170, 0, 0, 0))) g.FillRectangle(sb, 325, 235, 633, 460);
                Frame(g, AskBox, Color.FromArgb(245, 4, 10, 4));
                using (SolidBrush sb = new SolidBrush(Hover))
                    g.DrawString(askText, fText, sb, new RectangleF(AskBox.X + 22, AskBox.Y + 20, AskBox.Width - 44, AskBox.Height - 84));
                foreach (Btn b in ask) DrawButton(g, b, true);
            }
        }

        void DrawButton(Graphics g, Btn b, bool live)
        {
            if (!b.Visible) return;
            bool h = live && b == hot && b.Enabled;
            Bitmap img = h && btnHov != null ? btnHov : btnImg;
            if (img != null) g.DrawImage(img, b.R); else using (SolidBrush sb = new SolidBrush(Color.FromArgb(40, 48, 56))) g.FillRectangle(sb, b.R);
            if (!b.Enabled) using (SolidBrush sb = new SolidBrush(Color.FromArgb(120, 0, 0, 0))) g.FillRectangle(sb, b.R);
            StringFormat c = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            using (SolidBrush sb = new SolidBrush(!b.Enabled ? Dim : h ? Hover : Idle)) g.DrawString(b.Text, fBtn, sb, b.R, c);
        }

        void DrawPortrait(Graphics g, Portrait p, Rectangle r, bool staticFx)
        {
            g.FillRectangle(Brushes.Black, r);
            if (staticFx || !p.Ok) g.DrawImage(noise[tick % noise.Length], r);
            else g.DrawImage(p.Current, r);
            g.DrawImage(scan, r);
            Frame(g, r, Color.Transparent);
            Rectangle plate = new Rectangle(r.X, r.Bottom + 6, r.Width, 24);
            Frame(g, plate, Color.FromArgb(230, 0, 0, 0));
            if (p.Icon != null) g.DrawImage(p.Icon, plate.X + 7, plate.Y + 5, 14, 14);
            StringFormat c = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            using (SolidBrush sb = new SolidBrush(staticFx ? Dim : Idle)) g.DrawString(staticFx ? "· · ·" : p.Name, fName, sb, plate, c);
        }

        // /shot: the window at 1280x720 in a given state, for checking the design without clicking through it
        public void Shot(string png, string state)
        {
            S = 1f;
            for (int i = 0; i < 4; i++) { left.Tick(); right[0].Tick(); }
            if (state == "busy" || state == "done")
            {
                busy = state == "busy"; showBar = true; prog = state == "busy" ? 0.62 : 1; LoadState(false);
                AddLog(0, "Instalacja StarCraft mod 2026.10.28 w C:\\Games\\Dawn of the Tiberium Age");
                AddLog(0, "40 / 322 plików"); AddLog(0, "80 / 322 plików");
                AddLog(2, "INI/Rules.ini: inna wersja niż w DTA 16.2.3 (kopia w SCMod\\backup), zastąpiona wersją moda.");
                AddLog(0, "120 / 322 plików"); AddLog(0, "160 / 322 plików"); AddLog(0, "200 / 322 plików");
                if (state == "done") { AddLog(1, "Zapisano 322 plików, 0 już było aktualnych. Deinstalator: SCMod\\Odinstaluj SC Mod.exe"); Done(true, 1, null, false); }
            }
            if (state == "ask") OnUninstall();
            if (state == "hover") hot = bInstall;
            using (Bitmap b = new Bitmap(W, H))
            using (Graphics g = Graphics.FromImage(b))
            {
                Bitmap c = BuildCache(W, H);
                g.DrawImageUnscaled(c, 0, 0); c.Dispose();
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
            Pkg pkg = null;
            try { pkg = Pkg.Open(exe); }
            catch (Exception ex) { MessageBox.Show("Uszkodzony pakiet instalatora: " + ex.Message, "StarCraft mod"); return 2; }

            if (args.Length >= 2 && (args[0] == "/install" || args[0] == "/uninstall"))
                return Silent(exe, pkg, args[0] == "/install", args[1]);

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            if (args.Length >= 2 && args[0] == "/shot")
            {
                using (MainForm f = new MainForm(exe, args.Length >= 4 && args[3] == "uninstall" ? null : pkg, null, true))
                    f.Shot(args[1], args.Length >= 3 ? args[2] : "idle");
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
