#!/bin/bash
#SBATCH --job-name=SI_virome_QC
#SBATCH --output=./out/02.rQC/SI_virome_%A_%a.out
#SBATCH --mem=90gb
#SBATCH --time=05:59:00
#SBATCH --cpus-per-task=2

SAMPLE_LIST=$1

echo ${SAMPLE_LIST}

SAMPLE_ID=$(sed "${SLURM_ARRAY_TASK_ID}q;d" ${SAMPLE_LIST})

echo "SAMPLE_ID=${SAMPLE_ID}"

# --- WORKING IN $TMPDIR ---
mkdir -p ${TMPDIR}/${SAMPLE_ID}/filtering_data/

echo "> copying files to tmpdir"
cp ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_1.fq.gz ${TMPDIR}/${SAMPLE_ID}/filtering_data/
cp ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_2.fq.gz ${TMPDIR}/${SAMPLE_ID}/filtering_data/

# --- LOADING MODULES --- 
module purge
module load BBMap

# --- TRIMMING ADAPTERS ---
echo "> Trimming adapters" 

bbduk.sh \
        in1=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_1.fq.gz \
        in2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_2.fq.gz \
        out1=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_AdaptTr_1.fastq.gz \
        out2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_AdaptTr_2.fastq.gz \
        ref=/scratch/p282752/Data_for_HiC/adapters_UPD_IDT.fa \
        ktrim=r k=23 mink=11 hdist=1 tpe tbo 2>&1 \
        threads=${SLURM_CPUS_PER_TASK} \
        -Xmx$((${SLURM_MEM_PER_NODE} / 1024))g | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

# --- REMOVING RAW READS FASTQS---
echo "> Removing raw reads"

rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_1.fq.gz
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_2.fq.gz

# --- CHECKING PAIREDNESS AFTER ADAPTER TRIMMING ---
echo "> Check pairedness of adapter-trimmed fastqs"

reformat.sh \
	in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_AdaptTr_1.fastq.gz \
	in2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_AdaptTr_2.fastq.gz \
	vpair 2>&1 | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

# --- FILTERING HUMAN READS & LOW QUALITY READS ---
echo "> Loading Anaconda3 and conda environment"

module load Anaconda3/2022.05
conda activate /scratch/hb-tifn/condas/conda_biobakery3/

kneaddata \
	--input ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_AdaptTr_1.fastq.gz \
        --input ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_AdaptTr_2.fastq.gz \
        --threads ${SLURM_CPUS_PER_TASK} \
        --processes 4 \
        --output-prefix ${SAMPLE_ID}_kneaddata \
        --output ${TMPDIR}/${SAMPLE_ID}/filtering_data \
        --log ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_kneaddata.log \
        -db /scratch/hb-tifn/DBs/human_genomes/GRCh38p13  \
        --trimmomatic /scratch/hb-tifn/condas/conda_biobakery4/share/trimmomatic-0.39-2/ \
        --run-trim-repetitive \
        --fastqc fastqc \
        --sequencer-source none \
        --trimmomatic-options "LEADING:20 TRAILING:20 SLIDINGWINDOW:4:20 MINLEN:50" \
        --bypass-trf \
        --reorder

# --- REMOVING KNEADDATA BYPRODUCTS AND ADAPTER TRIMMED FASTQS ---
echo "> Removing kneaddata byproducts and adapter-trimmed fastqs"

rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_AdaptTr_1.fastq.gz
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_AdaptTr_2.fastq.gz
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_GRCh38p13_bowtie2_paired_contam_1.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_GRCh38p13_bowtie2_paired_contam_2.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_GRCh38p13_bowtie2_unmatched_1_contam.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_GRCh38p13_bowtie2_unmatched_2_contam.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata.trimmed.1.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata.trimmed.2.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata.trimmed.single.1.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata.trimmed.single.2.fastq

# --- CHECKING PAIREDNESS OF KNEADDATA-FILTERED READS ---
echo "> Check pairedness of kneaddata-filtered reads"

reformat.sh \
        in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_paired_1.fastq \
        in2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_paired_2.fastq \
        vpair 2>&1 | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

