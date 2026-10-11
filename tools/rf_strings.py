import pefile, sys
pe = pefile.PE(r'C:\Users\Alex\Documents\returnfire\RFIRE.BIN')
out = {}
for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
    if t.id == 6:  # RT_STRING
        for b in t.directory.entries:
            for l in b.directory.entries:
                d = l.data.struct
                data = pe.get_data(d.OffsetToData, d.Size)
                p = 0
                for i in range(16):
                    n = int.from_bytes(data[p:p+2], 'little'); p += 2
                    s = data[p:p+2*n].decode('utf-16le', 'replace'); p += 2*n
                    if n: out[(b.id - 1) * 16 + i] = s
for a in sys.argv[1:]:
    k = int(a, 0)
    print(hex(k), repr(out.get(k)))
if not sys.argv[1:]:
    for k in sorted(out): print(hex(k), repr(out[k]))
