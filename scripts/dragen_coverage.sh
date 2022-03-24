#!/usr/bin/bash
#
# Schedules coverage and multiqc analyses of samples given in /staging/output/<RUNID>/.
#
# Results are saved to /staging/output/<RUNID>/
#
# 2022-02-23 helmuth

RUNID="$1"

THREADS=8   #threads per sample
PTHREADS=6  #gnu parallel threads

SCRIPT=$(realpath $0)
SCRIPTDIR=$(dirname $SCRIPT)

#load conda
. /opt/conda/miniconda3/etc/profile.d/conda.sh
conda activate hum-dragen-routine

echo "[$(date)] Analyzing $RUNID: ">&2
mkdir -p /staging/output/${RUNID}-qc/
PATHS=$(find /staging/output/$RUNID -mindepth 1 -maxdepth 1 -type d)
for path in $PATHS; do
  id=${path##*/}
  bamfile=$(find $path -name "*bam")
  fqfiles=$(find $path -name "*fastq.gz")
  echo "[$(date)]    $id..." >&2
  mkdir -p /staging/output/${RUNID}-qc/${id}/{fastqc,mosdepth,qualimap,samtools}
  echo "
    #mosdepth
    mosdepth --threads ${THREADS} --no-per-base --fast-mode \
      /staging/output/${RUNID}-qc/${id}/mosdepth/${id}-WGS \
      ${bamfile} \
      > /staging/output/${RUNID}-qc/${id}/mosdepth_${id}-WGS.log 2>&1
    mosdepth --threads ${THREADS} --no-per-base --fast-mode \
      --flag 0 --include-flag 1796 \
      /staging/output/${RUNID}-qc/${id}/mosdepth/${id}-WGS_dups \
      ${bamfile} \
      > /staging/output/${RUNID}-qc/${id}/mosdepth_${id}-WGS_WGS_dups.log 2>&1
    mosdepth --threads ${THREADS} --no-per-base --fast-mode --thresholds 1,10,20,100 \
      --by /mnt/s-labb-ngs01/scratch/databases/HUM/BED/Padded_Exomev8.bed \
      /staging/output/${RUNID}-qc/${id}/mosdepth/${id}-Padded_Exomev8 \
      ${bamfile} \
      > /staging/output/${RUNID}-qc/${id}/mosdepth_${id}-Padded_Exomev8.log 2>&1
    mosdepth --threads ${THREADS} --no-per-base --fast-mode --thresholds 1,10,20,100 \
      --by /mnt/s-labb-ngs01/scratch/databases/HUM/BED/2202_CDS.gencode.v19-selected.bed \
      /staging/output/${RUNID}-qc/${id}/mosdepth/${id}-CDS_selected \
      ${bamfile} \
      > /staging/output/${RUNID}-qc/${id}/mosdepth_${id}-CDS_selected.log 2>&1
    #qualimap
    unset DISPLAY && qualimap bamqc --java-mem-size=32g \
        --bam ${bamfile} \
        --skip-duplicated --skip-dup-mode 0 \
        --collect-overlap-pairs \
        --outformat HTML \
        -nt ${THREADS} \
        -outdir /staging/output/${RUNID}-qc/${id}/qualimap/${id}-WGS \
        > /staging/output/${RUNID}-qc/${id}/qualimap/${id}-WGS.log 2>&1
    unset DISPLAY && qualimap bamqc --java-mem-size=32g \
        --bam ${bamfile} \
        --outformat HTML \
        -nt ${THREADS} \
        -outdir /staging/output/${RUNID}-qc/${id}/qualimap/${id}-WGS_dups \
        > /staging/output/${RUNID}-qc/${id}/qualimap/${id}-WGS_dups.log 2>&1
    unset DISPLAY && qualimap bamqc --java-mem-size=32g \
        --bam ${bamfile} \
        --feature-file /mnt/s-labb-ngs01/scratch/databases/HUM/BED/Padded_Exomev8.bed \
        --skip-duplicated --skip-dup-mode 0 \
        --collect-overlap-pairs \
        --outformat HTML \
        -nt ${THREADS} \
        -outdir /staging/output/${RUNID}-qc/${id}/qualimap/${id}-Padded_Exomev8 \
        > /staging/output/${RUNID}-qc/${id}/qualimap/${id}-Padded_Exomev8.log 2>&1
    unset DISPLAY && qualimap bamqc --java-mem-size=32g \
        --bam ${bamfile} \
        --feature-file /mnt/s-labb-ngs01/scratch/databases/HUM/BED/2202_CDS.gencode.v19-selected.bed \
        --skip-duplicated --skip-dup-mode 0 \
        --collect-overlap-pairs \
        --outformat HTML \
        -nt ${THREADS} \
        -outdir /staging/output/${RUNID}-qc/${id}/qualimap/${id}-CDS_selected \
        > /staging/output/${RUNID}-qc/${id}/qualimap/${id}-CDS_selected.log 2>&1
    #samtools
    samtools flagstat -@ ${THREADS} ${bamfile} > /staging/output/${RUNID}-qc/${id}/samtools/${id}.samtools-flagstat
    samtools stats -@ ${THREADS} ${bamfile} > /staging/output/${RUNID}-qc/${id}/samtools/${id}.samtools-stats
    samtools idxstats -@ ${THREADS} ${bamfile} > /staging/output/${RUNID}-qc/${id}/samtools/${id}.samtools-idxstats
    #fastqc
    fastqc --threads ${THREADS} --outdir /staging/output/${RUNID}-qc/${id}/fastqc/ \
      --adapters /mnt/s-labb-ngs01/scratch/databases/fastqc/fastqc_adapter_list.txt \
      --contaminants /mnt/s-labb-ngs01/scratch/databases/fastqc/fastqc_contaminant_list.txt \
      $bamfile $fqfiles \
      > /staging/output/${RUNID}-qc/${id}/fastqc.log 2>&1
  "
done | \
  parallel -j ${PTHREADS} --joblog /staging/output/${RUNID}-qc/joblog --keep-order --progress

#copy bclconvert information to qc folder
rsync -qru \
  /mnt/smb01-hum/NGSRawData/${RUNID}/Data/Intensities/Basecalls/{dragen-replay.json,dragen.time_metrics.csv,Logs,Reports}\
  /staging/output/${RUNID}-qc/bclconvert

#multiqc
multiqc --force --interactive \
  --config ${SCRIPTDIR}/../resources/multiqc_config.yaml \
  --outdir /staging/output/${RUNID}-qc/ \
  --title "LB HUM DRAGEN ${RUNID} QC Report" \
  /staging/output/${RUNID} /staging/output/${RUNID}-qc

echo "[$(date)]: Finished."
