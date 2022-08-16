//
// Quality Filter
//

include { BCFTOOLS_VIEW     } from '../../modules/nf-core/modules/bcftools/view/main'

workflow PREPARE_VCF {
    take:
    vcf         // channel: [ val(meta), [ vcf ] ]

    main:
    ch_versions = Channel.empty()

    ch_vcf = vcf.map{meta, vcf -> [meta, vcf, []] }

    BCFTOOLS_VIEW(ch_vcf, [], [], [])

    ch_versions = ch_versions.mix(BCFTOOLS_VIEW.out.versions)

    emit:

    vcf = BCFTOOLS_VIEW.out.vcf // channel: [ val(meta), [ vcf ] ]

    versions = ch_versions          // channel: [ versions.yml ]
}
