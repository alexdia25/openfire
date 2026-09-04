// Scans raw program bytes (regardless of whether Ghidra has them marked as
// data, code, or undefined) for a literal byte sequence, and for each hit
// prints the address plus every cross-reference to that address (direct or
// via the containing defined data item).
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript FindBytes.java <hexBytes, e.g. 57524C00>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSetView;
import ghidra.program.model.listing.Function;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

public class FindBytes extends GhidraScript {

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: FindBytes.java <hexBytes>");
            return;
        }
        String hex = args[0];
        byte[] pattern = new byte[hex.length() / 2];
        for (int i = 0; i < pattern.length; i++) {
            pattern[i] = (byte) Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16);
        }
        println("Searching for byte pattern: " + hex);

        Memory mem = currentProgram.getMemory();
        AddressSetView initialized = mem.getLoadedAndInitializedAddressSet();
        Address start = initialized.getMinAddress();
        int hits = 0;
        while (start != null) {
            Address found = mem.findBytes(start, pattern, null, true, monitor);
            if (found == null) break;
            hits++;
            println("HIT @ " + found);
            ReferenceIterator refs = currentProgram.getReferenceManager().getReferencesTo(found);
            boolean any = false;
            while (refs.hasNext()) {
                Reference r = refs.next();
                any = true;
                Function fn = currentProgram.getFunctionManager().getFunctionContaining(r.getFromAddress());
                println("   xref from " + r.getFromAddress()
                        + (fn != null ? "  in " + fn.getName() + " @ " + fn.getEntryPoint() : "  (no function)"));
            }
            if (!any) println("   (no references)");
            try {
                start = found.add(1);
            } catch (Exception e) {
                break;
            }
            if (hits > 200) {
                println("(stopping after 200 hits)");
                break;
            }
        }
        println("Total hits: " + hits);
        println("=== Done ===");
    }
}
