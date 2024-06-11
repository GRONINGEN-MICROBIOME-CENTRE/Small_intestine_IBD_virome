#!/bin/bash
#SBATCH --job-name=PostDiscovery
#SBATCH --output=./out/09.pdf/PD_filtering_and_extraction.out
#SBATCH --mem=8gb
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=2

# concatenating all pruned and renamed contigs after full virus discovery

mkdir -p ../VIR_DB/contigs

for i in $(cat ../sample.list_upd); do
	cat ../SAMPLES/${i}/virome_discovery/tidy/${i}_extended_pruned_viral_renamed.fasta >> ../VIR_DB/contigs/All_VD_virus_contigs.fasta
done

# --- LOADING MODULES ---
module load R
module load seqtk/1.3-GCC-11.3.0
module list

# filtering viruses based on their metadata
Rscript Filtering_pruned_contigs.R ../VIR_DB/table_of_origin/

# Creating the DNA virus fasta:
awk 'NR > 1 {print $1}' \
	../VIR_DB/table_of_origin/SIV_DNA_virus_contigs_filtered \
	> ../VIR_DB/table_of_origin/SIV_DNA_virus_contigs_filtered_IDs  

# pulling all DNA viruses of substantial quality:
seqtk \
        subseq \
        -l60 \
        ../VIR_DB/contigs/All_VD_virus_contigs.fasta \
        ../VIR_DB/table_of_origin/SIV_DNA_virus_contigs_filtered_IDs \
        > ../VIR_DB/contigs/SIV_DNA_virus_contigs_filtered.fasta

# Creating the RNA virus fasta:
awk 'NR > 1 {print $1}' \
        ../VIR_DB/table_of_origin/SIV_RNA_virus_contigs_filtered \
        > ../VIR_DB/table_of_origin/SIV_RNA_virus_contigs_filtered_IDs

# pulling all RNA viruses of substantial quality:
seqtk \
        subseq \
        -l60 \
        ../VIR_DB/contigs/All_VD_virus_contigs.fasta \
        ../VIR_DB/table_of_origin/SIV_RNA_virus_contigs_filtered_IDs \
        > ../VIR_DB/contigs/SIV_RNA_virus_contigs_filtered.fasta

module purge
