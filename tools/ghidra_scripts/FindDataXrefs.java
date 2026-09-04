// Given a hex data address, prints every cross-reference to it and decompiles
// each unique containing function. Complements FindCallers.java (which takes a
// FUNCTION address) -- this is for finding every function that touches a given
// global variable/data address.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript FindDataXrefs.java <hexAddr>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.util.task.ConsoleTaskMonitor;

import java.util.LinkedHashSet;
import java.util.Set;

public class FindDataXrefs extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: FindDataXrefs.java <hexAddr>");
            return;
        }
        Address target = currentProgram.getAddressFactory().getAddress(args[0]);
        println("=== Xrefs to " + target + " ===");

        Set<Function> fns = new LinkedHashSet<>();
        ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(target);
        while (refs.hasNext()) {
            Reference r = refs.next();
            Address from = r.getFromAddress();
            Function fn = currentProgram.getFunctionManager().getFunctionContaining(from);
            println("  xref from " + from + (fn != null ? "  in " + fn.getName() + " @ " + fn.getEntryPoint() : "  (no fn)"));
            if (fn != null) fns.add(fn);
        }

        println("\n=== Decompiling " + fns.size() + " unique referencing functions ===\n");
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        for (Function fn : fns) {
            if (monitor.isCancelled()) break;
            println("======================================================================");
            println("FUNCTION " + fn.getName() + " @ " + fn.getEntryPoint());
            println("======================================================================");
            DecompileResults res = decomp.decompileFunction(fn, 60, new ConsoleTaskMonitor());
            if (res != null && res.decompileCompleted() && res.getDecompiledFunction() != null) {
                println(res.getDecompiledFunction().getC());
            } else {
                println("(decompile failed: " + (res != null ? res.getErrorMessage() : "null") + ")");
            }
            println("");
        }
        decomp.dispose();
        println("=== Done ===");
    }
}
