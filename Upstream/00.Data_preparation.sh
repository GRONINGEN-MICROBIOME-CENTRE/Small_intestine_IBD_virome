#!/bin/bash

# --- COPYING FILES ---
rsync -av /scratch/hb-tifn/VLP/X201SC22060533-Z01-F003/01.RawData /scratch/p282752/ANALYSIS_SI

# --- CREATING SAMPLE LIST ---
ls /scratch/p282752/ANALYSIS_SI/01.RawData > /scratch/p282752/ANALYSIS_SI/sample.list

# --- CHECKING THAT ALL FILES COPIED CORRECTLY ---
cd /scratch/p282752/ANALYSIS_SI/01.RawData

for i in $(cat ../sample.list); do 
	cd ./${i} 
	md5sum --check MD5.txt >> /scratch/p282752/ANALYSIS_SI/Check_MD5 
	cd .. 
done

cd /scratch/p282752/ANALYSIS_SI

if [ $(cat Check_MD5 | wc -l) -eq $(grep 'OK' Check_MD5 | wc -l) ]; then
	echo "All files got copied correctly"
fi

# --- CREATE/RENAME SOME FOLDERS ---
mv 01.RawData SAMPLES # the majority of my scripts use relative paths, so it is more convenient
mkdir -p 01.MIDWAY/01.FastQC_preQC
mkdir -p 01.MIDWAY/02.FastQC_postQC


