// Given a hex entry-point address, print every caller of that function and
// decompile each caller. Also independently scans every function in the
// program for ones that call both a file-open API (CreateFileA/_lopen/fopen)
// and ReadFile/_lread/fread -- candidates for the .RFM file loader.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript FindCallers.java <hexAddr>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.util.task.ConsoleTaskMonitor;

import java.util.HashSet;
import java.util.Set;

public class FindCallers extends GhidraScript {

    @Override
    protected void run() throws Exception {
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        String[] scriptArgs = getScriptArgs();
        if (scriptArgs.length > 0) {
            Address target = currentProgram.getAddressFactory().getAddress(scriptArgs[0]);
            println("=== Callers of function @ " + target + " ===");
            ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(target);
            Set<Function> callers = new HashSet<>();
            while (refs.hasNext()) {
                Reference r = refs.next();
                Function fn = currentProgram.getFunctionManager().getFunctionContaining(r.getFromAddress());
                if (fn != null) {
                    println("  call from " + r.getFromAddress() + " in " + fn.getName() + " @ " + fn.getEntryPoint());
                    callers.add(fn);
                }
            }
            for (Function fn : callers) {
                println("\n====================================================================== ");
                println("CALLER " + fn.getName() + " @ " + fn.getEntryPoint());
                println("======================================================================");
                DecompileResults res = decomp.decompileFunction(fn, 60, new ConsoleTaskMonitor());
                if (res != null && res.decompileCompleted()) {
                    println(res.getDecompiledFunction().getC());
                } else {
                    println("(decompile failed)");
                }
            }
        }

        println("\n=== Scanning all functions for ones calling both a file-open and a read API ===");
        String[] openNames = {"CreateFileA", "_lopen", "fopen", "_open"};
        String[] readNames = {"ReadFile", "_lread", "fread", "_read"};

        FunctionIterator fit = currentProgram.getFunctionManager().getFunctions(true);
        while (fit.hasNext()) {
            if (monitor.isCancelled()) break;
            Function fn = fit.next();
            boolean hasOpen = false, hasRead = false;
            InstructionIterator instrs = currentProgram.getListing().getInstructions(fn.getBody(), true);
            while (instrs.hasNext()) {
                Instruction ins = instrs.next();
                if (!ins.getMnemonicString().equalsIgnoreCase("CALL")) continue;
                Reference[] refsFrom = ins.getReferencesFrom();
                for (Reference rf : refsFrom) {
                    Function target = currentProgram.getFunctionManager().getFunctionAt(rf.getToAddress());
                    if (target == null) continue;
                    String tn = target.getName();
                    for (String n : openNames) if (tn.equalsIgnoreCase(n)) hasOpen = true;
                    for (String n : readNames) if (tn.equalsIgnoreCase(n)) hasRead = true;
                }
            }
            if (hasOpen && hasRead) {
                println("CANDIDATE LOADER: " + fn.getName() + " @ " + fn.getEntryPoint());
            }
        }

        decomp.dispose();
        println("=== Done ===");
    }
}
