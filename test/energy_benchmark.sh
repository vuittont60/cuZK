#!/bin/bash

# this script is used to profile performance and energy consumption of MSM

# set up a log file
echo "Param,Mem,Graphics,Energy,Time" >>energy.log
# loop over arguments
IFS=$'\n'
for n in 20 21 22; do
    # loop over clock frequencies
    for mem in 877; do
        for freq in $(nvidia-smi -q -d SUPPORTED_CLOCKS | awk '/Graphics.*MHz/{ print $3 }'); do
            # change GPU clock
            nvidia-smi -ac $mem,$freq
            for i in {1..1}; do
                # run profiled computations
                output=$(./msmtestb $n)
                for line in $output; do
                    # extract and report results
                    time=$(echo $line | gawk 'match($0,/Time=([0-9]+\.[0-9]+)/, a) {print a[1]}')
                    energy=$(echo $line | gawk 'match($0,/Energy=([0-9]+)/, a) {print a[1]}')
                    if [ "$time" != "" ]; then
                        result="Param=$n,Mem=$mem,Graphics=$freq,Energy=$energy,Time=$time"
                        echo $result
                        echo "$n,$mem,$freq,$energy,$time" >>energy.log
                    fi
                done
            done
        done
    done
done
