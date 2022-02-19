process FASTP {
    label 'fastp'
    publishDir params.outdir

    input:
    tuple val(name), path(reads)

    output:
    tuple val(name), path("${name}*.trimmed.fastq"), emit: sample_trimmed
    path "${name}_fastp.json", emit: report_fastp_json
    path "${name}_fastp.html", emit: report_fastp_html

    script:
    """
    fastp -i ${reads[0]} -I ${reads[1]} -o ${name}.R1.trimmed.fastq -O ${name}.R2.trimmed.fastq --detect_adapter_for_pe --json ${name}_fastp.json --html ${name}_fastp.html --thread ${params.threads}
    """
}
