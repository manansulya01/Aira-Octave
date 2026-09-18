# hello-aira sample: host cross-build for the AiraOS-Octave guest (x86_64).
CC ?= gcc
CFLAGS ?= -O2 -Wall
all: hello-aira

hello-aira: hello-aira.c
	$(CC) $(CFLAGS) -o hello-aira hello-aira.c

clean:
	rm -f hello-aira

.PHONY: all clean
