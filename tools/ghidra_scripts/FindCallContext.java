// Like FindCallRel.java, but also prints the 24 bytes before each call (hex), so the pushed arguments can be read without
// disassembling: `6A 06` is PUSH 6, `68 xx xx xx xx` PUSH imm32. Used to find which call sites send a given command number to
// the sound/command queue FUN_004232d0 (document 113). Run: ... -postScript FindCallContext.java <hexTarget>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryBlock;

public class FindCallContext extends GhidraScript {
    @Override
    protected void run() throws Exception {
        Memory mem = currentProgram.getMemory();
        long target = Long.parseLong(getScriptArgs()[0].replace("0x", ""), 16);
        for (MemoryBlock b : mem.getBlocks()) {
            if (!b.isInitialized() || !b.isExecute()) continue;
            long start = b.getStart().getOffset(), end = b.getEnd().getOffset();
            for (long p = start + 24; p + 5 <= end; p++) {
                if ((mem.getByte(toAddr(p)) & 0xFF) != 0xE8) continue;
                int rel = mem.getInt(toAddr(p + 1));
                if (p + 5 + (long) rel != target) continue;
                StringBuilder sb = new StringBuilder();
                for (long q = p - 24; q < p; q++) sb.append(String.format("%02x ", mem.getByte(toAddr(q)) & 0xFF));
                println(String.format("CALL from %08x  [%s]", p, sb.toString().trim()));
            }
        }
    }
}
