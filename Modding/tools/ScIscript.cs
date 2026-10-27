// Finds which sounds StarCraft plays for a unit's attack: unit -> image iscript (attack anims, overlays, weapon bullets)
// -> playsnd / playsndrand / playsndbtwn / attackmelee -> sfxdata.dat -> sfxdata.tbl file name.
using System;
using System.Collections.Generic;
using System.Text;

public class ScIscript
{
    byte[] isc, img, spr, fli, wpn, unt, sfx; string[] sfxNames, imgNames;
    Dictionary<int, int> scriptOffset = new Dictionary<int, int>();
    public List<string> Log = new List<string>();

    static string[] Tbl(byte[] d)
    {
        int n = BitConverter.ToUInt16(d, 0); string[] s = new string[n + 1];
        for (int i = 0; i < n; i++)
        {
            int o = BitConverter.ToUInt16(d, 2 + i * 2); int e = o; while (e < d.Length && d[e] != 0) e++;
            s[i + 1] = Encoding.ASCII.GetString(d, o, e - o);
        }
        return s;
    }

    public ScIscript(byte[] iscript, byte[] images, byte[] imagesTbl, byte[] sprites, byte[] flingy, byte[] weapons, byte[] units, byte[] sfxdata, byte[] sfxTbl)
    {
        isc = iscript; img = images; spr = sprites; fli = flingy; wpn = weapons; unt = units; sfx = sfxdata;
        sfxNames = Tbl(sfxTbl); imgNames = Tbl(imagesTbl);
        int table = BitConverter.ToUInt16(isc, 0);
        for (int p = table; p + 4 <= isc.Length; p += 4)
        {
            int id = BitConverter.ToUInt16(isc, p); if (id == 0xFFFF) break;
            scriptOffset[id] = BitConverter.ToUInt16(isc, p + 2);
        }
    }

    int ImageIscript(int image) { return (int)BitConverter.ToUInt32(img, 9990 + image * 4); }
    public string ImageName(int image) { uint g = BitConverter.ToUInt32(img, image * 4); return g < imgNames.Length ? imgNames[g] : "?"; }
    int SpriteImage(int sprite) { return BitConverter.ToUInt16(spr, sprite * 2); }
    int FlingySprite(int flingy) { return BitConverter.ToUInt16(fli, flingy * 2); }
    int WeaponFlingy(int weapon) { return (int)BitConverter.ToUInt32(wpn, 260 + weapon * 4); }
    public int UnitFlingy(int unit) { return unt[unit]; }
    public int UnitSubunit(int unit) { return BitConverter.ToUInt16(unt, 228 + unit * 2); }
    public int UnitGroundWeapon(int unit) { return unt[5892 + unit]; }
    public int UnitAirWeapon(int unit) { return unt[6348 + unit]; }
    public int UnitImage(int unit) { return SpriteImage(FlingySprite(UnitFlingy(unit))); }
    public int WeaponImage(int weapon) { return SpriteImage(FlingySprite(WeaponFlingy(weapon))); }
    public string Sound(int id)
    {
        int n = sfx.Length / 9; if (id < 0 || id >= n) return "#" + id + "?";
        uint f = BitConverter.ToUInt32(sfx, id * 4); return f < sfxNames.Length ? sfxNames[f] : "#" + id;
    }

    static readonly int[] AnimCount = MakeAnimCount();
    static int[] MakeAnimCount()
    {
        int[] c = new int[32];
        int[,] t = { {0,2},{1,2},{2,4},{12,14},{13,14},{14,16},{15,16},{20,22},{21,22},{23,24},{24,26},{26,28},{27,28},{28,28},{29,28} };
        for (int i = 0; i < t.GetLength(0); i++) c[t[i, 0]] = t[i, 1];
        return c;
    }

