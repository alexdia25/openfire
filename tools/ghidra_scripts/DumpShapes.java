// Dumps the collision-shape chains hanging off draw descriptors (document 53). A descriptor's +8 points
// at a chain of shapes (each shape's +4 is the next); a descriptor's +4 is the next descriptor of the
// same object. Shape layout as read from FUN_0041e060 / FUN_0041e4c0:
//   +0x00 type (1 point, 2 axis-aligned box, 3 convex polygon, 4 swept point)   +0x04 next
//   +0x09/+0x0a/+0x0b: flag byte, own layer bits, mask of layers it collides with
//   +0x0c z low, +0x10 z high (16.16)   +0x14/+0x18 x/y offset
//   +0x1c..+0x28 box minx, miny, maxx, maxy (types 2, 3)
//   +0x2c corner count, +0x30 corner array (x, y, z x 3 ints), +0x34 count, +0x38 vertex order bytes (type 3)
// Run: ... -postScript DumpShapes.java <hexDescAddr> [<hexDescAddr> ...]
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;

public class DumpShapes extends GhidraScript {
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
        for (String arg : getScriptArgs()) {
            long d = Long.parseLong(arg, 16);
            int guard = 0;
            while (ok(d) && guard++ < 8) {
                long sh = u32(d + 8);
                StringBuilder sb = new StringBuilder("DESC 0x" + Long.toHexString(d) + " shapes:");
                int g2 = 0;
                while (ok(sh) && g2++ < 8) {
                    int type = s32(sh);
                    sb.append(" [type=").append(type);
                    sb.append(" b9=").append(mem.getByte(toAddr(sh + 9)) & 0xFF);
                    sb.append(" layer=").append(mem.getByte(toAddr(sh + 10)) & 0xFF);
                    sb.append(" mask=").append(mem.getByte(toAddr(sh + 11)) & 0xFF);
                    sb.append(" z=").append(s32(sh + 0xc) / 65536.0).append("..").append(s32(sh + 0x10) / 65536.0);
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
                            sb.append("(").append(s32(cp + 12L * i) / 65536.0).append(",")
                              .append(s32(cp + 12L * i + 4) / 65536.0).append(")");
                        }
                    }
                    sb.append("]");
                    sh = u32(sh + 4);
                }
                println(sb.toString());
                d = u32(d + 4);
            }
        }
        println("=== Done ===");
    }
}
