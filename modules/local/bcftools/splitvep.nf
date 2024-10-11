process BCFTOOLS_SPLITVEP {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::bcftools=1.15.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.15.1--h0ea216a_0':
        'quay.io/biocontainers/bcftools:1.15.1--h0ea216a_0' }"

    input:
    tuple val(meta), path(vcf), path(index)

    output:

    tuple val(meta), path("*.tsv"), emit: tsv
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    bcftools \\
        +split-vep \\
        $args \\
        --output ${prefix}.tsv \\
        $vcf

    # insert header
    sed  -i '1i #CHROM POS ID REF ALT AF IMPACT Gene SYMBOL Consequence SIFT PolyPhen HGVSc HGVSp RefSeq Existing_variation CLIN_SIG' ${prefix}.tsv

    # replace whitespace by tab
    sed -i 's/\s/\t/g' ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}
