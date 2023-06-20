/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowVariantmtb.initialise(params, log)


// Check input path parameters to see if they exist
def checkPathParamList = [
    params.fasta,
    params.input,
    ]

for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { error('Input samplesheet not specified!')}

// Initialize file channels based on params
fasta              = params.fasta              ? Channel.fromPath(params.fasta).collect()                    : Channel.value([])

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK }                 from '../subworkflows/local/input_check'
include { PREPARE_VCF }                 from '../subworkflows/local/prepare_vcf'
include { QUERYNATOR_INPUT }            from '../subworkflows/local/create_querynator_input'
include { QUERYNATOR_CGIAPI }           from '../modules/local/querynator/cgiapi' 
include { QUERYNATOR_CIVICAPI }         from '../modules/local/querynator/civicapi'
include { QUERYNATOR_CREATEREPORT }     from '../modules/local/querynator/createreport' 

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { GUNZIP }                      from '../modules/nf-core/gunzip/main'
include { TABIX_TABIX }                 from '../modules/nf-core/tabix/tabix/main'
include { TABIX_BGZIPTABIX }            from '../modules/nf-core/tabix/bgziptabix/main'
include { BCFTOOLS_NORM }               from '../modules/nf-core/bcftools/norm/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary

workflow VARIANTMTB {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //

    INPUT_CHECK (
        ch_input
    )

    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)


    /*
    ========================================================================================
       PREPARE INPUT FOR THE DIFFERENT QUERYNATOR QUERIES
    ========================================================================================
    */

    // CHECK PARAMETERS

    if (params.databases.contains("cgi") & !params.cgi_email ) {error("No E-mail address associated to CGI specified!")}
    if (params.databases.contains("cgi") & !params.cgi_token ) {error("No CGI token specified!")}
    if (params.databases.contains("cgi") & !params.cgi_cancer_type ) {error("Please include the cancer types to query CGI for!")}
    if (params.databases.contains("civic") & !params.fasta ) {error("The reference sequence of the vcf file is missing!")}


    INPUT_CHECK.out.input_row_vals
        .map { meta, input_file, genome, filetype, compressed ->
            meta["ref"] = genome
            meta["filetype"] = filetype
            meta["compressed"] = compressed
            return [ meta, input_file ] }
        .set { ch_input }


    /*
    ------------------------
        CGI
    ------------------------
    */

    

    if (params.databases.contains("cgi")) {

        // Separate different filetypes for cgi input (mutations, translocations, cnas)
        ch_input
            .branch {
                meta, input_file  -> 
                    mutations : meta["filetype"] == 'mutations'
                        return [    meta,
                                    input_file,
                                    [],
                                    [], 
                                    create_cgi_cancer_type_string(params.cgi_cancer_type),
                                    meta["ref"], 
                                    params.cgi_token, 
                                    params.cgi_email ]
                    translocations : meta["filetype"] == 'translocations'
                        return [    meta,
                                    [],
                                    input_file,
                                    [], 
                                    create_cgi_cancer_type_string(params.cgi_cancer_type),
                                    meta["ref"], 
                                    params.cgi_token, 
                                    params.cgi_email ]
                    cnas : meta["filetype"] == 'cnas'
                        return [    meta,
                                    [],
                                    [],
                                    input_file, 
                                    create_cgi_cancer_type_string(params.cgi_cancer_type),
                                    meta["ref"],
                                    params.cgi_token, 
                                    params.cgi_email ]
                }
            .set { ch_input_filetype_split }

        // Recombine the channels & Create querynator CGI input
        ch_input_filetype_split.mutations
            .mix (ch_input_filetype_split.translocations, 
                    ch_input_filetype_split.cnas )
            .set { ch_cgi_input }
    }

    /*
    ------------------------
        CIViC
    ------------------------
    */

    if (params.databases.contains("civic")) {

        ch_input
            .branch { meta, input_file ->
                compressed_mutations : meta["compressed"] == 'compressed' & meta["filetype"] == 'mutations'
                    return [ meta, input_file ]
                uncompressed_mutations : meta["compressed"] == 'uncompressed' & meta["filetype"] == 'mutations'
                    return [ meta, input_file ] 
        }
        .set { ch_input_mutation_compressed_split }
        
        
        // Tabix compressed files
        TABIX_TABIX( ch_input_mutation_compressed_split.compressed_mutations )
        
        ch_versions = ch_versions.mix(TABIX_TABIX.out.versions)
        
        // bgzip & tabix uncompressed files
        TABIX_BGZIPTABIX( ch_input_mutation_compressed_split.uncompressed_mutations )

        ch_versions = ch_versions.mix(TABIX_BGZIPTABIX.out.versions)

        // Recombine tabix & gzipped input
        ch_input_mutation_compressed_split.compressed_mutations
            .join(TABIX_TABIX.out.tbi)
            .set { ch_input_tabix }

        // Recombine the channels & Create input for bcftools norm
        TABIX_BGZIPTABIX.out.gz_tbi
            .mix(ch_input_tabix)
            .map{ meta, input_file, index_file ->
                    [ meta, input_file, index_file ] }
            .set { ch_bcfnorm_input }


        // Normalize the vcf input 
        BCFTOOLS_NORM ( 
            ch_bcfnorm_input,
            fasta )

        ch_versions = ch_versions.mix(BCFTOOLS_NORM.out.versions)

    }
    
    /*
    ========================================================================================
        RUN QUERYNATOR MODULES (CGI & CIViC & CREATE REPORT)
    ========================================================================================
    */

    /*
    ------------------------
        CGI
    ------------------------
    */

    if (params.databases.contains("cgi")) {
        //MODULE: Run querynator query_cgi
        QUERYNATOR_CGIAPI( ch_cgi_input )

        ch_versions = ch_versions.mix(QUERYNATOR_CGIAPI.out.versions)
    }
    /*
    ------------------------
        CIViC
    ------------------------
    */
    
    if (params.databases.contains("civic")) {

        // MODULE: Run querynator query_civic      
        QUERYNATOR_CIVICAPI( BCFTOOLS_NORM.out.vcf )

        ch_versions = ch_versions.mix(QUERYNATOR_CIVICAPI.out.versions)
    }
    

    /*
    ------------------------
        CREATE REPORT
    ------------------------
    */
    
    if (params.databases.contains("civic") && params.databases.contains("cgi")) {

        QUERYNATOR_CGIAPI.out.result_dir
            .join(QUERYNATOR_CIVICAPI.out.result_dir)
            .set { ch_report_input }

        QUERYNATOR_CREATEREPORT( ch_report_input )

        ch_versions = ch_versions.mix(QUERYNATOR_CREATEREPORT.out.versions)
    }
    
    
    //Dump Software versions
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

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

    

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
