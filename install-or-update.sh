#!/bin/bash

die()    { echo "Error: $1" >&2 ; exit $2; }
warn()   { echo "Warning: $1" >&2 ; }
deploy() {

	[ -f "$1" -a -r "$1" ] || die "$Self: file $1 not readable" 10
	[ ! -e "$2" ] && ( echo "$Self: $2 does not exist, trying to create" ; mkdir -p "$2" || die "$Self: could not create directory $2" 20 )
	[ -e "$2" -a ! -d "$2" ] && die "$Self: $2 is not a directory" 30

	if [ ! -w "$2" ]
	then
		warn "$Self: directory $2 not writable, simulating only."
		CP="echo install"
	else
		CP="install"
	fi

	if [ -f "$2/$1" ]
	then
		if [ "$2/$1" -nt "$1" ]
		then
			echo "$Self: $1 in $2 is newer than install candidate, these changes would be overwritten:"
			if git diff --no-index "$1" "$2/$1"
			then
				echo "-- files identical, skipped."
			else
				echo ; echo -n "-- Overwrite? "
				read yn
				case "$yn" in
					y|Y)	$CP -p --mode="$3" "$1" "$2"
						;;
					*)	echo "Skipped $1."
						;;
				esac
			fi
		elif [ "$2/$1" -ot "$1" ]
		then
			echo "$Self: updating older version of $1 in $2"
			if git diff --no-index "$2/$1" "$1"
			then
				echo "-- files identical, skipped."
			else
				$CP -p --mode="$3" "$1" "$2"
			fi
		else
			if git diff --no-index "$1" "$2/$1"
			then
				echo "$Self: current version of $1 in $2"
			else
				warn "$Self: $1 in $2 has equal mtime, but does differ from install candidate, these changes would be overwritten:"
				echo ; echo -n "-- Overwrite? "
				read yn
				case "$yn" in
					y|Y)	$CP -p --mode="$3" "$1" "$2"
						;;
					*)	echo "Skipped $1."
						;;
				esac
			fi
		fi
	else
		echo "$Self: installing $1 to $2"
		$CP -p --mode="$3" "$1" "$2"
	fi
}

############################################################

set -o pipefail -o nounset

Self=$(basename $0)

deploy make-snapshot /usr/local/sbin 0755
deploy database-snapshot /usr/local/sbin 0755
deploy snapshot@.service /etc/systemd/system 0644
deploy database-snapshot@.service /etc/systemd/system 0644
deploy failure-notify@.service /etc/systemd/system 0644

systemctl daemon-reload

