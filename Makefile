CC = gcc
LUA_DIR = /usr/local/include
HEADERS = cvemu.h

default: cvemu.so

.c.o: ${HEADERS}
	${CC} $? -c -o $@ -I${LUA_DIR} -fPIC

cvemu.so: cvemu.o
	${CC} *.o -o cvemu.so -shared

test: cvemu.so
	lua example.lua

clean:
	rm -f cvemu.so
	rm -f *.o
