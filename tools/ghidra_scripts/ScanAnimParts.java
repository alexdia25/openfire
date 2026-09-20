// Finds animated parts in the 6-dword layout seen in explosion-style descriptors (document 49):
// [cel, flags (byte0 mode, byte1 frame count, byte2 timing), 4 corner indices]. Prints each hit with
// the cel range [cel, cel + frames). Heuristic scan of the data segment; see ScanDescriptors.java for
// the static 8-int layout.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.Memory;

public class ScanAnimParts extends GhidraScript {
    private long s32(Memory m, long a) throws Exception {
        return m.getInt(currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(a));
    }

    @Override
    protected void run() throws Exception {
        Memory mem = currentProgram.getMemory();
        for (long a = 0x43a000L; a < 0x45a000L; a += 4) {
            try {
                long cel = s32(mem, a);
                long fl = s32(mem, a + 4) & 0xFFFFFFFFL;
                long frames = (fl >> 8) & 0xFF;
                long timing = (fl >> 16) & 0xFF;
                if (cel < 0 || cel >= 2165 || (fl >> 24) != 0 || frames < 2 || frames > 64 || timing == 0) continue;
                long c0 = s32(mem, a + 8), c1 = s32(mem, a + 12), c2 = s32(mem, a + 16), c3 = s32(mem, a + 20);
                if (c0 < 0 || c0 > 60 || c1 != c0 + 1 || c2 != c1 + 1 || c3 != c2 + 1) continue;
                println("ANIM 0x" + Long.toHexString(a) + " cel=" + cel + " frames=" + frames + " timing=" + timing
                        + " mode=" + (fl & 0xFF) + " corners=" + c0 + ".." + c3);
            } catch (Exception e) {
            }
        }
        println("=== Done ===");
    }
}
