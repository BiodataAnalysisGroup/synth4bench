#!/bin/bash

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

eval $(parse_yaml parameters.yaml)

printf "#Printing freebayes commands"
printf "\n"

printf "freebayes"
printf " --fasta-reference ${path_to_reference}"
printf " --bam ${working_directory}/${folder}/${output_bam_merged}.sorted.uniq.rg.bam"
printf " > ${working_directory}/${folder}/freebayes.vcf"
printf "\n"

printf "bcftools reheader --fai ${path_to_reference}.fai"
printf " -o ${working_directory}/${folder}/${output_bam_merged}_freebayes.vcf "
printf "${working_directory}/${folder}/freebayes.vcf"
printf "\n"

printf "rm ${working_directory}/${folder}/freebayes.vcf"
printf "\n"

printf "bcftools norm ${working_directory}/${folder}/${output_bam_merged}_freebayes.vcf"
printf " --output ${working_directory}/${folder}/${output_bam_merged}_freebayes_norm.vcf"
printf " --output-type v"
printf " -m \"-\""
printf "\n"

printf "rm ${working_directory}/${folder}/${output_bam_merged}_freebayes.vcf"
printf "\n \n"