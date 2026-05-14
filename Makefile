CC=gcc
CFLAGS=-Wall -pthread -O2

all: vmswarm_fork vmswarm_thread

vmswarm_fork: vmswarm_fork.c
	mkdir -p bin
	$(CC) $(CFLAGS) -o bin/vmswarm_fork vmswarm_fork.c

vmswarm_thread: vmswarm_thread.c
	mkdir -p bin
	$(CC) $(CFLAGS) -o bin/vmswarm_thread vmswarm_thread.c

clean:
	rm -rf bin

install: all
	mkdir -p /usr/local/lib/vmswarm/src
	cp -r src/* /usr/local/lib/vmswarm/src/
	cp bin/vmswarm_fork /usr/local/lib/vmswarm/
	cp bin/vmswarm_thread /usr/local/lib/vmswarm/
	cp vmswarm /usr/local/bin/
	chmod +x /usr/local/bin/vmswarm
	chmod +x /usr/local/lib/vmswarm/vmswarm_fork
	chmod +x /usr/local/lib/vmswarm/vmswarm_thread
	mkdir -p /etc/vmswarm
	mkdir -p /usr/local/share/man/man1
	cp vmswarm.1 /usr/local/share/man/man1/
uninstall:
	rm -f /usr/local/bin/vmswarm
	rm -rf /usr/local/lib/vmswarm
	rm -f /usr/local/share/man/man1/vmswarm.1
