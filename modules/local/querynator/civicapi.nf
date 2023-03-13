process QUERYNATOR_CIVICAPI {
    tag "$meta.id"
    label 'process_low'

    // conda "bioconda::querynator=0.1.3"
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/querynator:0.2.1':
    //     'https://hub.docker.com/r/mvp9/querynator' }"
    
    container "mvp9/querynator:0.2.1"
    
    input:

    tuple val(meta), path(input_file), path(index_file)

    output:
    
    publishDir "${params.outdir}/${meta.id}", mode: 'copy', pattern: "*"

    // path("${meta.id}")                      , emit: results
    // path("${meta.id}/civic_results.tsv")    , emit: civic_table
    // path("${meta.id}/metadata.txt")         , emit: metadata

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    querynator query-api-civic -v $input_file -o $prefix


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        querynator: \$(echo \$(querynator --version 2>&1) | sed 's/^.*querynator //; s/Using.*\$//' ))
    END_VERSIONS
    """
}
