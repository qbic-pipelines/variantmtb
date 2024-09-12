process QUERYNATOR_CREATEREPORT {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::querynator=0.5.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/querynator:0.5.5--pyhdfd78af_0':
        'quay.io/biocontainers/querynator:0.5.5--pyhdfd78af_0' }"


    input:

    tuple val(meta), path(cgi_out), path(civic_out)

    output:

    tuple val(meta), path("${meta.id}_report")                                      , emit: report_dir
    tuple val(meta), path("${meta.id}_report/combined_files")                       , emit: combined_files_dir
    tuple val(meta), path("${meta.id}_report/combined_files/*")                     , emit: combined_files
    tuple val(meta), path("${meta.id}_report/report")                               , emit: report_html_dir
    tuple val(meta), path("${meta.id}_report/report/*")                             , emit: report_files

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    querynator create-report \\
        --cgi_path $cgi_out \\
        --civic_path $civic_out \\
        --outdir ${prefix}_report \\
        $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        querynator: \$(echo \$(querynator --version 2>&1) | sed 's/^.*querynator //; s/Using.*\$//' ))
    END_VERSIONS
    """
}
