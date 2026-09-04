// Finds strings relevant to the Return Fire loader (.RFM path pattern, ART.CAR,
// retfire.ini), prints every cross-reference to each, and decompiles the
// containing function so the .RFM header layout can be read directly out of
// the loader logic instead of guessed at from raw bytes.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN
//       -scriptPath <this dir> -postScript FindRfmStrings.java
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.StringDataInstance;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.util.task.ConsoleTaskMonitor;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class FindRfmStrings extends GhidraScript {

    private static final String[] NEEDLES = {
        "rfm", "art.car", "retfire.ini", "worlds", ".sdt", ".rfa"
    };

    @Override
    protected void run() throws Exception {
        println("=== Scanning defined strings for Return Fire format markers ===");

        List<Data> hits = new ArrayList<>();
        DataIterator it = currentProgram.getListing().getDefinedData(true);
        while (it.hasNext()) {
            Data d = it.next();
            if (monitor.isCancelled()) break;
            if (d == null || !d.hasStringValue()) continue;
            String val;
            try {
                val = StringDataInstance.getStringDataInstance(d).getStringValue();
            } catch (Exception e) {
                continue;
            }
            if (val == null) continue;
            String lower = val.toLowerCase(Locale.ROOT);
            for (String needle : NEEDLES) {
                if (lower.contains(needle)) {
                    hits.add(d);
                    break;
                }
            }
        }

        println("Found " + hits.size() + " matching strings.\n");

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        java.util.Set<Function> seenFunctions = new java.util.HashSet<>();

        for (Data d : hits) {
            Address addr = d.getAddress();
            String val = StringDataInstance.getStringDataInstance(d).getStringValue();
            println("---- STRING @ " + addr + " : " + val);

            ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(addr);
            boolean any = false;
            while (refs.hasNext()) {
                Reference r = refs.next();
                any = true;
                Address fromAddr = r.getFromAddress();
                Function fn = currentProgram.getFunctionManager().getFunctionContaining(fromAddr);
                println("     xref from " + fromAddr
                        + (fn != null ? "  in function " + fn.getName() + " @ " + fn.getEntryPoint()
                                      : "  (no containing function)"));
                if (fn != null) {
                    seenFunctions.add(fn);
                }
            }
            if (!any) {
                println("     (no references to this string)");
            }
        }

        println("\n=== Decompiling " + seenFunctions.size() + " unique functions that reference these strings ===\n");

        for (Function fn : seenFunctions) {
            if (monitor.isCancelled()) break;
            println("======================================================================");
            println("FUNCTION " + fn.getName() + " @ " + fn.getEntryPoint());
            println("======================================================================");
            DecompileResults res = decomp.decompileFunction(fn, 60, new ConsoleTaskMonitor());
            if (res != null && res.decompileCompleted() && res.getDecompiledFunction() != null) {
                println(res.getDecompiledFunction().getC());
            } else {
                println("(decompilation failed: " + (res != null ? res.getErrorMessage() : "null result") + ")");
            }
            println("");
        }

        decomp.dispose();
        println("=== Done ===");
    }
}
