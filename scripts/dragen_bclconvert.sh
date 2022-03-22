#!/bin/bash
#
# Applies dragen --bcl-conversion-only on a RUNID in /mnt/smb01-hum/NGSRawData starting a given DATE
#
# 2022-03-18 helmuth

RUNID=$1
DATE=$2

#NOTE: SampleSheet needs to copied to RUNDIR and adapted to
# AdapterRead1,AGATCGGAAGAGCACACGTCTGAACTCCAGTCA,,,,,,,,
# AdapterRead2,AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT,,,,,,,,

dragen_lic -f Genome | grep Gbases >&2

RUNDIR="/mnt/smb01-hum/NGSRawData/$RUNID"

#Check if an offset is given
if [ -z "$DATE" ]; then
  echo "[$(date)]: No starting time given! Processing starts now..."
else
  echo "[$(date)]: Starting time given!"
  current_epoch=$(date +%s)
  target_epoch=$(date -d "$DATE" +%s)
  sleep_seconds=$(( $target_epoch - $current_epoch ))
  echo "[$(date)]: Waiting for $sleep_seconds secs until $(date -d @${target_epoch}):"
  echo 
  c=$sleep_seconds # seconds to wait
  REWRITE="\e[25D\e[1A\e[K"
  while [ $c -gt 0 ]; do 
      c=$((c-1))
      sleep 1
      rest_time=$(eval "echo $(date -ud "@$c" +'$((%s/3600/24)) d %H hrs %M mins %S secs')")
      #echo -e "${REWRITE}$rest_time" >&2
  done
  echo -e "${REWRITE}Starting..." >&2
fi

#Wait for sequencing to complete (Empty file CopyComplete.txt created?)
COMPLETE="${RUNDIR}/CopyComplete.txt"
if [ ! -f "$COMPLETE" ]
then
  echo -n "[$(date)]: Run is not yet finished, waiting..." >&2
  until [ -f  "$COMPLETE" ]
  do
    sleep 5m
    echo -n "." >&2
  done
  echo "[$(date)]:\e[92m Sequencing is finished.\e[0m" >&2
  sleep 5m
fi

dragen --force --bcl-conversion-only true \
  --bcl-input-directory ${RUNDIR} \
  --output-directory ${RUNDIR}/Data/Intensities/BaseCalls/ \
  --no-lane-splitting true \
  2>&1 | tee ${RUNID}_BCLCONVERT.log

dragen_lic -f Genome | grep Gbases >&2

echo "Finished."
