#OPTS=-s EXPORTED_FUNCTIONS='["_loadROM", "_peek", "_poke", "_step", "_reset", "_stackSize", "_getStack"]' -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap"]'
OPTS=--bind
HEADERS=Vulcan.h

all: public/emulator.js

%.o: %.cpp ${HEADERS}
	emcc $< -O -c -o $@

public/emulator.js: Vulcan.o emulator.o
	emcc Vulcan.o emulator.o -O -o $@ ${OPTS}

clean:
	rm -f *.o *.wasm
