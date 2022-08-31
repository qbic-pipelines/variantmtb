//
// Quality Filter
//

include { BCFTOOLS_VIEW     } from '../../modules/nf-core/modules/bcftools/view/main'
include { BCFTOOLS_SPLITVEP } from '../../modules/local/bcftools/splitvep'

workflow PREPARE_VCF {
    take:
    vcf         // channel: [ val(meta), [ vcf ] ]

    main:
    ch_versions = Channel.empty()

    // remap channel to have right number of input dimensions: channel [val(meta), vcf, tbi]
    ch_vcf = vcf.map{ meta, vcf -> [meta, vcf, []] }

    // channels: [ [val(meta), vcf, tbi], regions, targets, samples ]
    BCFTOOLS_VIEW(ch_vcf, [], [], [])

    ch_vcf_pass = BCFTOOLS_VIEW.out.vcf

    // remap channel to have right number of input dimensions: channel [val(meta), vcf, tbi]
    ch_vcf_splitvep = ch_vcf_pass.map{ meta, vcf -> [meta, vcf, []] }

    // channel: [ [val(meta), vcf, tbi] ]
    BCFTOOLS_SPLITVEP( ch_vcf_splitvep )

    // gather used software versions
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW.out.versions)
    ch_versions = ch_versions.mix(BCFTOOLS_SPLITVEP.out.versions)

    emit:

    vcf = ch_vcf_pass                       // channel: [ val(meta), [ vcf ] ]
    split_vep = BCFTOOLS_SPLITVEP.out.tsv   // channel: [ val(meta), [ tsv ] ]

    versions = ch_versions                  // channel: [ versions.yml ]
}
