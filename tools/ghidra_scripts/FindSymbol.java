// Searches ALL symbols (not just Functions -- covers imported-function
// pointers sitting in .idata as Data symbols too) for a case-insensitive
// substring match, printing each match's address, type, and namespace.
//@category ReturnFire

import ghidra.app.script.GhidraScript;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolIterator;

public class FindSymbol extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("usage: FindSymbol.java <substring>");
            return;
        }
        String needle = args[0].toLowerCase();
        int count = 0;
        SymbolIterator it = currentProgram.getSymbolTable().getAllSymbols(true);
        while (it.hasNext()) {
            Symbol s = it.next();
            if (s.getName().toLowerCase().contains(needle)) {
                println(s.getAddress() + "  " + s.getSymbolType() + "  " + s.getName()
                        + "  ns=" + s.getParentNamespace().getName());
                count++;
            }
        }
        println("Total matches: " + count);
        println("=== Done ===");
    }
}
