import pefile, struct, sys
pe = pefile.PE(r'C:\Users\Alex\Documents\returnfire\RFIRE.BIN')
for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
    if t.id == 2:
        for b in t.directory.entries:
            if b.id in (0x7d9, 0x7da):
                for l in b.directory.entries:
                    d = l.data.struct
                    data = pe.get_data(d.OffsetToData, d.Size)
                    hs, w, h, planes, bpp = struct.unpack('<IiiHH', data[:16])
                    print(hex(b.id), w, h, bpp, len(data))
                    # dump pixels as ascii (assume 4bpp or 8bpp)
                    ncol = struct.unpack('<I', data[32:36])[0] or (1 << bpp)
                    pal = data[hs:hs + ncol * 4]
                    off = hs + ncol * 4
                    stride = ((w * bpp + 31) // 32) * 4
                    for y in range(h - 1, -1, -1):
                        row = data[off + y * stride: off + (y + 1) * stride]
                        s = ''
                        for x in range(w):
                            if bpp == 4: v = (row[x // 2] >> (4 if x % 2 == 0 else 0)) & 15
                            elif bpp == 1: v = (row[x // 8] >> (7 - x % 8)) & 1
                            else: v = row[x]
                            bgr = pal[v * 4:v * 4 + 3]
                            s += '#' if sum(bgr) < 300 else ('.' if sum(bgr) > 700 else '+')
                        print(s)
