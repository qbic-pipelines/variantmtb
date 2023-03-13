process QUERYNATOR_CGIAPI {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::querynator=0.1.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/querynator:0.1.3':
        'quay.io/biocontainers/querynator:0.1.3' }"
    
    
    input:

    tuple val(meta), path(mutations), path(translocations), path(cnas), val(cancer), val(genome), val(token), val(email)

    output:
    
    publishDir "${params.outdir}/${meta.id}", mode: 'copy', pattern: "*"

    path("${meta.id}.cgi_results.zip"), emit: zip
    path("${meta.id}.cgi_results"), emit: results    
    path("${meta.id}.cgi_results/drug_prescription.tsv"), emit: drug_tsv
    path("${meta.id}.cgi_results/input01.tsv"), emit: input_tsv
    path("${meta.id}.cgi_results/mutation_analysis.tsv"), emit: mutation_tsv, optional: true
    path("${meta.id}.cgi_results/fusion_analysis.tsv"), emit: fusion_tsv, optional: true
    path("${meta.id}.cgi_results/cna_analysis.tsv"), emit: cnas_tsv, optional: true
    path("${meta.id}.cgi_results/metadata.txt"), emit: metadata

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mutations_file = mutations ? "--mutations ${mutations}" : "" 
    def translocation_file = translocations ? "--translocations ${translocations}" : ''
    def cnas_file = cnas ? "--cnas ${cnas}" : ''
    
    """
    querynator query-api-cgi \
        $mutations_file \
        $translocation_file \
        $cnas_file \
        --output $prefix \
        --cancer $cancer \
        --genome $genome \
        --token $token \
        --email $email \
    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        querynator: \$(echo \$(querynator --version 2>&1) | sed 's/^.*querynator //; s/Using.*\$//' ))
    END_VERSIONS
    """
}
