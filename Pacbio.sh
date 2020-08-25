###Three-generation sequencing


#1. Data download
#Download greg200k data with a genome size of only 200kb, and E. coli data with a genome size of 4.6Mb
~$ curl -L https://downloads.pacbcloud.com/public/data/git-sym/greg200k-sv2.tar
~$ curl -L https://downloads.pacbcloud.com/public/data/git-sym/ecoli.m140913_050931_42139_c100713652400000001823152404301535_s1_p0.subreads.tar
~$ tar -xvf greg200k-sv2.tar
~$ tar -xvf ecoli.m140913_050931_42139_c100713652400000001823152404301535_s1_p0.subreads.tar
#Original data is too big, 39920 lines before cut get .cut.fastq
~$ head -39920 ecoli.3.fasta> ecoli.3.cut.fasta

#2. Preliminary quality control


###3. Subreads three-generation assembly after quality control
#纯三代assembly software, mainly including: Falcon, Canu
#Pure three-generation assembly adopts OLC algorithm (overlap-layout-consensus)

#3.1 Falcon software assembly
#3.1.1 conda installation
~$ conda create -n pb-assembly pb-assembly
~$ source activate pb-assembly
#If an error is reported, you may also need to install the following commands:
$conda install python=2.7.13 #or higher version
$conda install python-intervaltree=2.1.0
$conda update --all
$conda update -c bioconda --all
$conda install pbmm2=0.12.0
$conda install pbcore=1.6.5
$conda install pbalign=0.3.2
#3.1.2 Configuration file-assembly
#Write the absolute path of the sequencing file into the input_fofn text. It is recommended to put the file in the same level directory of the fc_run.cfg file, so that there is no need to change the path of the configuration file.
~$ ls -R /home/minminli/pacbio/data/ecoli.subreads/ecoli.*.fasta> input_fofn
#Configuration file fc_run.cfg It is best to download the template and modify it, otherwise it is easy to make mistakes. It controls the parameters used in each stage of the Falcon assembly. However, at the beginning, we did not know which parameter is the best. It usually requires constant adjustment. Of course, since many species have used Falcon for assembly, they can learn from their configuration files.
~$ wget https://pb-falcon.readthedocs.io/en/latest/_downloads/fc_run_ecoli_local.cfg
#Run assembly assembly
~$ fc_run fc_run.cfg
#falcon-unzip can assemble polyploid\Find SNP
~$fc_unzip.py fc_unzip.cfg
#3.1.3 FALCON's result file:
#0-rawreads/, this directory stores the results of overlpping analysis and correction of raw subreads;
0-rawreads/cns-runs/cns_*/*/*.fasta stores the corrected sequence information. 1-preads_ovl/, this directory stores the result of overlapped reads after correction. 2-asm-falcon/, this directory is the final result directory, and the final main result file generated is 2-asm-falcon/p_ctg.fa.

#3.2 Canu software assembly
#3.2.1 conda installation
~$ conda create -n canu canu
~$ source activate canu
#3.2.2 Data download
#3.2.3 Assembly
##Basic parameters: -p output file prefix, must be specified; -d output folder; Threads thread number; gnuplotTested detects whether there is a gnuplot program, gnuplotTested=true can skip the check; gnuplotImageFormat uses gnuplot to generate the image format; genomeSize estimation Genome size; minReadLength read length less than this value will not be used for assembly; -pacbio-raw raw sequencing file.
~$ cat *.fasta> merge.fasta
#(1)Error correction
~$ canu -correct \
    -p ecoli -d /home/minminli/pacbio/canu/data/ecoli2/ \
    corThreads=32 corOutCoverage=120 corMinCoverage=2 \
    gnuplotTested=true \
    genomeSize=500k minReadLength=1000 minOverlapLength=500 \
    maxMemory=500g maxThreads=32 \
    ovsMemory=1-32G ovsThreads=16 ovsConcurrency=16 \
    ovbMemory=1g ovbConcurrency=16 oeaThreads=16 \
    -pacbio-raw ./merge.fasta
#(2)Finishing
~$ canu -trim \
    -p ecoli -d /home/minminli/pacbio/canu/data/ecoli2/ \
    gnuplotTested=true \
    genomeSize=500k minReadLength=1000 minOverlapLength=500 \
    maxMemory=500g maxThreads=32 \
    ovsMemory=1-32G ovsThreads=16 ovsConcurrency=16 \
    ovbMemory=1g ovbConcurrency=16 oeaThreads=16 \
    -pacbio-corrected ./ecoli.correctedReads.fasta.gz
#(3)Assemble
#This step mainly adjusts the error rate of the sequence after error correction, correctedErrorRate, which will affect utgOvlErrorRate. You can try multiple parameters in this step, because the speed is relatively block.
~$ canu -assemble \
    -p ecoli -d /home/minminli/pacbio/canu/data/ecoli2/ \
    gnuplotTested=true \
    genomeSize=500k minReadLength=1000 minOverlapLength=500 \
    maxMemory=500g maxThreads=32 \
    ovsMemory=1-32G ovsThreads=16 ovsConcurrency=16 \
    ovbMemory=1g ovbConcurrency=16 oeaThreads=16 \
    correctedErrorRate=0.050 \
    -pacbio-corrected ./ecoli.trimmedReads.fasta.gz
#The ath.contigs.fasta under the final output file is the result file.

#3.3 Merge optimizes the results of different software assembly


#3.3 Optimize assembly results
blasr
arrow

#3.4 Further QUAST and BUSCO evaluations of the assembled results
#View the report after running quast/report.html
~$ quast.py -o quast_mecat2 mecat2/Paenibacillus_sp.R4/4-fsa/contigs.fasta


#3.5 Genome polish
#Pilon can polish the initially assembled genome to improve the assembly result.
#(1) Preprocessing: Generate bam file
#(2)Run:
#--genome: genes to be proofread; frags: bam files generated by Reads (sorted); --output: output file prefix; --outdir: output folder; --threads: number of calling threads; --diploid: waiting The analyzed species is diploid; --fix bases: used when only second-generation data is available; --vcf: used when only second-generation data is available; --changes: used when only second-generation data is available;
~$ pilon \
  --genome h1.contigs.fasta \
  --frags h1.contigs.fasta.sorted.bam \
  --output h1_pilon \
  --outdir h1_pilon \
  --threads 24 \
  --diploid


#Whether the collinearity analysis is circular after assembly
