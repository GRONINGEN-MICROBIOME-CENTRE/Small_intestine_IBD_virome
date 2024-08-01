##########################################
# cleaning ETOF & getting the dereplication
# stat
##########################################
args = commandArgs(trailingOnly=TRUE)
##############################
# Loading libraries
##############################
library(readr)
##############################
# Functions
##############################

##############################
# Input data
##############################

##############################
# ANALYSIS
##############################
Extended_TOF <- read_delim(paste0(args[1]))
clean_dereplicated <- read.table(paste0(args[2]), sep='\t', header=F)

Extended_TOF <- Extended_TOF[Extended_TOF$New_CID %in% clean_dereplicated $V1,]

##############################
# OUTPUT
##############################
write.table(Extended_TOF[,"New_CID"], paste0(dirname(args[1]), '/NONEG_deRep_RNA_virus_IDs'), sep='\t', row.names=F, col.names=F, quote=F)
write.table(Extended_TOF, paste0(dirname(args[1]), '/Extended_TOF_filtered'), sep='\t', row.names=F, col.names=T, quote=F)
