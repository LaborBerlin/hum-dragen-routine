#!/usr/bin/bash
#
# Schedules computation of fastq.gz files given in /mnt/smb01-hum/NGSRawData/<RUNID>/Data/Intensities/BaseCalls for
# given "<IDS>" (multiple ids seperated by space).
#
# Results are saved to /staging/output/<RUNID>/
#
# 2022-03-22

RUNID="$1"
IDS="$2"

DOWNSAMPLINGSEED="1234"

echo -n "DRAGEN LICENSE: "
echo $(dragen_lic -f Genome | grep Gbases) >&2

echo "[$(date)] Analyzing $IDS from $RUNID: ">&2

for id in $IDS; do
  echo "[$(date)]    $id..." >&2
  fq1=$(find "/mnt/smb01-hum/NGSRawData/${RUNID}/" -name "${id}*_R1_*.fastq.gz")
  fq2=$(find "/mnt/smb01-hum/NGSRawData/${RUNID}/" -name "${id}*_R2_*.fastq.gz")
  mkdir -p /staging/output/${RUNID}/${id}-90Gb/
  echo "/usr/bin/time \
   dragen --ref-dir /staging/human/reference/hs37d5/hs37d5.fa.k_21.f_16.m_149 \
   --fastq-file1 ${fq1} --fastq-file2 ${fq2} \
   --output-directory /staging/output/${RUNID}/${id}-90Gb/ --output-file-prefix ${id}-90Gb_dragen \
   --RGID WGS --RGSM ${id}-90Gb \
   --num-threads 46 \
   --enable-map-align true --enable-map-align-output true --enable-duplicate-marking true \
   --enable-variant-caller true \
   --qc-cross-cont-vcf /opt/edico/config/sample_cross_contamination_resource_GRCh37.vcf.gz \
   --enable-cnv true --cnv-enable-self-normalization true \
   --enable-sv true \
   --enable-down-sampler true --down-sampler-random-seed ${DOWNSAMPLINGSEED} --down-sampler-reads 305000000 \
   --enable-down-sampler-output true --down-sampler-num-threads 32 \
   --qc-coverage-region-1 /staging/human/bed/CDS-v19-ROIs_v2.bed \
   --qc-coverage-reports-1 cov_report full_res \
   --qc-coverage-region-2 /staging/human/bed/Regions_Exomev8.bed \
   --qc-coverage-reports-2 cov_report full_res \
   --qc-coverage-region-3 /staging/human/bed/Padded_Exomev8.bed \
   --qc-coverage-reports-3 cov_report full_res \
   2>&1 | tee ${RUNID}_${id}-90Gb_dragen.log"
done \
  | parallel -j 1 -k --joblog dragen_command-${RUNID}-90Gb.joblog

echo "[$(date)]: Finished."
