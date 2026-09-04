// Scans every instruction in the program for a reference to (or scalar operand
// equal to) a given 32-bit constant, e.g. the "WRL\0" magic packed as a
// little-endian DWORD (0x004C5257). Prints the instruction, its address, and
// the containing function -- much more direct than chasing generic I/O
// plumbing when a file format's magic bytes are compared as an immediate.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript FindConstant.java <hex32>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.scalar.Scalar;

public class FindConstant extends GhidraScript {

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: FindConstant.java <hex32, e.g. 4C5257>");
            return;
        }
        long target = Long.parseLong(args[0], 16);
        println("Searching for scalar operand == 0x" + Long.toHexString(target));

        int hits = 0;
        InstructionIterator it = currentProgram.getListing().getInstructions(true);
        while (it.hasNext()) {
            if (monitor.isCancelled()) break;
            Instruction ins = it.next();
            int n = ins.getNumOperands();
            for (int i = 0; i < n; i++) {
                Object[] objs = ins.getOpObjects(i);
                for (Object o : objs) {
                    if (o instanceof Scalar) {
                        Scalar s = (Scalar) o;
                        if (s.getUnsignedValue() == target || s.getValue() == target) {
                            Address addr = ins.getAddress();
                            Function fn = currentProgram.getFunctionManager().getFunctionContaining(addr);
                            println("HIT @ " + addr + "  " + ins
                                    + (fn != null ? "  in " + fn.getName() + " @ " + fn.getEntryPoint()
                                                  : "  (no function)"));
                            hits++;
                        }
                    }
                }
            }
        }
        println("Total hits: " + hits);
        println("=== Done ===");
    }
}
