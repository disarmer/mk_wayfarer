#!/usr/bin/perl -w -CSDA
use utf8;
use strict;
use feature qw/say/;
use IO::Handle;
use Data::Dumper;

#sysopen (IN,$log,O_RDONLY | O_NONBLOCK) or die "Can't open log!";
#perl -wE 'my$s=1;my$r=5;my$m=100;map{$_/=$m;my$a=($_-0.5)*2*3.14;$a*=1.415;my$x=1.5*(sin($a)-$a*cos($a));my$y=-0.25*(cos($a)+5*$a*sin($a));printf "say /dot %g %g %g %g 80 1;\n",$r*$x,$r*$y,$x*$s,$y*$s} 0..$m' > ~/.teeworlds/heart.cfg
my %pending;

my $cwd;

BEGIN {
	$0=~m#(.*/)# and $cwd=$1;
	$cwd //= './';
}
use constant {
	FIFOPATH=>$ENV{FIFOPATH}  // '/home/disarmer/.teeworlds/fifo',
	FONTPATH=>$ENV{FONTPATH}  // $cwd.'/font/UniCyr_8x8.8x8.txt',
	FONTTABLE=>$ENV{FONTPATH} // $cwd.'/font/UniCyr_8x8.psfgettable',
	CONFPATH=>$ENV{CONFPATH}  // '/home/disarmer/.teeworlds/scripts/dynamic',
	EXECPATH=>$ENV{EXECPATH}  // 'scripts/dynamic/',
	NICKNAME=>[split /\s+/, $ENV{NICKNAME} // 'disarmer dis дисармер дис дизармер диз'],
	CHARZOOMX=>10,
	CHARZOOMY=>16,};
die "No dir: ".CONFPATH unless -d CONFPATH;

open FIFO, '>', FIFOPATH or warn "Can't open FIFO: $! ".FIFOPATH;
FIFO->autoflush;

sub mkcfg($@) {
	my $f=shift;
	open my $fh, '>', CONFPATH."/$f.cfg";
	say $fh shift while @_;
}

sub escape {
	local @_=@_;
	map {s/\\/\\\\/g; s/"/\\"/g} @_;
	return @_;
}

sub parse_coords {
	my %h;
	while ($_[0]=~m/\s(\S+): (-?\d+\.\d+)/g) {
		$h{$1}=$2;
	}
	return %h;
}
{
	my %cmd=(
		text=>sub {
			my $txt=join('', @_);
			cur_coords(
				sub {
					my %c=parse_coords(@_);
					say FIFO write_text(
						text=>$txt,
						x=>$c{tx},
						y=>$c{ty},
						mode=>2);
				});
		},
		textt=>sub {
			my $txt=join('', @_);
			cur_coords(
				sub {
					my %c=parse_coords(@_);
					say FIFO write_text(
						effect=>'timer',
						text=>$txt,
						x=>$c{tx},
						y=>$c{ty},
						mode=>2);
				});
		},
		test=>sub {
			cur_coords(
				sub {
					my %c=parse_coords(@_);

					#say "test @_: ",%c;
					#printf "say /dot %f %f 0 0 %i\n",$c{x},$c{y},999;
					printf FIFO "say /dot %f %f 0 0 %i 2\n", $c{tx}, $c{ty}, 999;
				});
		},);

	sub run_command {
		my ($cmd, @args)=split /\s+/, $_[0];
		say "Run cmd: $cmd with @args";
		if (exists $cmd{$cmd} && ref $cmd{$cmd}) {
			$cmd{$cmd}->(@args);
		}
	}
}

sub schedule {
	my ($realm, $re, $sub)=@_;
	say "Scheduling sub on $realm:$re";
	$pending{$realm}->{$re} ||= [];
	push @{$pending{$realm}->{$re}}, $sub;
}

sub cur_coords {
	say FIFO "mouse_get";
	my $sub=shift;
	schedule(
		'controls',
		'^mouse a',
		sub {
			$sub->(@_);
		});
}
{
	my $letter='';
	my $bits='';
	my %abc=();
	my %codetable;
	open my $FT, "<:bytes", FONTTABLE or warn "Cant open FONTTABLE: $! ".FONTTABLE;
	while (<$FT>) {
		m/^0x([\w\d]+)\s+U\+([\w\d]+)/ and $codetable{hex $1}=hex $2;
	}
	open my $ABC, "<:bytes", FONTPATH;
	while (<$ABC>) {
		if (m/^\+\+---(\d+)/) {

			#say "$letter\n$bits";
			chomp $bits;
			$abc{$letter}=$bits;
			$letter=chr($codetable{$1} // $1);
			$bits='';
		} else {
			$bits.=$_;
		}
	}
	chomp $bits;

	#say "$letter\n$bits";
	$abc{$letter}=$bits;

	sub write_char {
		my %h=@_;
		my $in=$h{char};
		$in=lc $in unless exists $abc{$in};
		unless (exists $abc{$in}) {
			warn "NOCHAR: $in ".ord $in;
			return '';
		}
		my $buf;
		$bits=$abc{$in};
		my $rn=0;
		my $longest=0;
		$h{mode} //= 1;
		$h{time} //= 100;
		$h{x}    //= 0;
		$h{y}    //= 0;

		for my $row (split /\n/, $bits) {
			my $c=0;
			for my $i (split //, $row) {
				if ($i ne ' ') {
					$h{dots}++;
					if (exists $h{effect} && $h{effect} eq 'timer') {
						$buf.=sprintf "set_ticktimer -1 %i say /dot %g %g %g %g %i %i;\n", $h{dots}, $h{x}+CHARZOOMX*$c, $h{y}+CHARZOOMY*$rn, 0, 0, $h{time}+$h{dots}/2, $h{mode};
					} else {
						$buf.=sprintf "say /dot %g %g %g %g %i %i;\n", $h{x}+CHARZOOMX*$c, $h{y}+CHARZOOMY*$rn, 0, 0, $h{time}+$h{dots}/2, $h{mode};
					}
				}

				#printf "%s(%3i %3i)",$i,$x + CHARZOOMX*$c,$y + CHARZOOMY*$rn;
				$c++;
			}

			#print $/;
			$longest=$c if $c>$longest;
			$rn++;
		}
		return wantarray ? ($buf // '', $longest*CHARZOOMX, $h{dots}) : $buf // '';
	}

	sub write_text {
		my %h=@_;
		$h{x} //= 0;
		$h{y} //= 0;
		my @buf;
		my $width=0;
		for my $i (split //, $h{text}) {
			my ($char, $len, $dots)=write_char(%h, char=>$i, x=>$h{x}+$width);
			$h{dots}=$dots;
			$width += $len;
			push @buf, $char;
		}
		mkcfg('text', @buf);
		return sprintf "exec %stext.cfg;\n", EXECPATH;
	}
	if ($ENV{TEST}) {

		#say write_char(1,0,0);
		say FIFO write_text(text=>$ENV{TEST}, time=>100, x=>-200, y=>-200);
		print Dumper \%abc;
		exit;
	}
	if ($ENV{EXPORT}) {
		while (my ($k, $v)=each %abc) {
			$v=~s/\n//g;
			$v=~s/\S/1/g;
			$v=~s/ /0/g;
			$v=unpack 'H*', pack 'b*', $v;
			say "$v //$k";
		}
		exit;
	}
};

{
	my %execs=(
		draw_rand=>sub {
			my @a;
			my $r=8;
			my $x=0;
			my $y=0;
			map {
				$x += $r*(0.5-rand);
				$y += $r*(0.5-rand);
				push @a, sprintf "set_ticktimer -1 %i say /dot %g %g 0 0 3 0;\n", $_*3, $r*$x, $r*$y;
			} 0..100;
			mkcfg('draw_rand', @a);
		},);

	sub exec_rearm {
		my $i=shift;
		say "Rearm $i";
		if (exists $execs{$i}) {$execs{$i}->()}
	}
	for (keys %execs) {exec_rearm($_)}
}
my %h=(
	chat=>sub {
		$_=shift;
		my $nick=NICKNAME;
		if (s/\*\*\* //) {
			if (m/'(.+)' entered and joined the game/) {
				mkcfg 'hello', $1 eq $nick->[0] ? 'say /mk Привет, %username%!' : sprintf 'say "Привет, %s!";emote 4', &escape($1);
			}
		} else {
			s/(.+?): //;
			my $sender=$1;
			return if $sender eq $nick->[0];
			for my $n (@{$nick}) {
				say "nick $n";
				s/\Q$n\E/$sender/ig and last;
			}
			mkcfg 'chat', sprintf 'say "%s";emote 4', &escape($_);
		}
	},
	console=>sub {
		$_=shift;
		my $dir=EXECPATH;
		if (m#^executing '$dir(.+)\.cfg'$#) {
			exec_rearm($1);
		} elsif (m#^cmd (.+)$#) {
			run_command($1);
		}
	},
	binds=>sub {
		$_=shift;
		if (m/^a: (-?\d+\.\d+)/) {
			say FIFO "mouse_angle ", int($1+15-rand 30);
			say "angle $1";
		}
	},);
$h{teamchat}=$h{chat};

while (<STDIN>) {
	s/^\[[\d :-]+\]\[(.*?)\]: // or warn "Can't parse: $_";
	chomp $_;
	my $str=$_;
	my $realm=lc $1;
	if (exists $h{$realm}) {
		say "$realm	$str";
		$h{$realm}->($str);
	}
	if (exists $pending{$realm}) {
		for my $re (keys %{$pending{$realm}}) {
			if ($str=~$re) {
				say "Callback for $realm:$re fired";
				map {$_->($str)} @{$pending{$realm}->{$re}};
				delete $pending{$realm}->{$re};
			}
		}
	}
}
