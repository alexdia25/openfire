// Walks the coastal-blend table (DAT_00447038, 0x38 bytes per entry, ids 1..91 -- see
// tools/rf_tile_art.py / tools/data/tile_lookup_tables.json, section 1.5) and, for every
// entry whose "valid" field (offset +0x00) is a nonzero pointer, follows it to the real
// decoration-object descriptor and dumps every part's ART.CAR cel index -- the mechanism
// document 35 (docs/process/) traced by hand for coastal id 1 alone. Confirmed chain, all
// offsets relative to the descriptor pointer ("valid"):
//   +0x34  int    part count
//   +0x38  int*   pointer to a part-count * 8-int array; each part is
//                    part[0] = ART.CAR cel index
//                    part[1] = flags (bit 3 selects a team-colour-offset variant, matching
//                              vehicle team-colour pairs, document 21)
//                    part[2..3] = corner-buffer indices used for a back-face-culling check
//                    part[4..7] = corner-buffer indices for this part's projected quad
// This only reads memory (no writes) and is safe to re-run any time.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class DumpCoastalDecorations extends GhidraScript {

    private static final long COASTAL_TABLE_BASE = 0x00447038L;
    private static final int COASTAL_ENTRY_STRIDE = 0x38;
    private static final int COASTAL_ID_MIN = 1;
    private static final int COASTAL_ID_MAX = 91;

    private static final int OFF_VALID = 0x00;
    private static final int OFF_PART_COUNT = 0x34;
    private static final int OFF_PARTS_PTR = 0x38;
    private static final int PART_STRIDE_INTS = 8;

    @Override
    protected void run() throws Exception {
        Memory mem = currentProgram.getMemory();

        for (int coastalId = COASTAL_ID_MIN; coastalId <= COASTAL_ID_MAX; coastalId++) {
          try {
            long entryAddr = COASTAL_TABLE_BASE + (long) coastalId * COASTAL_ENTRY_STRIDE;
            long validPtr = readU32(mem, entryAddr + OFF_VALID);
            if (validPtr == 0) {
                println("coastal_id=" + coastalId + " valid=0 (no decoration)");
                continue;
            }
            // A handful of entries carry a small nonzero "valid" value that is not a real
            // pointer into this program's address space at all (e.g. coastal_id 76 -> 0x1f4) --
            // guard against that rather than crashing the whole run on one bad entry.
            if (validPtr < 0x00400000L || validPtr > 0x00460000L) {
                println("coastal_id=" + coastalId + " valid=0x" + Long.toHexString(validPtr)
                        + "  (not a plausible pointer -- skipped)");
                continue;
            }

            long partCount = readS32(mem, validPtr + OFF_PART_COUNT);
            long partsPtr = readU32(mem, validPtr + OFF_PARTS_PTR);
            if (partCount <= 0 || partCount > 32 || partsPtr == 0) {
                println("coastal_id=" + coastalId + " valid=0x" + Long.toHexString(validPtr)
                        + " part_count=" + partCount + " partsPtr=0x" + Long.toHexString(partsPtr)
                        + "  (out of expected range -- likely takes the other code path, "
                        + "single-flags-array branch, not walked by this script)");
                continue;
            }

            StringBuilder parts = new StringBuilder();
            for (int i = 0; i < partCount; i++) {
                long partAddr = partsPtr + (long) i * PART_STRIDE_INTS * 4;
                long celIndex = readS32(mem, partAddr + 0);
                long flags = readU32(mem, partAddr + 4);
                if (i > 0) {
                    parts.append(", ");
                }
                parts.append("cel=").append(celIndex).append(" flags=0x")
                        .append(Long.toHexString(flags));
            }
            println("coastal_id=" + coastalId + " parts=" + partCount + " [" + parts + "]");
          } catch (Exception e) {
              println("coastal_id=" + coastalId + "  EXCEPTION: " + e.getMessage()
                      + "  (skipped -- see this script's own bounds checks above for why this "
                      + "shouldn't normally happen; investigate rather than trust downstream ids "
                      + "if this fires often)");
          }
        }
    }

    private long readU32(Memory mem, long addr) throws Exception {
        Address a = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(addr);
        return mem.getInt(a) & 0xFFFFFFFFL;
    }

    private long readS32(Memory mem, long addr) throws Exception {
        Address a = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(addr);
        return mem.getInt(a);
    }
}
