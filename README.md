# mk_wayfarer
mk_wayfarer is a helper script for teeworlds mkrace client.

##Run
mkfifo ~/.teeworlds/fifo
(tail -f ~/.teeworlds/tee.log -n 100| ~/.teeworlds/proj/mk_wayfarer/mk_wayfarer.pl ) &
TW=$!;
mkrace < ~/.teeworlds/fifo
kill -- -$TW
