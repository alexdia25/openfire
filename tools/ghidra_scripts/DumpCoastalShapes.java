// For every coastal id (table at 0x447038, stride 0x38) prints the collision shapes of its descriptor chain
// (document 53): descriptor +8 -> shape chain (see DumpShapes.java for the layout), descriptor +4 -> next
// descriptor. Also prints whether the first descriptor's +0x28 callback is the per-tile jitter (0x4365c0),
// which FUN_0042bb10 applies to the shape position exactly as the draw code does.
// Output: one "ID n jitter=b" line, then one "SHAPE ..." line per shape.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.Memory;

public class DumpCoastalShapes extends GhidraScript {
    private Memory mem;

    private long u32(long a) throws Exception {
        return mem.getInt(toAddr(a)) & 0xFFFFFFFFL;
    }

    private int s32(long a) throws Exception {
        return mem.getInt(toAddr(a));
    }

    private boolean ok(long p) {
        return p >= 0x00400000L && p < 0x00500000L;
    }

    @Override
    protected void run() throws Exception {
        mem = currentProgram.getMemory();
        for (int id = 1; id <= 91; id++) {
            long d = u32(0x00447038L + id * 0x38L);
            if (!ok(d)) continue;
            println("ID " + id + " jitter=" + (u32(d + 0x28) == 0x4365c0L));
            int g = 0;
            while (ok(d) && g++ < 8) {
                long sh = u32(d + 8);
                int g2 = 0;
                while (ok(sh) && g2++ < 8) {
                    int type = s32(sh);
                    StringBuilder sb = new StringBuilder("SHAPE " + id + " desc=0x" + Long.toHexString(d));
                    sb.append(" type=").append(type);
                    sb.append(" layer=").append(mem.getByte(toAddr(sh + 10)) & 0xFF);
                    sb.append(" mask=").append(mem.getByte(toAddr(sh + 11)) & 0xFF);
                    sb.append(" z=").append(s32(sh + 0xc) / 65536.0).append(",").append(s32(sh + 0x10) / 65536.0);
                    sb.append(" off=").append(s32(sh + 0x14) / 65536.0).append(",").append(s32(sh + 0x18) / 65536.0);
                    if (type == 2 || type == 3) {
                        sb.append(" box=").append(s32(sh + 0x1c) / 65536.0).append(",").append(s32(sh + 0x20) / 65536.0)
                          .append(",").append(s32(sh + 0x24) / 65536.0).append(",").append(s32(sh + 0x28) / 65536.0);
                    }
                    if (type == 3) {
                        int n = s32(sh + 0x2c);
                        long cp = u32(sh + 0x30);
                        sb.append(" poly=");
                        for (int i = 0; i < n && i < 16 && ok(cp); i++) {
                            if (i > 0) sb.append(";");
                            sb.append(s32(cp + 12L * i) / 65536.0).append(",").append(s32(cp + 12L * i + 4) / 65536.0);
                        }
                    }
                    println(sb.toString());
                    sh = u32(sh + 4);
                }
                d = u32(d + 4);
            }
        }
        println("=== Done ===");
    }
}
