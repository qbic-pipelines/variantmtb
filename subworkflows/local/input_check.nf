//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_vcf_channel(it) }
        .set { input_row_vals }

    emit:
    input_row_vals                                   // channel: [ val(meta), file(vcf), val(genome)  ]
    versions = SAMPLESHEET_CHECK.out.versions       // channel: [ versions.yml ]
}

// Function to get list of [ meta, vcf, genome  ]
def create_vcf_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.sample

    // add path(s) of the fastq file(s) to the meta map
    def vcf_meta = []
    if (!file(row.vcf).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> VCF file does not exist!\n${row.vcf}"
    }
    else{
        vcf_meta = [ meta, file(row.vcf), row.genome ] 
    }
    printl(vcf_meta)
    return vcf_meta
}
