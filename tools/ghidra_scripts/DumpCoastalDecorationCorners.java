// Extends DumpCoastalDecorations.java: same coastal-table walk, but for every part also resolves
// its 4 corner indices (part[4..7]) through the descriptor's own corner array (+0x2c count,
// +0x30 pointer, 16.16 fixed-point x/y/z -- the identical layout DumpVehicleTypeParts.java
// confirmed for vehicle descriptors), giving each decoration part's REAL local-space quad
// (document 35 left this undecoded). Read-only; safe to re-run.
// Output: one machine-parseable line per part.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class DumpCoastalDecorationCorners extends GhidraScript {

    private static final long COASTAL_TABLE_BASE = 0x00447038L;
    private static final int COASTAL_ENTRY_STRIDE = 0x38;

    @Override
    protected void run() throws Exception {
        Memory mem = currentProgram.getMemory();
        for (int id = 1; id <= 91; id++) {
            try {
                long valid0 = readU32(mem, COASTAL_TABLE_BASE + (long) id * COASTAL_ENTRY_STRIDE);
                if (valid0 < 0x00400000L || valid0 > 0x00460000L) {
                    continue;
                }
                // FUN_0041afb0 (document 35) reads *(desc + 4) as a "next" link: one descriptor
                // can chain into several sub-objects. Follow it (bounded) and dump each link.
                long valid = valid0;
                for (int link = 0; link < 8; link++) {
                long cornerCount = readS32(mem, valid + 0x2c);
                long cornerPtr = readU32(mem, valid + 0x30);
                long partCount = readS32(mem, valid + 0x34);
                long partsPtr = readU32(mem, valid + 0x38);
                // FUN_0041b2b0: part count <= 0 means "draw the parts named by angle-bucket list
                // #(entry.+0x1c bits -> 0 for decorations)" instead of walking every part -- the
                // list at *(desc + 0x3c) is a 0xFF-terminated run of part indices (no culling).
                java.util.ArrayList<Integer> order = new java.util.ArrayList<>();
                boolean bucketMode = partCount <= 0;
                if (bucketMode && partsPtr != 0) {
                    long bucketPtr = readU32(mem, valid + 0x3c);
                    if (bucketPtr >= 0x00400000L && bucketPtr <= 0x00500000L) {
                        for (int i = 0; i < 64; i++) {
                            int v = mem.getByte(addr(bucketPtr + i));
                            if (v < 0) break;
                            order.add(v);
                        }
                    }
                    partCount = order.size();
                }
                if (partCount <= 0 || partCount > 64 || partsPtr == 0 || cornerCount <= 0
                        || cornerCount > 256 || cornerPtr == 0) {
                    println("# coastal_id=" + id + " link=" + link + " skipped: corner_count="
                            + cornerCount + " part_count=" + partCount);
                    break;
                }
                println("# coastal_id=" + id + " link=" + link + " desc=0x" + Long.toHexString(valid)
                        + " corner_count=" + cornerCount + " parts=" + partCount + " bucket=" + bucketMode
                        + " local_x14=" + readS32(mem, valid + 0x14)
                        + " local_x18=" + readS32(mem, valid + 0x18)
                        + " local_z1c=" + readS32(mem, valid + 0x1c)
                        + " flags10=0x" + Long.toHexString(mem.getByte(addr(valid + 0x10)) & 0xFF)
                        + " cb24=0x" + Long.toHexString(readU32(mem, valid + 0x24))
                        + " cb28=0x" + Long.toHexString(readU32(mem, valid + 0x28)));
                for (int p = 0; p < partCount; p++) {
                    long pa = partsPtr + (long) (bucketMode ? order.get(p) : p) * 32;
                    long cel = readS32(mem, pa);
                    long flags = readU32(mem, pa + 4);
                    StringBuilder idx = new StringBuilder();
                    StringBuilder corners = new StringBuilder();
                    boolean ok = true;
                    for (int c = 0; c < 4; c++) {
                        long ci = readS32(mem, pa + (4 + c) * 4);
                        if (ci < 0 || ci >= cornerCount) {
                            ok = false;
                            break;
                        }
                        long ca = cornerPtr + ci * 12;
                        if (c > 0) {
                            idx.append(",");
                            corners.append(";");
                        }
                        idx.append(ci);
                        corners.append(readS32(mem, ca)).append(",")
                               .append(readS32(mem, ca + 4)).append(",")
                               .append(readS32(mem, ca + 8));
                    }
                    if (!ok) {
                        println("part coastal_id=" + id + " link=" + link + " part_idx=" + p + " cel=" + cel
                                + " BAD_CORNER_INDEX");
                        continue;
                    }
                    println("part coastal_id=" + id + " link=" + link + " part_idx=" + p + " cel=" + cel
                            + " flags=0x" + Long.toHexString(flags) + " corner_idx=" + idx
                            + " corners_fixed16_16=" + corners);
                }
                    long next = readU32(mem, valid + 4);
                    if (next < 0x00400000L || next > 0x00460000L || next == valid) {
                        break;
                    }
                    valid = next;
                }
            } catch (Exception e) {
                println("# coastal_id=" + id + " EXCEPTION: " + e.getMessage());
            }
        }
    }

    private Address addr(long a) {
        return currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(a);
    }

    private long readU32(Memory mem, long a) throws Exception {
        return mem.getInt(addr(a)) & 0xFFFFFFFFL;
    }

    private long readS32(Memory mem, long a) throws Exception {
        return mem.getInt(addr(a));
    }
}
