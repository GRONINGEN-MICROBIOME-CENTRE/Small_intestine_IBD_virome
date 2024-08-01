#!/bin/bash
#SBATCH --job-name=PostDiscovery_virRNA_deRep
#SBATCH --output=./out/09.drp/PD_virRNA_dereplication.out
#SBATCH --mem=32gb
#SBATCH --time=04:30:00
#SBATCH --cpus-per-task=4
#SBATCH --open-mode=truncate

mkdir -p ../VIR_DB/RNA_VIR_DEREPLICATION

# --- CONCATENATING ALL PUTATIVE VIRUS CONTIGS & THEIR ETOF---
# own viruses
cat ../VIR_DB/contigs/SIV_RNA_virus_contigs_filtered.fasta > ../VIR_DB/RNA_VIR_DEREPLICATION/RNA_viruses_filt_all.fasta

cat ../VIR_DB/table_of_origin/SIV_RNA_virus_contigs_filtered_IDs > ../VIR_DB/RNA_VIR_DEREPLICATION/all_RNA_virus_ids

cat ../VIR_DB/table_of_origin/SIV_RNA_virus_contigs_filtered > ../VIR_DB/RNA_VIR_DEREPLICATION/ETOF

# RNA viruses from viral refseq
cat ../VIR_DB/viral_refseq_216_RNA.fna >> ../VIR_DB/RNA_VIR_DEREPLICATION/RNA_viruses_filt_all.fasta

cat ../VIR_DB/viral_refseq_216_RNA_ids >> ../VIR_DB/RNA_VIR_DEREPLICATION/all_RNA_virus_ids

awk 'NR>1' /scratch/p282752/databases/viral_refseq_apr_24/Extended_TOF_simulated | sed 's/VREF_//g' >> ../VIR_DB/RNA_VIR_DEREPLICATION/ETOF

# IMGVR:
cat /scratch/p282752/databases/IMGVR_13012024/IMGVR_Sequence_human_hq_Riboviria.fasta >> ../VIR_DB/RNA_VIR_DEREPLICATION/RNA_viruses_filt_all.fasta

cat /scratch/p282752/databases/IMGVR_13012024/IMGVR_Sequence_human_hq_Riboviria_ids >> ../VIR_DB/RNA_VIR_DEREPLICATION/all_RNA_virus_ids

awk 'NR>1' /scratch/p282752/databases/IMGVR_13012024/Extended_TOF >> ../VIR_DB/RNA_VIR_DEREPLICATION/ETOF

# FILTERING VIRUS CONTIGS ACCORDING TO CHECKV QUALITY, N VIRAL GENES AND K-MER FREQ

# from all negative and positive controls:
for SAMPLE_ID in $(cat ../controls.list); do
       cat ../SAMPLES/${SAMPLE_ID}/virome_discovery/tidy/${SAMPLE_ID}_extended_pruned_viral_renamed.fasta >> \
                ../VIR_DB/RNA_VIR_DEREPLICATION/RNA_viruses_filt_all.fasta
done

# --- LOAD MODULES ---
module purge
module load BLAST+/2.13.0-gompi-2022a 
module list

# --- DEREPLICATION ACCORDING TO MIUViG GUIDELINES ---

# DECONTAMINATION: removal of sequences dereplicating with control sequences

mkdir ../VIR_DB/RNA_VIR_DEREPLICATION/DECONTAMINATION

# First, create a blast+ database:
makeblastdb \
    -in ../VIR_DB/RNA_VIR_DEREPLICATION/RNA_viruses_filt_all.fasta \
    -dbtype nucl \
    -out ../VIR_DB/RNA_VIR_DEREPLICATION/DECONTAMINATION/RNA_VIR_DB

# Next, use megablast from blast+ package to perform all-vs-all blastn of sequences:
blastn \
    -query ../VIR_DB/RNA_VIR_DEREPLICATION/RNA_viruses_filt_all.fasta \
    -db ../VIR_DB/RNA_VIR_DEREPLICATION/DECONTAMINATION/RNA_VIR_DB \
    -outfmt '6 std qlen slen' \
    -max_target_seqs 10000 \
    -out ../VIR_DB/RNA_VIR_DEREPLICATION/DECONTAMINATION/RNA_viruses_blast.tsv \
    -num_threads ${SLURM_CPUS_PER_TASK}

echo "all-vs-all blastn done!"

# --- LOAD MODULES --- 
module purge
module load Python/3.10.8-GCCcore-12.2.0
module load CheckV/1.0.1-foss-2021b-DIAMOND-2.1.8
module list

# Next, calculate pairwise ANI by combining local alignments between sequence pairs:
python /scratch/p282752/tools/checkv_scripts/anicalc.py \
	-i ../VIR_DB/RNA_VIR_DEREPLICATION/DECONTAMINATION/RNA_viruses_blast.tsv \
	-o ../VIR_DB/RNA_VIR_DEREPLICATION/DECONTAMINATION/RNA_viruses_ani.tsv

# anicalc.py is available at https://bitbucket.org/berkeleylab/checkv/src/master/scripts/anicalc.py

