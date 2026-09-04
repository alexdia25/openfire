// Prints the string/byte representation at a given address, plus nearby
// short ALL-CAPS-ish strings in the same data region (chunk-tag hunting).
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class DumpStringAt extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: DumpStringAt.java <hexAddr> [byteCount]");
            return;
        }
        Address addr = currentProgram.getAddressFactory().getAddress(args[0]);
        int n = args.length > 1 ? Integer.parseInt(args[1]) : 32;
        Memory mem = currentProgram.getMemory();
        byte[] buf = new byte[n];
        mem.getBytes(addr, buf);
        StringBuilder hex = new StringBuilder();
        StringBuilder txt = new StringBuilder();
        for (byte b : buf) {
            hex.append(String.format("%02x ", b));
            txt.append((b >= 32 && b < 127) ? (char) b : '.');
        }
        println("@ " + addr + "  hex: " + hex);
        println("@ " + addr + "  txt: " + txt);
        println("=== Done ===");
    }
}
