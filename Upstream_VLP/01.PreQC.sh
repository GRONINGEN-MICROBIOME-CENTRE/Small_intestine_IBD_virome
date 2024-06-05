#!/bin/bash
#SBATCH --job-name=SI_virome_preQC
#SBATCH --output=./out/01.PreQC/SI_virome_%A_%a.out
#SBATCH --mem=16gb
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=4


SAMPLE_LIST=$1

echo ${SAMPLE_LIST}

SAMPLE_ID=$(sed "${SLURM_ARRAY_TASK_ID}q;d" ${SAMPLE_LIST})

echo "SAMPLE_ID=${SAMPLE_ID}"

# --- SAMPLE RENAMING & LANE MERGING ---
if [ $(ls ../SAMPLES/${SAMPLE_ID} | wc -l) -eq 3 ]; then
	
	# if there are only paired-end fastqs & MD5.txt:
	
	mv ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_*_1.fq.gz ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_1.fq.gz
	mv ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_*_2.fq.gz ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_2.fq.gz
else
	if [ $(ls ../SAMPLES/${SAMPLE_ID} | wc -l) -gt 3 ]; then
		
		# if there are multiple paired-end fastqs & MD5.txt:

		zcat ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_*_1.fq.gz | pigz -c -p ${SLURM_CPUS_PER_TASK} > ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_1.fq.gz
		zcat ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_*_2.fq.gz | pigz -c -p ${SLURM_CPUS_PER_TASK} > ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_2.fq.gz
		rm ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_*_1.fq.gz
		rm ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_*_2.fq.gz
	fi
fi

# --- LOADING MODULES ---
module purge
module load FastQC
module list

# --- CHECKING QUALITY OF RAW READS ---
fastqc -o ../01.MIDWAY/01.FastQC_preQC -t ${SLURM_CPUS_PER_TASK} ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_1.fq.gz
fastqc -o ../01.MIDWAY/01.FastQC_preQC -t ${SLURM_CPUS_PER_TASK} ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_2.fq.gz
