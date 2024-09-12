process QUERYNATOR_CIVICAPI {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::querynator=0.5.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/querynator:0.5.5--pyhdfd78af_0':
        'quay.io/biocontainers/querynator:0.5.5--pyhdfd78af_0' }"


    input:

    tuple val(meta), path(input_file)

    output:

    tuple val(meta), path("${meta.id}_civic")                                                       , emit: result_dir
    tuple val(meta), path("${meta.id}_civic/${meta.id}_civic.civic_results.tsv")                    , emit: civic_table
    tuple val(meta), path("${meta.id}_civic/vcf_files")                                             , emit: input_vcf_dir
    tuple val(meta), path("${meta.id}_civic/vcf_files/${meta.id}_civic.filtered_variants.vcf")      , emit: input_vcf_filtered
    tuple val(meta), path("${meta.id}_civic/vcf_files/${meta.id}_civic.removed_variants.vcf")       , emit: input_vcf_removed
    tuple val(meta), path("${meta.id}_civic/metadata.txt")                                          , emit: metadata


    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args    = task.ext.args     ?: ''
    def prefix  = task.ext.prefix   ?: "${meta.id}"
    def cancer  = meta.civic_cancer ? "--cancer '${meta.civic_cancer}'" : ''

    """
    # set path to civicpy cache
    export CIVICPY_CACHE_FILE=${workDir}/.civicpy/cache.pkl
    export MPLCONFIGDIR=${workDir}/.config/matplotlib

    # run querynator
    querynator query-api-civic \\
        --vcf $input_file \\
        --outdir ${prefix}_civic \\
        --genome $meta.ref \\
        --filter_vep \\
        $cancer \\
        $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        querynator: \$(echo \$(querynator --version 2>&1) | sed 's/^.*querynator //; s/Using.*\$//' ))
    END_VERSIONS
    """
}
