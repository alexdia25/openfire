// Refined search for a facing-table team-variant PAIR (see FUN_0042dd90's mode field):
// two adjacent 24-byte entries where the low 3 bits of byte+7 are 1 or 4 (a "2-way
// variant" group selected by a 1-bit object-state flag), the SAME angle range in both
// (bytes 4-5), and base cel indices (int0) in the two known team ranges.
//@category ReturnFire
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class FindFacingPair extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        Address start = currentProgram.getAddressFactory().getAddress(args[0]);
        Address end = currentProgram.getAddressFactory().getAddress(args[1]);
        int loA = Integer.parseInt(args[2]);
        int hiA = Integer.parseInt(args[3]);
        int loB = Integer.parseInt(args[4]);
        int hiB = Integer.parseInt(args[5]);

        Memory mem = currentProgram.getMemory();
        int found = 0;
        Address addr = start;
        while (addr.compareTo(end) < 0 && found < 200) {
            try {
                int base0 = mem.getInt(addr);
                int mode0 = mem.getByte(addr.add(7)) & 7;
                if ((mode0 == 1 || mode0 == 4) && base0 >= loA && base0 <= hiA) {
                    Address next = addr.add(24);
                    int base1 = mem.getInt(next);
                    if (base1 >= loB && base1 <= hiB) {
                        byte r0s = mem.getByte(addr.add(4));
                        byte r0e = mem.getByte(addr.add(5));
                        byte r1s = mem.getByte(next.add(4));
                        byte r1e = mem.getByte(next.add(5));
                        println(String.format("PAIR @%s base0=%d range0=[%d,%d] mode0=%d | @%s base1=%d range1=[%d,%d]",
                            addr, base0, r0s, r0e, mode0, next, base1, r1s, r1e));
                        found++;
                    }
                }
                // also check the reverse order (green first, tan second)
                if ((mode0 == 1 || mode0 == 4) && base0 >= loB && base0 <= hiB) {
                    Address next = addr.add(24);
                    int base1 = mem.getInt(next);
                    if (base1 >= loA && base1 <= hiA) {
                        byte r0s = mem.getByte(addr.add(4));
                        byte r0e = mem.getByte(addr.add(5));
                        println(String.format("PAIR(rev) @%s base0=%d range0=[%d,%d] mode0=%d | @%s base1=%d",
                            addr, base0, r0s, r0e, mode0, next, base1));
                        found++;
                    }
                }
            } catch (Exception e) {
                // out of bounds or unmapped, skip
            }
            addr = addr.add(4);
        }
        println("=== " + found + " pair candidate(s) found ===");
    }
}
