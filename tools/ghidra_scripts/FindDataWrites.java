// Like FindDataXrefs.java but prints only WRITE references (with type), and decompiles the
// unique writing functions. Useful for finding where a runtime-initialised global is set.
//
// Run headless: ... -postScript FindDataWrites.java <hexAddr>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.util.task.ConsoleTaskMonitor;

import java.util.LinkedHashSet;
import java.util.Set;

public class FindDataWrites extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: FindDataWrites.java <hexAddr>");
            return;
        }
        Address addr = toAddr(args[0]);
        Set<Function> funcs = new LinkedHashSet<>();
        for (Reference r : getReferencesTo(addr)) {
            if (!r.getReferenceType().isWrite()) {
                continue;
            }
            Function f = getFunctionContaining(r.getFromAddress());
            println("  write from " + r.getFromAddress() + " in " + (f == null ? "?" : f.getName()));
            if (f != null) {
                funcs.add(f);
            }
        }
        DecompInterface ifc = new DecompInterface();
        ifc.openProgram(currentProgram);
        for (Function f : funcs) {
            DecompileResults res = ifc.decompileFunction(f, 60, new ConsoleTaskMonitor());
            println("FUNCTION " + f.getName() + " @ " + f.getEntryPoint());
            println(res.decompileCompleted() ? res.getDecompiledFunction().getC() : "(decompile failed)");
        }
        println("=== Done ===");
    }
}
