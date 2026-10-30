"""vdis.py <pe> <va hex> <len hex>  -- disassemble a PE (x86) at a VA, via the section table.
   vdis.py <pe> find <hex bytes with ?? wildcards>  -- list VAs of a byte pattern in executable sections."""
import struct, sys
from capstone import Cs, CS_ARCH_X86, CS_MODE_32

def load(path):
    b = open(path, 'rb').read()
    pe = struct.unpack_from('<I', b, 0x3C)[0]
    nsec = struct.unpack_from('<H', b, pe + 6)[0]
    optsz = struct.unpack_from('<H', b, pe + 20)[0]
    base = struct.unpack_from('<I', b, pe + 24 + 28)[0]
    st = pe + 24 + optsz
    secs = []
    for i in range(nsec):
        e = st + 40 * i
        name = b[e:e + 8].rstrip(b'\0').decode()
        vs, va, rs, raw, _, _, _, _, ch = struct.unpack_from('<IIIIIIHHI', b, e + 8)
        secs.append((name, base + va, vs, raw, rs, ch))
    return b, base, secs

def off(secs, va):
    for n, sva, vs, raw, rs, ch in secs:
        if sva <= va < sva + max(vs, rs):
            return raw + va - sva
    raise ValueError(hex(va))

b, base, secs = load(sys.argv[1])
if sys.argv[2] == 'find':
    pat = sys.argv[3].split()
    for n, sva, vs, raw, rs, ch in secs:
        if not ch & 0x20000000:
            continue
        data = b[raw:raw + rs]
        first = [i for i, p in enumerate(pat) if p != '??']
        f0 = first[0]
        bf = int(pat[f0], 16)
        start = 0
        while True:
            i = data.find(bytes([bf]), start)
            if i < 0:
                break
            s = i - f0
            if s >= 0 and s + len(pat) <= len(data) and all(p == '??' or data[s + k] == int(p, 16) for k, p in enumerate(pat)):
                print(hex(sva + s))
            start = i + 1
else:
    va = int(sys.argv[2], 16); ln = int(sys.argv[3], 16)
    o = off(secs, va)
    md = Cs(CS_ARCH_X86, CS_MODE_32)
    for ins in md.disasm(b[o:o + ln], va):
        print('%08X  %-24s %s %s' % (ins.address, ins.bytes.hex(' '), ins.mnemonic, ins.op_str))
