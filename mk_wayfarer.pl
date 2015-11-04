#!/usr/bin/perl -w -CSDA
use utf8;
use strict;
use feature qw/say/;
use IO::Handle;
use Data::Dumper;
my @nick=qw/disarmer dis дисармер дис дизармер диз/;

#sysopen (IN,$log,O_RDONLY | O_NONBLOCK) or die "Can't open log!";
#perl -wE 'my$s=1;my$r=5;my$m=100;map{$_/=$m;my$a=($_-0.5)*2*3.14;$a*=1.415;my$x=1.5*(sin($a)-$a*cos($a));my$y=-0.25*(cos($a)+5*$a*sin($a));printf "say /dot %g %g %g %g 80 1;\n",$r*$x,$r*$y,$x*$s,$y*$s} 0..$m' > ~/.teeworlds/heart.cfg
my %pending;

use constant {
	FIFOPATH=>$ENV{FIFOPATH}//'/home/disarmer/.teeworlds/fifo',
	FONTPATH=>$ENV{FONTPATH}//'/home/disarmer/.teeworlds/proj/font/UniCyr_8x8.8x8.txt',
	CONFPATH=>$ENV{CONFPATH}//'/home/disarmer/.teeworlds/scripts/dynamic',
	CHARZOOMX=>10,
	CHARZOOMY=>16,
};
die "No dir: ".CONFPATH unless -d CONFPATH;