# Finally, perform UCLUST-like clustering using the MIUVIG recommended-parameters (95% ANI + 85% AF):
python /scratch/p282752/tools/checkv_scripts/aniclust.py \
    --fna ../VIR_DB/RNA_VIR_DEREPLICATION/RNA_viruses_filt_all.fasta \
    --ani ../VIR_DB/RNA_VIR_DEREPLICATION/DECONTAMINATION/RNA_viruses_ani.tsv \
    --out ../VIR_DB/RNA_VIR_DEREPLICATION/DECONTAMINATION/RNA_viral_clusters.tsv \
    --min_ani 99 \
    --min_tcov 85 \
    --min_qcov 0

# aniclust.py is available at https://bitbucket.org/berkeleylab/checkv/src/master/scripts/aniclust.py

# Removing clusters containing control sequences:
grep \
-vE "VCTRL" ../VIR_DB/RNA_VIR_DEREPLICATION/DECONTAMINATION/RNA_viral_clusters.tsv | \
	awk -F '\t' '{print $2}' | \
	tr , '\n' | sort | uniq \
	> ../VIR_DB/RNA_VIR_DEREPLICATION/ALL_VIRUS_NO_NEG_99_IDs

# --- LOAD MODULES ---
module purge
module load seqtk/1.3-GCC-11.3.0

# Creating a fasta-file with all virus seqeunces that do not cluster with control seqeunces at "strain" level:
seqtk \
        subseq \
        -l60 \
        ../VIR_DB/RNA_VIR_DEREPLICATION/RNA_viruses_filt_all.fasta \
        ../VIR_DB/RNA_VIR_DEREPLICATION/ALL_VIRUS_NO_NEG_99_IDs \
        > ../VIR_DB/RNA_VIR_DEREPLICATION/ALL_VIRUS_NO_NEG_99.fasta

# DEREPLICATION: species-level
mkdir ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION

# --- LOAD MODULES ---
module purge
module load BLAST+/2.13.0-gompi-2022a
module list

# First, create a blast+ database:
makeblastdb \
    -in ../VIR_DB/RNA_VIR_DEREPLICATION/ALL_VIRUS_NO_NEG_99.fasta \
    -dbtype nucl \
    -out ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION/NO_NEG_RNA_VIR_DB

# Next, use megablast from blast+ package to perform all-vs-all blastn of sequences:
blastn \
    -query ../VIR_DB/RNA_VIR_DEREPLICATION/ALL_VIRUS_NO_NEG_99.fasta \
    -db ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION/NO_NEG_RNA_VIR_DB \
    -outfmt '6 std qlen slen' \
    -max_target_seqs 10000 \
    -out ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION/NO_NEG_RNA_viruses_blast.tsv \
    -num_threads ${SLURM_CPUS_PER_TASK}

echo "all-vs-all blastn done!"

# --- LOAD MODULES --- 
module purge
module load Python/3.10.8-GCCcore-12.2.0
module load CheckV/1.0.1-foss-2021b-DIAMOND-2.1.8
module list

# Next, calculate pairwise ANI by combining local alignments between sequence pairs:
python /scratch/p282752/tools/checkv_scripts/anicalc.py \
        -i ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION/NO_NEG_RNA_viruses_blast.tsv \
	-o ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION/NO_NEG_RNA_viruses_ani.tsv

# anicalc.py is available at https://bitbucket.org/berkeleylab/checkv/src/master/scripts/anicalc.py

# Finally, perform UCLUST-like clustering using the MIUVIG recommended-parameters (95% ANI + 85% AF):
python /scratch/p282752/tools/checkv_scripts/aniclust.py \
    --fna ../VIR_DB/RNA_VIR_DEREPLICATION/ALL_VIRUS_NO_NEG_99.fasta \
    --ani ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION/NO_NEG_RNA_viruses_ani.tsv \
    --out ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION/NO_NEG_RNA_viral_clusters.tsv \
    --min_ani 95 \
    --min_tcov 85 \
    --min_qcov 0

# aniclust.py is available at https://bitbucket.org/berkeleylab/checkv/src/master/scripts/aniclust.py

# Creating a fasta-file with vOTU representatives:

# --- LOAD MODULES ---
module purge
module load R

# Getting VC clustering info
Rscript dereplication_stat.R ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION/NO_NEG_RNA_viral_clusters.tsv

cut -f 1 ../VIR_DB/RNA_VIR_DEREPLICATION/DEREPLICATION/NO_NEG_RNA_viral_clusters.tsv > ../VIR_DB/RNA_VIR_DEREPLICATION/NONEG_deRep_RNA_virus_IDs
# FIltering ETOF
Rscript ETOF_filtering.R ../VIR_DB/RNA_VIR_DEREPLICATION/ETOF \
	../VIR_DB/RNA_VIR_DEREPLICATION/NONEG_deRep_RNA_virus_IDs

# --- LOAD MODULES ---
module purge
module load seqtk/1.3-GCC-11.3.0

seqtk \
        subseq \
        -l60 \
        ../VIR_DB/RNA_VIR_DEREPLICATION/ALL_VIRUS_NO_NEG_99.fasta \
        ../VIR_DB/RNA_VIR_DEREPLICATION/NONEG_deRep_RNA_virus_IDs \
        > ../VIR_DB/RNA_VIR_DEREPLICATION/RNA_vOTU_representatives_noneg_der95.fasta


module purge
