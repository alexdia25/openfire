// Decompiles each function in a list of hex addresses, nothing else (no
// caller/callee expansion) -- for surveying many candidate functions at once
// without blowing up the log with unrelated context.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.util.task.ConsoleTaskMonitor;

public class DecompileMany extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: DecompileMany.java <hexAddr1> <hexAddr2> ...");
            return;
        }
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        for (String a : args) {
            Address addr = currentProgram.getAddressFactory().getAddress(a);
            Function fn = currentProgram.getFunctionManager().getFunctionAt(addr);
            println("\n======================================================================");
            if (fn == null) {
                println("NO FUNCTION @ " + addr);
                continue;
            }
            println("FUNCTION " + fn.getName() + " @ " + fn.getEntryPoint());
            println("======================================================================");
            DecompileResults res = decomp.decompileFunction(fn, 60, new ConsoleTaskMonitor());
            if (res != null && res.decompileCompleted()) {
                println(res.getDecompiledFunction().getC());
            } else {
                println("(decompile failed: " + (res != null ? res.getErrorMessage() : "null") + ")");
            }
        }
        decomp.dispose();
        println("\n=== Done ===");
    }
}
