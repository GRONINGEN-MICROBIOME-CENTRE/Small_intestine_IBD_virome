#!/bin/bash

for SAMPLE in $@; do
 	# Running the regular assembly script:
	sbatch --output ./out/03.sc/${SAMPLE}_03.out --job-name RAs_${SAMPLE} 03.sc_assembly.sh ${SAMPLE}
	# Running the time-extended assembly script:
	#sbatch --output ./out/${SAMPLE}_02.out --error ./err/${SAMPLE}_02.err --job-name RAs_${SAMPLE} 02a.sc_assembly.sh ${SAMPLE}
done
