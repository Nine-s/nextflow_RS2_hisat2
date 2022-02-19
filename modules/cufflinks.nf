process CUFFLINKS {
    label 'cufflinks'
    publishDir params.outdir
     
    input:
    env STRANDNESS
    tuple val(sample_name), path(sorted_bam)
    path(annotation)
    
    output:
    path('transcripts.gtf'), emit: cufflinks_gtf 
    
    shell:
    '''
    if [[ $STRANDNESS == "firststrand" ]]; then
         cufflinks -G !{annotation} !{sorted_bam} --library-type fr-firststrand --num-threads !{params.threads}
    elif [ $STRANDNESS == "secondstrand" ]]; then
         cufflinks -G !{annotation} !{sorted_bam} --library-type fr-secondstrand --num-threads !{params.threads}
    elif [[ $STRANDNESS == "unstranded" ]]; then
         cufflinks -G !{annotation} !{sorted_bam} --library-type fr-unstranded --num-threads !{params.threads}
	else  
		echo $STRANDNESS > error_strandness.txt
		echo "strandness cannot be determined" >> error_strandness.txt
    fi
    '''

}
