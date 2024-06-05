#!/bin/bash

for SAMPLE in $@; do
 	# Running the regular assembly script:
	sbatch --output ./out/03.met/${SAMPLE}_03.out --job-name RAs_${SAMPLE} 03.meta_assembly.sh ${SAMPLE}
	# Running the meta-assembly with alternative read error correction script:
	#sbatch --output ./out/03.met/${SAMPLE}_03.out --job-name RAs_${SAMPLE} 03.meta_assembly_AltREC.sh ${SAMPLE}
done
