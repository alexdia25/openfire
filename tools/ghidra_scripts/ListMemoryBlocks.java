// Lists all memory blocks (name, start, end, size, permissions) so a byte-pattern
// scan knows real bounds instead of guessing an address range.
//@category ReturnFire
import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.MemoryBlock;

public class ListMemoryBlocks extends GhidraScript {
    @Override
    protected void run() throws Exception {
        for (MemoryBlock b : currentProgram.getMemory().getBlocks()) {
            println(String.format("%-12s %s - %s  size=0x%x  r=%b w=%b x=%b init=%b",
                b.getName(), b.getStart(), b.getEnd(), b.getSize(),
                b.isRead(), b.isWrite(), b.isExecute(), b.isInitialized()));
        }
    }
}
