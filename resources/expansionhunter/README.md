# Evaluation von Repeat Expansion Katalogen für das CADS Projekt

Downloaded *57* ExpansionHunter targets from (stripy)[https://stripy.org/expansionhunter-catalog-creator] on 2022-04-11 to 
`stripy_str_variant_catalog.json`

Generation of a composite repeats catalogue incorporating `/opt/edico/repeat-specs/hg19/variant_catalog.json` (*29*
loci),  `stripy_str_variant_catalog.json` (*57* loci) and SMN (*1* loci) under `GRCh37_edico+stripy+smn.json` (*60* 
loci) with (jq)[https://github.com/stedolan/jq] with precedence given to stripy for duplicates:
``bash
jq '. | length' /opt/edico/repeat-specs/hg19/variant_catalog.json
jq '. | length' stripy_str_variant_catalog.json
jq -s 'add' \
  /opt/edico/repeat-specs/hg19/variant_catalog.json \
  stripy_str_variant_catalog.json \
  <(echo '[{"VariantType": "SMN","LocusId": "SMN","LocusStructure": "(C|T)","ReferenceRegion":"chr5:70247772-70247773","TargetRegion": ["chr5:70247772-70247773", "chr5:69372352-69372353"],"MinimalLocusCoverage":5}]') \
  | sed 's/chr\([0-9MTXY]\)/\1/' \
  | jq 'unique_by(.LocusId) | sort_by(.LocusId)' \
  >GRCh37_edico+stripy+smn.json
jq '. | length' GRCh37_edico+stripy+smn.json
```
