
nextflow.enable.dsl = 2

include { FASTP } from './modules/fastp.nf'
include { CHECK_STRANDNESS } from './modules/check_strandness.nf'
include { HISAT2_INDEX_REFERENCE ; HISAT2_ALIGN ; EXTRACT_SPLICE_SITES ; EXTRACT_EXONS } from './modules/hisat2.nf'
include { SAMTOOLS ; SAMTOOLS_MERGE } from './modules/samtools.nf'
include { CUFFLINKS } from './modules/cufflinks.nf'

log.info """\
         RNAseq differential analysis using NextFlow 
         =============================
         genome: ${params.reference_genome}
         annot : ${params.reference_annotation}
         reads : ${params.reads}
         outdir: ${params.outdir}
         """
         .stripIndent()
 
params.outdir = 'results'

process split_fastq {
    
    input: 
    tuple val(name), path(fastq)

    output:
    tuple val(name), path("*${name}*R1*.f*q"), path("*${name}*R2*.f*q")

    script:
    """ 
    ${params.baseDir}/bin/splitFastq -i ${fastq[0]} -n ${params.split} -o ${fastq[0].getBaseName()} 
    ${params.baseDir}/bin/splitFastq -i ${fastq[1]} -n ${params.split} -o ${fastq[1].getBaseName()} 

    """
}

process split_fastq_unzipped {

    input:
    tuple val(name), path(fastq)

    output:
    tuple val(name), path("${name}_1-${/[0-9]/*params.suffix_length}.fq"), path("${name}_2-${/[0-9]/*params.suffix_length}.fq")

    script:
    """
    cat ${fastq[0]} | split \\
        -a ${params.suffix_length} \\
        -d \\
        -l ${params.num_lines} \\
        - \\
        ${fastq[0].getBaseName()}- \\
        --additional-suffix=".fq"

    cat ${fastq[1]} | split \\
        -a ${params.suffix_length} \\
        -d \\
        -l ${params.num_lines} \\
        - \\
        ${fastq[1].getBaseName()}- \\
        --additional-suffix=".fq" 
    """
}

workflow {

    Channel.fromFilePairs(params.reads, checkIfExists: true).set{ read_pairs_unsplit_ch }

    CHECK_STRANDNESS( read_pairs_unsplit_ch, params.reference_cdna_ensembl, params.reference_annotation_ensembl )
    FASTP( read_pairs_unsplit_ch )
    EXTRACT_EXONS( params.reference_annotation )
    EXTRACT_SPLICE_SITES( params.reference_annotation )
    HISAT2_INDEX_REFERENCE( params.reference_genome, EXTRACT_EXONS.out, EXTRACT_SPLICE_SITES.out )
    
    split_fastq(FASTP.out.sample_trimmed) \
	    | map { name, fastq, fastq1 -> tuple( groupKey(name, fastq.size()), fastq, fastq1 ) } \
        | transpose() \
        | view()
        | set{ read_pairs_ch }

    HISAT2_ALIGN( read_pairs_ch, HISAT2_INDEX_REFERENCE.out, EXTRACT_EXONS.out, EXTRACT_SPLICE_SITES.out, CHECK_STRANDNESS.out.first() )
    SAMTOOLS( HISAT2_ALIGN.out.sample_sam )
    SAMTOOLS_MERGE( SAMTOOLS.out.sample_bam.collect() )
    CUFFLINKS( CHECK_STRANDNESS.out, SAMTOOLS_MERGE.out.gathered_bam, params.reference_annotation )
}
