// Given an imported API function's name (e.g. "StretchDIBits"), finds its
// thunk/PLT-ish address, lists every caller, and decompiles each unique
// caller. Useful for finding the software rasterizer's present/blit routine
// from a known Win32 API it must call.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript FindImportCallers.java <name>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.util.task.ConsoleTaskMonitor;

import java.util.LinkedHashSet;
import java.util.Set;

public class FindImportCallers extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: FindImportCallers.java <importedFunctionName>");
            return;
        }
        String name = args[0];

        Set<Function> targets = new LinkedHashSet<>();
        FunctionIterator all = currentProgram.getFunctionManager().getFunctions(true);
        while (all.hasNext()) {
            Function f = all.next();
            if (f.getName().toLowerCase().contains(name.toLowerCase())) {
                targets.add(f);
            }
        }
        if (targets.isEmpty()) {
            println("No function/import matching '" + name + "' found.");
            return;
        }

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        Set<Function> callers = new LinkedHashSet<>();
        for (Function t : targets) {
            println("=== Target: " + t.getName() + " @ " + t.getEntryPoint()
                    + (t.isExternal() ? " [external]" : (t.isThunk() ? " [thunk]" : "")));
            Address a = t.getEntryPoint();
            ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(a);
            while (refs.hasNext()) {
                Reference r = refs.next();
                Function fn = currentProgram.getFunctionManager().getFunctionContaining(r.getFromAddress());
                println("  xref from " + r.getFromAddress() + (fn != null ? "  in " + fn.getName() + " @ " + fn.getEntryPoint() : "  (no fn)"));
                if (fn != null) callers.add(fn);
            }
        }

        println("\n=== Decompiling " + callers.size() + " unique callers ===\n");
        for (Function fn : callers) {
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
