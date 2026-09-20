// Prints every instruction in [lo, hi) whose text contains the given displacement string, e.g. "+ 0x40]".
// Works without analysis (walks raw bytes with the disassembler where code exists). Used by document 59 to find
// writers of an object field. Run: ... -postScript FindDispOps.java <hexLo> <hexHi> "<needle>"
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Instruction;

public class FindDispOps extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] a = getScriptArgs();
        long lo = Long.parseLong(a[0].replace("0x", ""), 16), hi = Long.parseLong(a[1].replace("0x", ""), 16);
        String needle = a[2];
        for (long p = lo; p < hi; ) {
            Address ad = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(p);
            Instruction ins = currentProgram.getListing().getInstructionAt(ad);
            if (ins == null) { p++; continue; }
            String s = ins.toString();
            if (s.contains(needle)) println(String.format("%08x  %s", p, s));
            p += ins.getLength();
        }
    }
}
