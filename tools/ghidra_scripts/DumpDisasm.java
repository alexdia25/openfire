// Prints raw disassembly (address, bytes, mnemonic) for every instruction between two hex
// addresses, inclusive of start, exclusive of end. Complements DecompileOne.java for cases
// where the decompiler's C-level reconstruction disagrees with what the reference database
// says is actually there (e.g. a call the decompiled text doesn't show even though xrefs
// report it) -- this shows the ground truth the decompiler is (or isn't) modelling.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript DumpDisasm.java <startHexAddr> <endHexAddr>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;

public class DumpDisasm extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 2) {
            println("usage: DumpDisasm.java <startHexAddr> <endHexAddr>");
            return;
        }
        Address start = currentProgram.getAddressFactory().getAddress(args[0]);
        Address end = currentProgram.getAddressFactory().getAddress(args[1]);

        InstructionIterator it = currentProgram.getListing().getInstructions(start, true);
        while (it.hasNext()) {
            Instruction insn = it.next();
            if (insn.getAddress().compareTo(end) >= 0) {
                break;
            }
            StringBuilder bytes = new StringBuilder();
            try {
                for (byte b : insn.getBytes()) {
                    bytes.append(String.format("%02x ", b));
                }
            } catch (Exception e) {
                bytes.append("??");
            }
            println(insn.getAddress() + "  " + bytes.toString().trim() + "   " + insn.toString());
        }
        println("=== Done ===");
    }
}
