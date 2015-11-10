# mk_wayfarer
mk_wayfarer is a helper script for teeworlds mkrace client.

##Run
```sh
mkfifo ~/.teeworlds/fifo
~/.teeworlds/proj/mk_wayfarer/mk_wayfarer.pl &
TW=$!;
stdbuf -oL less -f +F ~/.teeworlds/fifo | mkrace
kill -- -$TW
```
