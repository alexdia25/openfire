// Disassembles raw bytes in memory that Ghidra never marked as code (in the in-memory copy only; the project is
// opened read-only) and prints the instructions of [lo, hi). Use it for callbacks that only appear as pointers in
// data, where DumpDisasm.java and the decompiler find nothing (document 59).
// Run: ... -postScript DisasmForce.java <hexLo> <hexHi>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Instruction;

public class DisasmForce extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] a = getScriptArgs();
        long lo = Long.parseLong(a[0].replace("0x", ""), 16), hi = Long.parseLong(a[1].replace("0x", ""), 16);
        Address s = toAddr(lo), e = toAddr(hi);
        new DisassembleCommand(s, new AddressSet(s, e), true).applyTo(currentProgram, monitor);
        for (long p = lo; p < hi; ) {
            Instruction ins = getInstructionAt(toAddr(p));
            if (ins == null) { println(String.format("%08x  ??", p)); p++; continue; }
            println(String.format("%08x  %s", p, ins.toString()));
            p += ins.getLength();
        }
    }
}
