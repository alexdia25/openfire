// Forces function creation at an address (for code only reachable via an
// indirect/computed call that static analysis didn't resolve into a
// recognized Function), then decompiles it.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.util.task.ConsoleTaskMonitor;

public class ForceDecompile extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: ForceDecompile.java <hexAddr>");
            return;
        }
        Address addr = currentProgram.getAddressFactory().getAddress(args[0]);
        Function fn = currentProgram.getFunctionManager().getFunctionAt(addr);
        if (fn == null) {
            println("No function recognized at " + addr + " -- disassembling and creating one.");
            if (!currentProgram.getListing().isUndefined(addr, addr)) {
                println("(already has code/data at this address, proceeding)");
            }
            disassemble(addr);
            fn = createFunction(addr, null);
            if (fn == null) {
                println("createFunction failed.");
                return;
            }
        }
        println("FUNCTION " + fn.getName() + " @ " + fn.getEntryPoint());
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        DecompileResults res = decomp.decompileFunction(fn, 60, new ConsoleTaskMonitor());
        if (res != null && res.decompileCompleted()) {
            println(res.getDecompiledFunction().getC());
        } else {
            println("(decompile failed: " + (res != null ? res.getErrorMessage() : "null") + ")");
        }
        decomp.dispose();
        println("=== Done ===");
    }
}
