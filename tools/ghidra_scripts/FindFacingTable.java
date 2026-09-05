// Scans a given address range for candidate per-object "facing table" entries
// (see FUN_0042dd90): 24-byte records of the form
//   int32 base_cel_index; int8 range_start; int8 range_end; int8 alt_threshold; int8 mode;
//   int32 corner_idx_a; int32 corner_idx_b; int32 unknown1; int32 unknown2;
// Looks for any 4-byte-aligned int32 in [minBase, maxBase] and prints the full 24-byte
// record around it as a candidate, so real hovercraft rotation-frame table data (cels
// 218-240ish) can be found directly instead of inferred from pixels.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class FindFacingTable extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 4) {
            println("usage: FindFacingTable.java <startAddrHex> <endAddrHex> <minBase> <maxBase>");
            return;
        }
        Address start = currentProgram.getAddressFactory().getAddress(args[0]);
        Address end = currentProgram.getAddressFactory().getAddress(args[1]);
        int minBase = Integer.parseInt(args[2]);
        int maxBase = Integer.parseInt(args[3]);

        Memory mem = currentProgram.getMemory();
        int found = 0;
        Address addr = start;
        while (addr.compareTo(end) < 0 && found < 200) {
            int val;
            try {
                val = mem.getInt(addr);
            } catch (Exception e) {
                addr = addr.add(4);
                continue;
            }
            if (val >= minBase && val <= maxBase) {
                byte[] rec = new byte[24];
                try {
                    mem.getBytes(addr, rec);
                } catch (Exception e) {
                    addr = addr.add(4);
                    continue;
                }
                int rangeStart = rec[4];
                int rangeEnd = rec[5];
                int altThresh = rec[6] & 0xff;
                int mode = rec[7] & 0xff;
                int idxA = mem.getInt(addr.add(8));
                int idxB = mem.getInt(addr.add(12));
                println(String.format(
                    "@%s base=%d range=[%d,%d] altThresh=%d mode=%d idxA=%d idxB=%d",
                    addr, val, rangeStart, rangeEnd, altThresh, mode, idxA, idxB));
                found++;
            }
            addr = addr.add(4);
        }
        println("=== " + found + " candidate(s) found ===");
    }
}
