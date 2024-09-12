process QUERYNATOR_CGIAPI {
    tag "$meta.id"
    label 'process_low'
    secret 'cgi_email'
    secret 'cgi_token'
    maxForks 1

    conda "bioconda::querynator=0.5.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/querynator:0.5.5--pyhdfd78af_0':
        'quay.io/biocontainers/querynator:0.5.5--pyhdfd78af_0' }"


    input:

    tuple val(meta), path(mutations), path(translocations), path(cnas), val(cancer), val(genome)

    output:

    tuple val(meta), path("${meta.id}_cgi")                                                     , emit: result_dir
    tuple val(meta), path("${meta.id}_cgi/${meta.id}_cgi.cgi_results.zip")                      , emit: zip
    tuple val(meta), path("${meta.id}_cgi/${meta.id}_cgi.cgi_results")                          , emit: cgi_results
    tuple val(meta), path("${meta.id}_cgi/${meta.id}_cgi.cgi_results/*")                        , emit: results
    tuple val(meta), path("${meta.id}_cgi/vcf_files")                                           , emit: input_vcf_dir
    tuple val(meta), path("${meta.id}_cgi/vcf_files/${meta.id}_cgi.filtered_variants.vcf")      , emit: input_vcf_filtered
    tuple val(meta), path("${meta.id}_cgi/vcf_files/${meta.id}_cgi.removed_variants.vcf")       , emit: input_vcf_removed


    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mutations_file = mutations ? "--mutations ${mutations}" : ""
    def translocation_file = translocations ? "--translocations ${translocations}" : ''
    def cnas_file = cnas ? "--cnas ${cnas}" : ''
    def cancer = cancer ? cancer : 'Any cancer type'        // default to any cancer type if not specified

    """
    export MPLCONFIGDIR=${workDir}/.config/matplotlib

    querynator query-api-cgi \\
        $mutations_file \\
        $translocation_file \\
        $cnas_file \\
        --outdir ${prefix}_cgi \\
        --cancer '$cancer' \\
        --genome $genome \\
        --token \${cgi_token} \\
        --email \${cgi_email} \\
        --filter_vep \\
        $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        querynator: \$(echo \$(querynator --version 2>&1) | sed 's/^.*querynator //; s/Using.*\$//' ))
    END_VERSIONS
    """
}
