// Scans RFIRE.BIN's data segment for every draw descriptor (the document 37-40 layout: +0x2c corner
// count, +0x30 corner array, +0x38 parts array of 8-int parts) regardless of who owns it, and prints one
// line per descriptor with its parts' cels and flags. Used by the registry audit (document 48) to
// attribute cels to *some* game object even when the owner (explosion script, effect record...) has
// not been decoded. Heuristic: pointer/alignment/range checks, part 0..n boundary detection.
//
// Run headless:
//   analyzeHeadless.bat <project_dir> <project_name> -process RFIRE.BIN -noanalysis -readOnly
//       -scriptPath <this dir> -postScript ScanDescriptors.java [startHex endHex]
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.Memory;

public class ScanDescriptors extends GhidraScript {
    private long s32(Memory m, long a) throws Exception {
        return m.getInt(currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(a));
    }

    private boolean ptr(long p) {
        return p >= 0x00440000L && p < 0x00470000L && (p & 3) == 0;
    }

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        long start = args.length > 1 ? Long.parseLong(args[0], 16) : 0x00443000L;
        long end = args.length > 1 ? Long.parseLong(args[1], 16) : 0x00458000L;
        Memory mem = currentProgram.getMemory();
        for (long d = start; d < end; d += 4) {
            try {
                long cc = s32(mem, d + 0x2c);
                long cp = s32(mem, d + 0x30) & 0xFFFFFFFFL;
                long pp = s32(mem, d + 0x38) & 0xFFFFFFFFL;
                if (cc < 3 || cc > 128 || !ptr(cp) || !ptr(pp)) continue;
                // first corner must be a plausible small coordinate
                boolean cornersOk = true;
                for (int i = 0; i < cc * 3 && cornersOk; i++) {
                    long v = s32(mem, cp + i * 4L);
                    if (Math.abs(v) > 0x01000000L) cornersOk = false;
                }
                if (!cornersOk) continue;
                StringBuilder parts = new StringBuilder();
                int n = 0;
                for (int p = 0; p < 64; p++) {
                    long pa = pp + p * 32L;
                    long cel = s32(mem, pa);
                    long fl = s32(mem, pa + 4) & 0xFFFFFFFFL;
                    boolean ok = cel >= 0 && cel < 2165 && fl < 0x10000L;
                    for (int c = 0; c < 4 && ok; c++) {
                        long ci = s32(mem, pa + 16 + c * 4L);
                        if (ci < 0 || ci >= cc) ok = false;
                    }
                    if (!ok) break;
                    parts.append(cel).append(":").append(Long.toHexString(fl)).append(" ");
                    n++;
                }
                if (n == 0) continue;
                println("DESC 0x" + Long.toHexString(d) + " corners=" + cc + " parts=" + n + " " + parts);
            } catch (Exception e) {
                // unreadable address: skip
            }
        }
        println("=== Done ===");
    }
}
