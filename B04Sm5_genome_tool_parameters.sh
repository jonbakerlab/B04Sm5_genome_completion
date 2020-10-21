## Quality control of read libraries  ##
# Quality control of short (Illumina) reads using Kneaddata
kneaddata \
    -i illumina_reads_raw_1.fastq \
    -i illumina_reads_raw_2.fastq \
    -o illumina_reads_qc \
    --trimmomatic-options SLIDINGWINDOW:4:20 \
    --trimmomatic-options MINLEN:90

# Quality control of long (Oxford Nanopore) reads using filtlong
#  (in addition to length target bases cutoffs, filters out long reads that don't have k-mer matches to the short read library)
filtlong \
    -1 illumina_reads_qc_1.fastq \
    -2 illumina_reads_qc_2.fastq \
    --min_length 10000 \
    --target_bases 100000000 \
    --trim \
    --split 100 \
    nanopore_reads_raw.fastq > filtered_nanopore_reference_split.fastq

## Generation of draft assemblies ##
# flye
flye \
    --nano-raw filtered_nanopore_reference_split.fastq \
    --genome-size 2m \
    --threads 32 \
    --out-dir flye_output

# hybridSPAdes
spades.py \
    -1 illumina_reads_qc_1.fastq \
    -2 illumina_reads_qc_2.fastq \
    --nanopore filtered_nanopore_reference_split.fastq \
    -t 32 \
    -m 750 \
    -o spades_output/

# Unicycler
unicycler \
    -1 illumina_reads_qc_1.fastq \
    -2 illumina_reads_qc_2.fastq \
    -l nanopore filtered_nanopore_reference_split.fastq \
    --threads 32 \
    -o unicycler_output

# Generating a consensus assembly using Trycycler
trycycler cluster \
    --assemblies assemblies/*.fasta \
    --reads nanopore_reads_raw.fastq \
    --threads 32 \
    --out_dir trycycler_cluster

trycycler reconcile \
    --reads reads.fastq \
    --cluster_dir trycycler_cluster/cluster_001 \
    --threads 48 \
    --max_add_seq 1100

trycycler msa \
    --cluster_dir trycycler_cluster2/cluster_001/ \
    --threads 48

trycycler partition \
    --reads nanopore_reads_raw.fastq \
    --cluster_dirs trycycler_cluster2/cluster_001/ \
    --threads 48

trycycler consensus \
    --cluster_dir trycycler/cluster_001 \
    --threads 48

## Polishing the final consensus
# Polishing the final consensus with the long read library using medaka
medaka_consensus \
    -i nanopore_reads_raw.fastq \
    -d trycycler_cluster/cluster_001/7_final_consensus.fasta \
    -o medaka \
    -m r941_min_high_g360 \
    -t 48

# Polishing the final consensus with the short read libraries using Pilon
#multiple rounds of pilon were performed until no further changes occurred

pilon \
    --genome "$before".fasta \
    --frags illumina_alignments.bam \
    --unpaired illumina_alignments_u.bam \
    --output "$after" \
    --changes