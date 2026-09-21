// Finds every `E8 rel32` (a near CALL) in initialised memory whose target is the given address, whether or not Ghidra
// disassembled that spot (analysis is off, so FindDispOps / FindCallers miss callers in undisassembled code). Prints the
// call site. Run: ... -postScript FindCallRel.java <hexTarget> [<hexTarget> ...]
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryBlock;

public class FindCallRel extends GhidraScript {
    @Override
    protected void run() throws Exception {
        Memory mem = currentProgram.getMemory();
        for (String a : getScriptArgs()) {
            long target = Long.parseLong(a.replace("0x", ""), 16);
            for (MemoryBlock b : mem.getBlocks()) {
                if (!b.isInitialized() || !b.isExecute()) continue;
                long start = b.getStart().getOffset(), end = b.getEnd().getOffset();
                for (long p = start; p + 5 <= end; p++) {
                    if ((mem.getByte(toAddr(p)) & 0xFF) != 0xE8) continue;
                    int rel = mem.getInt(toAddr(p + 1));
                    if (p + 5 + (long) rel == target) println(String.format("CALL %08x from %08x", target, p));
                }
            }
        }
    }
}
