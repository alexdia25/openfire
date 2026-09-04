// Reads `count` 4-byte little-endian pointers starting at `addr`, and for each
// distinct non-zero one that lands on a known function, decompiles it. Useful
// for jump/dispatch tables where Ghidra hasn't already turned the pointers
// into references.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript DumpFunctionTable.java <hexAddr> <count>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.mem.Memory;
import ghidra.util.task.ConsoleTaskMonitor;

import java.util.LinkedHashSet;
import java.util.Set;

public class DumpFunctionTable extends GhidraScript {

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 2) {
            println("usage: DumpFunctionTable.java <hexAddr> <count>");
            return;
        }
        Address base = currentProgram.getAddressFactory().getAddress(args[0]);
        int count = Integer.parseInt(args[1]);
        Memory mem = currentProgram.getMemory();

        Set<Long> seen = new LinkedHashSet<>();
        println("Index -> pointer value (raw table dump):");
        for (int i = 0; i < count; i++) {
            Address slot = base.add((long) i * 4);
            long val = mem.getInt(slot) & 0xFFFFFFFFL;
            println(String.format("  [%3d] @ %s -> 0x%08x", i, slot, val));
            if (val != 0) seen.add(val);
        }

        println("\nDistinct non-zero pointer values: " + seen.size());
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        for (long val : seen) {
            Address target = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(val);
            Function fn = currentProgram.getFunctionManager().getFunctionAt(target);
            println("\n======================================================================");
            println("POINTER 0x" + Long.toHexString(val) + "  ->  "
                    + (fn != null ? "FUNCTION " + fn.getName() : "(no function at this address)"));
            println("======================================================================");
            if (fn != null) {
                DecompileResults res = decomp.decompileFunction(fn, 60, new ConsoleTaskMonitor());
                if (res != null && res.decompileCompleted()) {
                    println(res.getDecompiledFunction().getC());
                } else {
                    println("(decompile failed)");
                }
            }
        }
        decomp.dispose();
        println("=== Done ===");
    }
}
