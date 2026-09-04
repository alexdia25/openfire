// Decompiles a single function given its entry-point hex address, and also
// decompiles its immediate callers and callees for context.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.util.task.ConsoleTaskMonitor;

import java.util.HashSet;
import java.util.Set;

public class DecompileOne extends GhidraScript {

    private void decompileAndPrint(DecompInterface decomp, Function fn) {
        println("\n======================================================================");
        println("FUNCTION " + fn.getName() + " @ " + fn.getEntryPoint());
        println("======================================================================");
        DecompileResults res = decomp.decompileFunction(fn, 60, new ConsoleTaskMonitor());
        if (res != null && res.decompileCompleted()) {
            println(res.getDecompiledFunction().getC());
        } else {
            println("(decompile failed: " + (res != null ? res.getErrorMessage() : "null") + ")");
        }
    }

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: DecompileOne.java <hexAddr>");
            return;
        }
        Address target = currentProgram.getAddressFactory().getAddress(args[0]);
        Function fn = currentProgram.getFunctionManager().getFunctionAt(target);
        if (fn == null) {
            println("no function at " + target);
            return;
        }

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        decompileAndPrint(decomp, fn);

        println("\n--- callers of " + fn.getName() + " ---");
        Set<Function> callers = new HashSet<>();
        ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(target);
        while (refs.hasNext()) {
            Reference r = refs.next();
            Function caller = currentProgram.getFunctionManager().getFunctionContaining(r.getFromAddress());
            if (caller != null) {
                println("  " + r.getFromAddress() + " in " + caller.getName() + " @ " + caller.getEntryPoint());
                callers.add(caller);
            }
        }
        for (Function caller : callers) {
            decompileAndPrint(decomp, caller);
        }

        println("\n--- callees of " + fn.getName() + " ---");
        Set<Function> callees = fn.getCalledFunctions(monitor);
        for (Function callee : callees) {
            println("  " + callee.getName() + " @ " + callee.getEntryPoint()
                    + (callee.isExternal() ? "  [external/import]" : ""));
        }
        for (Function callee : callees) {
            if (!callee.isExternal()) {
                decompileAndPrint(decomp, callee);
            }
        }

        decomp.dispose();
        println("\n=== Done ===");
    }
}
