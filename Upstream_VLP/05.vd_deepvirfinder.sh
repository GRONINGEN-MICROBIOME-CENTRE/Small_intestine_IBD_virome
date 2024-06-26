#!/bin/bash
#SBATCH --job-name=ViromeDiscovery
#SBATCH --output=./out/05.dvf/VD_SI_%A_%a.out
#SBATCH --mem=16gb
#SBATCH --time=12:59:00
#SBATCH --cpus-per-task=8

SAMPLE_LIST=$1

echo ${SAMPLE_LIST}

SAMPLE_ID=$(sed "${SLURM_ARRAY_TASK_ID}q;d" ${SAMPLE_LIST})

echo "SAMPLE_ID=${SAMPLE_ID}"

mkdir -p ../SAMPLES/${SAMPLE_ID}/virome_discovery/DeepVirFinder

# --- LOAD MODULES --- 
module purge
module load Anaconda3
source activate /scratch/hb-llnext/conda_envs/DeepVirFinder_env

# --- RUNNING VIRSORTER2 ---
echo "> Running DeepVirFinder"

python /scratch/hb-llnext/conda_envs/DeepVirFinder_env/DeepVirFinder/dvf.py \
	-i ../SAMPLES/${SAMPLE_ID}/01_sc_assembly/${SAMPLE_ID}_contigs.min1kbp.fasta \
	-o ../SAMPLES/${SAMPLE_ID}/virome_discovery/DeepVirFinder/ \
	-l 1000

conda list
conda deactivate

module list

module purge
