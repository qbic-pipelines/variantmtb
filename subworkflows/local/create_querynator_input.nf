//
// Quality Filter
//

include { BCFTOOLS_VIEW     } from '../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_SPLITVEP } from '../../modules/local/bcftools/splitvep'

workflow QUERYNATOR_INPUT {
    take:
    input_check_out         // channel: [ val(meta), input_file, ref_genome ]

    main:
        
    // remap channel to have right number of input dimensions: channel [val(meta), input, [], [], cancer_type, ref_genome, cgi_token, cgi_mail]
    
    ch_cgi_input = input_check_out.map{ meta, input_file, genome -> [ meta, input_file, [], [], create_cgi_cancer_type_string(params.cgi_cancer_type), genome, params.cgi_token, params.cgi_email ] }

    // specify between mutations (variants --> vcf), cnas, translocations
    // if (row.vcf.endsWith('.vcf')){
    //     vcf_meta =  [ meta, file(row.vcf), [], [], params.cgi_cancer_type, row.genome, params.cgi_token, params.cgi_email ]
    // }
    // else if (row.vcf.endsWith('.vcf')){
    //     vcf_meta =  [ meta, file(row.vcf), [], [], params.cgi_cancer_type, row.genome, params.cgi_token, params.cgi_email ]
    // }
    // else if (row.vcf.endsWith('.vcf')){
    //     vcf_meta =  [ meta, file(row.vcf), [], [], params.cgi_cancer_type, row.genome, params.cgi_token, params.cgi_email ]
    // }    

    emit:

    cgi_input = ch_cgi_input                      // channel: [ val(meta), [ vcf ] ]
}


// Function that checks whether params.cgi_cancer_types contains the quotations ('') and isnt just a string. 
// If lonely string, adds the quotations, so that cancer types consisting of multiple words can be read by querynator
def create_cgi_cancer_type_string(cancer_type) {
    if (!params.cgi_cancer_type.contains("'")) {
        cgi_cancer_type_string = "'" + cancer_type + "'"
    }
    else {
        cgi_cancer_type_string = cancer_type
    }
    return cgi_cancer_type_string
}
