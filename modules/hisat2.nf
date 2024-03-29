process EXTRACT_EXONS {
    label 'python'

    input:
    path(annotation)

    output:
    path("out_exons.txt")

    script:
    """ 
    python ${params.baseDir}/bin/hisat2_extract_exons.py ${annotation}  > out_exons.txt
    """
}

process EXTRACT_SPLICE_SITES {
    label 'python'

    input:
    path(annotation)

    output:
    path("out_splice_sites.txt")

    script:
    """ 
    python ${params.baseDir}/bin/hisat2_extract_splice_sites.py ${annotation} > out_splice_sites.txt
    """
}

process HISAT2_INDEX_REFERENCE {
    label 'hisat2'
    publishDir params.outdir
    executor 'k8s'


    input:
    path(reference)
    path(exon)
    path(splice_sites)

    output:
    tuple path(reference), path("${reference.baseName}*.ht2")

    script:
    """
    hisat2-build ${reference} ${reference.baseName} -p ${params.threads} --exon ${exon} --ss ${splice_sites}
    """
}

process HISAT2_ALIGN {
    label 'hisat2'
    publishDir params.outdir
 
    input:
    tuple val(sample_name), path(reads_1), path(reads_2)
    tuple path(reference), path(index)
    env STRANDNESS

    output:
    path "${sample_name}_summary.log", emit: log
    tuple val(sample_name), path("${reads_1.getBaseName()}.sam"), emit: sample_sam 

    shell:
    '''
    if [[ ($STRANDNESS == "firststrand") ]]; then
    
        hisat2 -x !{reference.baseName} -1 !{reads_1} -2 !{reads_2} --new-summary --summary-file !{sample_name}_summary.log --thread !{params.threads} --dta-cufflinks --rna-strandness FR -S !{reads_1.getBaseName()}.sam

    elif [[ ($STRANDNESS == "secondstrand") ]]; then
    
        hisat2 -x !{reference.baseName} -1 !{reads_1} -2 !{reads_2} --new-summary --summary-file !{sample_name}_summary.log --thread !{params.threads} --dta-cufflinks --rna-strandness RF -S !{reads_1.getBaseName()}.sam

    elif [[ $STRANDNESS == "unstranded" ]]; then
       
        hisat2 -x !{reference.baseName} -1 !{reads_1} -2 !{reads_2} --new-summary --summary-file !{sample_name}_summary.log --thread !{params.threads} --dta-cufflinks -S !{reads_1.getBaseName()}.sam
    else  
		echo $STRANDNESS > error_strandness.txt
		echo "strandness cannot be determined" >> error_strandness.txt
    fi
    '''   
   
}
