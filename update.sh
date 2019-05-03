#!/usr/bin/env bash

# this script takes zero or more paths and assembles the asm directory at each location.

exe=csx.exe # name of executable

# ---------------------------

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # script dir

# ---------------------------

# update all the paths
while [ ! $# -eq 0 ]
do
	echo "beginning $1"

    # make sure the executable exists
    if [ ! -x "$1/$exe" ]
    then
        echo "FAILED $1 - No $exe found"
        shift
        continue
    fi
    
    # remove target's stdlib folder (if it exists)
    if [ -d "$1/stdlib" ]
    then
        rm -r "$1/stdlib"
    fi
    
	# copy over asm files
	cp "$root/_start.asm" "$1/."
	cp -r "$root/stdlib" "$1/."
	
	# assemble them into object files
	"$1/$exe" -a _start.asm stdlib/*.asm
	
	# remove the assembly files
	rm "$1/_start.asm" "$1/stdlib"/*.asm
    
	shift
done
