#!/usr/bin/perl

use strict;
use File::Path qw(rmtree);

my @Existing;
my %Keep;
my @Intervals;
my $Latest;
my $TimestampFile = ".snapshot-timestamp";
my $Base;
my $Batch = 0;

# process arguments
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
		warn("Interval definition with n=1 does not make real sense.\n") if $n eq "1";
	} elsif (/^\s*\+(\d+)\s*$/) {
		$Latest = $1;
	} elsif (/^\s*\-(b|\-batch)\s*$/) {
		$Batch = 1;
	} elsif (/^\s*(\/.*|.*\/)\s*$/) {
		if ($Base != "") {
			die("You should specify exactly one directory on which to operate.\n");
		}
		$Base = $1;
	} else {
		die("'$_' is not a valid option, interval definition or directory (should start or end with /).");
	}
}

# check if $Base is a directory
-d $Base || die("'$Base' is not a directory.\n");

unless ($Base =~ /\/$/) { $Base .= '/'; } # make sure we always have a trailing slash

@Intervals = sort { $b->{"interval"} <=> $a->{"interval"} } @Intervals; # sort intervals from longest to shortest

# check if we got sane parameters
if ( ($#Intervals < 0) && ($Latest < 1) ) {
	die("You need to specify at least one interval or a number of last snapshots to keep.\n");
	# otherwise, everything will be deleted...
}

print "Rotating snapshots in $Base with following schedule:\n";
print " * keeping the $Latest last snapshots\n" if ($Latest > 0);
foreach(@Intervals) {
	print " * keeping up to ".$_->{n}." snapshots at ".$_->{readable}." intervals\n";
}

# find snapshots

opendir(my $D, $Base) or die("Cannot open directory: $!");
my @ReadDir = readdir $D;
closedir $D;

foreach (@ReadDir) {
	if ( (! /^\.\.?$/) && (-f $Base.'/'.$_.'/'.$TimestampFile) ) {
		# we only 
		my $tag = $_;
		my $mtime = (stat($Base.'/'.$tag.'/'.$TimestampFile))[9];
		push(@Existing, { "tag" => $tag, "mtime" => $mtime });
	}
}

@Existing = sort { $a->{"mtime"} <=> $b->{"mtime"} } @Existing;

for(my $i=0;$i<=$#Existing;$i++) {
	$Existing[$i]->{i} = $i;
	$Existing[$i]->{chart} = [ ] unless ($Batch);
}

print "\n".($#Existing+1)." snapshots found.\n";

my $start = 1;

my $lastmtime = 0;	# since we start with 0, the second element will (almost) always be beyond interval, and first one is thus added

my $interval = 1 unless ($Batch);

foreach (@Intervals) {

	##print "Searching with ".$_->{readable}." interval - i=$start / lastmtime=$lastmtime :\n";

	my @List;

	for(my $i=$start;$i<=$#Existing;$i++) {
		if ($Existing[$i]->{mtime} > ($lastmtime + $_->{interval})) {
			push(@List, $Existing[$i-1]);
			$Existing[$i-1]->{chart}->[$interval] = 1 unless ($Batch);
			##print (($i-1)."..".$Existing[$i-1]->{tag}." (".$Existing[$i]->{tag}." is more than ".$_->{interval}." after $lastmtime\n");
			$lastmtime = $Existing[$i-1]->{mtime};
		} else {
			$Existing[$i-1]->{chart}->[$interval] = -1 unless ($Batch);
		}
	}
	
	# last one always added
	push(@List, $Existing[$#Existing]);
	$Existing[$#Existing]->{chart}->[$interval] = 1 unless ($Batch);

	$start = ( $#List >= 2 ? $List[$#List-2]->{i} : 0 ) + 1;
	$lastmtime = $Existing[$start-1]->{mtime};

	if ($#List + 1 > $_->{n}) {
		splice(@List,0,($#List-$_->{n}+1));
	}

	foreach (@List) {
		$Keep{$_->{tag}} = 1;
		$_->{chart}->[$interval] = 2 unless ($Batch);
	}

	$interval++;
}

if ($Latest > 0) {
	for(my $i=($#Existing-$Latest+1 > 0 ? $#Existing-$Latest+1 : 0);$i<=$#Existing;$i++) {
		$Keep{$Existing[$i]->{tag}} = 1;
		$Existing[$i]->{chart}->[0] = 2 unless ($Batch);
	}
}

unless ($Batch) {
	print "\n";
	foreach (@Existing) {
		if ($Keep{$_->{tag}}) {
			print " --> ";
		} else {
			print " xxx ";
		}
		print "[".$_->{i}."]".$_->{tag}."\t".$_->{mtime}."\t";
		foreach(@{$_->{chart}}) {
			print " o " if ($_ == 2);
			print " . " if ($_ == 1);
			print "   " if ($_ == 0);
			print " | " if ($_ == -1);
		}
		print "\n";
	}

	print "\nCommit changes? ";

	$_ = <STDIN>; unless (/^[yY]/) {
		die("Exiting.\n");
	}
}

my $delcount = 0;

foreach (@Existing) {
	unless ($Keep{$_->{tag}}) {
		print("Deleting $Base".$_->{tag}.": ");
		if (rmtree($Base.$_->{tag})) {
			print("OK\n");
			$delcount++;
		} else {
			die("Error while deleting - exiting.\n");
		}
	}
}

print "$delcount snapshots deleted.\n";