    // Collects sounds reachable from the given animations of an image, recursing into overlay images and, when
    // `weapons` is given, into the bullet images of attackwith / useweapon.
    public void Scan(int image, int[] anims, int[] weapons, HashSet<string> outSounds, HashSet<int> seenImages, string path)
    {
        if (seenImages.Contains(image)) return; seenImages.Add(image);
        int sid = ImageIscript(image); int hdr;
        if (!scriptOffset.TryGetValue(sid, out hdr)) return;
        int type = isc[hdr + 4]; int count = AnimCount[type & 31];
        List<int> starts = new List<int>();
        for (int a = 0; a < count; a++)
        {
            if (anims != null && Array.IndexOf(anims, a) < 0) continue;
            int off = BitConverter.ToUInt16(isc, hdr + 8 + a * 2); if (off != 0) starts.Add(off);
        }
        Queue<int> q = new Queue<int>(starts); HashSet<int> seen = new HashSet<int>();
        string here = path + " > " + ImageName(image);
        while (q.Count > 0)
        {
            int p = q.Dequeue(); if (seen.Contains(p)) continue; seen.Add(p);
            bool stop = false; int guard = 0;
            while (!stop && p < isc.Length && guard++ < 400)
            {
                int op = isc[p++];
                switch (op)
                {
                    case 0x00: case 0x01: case 0x0A: case 0x0B: case 0x12: case 0x37: case 0x40: p += 2; break;
                    case 0x02: case 0x03: case 0x05: case 0x17: case 0x1F: case 0x20: case 0x22: case 0x23: case 0x24:
                    case 0x29: case 0x2B: case 0x2C: case 0x31: case 0x34: case 0x38: case 0x41: p += 1; break;
                    case 0x04: case 0x06: case 0x3D: p += 2; break;
                    case 0x07: q.Enqueue(BitConverter.ToUInt16(isc, p)); stop = true; break;
                    case 0x08: case 0x09: case 0x0D: case 0x0E:
                        { int im = BitConverter.ToUInt16(isc, p); p += 4; Scan(im, null, null, outSounds, seenImages, here); break; }
                    case 0x0F: case 0x10: case 0x11: case 0x13: case 0x14: case 0x42:
                        { int sp = BitConverter.ToUInt16(isc, p); p += 4; Scan(SpriteImage(sp), null, null, outSounds, seenImages, here); break; }
                    case 0x15: { int sp = BitConverter.ToUInt16(isc, p); p += 3; Scan(SpriteImage(sp), null, null, outSounds, seenImages, here); break; }
                    case 0x16: case 0x36: stop = true; break;
                    case 0x18: Add(outSounds, BitConverter.ToUInt16(isc, p), here, "playsnd"); p += 2; break;
                    case 0x19: case 0x1C:
                        { int n = isc[p++]; for (int k = 0; k < n; k++) { Add(outSounds, BitConverter.ToUInt16(isc, p), here, op == 0x1C ? "attackmelee" : "playsndrand"); p += 2; } break; }
                    case 0x1A:
                        { int a = BitConverter.ToUInt16(isc, p), b = BitConverter.ToUInt16(isc, p + 2); p += 4; for (int s = a; s <= b; s++) Add(outSounds, s, here, "playsndbtwn"); break; }
                    case 0x1E: p += 1; q.Enqueue(BitConverter.ToUInt16(isc, p)); p += 2; break;
                    case 0x25: case 0x28:
                        {
                            int which = isc[p++];
                            if (weapons != null) foreach (int w in weapons) if (w >= 0 && w < 130) Scan(WeaponImage(w), null, null, outSounds, seenImages, here + " [weapon " + w + "]");
                            break;
                        }
                    case 0x35: q.Enqueue(BitConverter.ToUInt16(isc, p)); p += 2; break;
                    case 0x39: case 0x3F: q.Enqueue(BitConverter.ToUInt16(isc, p)); p += 2; break;
                    case 0x3A: p += 2; q.Enqueue(BitConverter.ToUInt16(isc, p)); p += 2; break;
                    case 0x3B: case 0x3C: p += 4; q.Enqueue(BitConverter.ToUInt16(isc, p)); p += 2; break;
                    default: break; // no-argument opcodes
                }
            }
        }
    }

    // Frame numbers (playfram / playframtile) and sounds of one animation of an image, in order, following gotos once.
    public string Anim(int image, int anim)
    {
        int sid = ImageIscript(image); int hdr;
        if (!scriptOffset.TryGetValue(sid, out hdr)) return "(no iscript)";
        int type = isc[hdr + 4]; if (anim >= AnimCount[type & 31]) return "(no anim)";
        int p = BitConverter.ToUInt16(isc, hdr + 8 + anim * 2); if (p == 0) return "(none)";
        StringBuilder sb = new StringBuilder(); HashSet<int> visited = new HashSet<int>(); int guard = 0;
        while (guard++ < 300 && p < isc.Length)
        {
            if (visited.Contains(p)) { sb.Append(" [loop]"); break; } visited.Add(p);
            int op = isc[p++];
            switch (op)
            {
                case 0x00: case 0x01: sb.Append(" f" + BitConverter.ToUInt16(isc, p)); p += 2; break;
                case 0x07: { int t = BitConverter.ToUInt16(isc, p); p = t; sb.Append(" ->"); break; }
                case 0x16: sb.Append(" end"); return sb.ToString();
                case 0x05: sb.Append(" w" + isc[p]); p += 1; break;
                case 0x18: sb.Append(" snd:" + Sound(BitConverter.ToUInt16(isc, p))); p += 2; break;
                case 0x19: case 0x1C: { int n = isc[p++]; sb.Append(op == 0x1C ? " melee:" : " rand:"); for (int k = 0; k < n; k++) { sb.Append(Sound(BitConverter.ToUInt16(isc, p)) + (k < n - 1 ? "|" : "")); p += 2; } break; }
                case 0x1A: p += 4; break;
                case 0x25: case 0x28: sb.Append(" ATTACK"); p += 1; break;
                case 0x26: sb.Append(" ATTACK"); break;
                case 0x0A: case 0x0B: case 0x12: case 0x37: case 0x40: case 0x35: case 0x39: case 0x3F: p += 2; break;
                case 0x02: case 0x03: case 0x17: case 0x1F: case 0x20: case 0x22: case 0x23: case 0x24: case 0x29: case 0x2B: case 0x2C: case 0x31: case 0x34: case 0x38: case 0x41: p += 1; break;
                case 0x04: case 0x06: case 0x3D: p += 2; break;
                case 0x08: case 0x09: case 0x0D: case 0x0E: case 0x0F: case 0x10: case 0x11: case 0x13: case 0x14: case 0x42: p += 4; break;
                case 0x15: p += 3; break;
                case 0x1E: p += 3; break;
                case 0x3A: p += 4; break;
                case 0x3B: case 0x3C: p += 6; break;
                case 0x36: sb.Append(" return"); return sb.ToString();
                default: break;
            }
        }
        return sb.ToString();
    }

    void Add(HashSet<string> s, int id, string where, string how)
    {
        string name = Sound(id);
        if (s.Add(name)) Log.Add(how + " " + id + " " + name + "   (" + where + ")");
    }
}
