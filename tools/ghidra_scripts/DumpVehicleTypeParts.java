// Generalizes the by-hand trace document 37 did for the Tank (vehicle-type-table entry 0)
// to all 4 entries in that table -- and finds that document 37's own "8 real parts, not 6"
// addendum was *itself* still an undercount. +0x2c is NOT a part count at all (that
// assumption, and the angle-bucket-max-index heuristic used to patch it, both undercounted
// the Tank): re-checking against real memory, +0x2c is the CORNER array's own length (it's
// exactly 24 for the Tank, and every part's 4 corner indices resolve inside [0, 24) with no
// exceptions up to the real boundary). The angle-bucket draw-order lists only ever reference
// indices 0-5 for the Tank -- they are NOT a complete part manifest, only the draw order for
// the six "primary" hull faces; several more parts exist that are drawn unconditionally,
// outside any angle bucket, and were invisible to both this document's main-text method and
// its addendum.
//
// This version finds the real boundary the only reliable way: walk part index 0, 1, 2, ...
// and stop at the first entry whose cel index or corner indices fall outside plausible
// bounds -- exactly the same "garbage right after the real data" signal that first exposed
// document 37's own miscount (a Tank part 14 with cel=-491520 and corner indices in the
// millions, right after 14 consecutive perfectly plausible entries 0-13).
//
// Confirmed layout (document 37, this session):
//   vehicle-type table: 4 entries, 0x2e8 (744) bytes apart, at
//     0x004456b8 (Tank), 0x004459a0, 0x00445c88, 0x00445f70
//   each entry:
//     +0x04  char*  name string pointer
//     +0x148 void*  render descriptor pointer
//   each render descriptor:
//     +0x2c  int    corner array length (NOT a part count -- see above)
//     +0x30  int*   corner array pointer (each corner: 3 x int32, 16.16 fixed point)
//     +0x38  int*   parts array pointer (each part: 8 x int32 --
//                      [0]=cel index, [1]=flags, [2..3]=unused/culling, [4..7]=corner indices)
//     +0x3c..+0x58  8 x (byte*) angle-bucket pointers, each a list of part indices terminated
//                   by 0xFF -- draw ORDER for a subset of parts only, per viewing-angle bucket;
//                   not a complete part manifest (see above)
//
// Output is one line per part, machine-parseable (space-separated key=value), for
// tools/registry/audit_code_referenced_cels.py to ingest.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class DumpVehicleTypeParts extends GhidraScript {

    private static final long[] TYPE_ENTRY_ADDRS = {
        0x004456b8L, 0x004459a0L, 0x00445c88L, 0x00445f70L
    };

    private static final int OFF_NAME_PTR = 0x04;
    private static final int OFF_DESC_PTR = 0x148;

    private static final int OFF_CORNER_COUNT = 0x2c;
    private static final int OFF_CORNER_PTR = 0x30;
    private static final int OFF_PARTS_PTR = 0x38;
    private static final int OFF_ANGLE_BUCKETS = 0x3c;
    private static final int NUM_ANGLE_BUCKETS = 8;
    private static final int PART_STRIDE_INTS = 8;
    private static final int MAX_CEL_INDEX = 4000; // generous upper bound; real atlas has 2165
    private static final int HARD_PART_CAP = 128; // safety stop, never expected to be reached

    // Loose "is this a plausible pointer into this program's loaded image" guard -- same
    // purpose as DumpCoastalDecorations.java's identical check: some fields that look like
    // pointers in this data-driven format aren't, for entries this script doesn't yet
    // understand, and a bad dereference should be skipped-and-reported, not a fatal crash
    // that loses every entry after it.
    private boolean plausiblePtr(long p) {
        return p >= 0x00400000L && p <= 0x00500000L;
    }

    @Override
    protected void run() throws Exception {
        Memory mem = currentProgram.getMemory();

        for (int typeIdx = 0; typeIdx < TYPE_ENTRY_ADDRS.length; typeIdx++) {
          try {
            long entryAddr = TYPE_ENTRY_ADDRS[typeIdx];
            long namePtr = readU32(mem, entryAddr + OFF_NAME_PTR);
            String name = plausiblePtr(namePtr) ? readCString(mem, namePtr) : "<bad name ptr>";
            long descPtr = readU32(mem, entryAddr + OFF_DESC_PTR);
            if (!plausiblePtr(descPtr)) {
                println("# type_idx=" + typeIdx + " name=\"" + name + "\" desc=0x"
                        + Long.toHexString(descPtr) + "  NOT A PLAUSIBLE POINTER -- skipped");
                continue;
            }

            long cornerCount = readS32(mem, descPtr + OFF_CORNER_COUNT);
            long cornerPtr = readU32(mem, descPtr + OFF_CORNER_PTR);
            long partsPtr = readU32(mem, descPtr + OFF_PARTS_PTR);

            println("# type_idx=" + typeIdx + " name=\"" + name + "\" desc=0x"
                    + Long.toHexString(descPtr) + " corner_count=" + cornerCount
                    + " corner_ptr=0x" + Long.toHexString(cornerPtr)
                    + " parts_ptr=0x" + Long.toHexString(partsPtr));

            if (!plausiblePtr(cornerPtr) || !plausiblePtr(partsPtr) || cornerCount <= 0
                    || cornerCount > 256) {
                println("#   SKIPPED -- corner_ptr/parts_ptr/corner_count not plausible (this "
                        + "type likely uses a different descriptor layout than the Tank's -- "
                        + "needs its own trace, not assumed to match)");
                continue;
            }

            // Angle-bucket draw-order lists, printed for reference only -- document 37's
            // addendum treated the highest index referenced here as the true part count, which
            // this run's own boundary-detection below proves still undercounts the Tank (the
            // buckets only ever reference indices 0-5, but 8 more real parts exist beyond that,
            // drawn unconditionally rather than depth-sorted). Kept in the output because the
            // draw ORDER is still real and useful, just not a manifest.
            for (int b = 0; b < NUM_ANGLE_BUCKETS; b++) {
                long bucketPtr = readU32(mem, descPtr + OFF_ANGLE_BUCKETS + b * 4);
                if (!plausiblePtr(bucketPtr)) {
                    println("#   angle_bucket=" + b + " ptr=0x" + Long.toHexString(bucketPtr)
                            + "  not plausible -- skipped");
                    continue;
                }
                StringBuilder order = new StringBuilder();
                for (int i = 0; i < 64; i++) {
                    int val = mem.getByte(addr(bucketPtr + i)) & 0xFF;
                    if (val == 0xFF) {
                        break;
                    }
                    if (i > 0) order.append(",");
                    order.append(val);
                }
                println("#   angle_bucket=" + b + " order=[" + order + "]");
            }

            // Real boundary detection: walk parts from index 0 until one falls outside
            // plausible bounds (cel index out of the atlas's real range, or any corner index
            // outside [0, corner_count) -- corner_count itself is real and reliable, confirmed
            // by every valid part's corner indices resolving inside it with zero exceptions).
            // This is the same "garbage right after the real data" signal that first exposed
            // the miscount, applied systematically instead of eyeballed once.
            int realPartCount = 0;
            for (int p = 0; p < HARD_PART_CAP; p++) {
                long partAddr = partsPtr + (long) p * PART_STRIDE_INTS * 4;
                long cel = readS32(mem, partAddr + 0);
                boolean ok = cel >= 0 && cel < MAX_CEL_INDEX;
                if (ok) {
                    for (int c = 0; c < 4 && ok; c++) {
                        long ci = readS32(mem, partAddr + (4 + c) * 4);
                        if (ci < 0 || ci >= cornerCount) {
                            ok = false;
                        }
                    }
                }
                if (!ok) {
                    break;
                }
                realPartCount = p + 1;
            }
            println("#   real_part_count=" + realPartCount + " (boundary-detected, not the "
                    + "descriptor's own corner_count field and not an angle-bucket max-index "
                    + "guess)");

            for (int p = 0; p < realPartCount; p++) {
              try {
                long partAddr = partsPtr + (long) p * PART_STRIDE_INTS * 4;
                long cel = readS32(mem, partAddr + 0);
                long flags = readU32(mem, partAddr + 4);
                long[] cornerIdx = new long[4];
                StringBuilder cornersOut = new StringBuilder();
                for (int c = 0; c < 4; c++) {
                    cornerIdx[c] = readS32(mem, partAddr + (4 + c) * 4);
                    long cAddr = cornerPtr + cornerIdx[c] * 3 * 4;
                    long cx = readS32(mem, cAddr + 0);
                    long cy = readS32(mem, cAddr + 4);
                    long cz = readS32(mem, cAddr + 8);
                    if (c > 0) cornersOut.append(";");
                    cornersOut.append(cx).append(",").append(cy).append(",").append(cz);
                }
                println("part type_idx=" + typeIdx + " name=" + name + " part_idx=" + p
                        + " cel=" + cel + " flags=0x" + Long.toHexString(flags)
                        + " corner_idx=" + cornerIdx[0] + "," + cornerIdx[1] + "," + cornerIdx[2]
                        + "," + cornerIdx[3] + " corners_fixed16_16=" + cornersOut);
              } catch (Exception pe) {
                  println("part type_idx=" + typeIdx + " part_idx=" + p + " EXCEPTION: "
                          + pe.getMessage());
              }
            }
          } catch (Exception e) {
              println("# type_idx=" + typeIdx + "  EXCEPTION: " + e.getMessage());
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

    private String readCString(Memory mem, long a) throws Exception {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 64; i++) {
            byte b = mem.getByte(addr(a + i));
            if (b == 0) break;
            sb.append((char) b);
        }
        return sb.toString();
    }
}
