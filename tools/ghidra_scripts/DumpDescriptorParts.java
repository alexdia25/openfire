// Generic version of DumpVehicleTypeParts.java's extraction logic, for any single render
// descriptor address in the confirmed format (document 37/38/39), not just the 4 entries in
// the vehicle-type table. Needed to dump the Tank's real, SEPARATE turret descriptor
// (0x0043e9b8) found by decompiling FUN_00402dc0, the real vehicle draw dispatcher: it draws
// the hull once with the vehicle's own per-type descriptor, then -- if a linked turret
// sub-object exists -- swaps in this completely different descriptor and draws again with an
// independently composed rotation (hull heading + turret aim angle). This is the real
// mechanism for a rotating turret/barrel, confirmed to be a wholly separate object from the
// hull's own 14-part record (which document 38's footprint map already proved never extends
// past the hull's own bounding box).
//
// Same offsets, same boundary-detection philosophy as DumpVehicleTypeParts.java:
//   +0x2c  int    corner array length (NOT a part count)
//   +0x30  int*   corner array pointer (each corner: 3 x int32, 16.16 fixed point)
//   +0x38  int*   parts array pointer (each part: 8 x int32 --
//                    [0]=cel index, [1]=flags, [2..3]=unused/culling, [4..7]=corner indices)
//   +0x3c..+0x58  8 x (byte*) angle-bucket pointers (draw ORDER only, not a part manifest)
//
// Real part count found by walking part index 0, 1, 2, ... and stopping at the first entry
// whose cel/corner indices go implausible -- the only reliable method, confirmed twice now
// (document 38) to catch parts the angle-bucket-derived or descriptor-field-derived counts
// both missed.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript DumpDescriptorParts.java <hexDescAddr>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class DumpDescriptorParts extends GhidraScript {

    private static final int OFF_CORNER_COUNT = 0x2c;
    private static final int OFF_CORNER_PTR = 0x30;
    private static final int OFF_PARTS_PTR = 0x38;
    private static final int OFF_ANGLE_BUCKETS = 0x3c;
    private static final int NUM_ANGLE_BUCKETS = 8;
    private static final int PART_STRIDE_INTS = 8;
    private static final int MAX_CEL_INDEX = 4000;
    private static final int HARD_PART_CAP = 128;

    private boolean plausiblePtr(long p) {
        return p >= 0x00400000L && p <= 0x00500000L;
    }

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: DumpDescriptorParts.java <hexDescAddr>");
            return;
        }
        long descPtr = Long.parseLong(args[0], 16);
        Memory mem = currentProgram.getMemory();

        long cornerCount = readS32(mem, descPtr + OFF_CORNER_COUNT);
        long cornerPtr = readU32(mem, descPtr + OFF_CORNER_PTR);
        long partsPtr = readU32(mem, descPtr + OFF_PARTS_PTR);

        println("# desc=0x" + Long.toHexString(descPtr) + " corner_count=" + cornerCount
                + " corner_ptr=0x" + Long.toHexString(cornerPtr)
                + " parts_ptr=0x" + Long.toHexString(partsPtr));

        if (!plausiblePtr(cornerPtr) || !plausiblePtr(partsPtr) || cornerCount <= 0
                || cornerCount > 256) {
            println("#   ABORT -- corner_ptr/parts_ptr/corner_count not plausible");
            return;
        }

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
        println("#   real_part_count=" + realPartCount + " (boundary-detected)");

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
            println("part part_idx=" + p + " cel=" + cel + " flags=0x" + Long.toHexString(flags)
                    + " corner_idx=" + cornerIdx[0] + "," + cornerIdx[1] + "," + cornerIdx[2]
                    + "," + cornerIdx[3] + " corners_fixed16_16=" + cornersOut);
          } catch (Exception pe) {
              println("part part_idx=" + p + " EXCEPTION: " + pe.getMessage());
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