open FIFO,'>',FIFOPATH;
FIFO->autoflush;
sub escape{
	local @_=@_;
	map { s/\\/\\\\/g;s/"/\\"/g} @_;
	return @_;
}
sub parse_coords{
	my %h;
	while($_[0]=~m/\s(\S+): (-?\d+\.\d+)/g){
		$h{$1}=$2;
	}
	return %h;
	#mouse a: 56.3827  x: 221.4575  y: 333.1015  tx: 984.4575  ty: 2238.1016	
}
{
	my %cmd=(
		text=>sub{
			my $txt=join('',@_);
			cur_coords(sub {
			my %c=parse_coords(@_);
			say FIFO write_text(text=>$txt,x=>$c{tx},y=>$c{ty},mode=>2)
		})},
		textt=>sub{
			my $txt=join('',@_);
			cur_coords(sub {
			my %c=parse_coords(@_);
			say FIFO write_text(timer=>1,text=>$txt,x=>$c{tx},y=>$c{ty},mode=>2)
		})},
		test=>sub{cur_coords(sub {
			my %c=parse_coords(@_);
			#say "test @_: ",%c;
			#printf "say /dot %f %f 0 0 %i\n",$c{x},$c{y},999;
			printf FIFO "say /dot %f %f 0 0 %i 2\n",$c{tx},$c{ty},999;
		})},
	);
	sub run_command{
		my ($cmd,@args)=split /\s+/,$_[0];
		say "Run cmd: $cmd with @args";
		if(exists $cmd{$cmd} && ref $cmd{$cmd}){
			$cmd{$cmd}->(@args);
		}
	}
}
sub schedule{
	my($realm,$re,$sub)=@_;
	say "Scheduling sub on $realm:$re";
	$pending{$realm}->{$re}||=[];
	push @{$pending{$realm}->{$re}},$sub;
}
sub cur_coords{
	say FIFO "mouse_get";
	my $sub=shift;
	schedule('controls','^mouse a',sub{
		$sub->(@_);
	});
}
{
	my $letter='';
	my $bits='';
	my %abc=();
	open my $ABC,"<:bytes",FONTPATH;
	while(<$ABC>){
		if(m/^\+\+---(\d+)/){
			say "$letter\n$bits";
			chomp $bits;
			$abc{$letter}=$bits;
			$letter=chr $1;
			$bits='';
		}else{
			$bits.=$_;
		}
	}
	chomp $bits;
	say "$letter\n$bits";
	$abc{$letter}=$bits;
	sub write_char{
		my %h=@_;
		my $in=$h{char};
		$in=lc $in unless exists $abc{$in};
		unless(exists $abc{$in}){
			warn "NOCHAR: $in ".ord $in;
			return '';
		}
		my $buf;
		$bits=$abc{$in};
		my $rn=0;
		my $longest=0;
		$h{mode}//=1;
		$h{time}//=100;
		$h{x}//=0;$h{y}//=0;
		for my$row(split /\n/,$bits){
			my $c=0;
			for my$i(split //,$row){
				if($i ne ' '){
					$h{dots}++;
					if($h{timer}){
						$buf.=sprintf "set_ticktimer -1 %i say /dot %g %g %g %g %i %i;\n",$h{dots}, $h{x} + CHARZOOMX*$c,$h{y} + CHARZOOMY*$rn,0,0,$h{time}+$h{dots}/2,$h{mode};
					}else{
						$buf.=sprintf "say /dot %g %g %g %g %i %i;\n",$h{x} + CHARZOOMX*$c,$h{y} + CHARZOOMY*$rn,0,0,$h{time}+$h{dots}/2,$h{mode};
					}
				}
				#printf "%s(%3i %3i)",$i,$x + CHARZOOMX*$c,$y + CHARZOOMY*$rn;
				$c++;
			}
			#print $/;
			$longest=$c if $c>$longest;
			$rn++;
		}
		return wantarray ? ($buf//'',$longest*CHARZOOMX,$h{dots}):$buf//'';
	}
	sub write_text{
		my%h=@_;
		$h{x}//=0;$h{y}//=0;
		my @buf;
		my $width=0;
		for my$i(split //,$h{text}){
			my($char,$len,$dots)=write_char(%h,char=>$i,x=>$h{x}+$width);
			$h{dots}=$dots;
			$width+=$len;
			push @buf,$char;
		}
		mkcfg('text',@buf);
		return "exec scripts/dynamic/text.cfg;\n";
	}
	if($ENV{TEST}){
		#say write_char(1,0,0);
		say FIFO write_text(text=>$ENV{TEST},time=>100,x=>-200,y=>-200);
		exit;
	}
};
sub mkcfg($@){
	my $f=shift;
	open my $fh,'>',CONFPATH."/$f.cfg";
	say $fh shift while @_;
}
my %h=(
	chat=>sub{
		$_=shift;
		if(s/\*\*\* //){
			if (m/'(.+)' entered and joined the game/){
				mkcfg 'hello',$1 eq $nick[0]?'say /mk Привет, %username%!': sprintf 'say "Привет, %s!";emote 4',&escape($1);
			}
		}else{
			s/(.+?): //;
			my $sender=$1;
			return if $sender eq 'disarmer';
			for my $n(@nick){
				s/\Q$n\E/$sender/ig and last;
			}
			mkcfg 'chat',sprintf 'say "%s";emote 4',&escape($_);
		}
	},
	console=>sub{
		$_=shift;
		if(m/executing '.*'/){
			#$1
		}elsif(m#^cmd (.+)$#){
			run_command($1);
		}
	},
	binds=>sub{
		$_=shift;
		if(m/^a: (-?\d+\.\d+)/){
			say FIFO "mouse_angle ",int($1+15-rand 30);
			say "angle $1";
		}
	},
);
$h{teamchat}=$h{chat};


while(<STDIN>){
	s/^\[[\d :-]+\]\[(.*?)\]: // or warn "Can't parse: $_";
	chomp $_;
	my $str=$_;
	my $realm=lc $1;
	if(exists $h{$realm}){
		say "$realm	$str";
		$h{$realm}->($str);
	}
	if(exists $pending{$realm}){
		for my $re(keys %{$pending{$realm}}){
			if($str=~$re){
				say "Callback for $realm:$re fired";
				map {$_->($str)} @{$pending{$realm}->{$re}};
				delete $pending{$realm}->{$re};
			}
		}
	}
}
