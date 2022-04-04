#!/bin/bash
#
# Applies dragen --bcl-conversion-only on a RUNID in /mnt/smb01-hum/NGSRawData starting a given DATE
#
# 2022-03-18 helmuth

[ -z "$1" ] && { echo "Specify run ID as first argument!" >&2; exit 1; }
RUNID=${1}
RUNDIR=$(find /mnt/smb01-hum/NGSRawData/ /mnt/smb01-mol/NGSRawData/ -maxdepth 1 -type d -name "${RUNID}*")
echo "[$(date)]: For ${RUNID} the following RUNDIR was found: ${RUNDIR}." >&2

DATE=${2}

OUTPUTDIR=${3:-${RUNDIR}/Data/Intensities/BaseCalls/}
echo "[$(date)]: Output directory is set as: ${OUTPUTDIR}." >&2

echo "[$(date)]: Correcting SampleSheet for bclconvert usage." >&2

SAMPLESHEETF="$RUNDIR/SampleSheet.csv"
[ ! -f "$SAMPLSHEETF"] && { echo "Samplesheet $RUNDIR/SampleSheet.csv not found!" >&2;  exit 1; }

if [ $(grep -c "IsIndexedRead=\"Y\"" ${RUNDIR}/RunInfo.xml) -gt 1 ]; then
  BARCODESTR="-e /\[Settings\]/ a BarcodeMismatchesIndex1,1\nBarcodeMismatchesIndex2,1"
else
  BARCODESTR="-e /\[Settings\]/ a BarcodeMismatchesIndex1,1"
fi
sed \
  -e "/\[Settings\]/ a CreateFastqForIndexReads,1" `#Generate FASTQ for Index sequences` \
  -e "s/Adapter,/AdapterRead1,/"                   `#Adapter not an bclconvert field - AdapterRead1 is correct` \
  -e "/^ReverseComplement,*/d"                     `#Not supported by bclconvert`\
  "$BARCODESTR"                                    `#Allow 1 Mismatch for barcode - default value` \
  ${SAMPLESHEETF} \
  >${SAMPLESHEETF/.csv/_bclconvert.csv}

echo -n "Current DRAGEN LICENSE usage: " >&2
dragen_lic -f Genome | grep Gbases >&2

#Check if an offset is given
if [ -z "$DATE" ]; then
  echo "[$(date)]: No starting time given! Processing starts now..." >&2
else
  echo "[$(date)]: Starting time given!" >&2
  current_epoch=$(date +%s)
  target_epoch=$(date -d "$DATE" +%s)
  sleep_seconds=$(( $target_epoch - $current_epoch ))
  echo "[$(date)]: Waiting for $sleep_seconds secs until $(date -d @${target_epoch}):" >&2
  echo  >&2
  c=$sleep_seconds # seconds to wait
  while [ $c -gt 0 ]; do 
      c=$((c-1))
      sleep 1
      rest_time=$(eval "echo $(date -ud "@$c" +'$((%s/3600/24)) d %H hrs %M mins %S secs')")
  done
  echo -e "Starting..." >&2
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
fi
echo "[$(date)]: Sequencing is finished." >&2

#NOTE: Number of threads and HW+12 option are set automatically by dragen executable but can also be specified
dragen --force --bcl-conversion-only true \
  --bcl-input-directory ${RUNDIR} \
  --sample-sheet ${SAMPLESHEETF/.csv/_bclconvert.csv} \
  --output-directory ${OUTPUTDIR} \
  --no-lane-splitting true

echo -n "Current DRAGEN LICENSE usage: " >&2
dragen_lic -f Genome | grep Gbases >&2

echo "Finished." >&2
