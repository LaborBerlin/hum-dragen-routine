#!/usr/bin/bash
#
# Schedules computation of downsampled fastq.gz files given in
# /mnt/smb01-hum/NGSRawData/<RUNID>/Data/Intensities/BaseCalls for given "<IDS>" (multiple ids seperated by space).
# 
# Downsampling can be done by giving a XGb value (>=1Gb) as 3rd argument.
#
# Example with Downsampling to 8Gb:
#  bash dragen_germline 220311_A01077_0172_AH75YHDMXY "LB22-0706tn LB22-0695" "8Gb"
#
# Results are saved to /staging/output/<RUNID>/
#
# 2022-03-23

RUNID="$1"
IDS="$2"
DOWNSAMPLING=${3:-0}

#get basedir
SCRIPT=$(realpath $0)
SCRIPTDIR=$(dirname $SCRIPT)

echo -n "Current DRAGEN LICENSE usage: " >&2
echo $(dragen_lic -f Genome | grep Gbases) >&2

if [[ "$DOWNSAMPLING" != 0 ]]; then
  echo "[$(date)] Downsampling enabled for ${DOWNSAMPLING}."
  SAMPLESUFFIX="-${DOWNSAMPLING}"
  DOWNSAMPLINGREADS=$(echo "scale=12; (${DOWNSAMPLING/Gb/} / 0.15 ) * 500000" | bc | awk '{print int($1)}')
  DOWNSAMPLINGSNIPPET="--enable-down-sampler true --down-sampler-random-seed 1234 \
    --down-sampler-reads  $DOWNSAMPLINGREADS \
    --enable-down-sampler-output true --down-sampler-num-threads 32"
else
  SAMPLESUFFIX=""
  DOWNSAMPLINGSNIPPET=""
fi

echo "[$(date)] Preparing DRAGEN commands: ">&2
for id in $IDS; do
  echo "          $id..." >&2
  fq1=$(find "/mnt/smb01-hum/NGSRawData/${RUNID}/" -name "${id}*_R1_*.fastq.gz")
  fq2=$(find "/mnt/smb01-hum/NGSRawData/${RUNID}/" -name "${id}*_R2_*.fastq.gz")
  idfolder="${id}${SAMPLESUFFIX}"
  mkdir -p /staging/output/${RUNID}/${idfolder}/
  echo "/usr/bin/time \
   dragen --ref-dir /staging/human/reference/hs37d5/hs37d5.fa.k_21.f_16.m_149 \
   --fastq-file1 ${fq1} --fastq-file2 ${fq2} \
   --output-directory /staging/output/${RUNID}/${idfolder}/ --output-file-prefix ${idfolder}_dragen \
   --RGID WGS --RGSM ${idfolder} \
   --num-threads 46 \
   --enable-map-align true --enable-map-align-output true --enable-duplicate-marking true \
   --enable-variant-caller true \
   --qc-cross-cont-vcf /opt/edico/config/sample_cross_contamination_resource_GRCh37.vcf.gz \
   --enable-cnv true --cnv-enable-self-normalization true \
   --enable-sv true \
   --enable-cyp2d6 true \
   --repeat-genotype-enable true --repeat-genotype-specs ${SCRIPTDIR}/../resources/expansionhunter/GRCh37_edico+stripy+smn.json \
   --enable-hla true --hla-bed-file /opt/edico/config/hla_exons_grch37.bed \
   --enable-smn true \
   ${DOWNSAMPLINGSNIPPET} \
   --qc-coverage-region-1 /staging/human/bed/CDS-v19-ROIs_v2.bed \
   --qc-coverage-reports-1 cov_report full_res \
   --qc-coverage-region-2 /staging/human/bed/Regions_Exomev8.bed \
   --qc-coverage-reports-2 cov_report full_res \
   --qc-coverage-region-3 /staging/human/bed/Padded_Exomev8.bed \
   --qc-coverage-reports-3 cov_report full_res \
   2>&1 | tee ${RUNID}_${idfolder}_dragen.log"
done \
  >dragen_germline-${RUNID}${SAMPLESUFFIX}.sh

echo "[$(date)] Analyzing $IDS from $RUNID: ">&2
cat dragen_germline-${RUNID}${SAMPLESUFFIX}.sh \
  | parallel -j 1 -k --progress --joblog dragen_germline-${RUNID}${SAMPLESUFFIX}.joblog

echo "[$(date)] BGZIP for plain fastq files if present: ">&2
parallel -j 4 bgzip -@ 12 --compress-level 9 ::: $(find /staging/output/${RUNID}/ -name "*fastq")

echo -n "Current DRAGEN LICENSE usage: " >&2
echo $(dragen_lic -f Genome | grep Gbases) >&2

echo "[$(date)]: Finished."
