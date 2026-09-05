// Finds indirect CALL instructions whose memory operand has a given constant byte
// displacement (a COM/C++ vtable slot offset) -- e.g. CALL DWORD PTR [ECX + 0x2c].
// Named imports (FindSymbol.java) and xrefs to data (FindDataXrefs.java) can't find
// these: a vtable method call has no symbol and no fixed target address to reference.
// Prints every match's address and containing function, then decompiles each unique
// containing function so the call can be read in context.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript FindVtableCall.java <hexOffset>
// e.g. FindVtableCall.java 2c   (IDirectDrawSurface::Flip, vtable slot 11 * 4 bytes)
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.util.task.ConsoleTaskMonitor;

import java.util.LinkedHashSet;
import java.util.Set;

public class FindVtableCall extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: FindVtableCall.java <hexOffset>  (e.g. 2c)");
            return;
        }
        long offset = Long.parseLong(args[0], 16);
        String needle1 = String.format("+ 0x%x]", offset);
        String needle2 = String.format("+0x%x]", offset);

        println("=== CALL [.. " + needle1 + " candidates ===");
        Set<Function> fns = new LinkedHashSet<>();
        int matches = 0;
        InstructionIterator it = currentProgram.getListing().getInstructions(true);
        while (it.hasNext()) {
            if (monitor.isCancelled()) break;
            Instruction insn = it.next();
            String mnem = insn.getMnemonicString();
            if (!mnem.equals("CALL")) continue;
            String rep = insn.toString();
            if (!(rep.contains(needle1) || rep.contains(needle2))) continue;
            if (!rep.contains("[")) continue; // require a memory operand, not a direct call

            Address at = insn.getAddress();
            Function fn = currentProgram.getFunctionManager().getFunctionContaining(at);
            println("  " + at + "  " + rep + (fn != null ? "   in " + fn.getName() + " @ " + fn.getEntryPoint() : "   (no fn)"));
            matches++;
            if (fn != null) fns.add(fn);
        }
        println("=== " + matches + " matching instruction(s) in " + fns.size() + " unique function(s) ===\n");

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
