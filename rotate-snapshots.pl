#!/usr/bin/perl

use strict;
use File::Path qw(rmtree);

my @Existing;
my %Keep;
my @Intervals;
my $Latest;
my $Base = shift(@ARGV);
my $TimestampFile = ".snapshot-timestamp";

-d $Base || die("'$Base' is not a directory.\n");

unless ($Base =~ /\/$/) { $Base .= '/'; }

foreach(@ARGV) {
	$_ = lc($_);
	if (/^\s*(\d+)\s*x\s*(\d+)\s*([hdwmy]?)\s*$/) {
		my $n = $1;
		my $interval = $2;
		my $unit = $3;
		$interval *= 3600		if $unit eq 'h';
		$interval *= 3600 * 24		if $unit eq 'd';
		$interval *= 3600 * 24 * 7	if $unit eq 'w';
		$interval *= 3600 * 24 * 30	if $unit eq 'm';
		$interval *= 3600 * 24 * 365	if $unit eq 'y';
		push(@Intervals, { "n" => $n, "interval" => $interval, "readable" => $2.$unit });
	} elsif (/^\s*\+(\d+)\s*$/) {
		$Latest = $1;
	} else {
		die("'$_' is not a valid interval definition.");
	}
}

@Intervals = sort { $b->{"interval"} <=> $a->{"interval"} } @Intervals;

print "Rotating snapshots in $Base with following schedule:\n";
print "* keeping the $Latest last snapshots\n" if ($Latest > 0);
foreach(@Intervals) {
	print "* keeping (at least) one snapshot every ".$_->{readable}." up to ".$_->{n}." times\n";
}

# find snapshots

opendir(my $D, $Base) or die("Cannot open directory: $!");

my @ReadDir = readdir $D;
closedir $D;

foreach (@ReadDir) {
	if ( (! /^\.\.?$/) && (-f $Base.'/'.$_.'/'.$TimestampFile) ) {
		my $tag = $_;
		my $mtime = (stat($Base.'/'.$tag.'/'.$TimestampFile))[9];
		push(@Existing, { "tag" => $tag, "mtime" => $mtime });
	}
}

@Existing = sort { $a->{"mtime"} <=> $b->{"mtime"} } @Existing;

for(my $i=0;$i<=$#Existing;$i++) {
	$Existing[$i]->{i} = $i;
}

print "\nCurrently, there are ".($#Existing+1)." snapshots.\n";

my $start = 1;

my $lastmtime = 0;	# since we start with 0, the second element will (almost) always be beyond interval, and first one is thus added

foreach (@Intervals) {

	##print "Searching with ".$_->{readable}." interval - i=$start / lastmtime=$lastmtime :\n";

	my @List;

	for(my $i=$start;$i<=$#Existing;$i++) {
		if ($Existing[$i]->{mtime} > ($lastmtime + $_->{interval})) {
			push(@List, $Existing[$i-1]);
			##print (($i-1)."..".$Existing[$i-1]->{tag}." (".$Existing[$i]->{tag}." is more than ".$_->{interval}." after $lastmtime\n");
			$lastmtime = $Existing[$i-1]->{mtime};
		}
	}
	
	# last one always added
	push(@List, $Existing[$#Existing]);

	$start = ( $#List >= 2 ? $List[$#List-2]->{i} : 0 ) + 1;
	$lastmtime = $Existing[$start-1]->{mtime};

	if ($#List + 1 > $_->{n}) {
		splice(@List,0,($#List-$_->{n}+1));
	}

	foreach (@List) {
		$Keep{$_->{tag}} = 1;
	}
}

if ($Latest > 0) {
	for(my $i=($#Existing-$Latest+1 > 0 ? $#Existing-$Latest+1 : 0);$i<=$#Existing;$i++) {
		$Keep{$Existing[$i]->{tag}} = 1;
	}
}

foreach (@Existing) {
	print $_->{i};
	if ($Keep{$_->{tag}}) {
		print " --- ";
	} else {
		print " DEL ";
	}
	print $_->{tag}."\n";
}

print "\nCommit changes? ";

$_ = <STDIN>; unless (/^[yY]/) {
	die("Exiting.\n");
}

foreach (@Existing) {
	unless ($Keep{$_->{tag}}) {
		print "Deleting $Base".$_->{tag}."\n";
		rmtree($Base.$_->{tag});
	}
}

