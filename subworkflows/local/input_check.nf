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
        .map { create_input_channel(it) }
        .set { input_row_vals }

    emit:
    input_row_vals                                   // channel: [ val(meta), file(input_file), val(genome), val(filetype)  ]
    versions = SAMPLESHEET_CHECK.out.versions       // channel: [ versions.yml ]
}

// Function to get list of [ meta, inputfile, genome, filetype ]
def create_input_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.sample

    // add path(s) of the fastq file(s) to the meta map
    def input_meta = []
    if (!file(row.filename).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> inputfile file does not exist!\n${row.filename}"
    }
    else{
        input_meta =  [ meta, file(row.filename), row.genome, row.filetype, check_if_zipped(row.filename) ] 
    }
    return input_meta
}

def check_if_zipped(String filename){
    def filetype 
    def input_file = file(filename)

    if ( filename.endsWith(".gz") ){
        compressed_check = "compressed"
    }
    else {
        compressed_check = "uncompressed"
    }
    return compressed_check
}