# --- COPYING KNEADDATA-PROCESSED READS TO SCRATCH ---
mkdir -p ../SAMPLES/${SAMPLE_ID}/clean_reads/
cp ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_paired_*.fastq ../SAMPLES/${SAMPLE_ID}/clean_reads/
cat ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_unmatched_*.fastq > ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_kneaddata_unmatched.fastq
pigz -p ${SLURM_CPUS_PER_TASK} ../SAMPLES/${SAMPLE_ID}/clean_reads/*.fastq

# --- LAUNCHING META ASSEMBLY ---         
echo "> Launching meta assembly"
bash runAllSamples_meta.bash ${SAMPLE_ID}

# --- CORRECTING READ ERRORS IN PAIRED READS ---
echo "> Correcting of read errors"

tadpole.sh \
        in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_paired_1.fastq \
        in2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_paired_2.fastq \
        out=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_paired_1.fastq \
        out2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_paired_2.fastq \
        mode=correct \
        ecc=t \
        prefilter=2 2>&1 \
        threads=${SLURM_CPUS_PER_TASK} \
        -Xmx$((${SLURM_MEM_PER_NODE} / 1024))g | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

# --- CORRECTING READ ERRORS IN UNMATCHED READS ---

tadpole.sh \
        in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_unmatched_1.fastq \
        out=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_unmatched_1.fastq \
        mode=correct \
        ecc=t \
        prefilter=2 2>&1 \
        threads=${SLURM_CPUS_PER_TASK} \
        -Xmx$((${SLURM_MEM_PER_NODE} / 1024))g | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

tadpole.sh \
        in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_unmatched_2.fastq \
        out=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_unmatched_2.fastq \
        mode=correct \
        ecc=t \
        prefilter=2 2>&1 \
        threads=${SLURM_CPUS_PER_TASK} \
        -Xmx$((${SLURM_MEM_PER_NODE} / 1024))g | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

# --- REMOVING KNEADDATA PAIRED AND UNMATCHED FASTQS ---
echo "> Removing kneaddata paired and unmatched reads"

rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_paired_1.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_paired_2.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_unmatched_1.fastq
rm ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_kneaddata_unmatched_2.fastq

# --- CHECKING PAIREDNESS OF ERROR-CORRECTED READS ---
echo "> Check pairedness of error-corrected reads"

reformat.sh \
        in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_paired_1.fastq \
        in2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_paired_2.fastq \
        vpair 2>&1 | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

# --- DEDUPLICATING READS ---
echo "> Deduplicating reads"

clumpify.sh \
        in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_paired_1.fastq \
        in2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_paired_2.fastq \
        out=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_paired_1.fastq \
        out2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_paired_2.fastq \
        dedupe=t \
        subs=0 \
        deletetemp=t 2>&1 \
       threads=${SLURM_CPUS_PER_TASK} \
       -Xmx$((${SLURM_MEM_PER_NODE} / 1024))g | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

clumpify.sh \
        in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_unmatched_1.fastq \
        out=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_unmatched_1.fastq \
        dedupe=t \
        subs=0 \
        deletetemp=t 2>&1 \
       	threads=${SLURM_CPUS_PER_TASK} \
       -Xmx$((${SLURM_MEM_PER_NODE} / 1024))g | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

clumpify.sh \
        in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_ECC_unmatched_2.fastq \
        out=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_unmatched_2.fastq \
        dedupe=t \
        subs=0 \
        deletetemp=t 2>&1 \
        threads=${SLURM_CPUS_PER_TASK} \
       -Xmx$((${SLURM_MEM_PER_NODE} / 1024))g | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log

# --- CHECKING PAIREDNESS OF DEDUPLICATED READS ---
echo "> Check pairedness of deduplicated reads"

reformat.sh \
        in=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_paired_1.fastq \
        in2=${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_paired_2.fastq \
        vpair 2>&1 | tee -a ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_reformat_clumpify.log

# --- SWITCHING TO SCRATCH ---
echo "> Moving resulting clean reads to scratch"

if [ $(grep 'Done!' ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_bbduk.log | wc -l) == 3 ]; then
	echo "Clumpify is done"
	mv ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_paired_1.fastq ../SAMPLES/${SAMPLE_ID}/clean_reads/
	mv ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_paired_2.fastq ../SAMPLES/${SAMPLE_ID}/clean_reads/
	mv ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_unmatched_1.fastq ../SAMPLES/${SAMPLE_ID}/clean_reads/
	mv ${TMPDIR}/${SAMPLE_ID}/filtering_data/${SAMPLE_ID}_dedup_unmatched_2.fastq ../SAMPLES/${SAMPLE_ID}/clean_reads/
else
	echo "Deduplication or an earlier step is corrupted"
fi

# --- REMOVING DATA FROM TMPDIR ---
echo "> Removing data from tmpdir"
rm -r ${TMPDIR}/${SAMPLE_ID}/filtering_data


if [ -f ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_paired_1.fastq ] && [ $(grep 'Names appear to be correctly paired.' ../SAMPLES/${SAMPLE_ID}/${SAMPLE_ID}_reformat_clumpify.log | wc -l) == 1 ]; then
# --- CONCATENATING UNMATCHED READS ---	
	cat ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_unmatched_1.fastq \
	../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_unmatched_2.fastq > \
	../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_unmatched.fastq
	
# --- COMPRESSING ALL FASTQS ---	
	echo ">Compressing reads"
	pigz -p ${SLURM_CPUS_PER_TASK} ../SAMPLES/${SAMPLE_ID}/clean_reads/*.fastq

# --- GENERATING MD5SUMS FOR STORAGE --- 	
	echo "> Generating md5sums"
	md5sum ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_paired_1.fastq.gz > ../SAMPLES/${SAMPLE_ID}/MD5.txt
	md5sum ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_paired_2.fastq.gz >> ../SAMPLES/${SAMPLE_ID}/MD5.txt
	md5sum ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_unmatched_1.fastq.gz >> ../SAMPLES/${SAMPLE_ID}/MD5.txt
	md5sum ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_unmatched_2.fastq.gz >> ../SAMPLES/${SAMPLE_ID}/MD5.txt

# --- CHECKING QUALITY OF CLEAN READS ---
	module load FastQC
        fastqc -o ../01.MIDWAY/02.FastQC_postQC -t ${SLURM_CPUS_PER_TASK} ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_paired_1.fastq.gz
        fastqc -o ../01.MIDWAY/02.FastQC_postQC -t ${SLURM_CPUS_PER_TASK} ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_paired_2.fastq.gz
        fastqc -o ../01.MIDWAY/02.FastQC_postQC -t ${SLURM_CPUS_PER_TASK} ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_unmatched_1.fastq.gz
        fastqc -o ../01.MIDWAY/02.FastQC_postQC -t ${SLURM_CPUS_PER_TASK} ../SAMPLES/${SAMPLE_ID}/clean_reads/${SAMPLE_ID}_dedup_unmatched_2.fastq.gz

# --- LAUNCHING SC ASSEMBLY --- 	
	echo "> Launching sc assembly"
	bash runAllSamples_sc.bash ${SAMPLE_ID}

# --- LAUNCHING VIROMEQC --- 
	echo "> Launching ViromeQC"
	bash runAllSamples_vqc.bash ${SAMPLE_ID}
fi

module list

module purge

