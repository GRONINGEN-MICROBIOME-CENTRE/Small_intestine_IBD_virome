##########################################
# Filtering virus contigs prior to 
# dereplication with virus contigs disco-
# vered using MGS data
##########################################
args = commandArgs(trailingOnly=TRUE)
##############################
# Loading libraries
##############################
library(dplyr)
##############################
# Functions
##############################

##############################
# Input data
##############################
contigs_metadata <- read.table(paste0(args[1], 'Extended_table_of_origin'), sep='\t', header=T)

contigs_metadata <- contigs_metadata %>%
  mutate(
    RNA_virus = ifelse(grepl('Riboviria', taxonomy), "Yes", "No"),
    chimera = ifelse(grepl('contig >1.5x longer', warnings), "Yes", "No")
  )
##############################
# ANALYSIS
##############################
to_drep_MGS <- contigs_metadata %>%
  filter(plasmid != "Yes", # filter contigs recognized as plasmids by geNomad
         viral_genes > 0,  # filter contigs that have no viral genes
         viral_genes > host_genes, # filter contigs that have more or equal number of host genes compared to viral genes
         chimera != "Yes", # filter contigs that have a chimera warning
         checkv_quality %in% c("Complete", "High-quality", "Medium-quality")) # filter contigs of low or undetermined quality
##############################
# OUTPUT
##############################
write.table(to_drep_MGS[to_drep_MGS$RNA_virus!="Yes",], paste0(args[1], 'SIV_DNA_virus_contigs_filtered'), sep = '\t', row.names = F, quote=F)
write.table(to_drep_MGS[to_drep_MGS$RNA_virus!="No",], paste0(args[1], 'SIV_RNA_virus_contigs_filtered'), sep = '\t', row.names = F, quote=F)
