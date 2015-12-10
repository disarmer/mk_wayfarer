#!/usr/bin/perl -w -CSDA
use utf8;
use strict;
use feature qw/say/;
use Fcntl;
use IO::Handle;
use Data::Dumper;
#image to dots:
#convert /tmp/drawing.png -flatten -resize 30x30 -threshold 85% -compress none PBM:-|perl -wE '<>;<>;while(<>){my$x=0;$y=$.-2;map{$_&&printf "say /dot %i %i 0 0 999;\n",$x*14-400,$y*14-300;$x++} split}'| awk '{printf "set_ticktimer -1 %d %s\n",NR/20,$0}' > ~/.teeworlds/fifo

#perl -wE 'my$s=1;my$r=5;my$m=100;map{$_/=$m;my$a=($_-0.5)*2*3.14;$a*=1.415;my$x=1.5*(sin($a)-$a*cos($a));my$y=-0.25*(cos($a)+5*$a*sin($a));printf "say /dot %g %g %g %g 80 1;\n",$r*$x,$r*$y,$x*$s,$y*$s} 0..$m' > ~/.teeworlds/heart.cfg
my %pending;
my $cwd;

BEGIN {
	$0=~m#(.*/)# and $cwd=$1;
	$cwd //= './';
}
use constant {
	SLEEPSEC=>1/14,
	LOGPATH=>$ENV{LOGPATH}    // '/home/disarmer/.teeworlds/tee.log',
	FIFOPATH=>$ENV{FIFOPATH}  // '/home/disarmer/.teeworlds/fifo',
	FONTPATH=>$ENV{FONTPATH}  // $cwd.'/font/UniCyr_8x8.8x8.txt',
	FONTTABLE=>$ENV{FONTPATH} // $cwd.'/font/UniCyr_8x8.psfgettable',
	CONFPATH=>$ENV{CONFPATH}  // '/home/disarmer/.teeworlds/scripts/dynamic',
	EXECPATH=>$ENV{EXECPATH}  // 'scripts/dynamic/',
	HOMEPATH=>$ENV{HOMEPATH}  // '/home/disarmer/.teeworlds',
	NICKNAME=>[split defined $ENV{SPLIT} ? "\Q$ENV{SPLIT}\E" : '\s+', $ENV{NICKNAME} // 'disarmer dis дисармер дис дизармер диз'],
	CHARZOOMX=>10,
	CHARZOOMY=>16,};
die "No dir: ".CONFPATH unless -d CONFPATH;

#die path(split / /,q/20 358.60415,731.1337 127.27922,-127.27923 -138.39089,0 128.79445,-128.79444 -126.77415,0 124.5013,-124.50131 79.29698,-79.29697 205.3135,205.3135 -147.48227,0 137.38075,137.38075 -147.48228,0 116.67262,116.67262/);
$|=1;
open LOG,  '<', LOGPATH  or die "Can't open logfile: $! ".LOGPATH;
open FIFO, '>', FIFOPATH or warn "Can't open FIFO: $! ".FIFOPATH;
FIFO->autoflush;
LOG->autoflush;

sub equation{
	say "Run equation",Dumper \@_;
	
	my($m,$tx,$ty)=(0,0,0);
	my ($d,$x,$y,$X,$Y,$D);
	if(ref $_[0]){
		my $c=shift @_;
		my %c=%$c;
		($tx,$ty,$m)=@c{qw/tx ty a/};
		$m/=360/(2*3.1415926);
		$_[9]=2;
	}

	my($min,$max,$inc,@f)=@_;#split /\s+/,$eq; #%0%20%0.1%10*math.cos(t)*t%10*math.sin(t)*
	my @aliases=qw/d x y X Y D M/;

	my @buf;
	for (my $t=$min;$t<$max;$t+=$inc){
		my @vals=(0,0,0,0,0,300,1);
		for my$i(0..$#f){
			next unless defined $f[$i];
			$vals[$i]=eval($f[$i]);
			eval sprintf '$%s=%f', $aliases[$i],$vals[$i];
		}
		$vals[1]+=$tx;
		$vals[2]+=$ty;
		if(int $vals[0]){
			push @buf,sprintf "set_ticktimer -1 %i say /dot %g %g %g %g %i %i;",@vals;
		}else{
			shift @vals;
			push @buf,sprintf "say /dot %g %g %g %g %i %i;",@vals;
		}
	}
	return @buf;
}

#die join $/,equation(split /\s+/,'0 100  $t*3 0 0  rand<0.3?0:rand>0.5?10:-10 rand>0.5?10:-10');
#die join $/,equation(split /\s+/,'0 100 $t*3 3+$t $x $X+rand');

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
sub redot{
	my($s,$c)=@_;
	@_=split /\s+/,$s;
	$_[0]+=$c->{tx};
	$_[1]+=$c->{ty};
	$_[2]//=0;$_[3]//=0;
	$_[4]//=300;
	$_[5]=2;
	return join ' ',@_;
}
{
	my @harraser_actions=(
		2=>'say /r',
		2=>sub{return sprintf "+weapon%i",1+rand 4},
		1=>sub{return sprintf "emote %i",1+rand 14},
		1=>sub{return sprintf "say /emote %s",qw/surprise blink close angry happy pain/[rand 6]},
		2=>sub{return sprintf "mouse_angle %i",rand 360},
		4=>sub{my$act=qw/right left ride aimbotnear jump hook/[rand 6];return sprintf "set_ticktimer 1 %i +%s;set_ticktimer 0 %i +%s",0,$act,rand 100,$act},
	);
	my $harraser_state=0;
	$SIG{ALRM}=sub {
		if($harraser_state){
			my $buf='';
			for(0..rand 3){
				my $cmd=&randweight(\@harraser_actions);
				$cmd=$cmd->() if ref $cmd;
				$buf.=$cmd.";";
			}
			#say FIFO "echo 'mkharraser action: $buf';$buf";
			say FIFO $buf;
			alarm 1;
		}
		return 1;
		#goto MAINLOOP;
	};
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
		reexec=>sub{
			my $path=sprintf "%s/%s",HOMEPATH,$_[0];
			return unless -f $path;
			cur_coords(sub {
				my %c=parse_coords(@_);
				open my $FH,'<',$path;
				my @a=<$FH>;
				map {chomp;s#/dot ([\s\d\.-]+)#"/dot ".redot($1,\%c)#eg} @a;
				&mkcfg('reexec', @a);
				printf FIFO "exec %sreexec.cfg;\n", EXECPATH;
			});
		},
		harraser=>sub{
			warn Dumper \@_;
			if($_[-1]!=$harraser_state){
				say FIFO "echo 'mkHarraser new state => $_[-1]'";
				$harraser_state=$_[-1];
				$SIG{ALRM}->();
			}
		},
		equation=>sub{
			&mkcfg('equation', equation(@_));
			printf FIFO "exec %sequation.cfg;\n", EXECPATH;
		},
		mequation=>sub{
			my @a=@_;
			cur_coords(sub{
				my %c=parse_coords(@_);
				&mkcfg('equation', equation(\%c, @a));
				printf FIFO "exec %sequation.cfg;\n", EXECPATH;
			});
		},
		draw=>sub {
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
sub randweight{
	my $ref=shift;
	my $sum=0;
	for(my$i=0;$i<@$ref;$i+=2){
		$sum+=$ref->[$i];
	};
	my $rand=rand $sum;
	$sum=0;
	for(my$i=0;$i<@$ref;$i+=2){
		$sum+=$ref->[$i];
		return $ref->[$i+1] if $sum>$rand;
	}
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
		draw_rand=>sub { #not needed anymore
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
			if($sender eq $nick->[0]){
				y/\?!//cd;
				printf FIFO "say /text -20 -160 %s\n",$_ if length $_;
				return;
			}
			for my $n (@{$nick}) {
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

MAINLOOP:while (1) {
	while (<LOG>) {
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
	select undef, undef, undef, SLEEPSEC;
}
