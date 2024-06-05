#!/bin/bash
#SBATCH --job-name=ViromeDiscovery
#SBATCH --output=./out/05.vib/VD_SI_%A_%a.out
#SBATCH --mem=16gb
#SBATCH --time=05:59:00
#SBATCH --cpus-per-task=8

SAMPLE_LIST=$1

echo ${SAMPLE_LIST}

SAMPLE_ID=$(sed "${SLURM_ARRAY_TASK_ID}q;d" ${SAMPLE_LIST})

echo "SAMPLE_ID=${SAMPLE_ID}"

# --- LOAD MODULES --- 
module purge
module load prodigal-gv/2.11.0-GCCcore-12.2.0 
module load Python/3.11.3-GCCcore-12.3.0

# --- PREDICTING ORFs ---
echo "> Running parallel prodigal-gv"

# https://raw.githubusercontent.com/apcamargo/prodigal-gv/master/parallel-prodigal-gv.py

python parallel-prodigal-gv.py \
	-t ${SLURM_CPUS_PER_TASK} \
	-q \
	-i ../SAMPLES/${SAMPLE_ID}/01_sc_assembly/${SAMPLE_ID}_contigs.min1kbp.fasta \
	-a ../SAMPLES/${SAMPLE_ID}/01_sc_assembly/${SAMPLE_ID}_contigs.min1kbp.AA.fasta \
	-o ../SAMPLES/${SAMPLE_ID}/01_sc_assembly/${SAMPLE_ID}_prodigal.out

# --- CLEAN ENV --- 
module purge

# --- LOAD MODULES ---
module load Anaconda3/2022.05
conda activate /scratch/hb-llnext/conda_envs/Vibrant_env

# --- RUNNING VIBRANT ---
echo "> Running VIBRANT"
mkdir -p ${TMPDIR}/${SAMPLE_ID}/
mkdir -p ../SAMPLES/${SAMPLE_ID}/virome_discovery/VIBRANT

/scratch/hb-llnext/conda_envs/Vibrant_env/bin/VIBRANT_run.py \
	-i ../SAMPLES/${SAMPLE_ID}/01_sc_assembly/${SAMPLE_ID}_contigs.min1kbp.AA.fasta \
	-folder ${TMPDIR}/${SAMPLE_ID}/ \
	-f prot \
	-t ${SLURM_CPUS_PER_TASK} \
	-l 1000 \
	-virome \
	-no_plot

if [ $(grep 'End' ${TMPDIR}/${SAMPLE_ID}/VIBRANT_${SAMPLE_ID}_contigs.min1kbp.AA/VIBRANT_log_run_${SAMPLE_ID}_contigs.min1kbp.AA.log | wc -l) -eq 1 ]; then
	echo "VIBRANT is done"
fi

# --- COPYING THE RESULTS ---
echo "> Copying the results"
cp ${TMPDIR}/${SAMPLE_ID}/VIBRANT_${SAMPLE_ID}_contigs.min1kbp.AA/VIBRANT_log_run_${SAMPLE_ID}_contigs.min1kbp.AA.log \
	../SAMPLES/${SAMPLE_ID}/virome_discovery/VIBRANT/
cp ${TMPDIR}/${SAMPLE_ID}/VIBRANT_${SAMPLE_ID}_contigs.min1kbp.AA/VIBRANT_phages_${SAMPLE_ID}_contigs.min1kbp.AA/${SAMPLE_ID}_contigs.min1kbp.AA.phages_combined.txt \
	../SAMPLES/${SAMPLE_ID}/virome_discovery/VIBRANT/

conda list
conda deactivate

module list
§
module purge
