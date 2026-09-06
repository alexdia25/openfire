// Dumps a data region as 4-byte little-endian dwords (one per line, with the value in hex
// and a flag if it falls inside RFIRE.BIN's executable code range) -- easier to eyeball for
// vtable-style tables of function pointers/sub-struct pointers than DumpStringAt's raw hex.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis
//       -scriptPath <this dir> -postScript DumpDwords.java <hexAddr> <dwordCount>
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class DumpDwords extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 2) {
            println("usage: DumpDwords.java <hexAddr> <dwordCount>");
            return;
        }
        Address start = currentProgram.getAddressFactory().getAddress(args[0]);
        int count = Integer.parseInt(args[1]);
        Memory mem = currentProgram.getMemory();

        // RFIRE.BIN's .text-ish code range, from prior work in this project (functions seen
        // range roughly 0x00401000-0x00450000) -- just a heuristic flag, not authoritative.
        long codeLo = 0x00401000L;
        long codeHi = 0x00450000L;

        Address addr = start;
        for (int i = 0; i < count; i++) {
            int v = mem.getInt(addr);
            long uv = v & 0xFFFFFFFFL;
            String flag = (uv >= codeLo && uv < codeHi) ? "  <- code-range" : "";
            println(addr + "  " + String.format("%08x", uv) + flag);
            addr = addr.add(4);
        }
        println("=== Done ===");
    }
}
