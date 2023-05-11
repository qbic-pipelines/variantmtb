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
    
    // check if input file is compressed
    def compressed_check = file(row.filename).extension == "gz" ? "compressed" : "uncompressed"

    // create meta map
    def meta = [:]
    meta.id         = row.sample

    // add path(s) of the fastq file(s) to the meta map
    def input_meta = []
    if (!file(row.filename).exists()) {
        error("ERROR: Please check input samplesheet -> inputfile file does not exist!\n${row.filename}")
    }
    else{
        input_meta =  [ meta, file(row.filename), row.genome, row.filetype, compressed_check ] 
    }
    return input_meta
}
