// Like FindBytes.java but for many 32-bit values at once: scans all initialised memory once and prints,
// for each value, every address holding it as a little-endian dword, plus the function containing that
// address when it is code (an immediate operand) -- so callers that pass a record's address and data
// tables that store it are both found. Used by document 50 to find who references each explosion record.
//
// Run: ... -postScript FindPointerRefsMulti.java <hexValue> [<hexValue> ...]
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryBlock;

import java.util.HashMap;
import java.util.Map;

public class FindPointerRefsMulti extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        Map<Long, String> want = new HashMap<>();
        for (String a : args) {
            want.put(Long.parseLong(a, 16), a);
        }
        Memory mem = currentProgram.getMemory();
        for (MemoryBlock b : mem.getBlocks()) {
            if (!b.isInitialized()) continue;
            long start = b.getStart().getOffset();
            long len = b.getSize();
            byte[] buf = new byte[(int) len];
            b.getBytes(b.getStart(), buf);
            for (int i = 0; i + 4 <= len; i++) {
                long v = (buf[i] & 0xFFL) | ((buf[i + 1] & 0xFFL) << 8) | ((buf[i + 2] & 0xFFL) << 16)
                        | ((buf[i + 3] & 0xFFL) << 24);
                String key = want.get(v);
                if (key == null) continue;
                Address at = b.getStart().add(i);
                Function f = getFunctionContaining(at);
                println("REF " + key + " @ " + at + (f == null ? "" : " in " + f.getName() + " @ " + f.getEntryPoint()));
            }
        }
        println("=== Done ===");
    }
}
