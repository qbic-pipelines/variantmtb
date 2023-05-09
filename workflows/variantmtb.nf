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
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

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
//include { FASTQC                      } from '../modules/nf-core/fastqc/main'
//include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
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
def multiqc_report = []

workflow VARIANTMTB {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //

    INPUT_CHECK (
        ch_input
    )

    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // SUBWORKFLOW: Filter vcf file for PASS
    //              Split VEP fields into tsv
    //
    

    //PREPARE_VCF( INPUT_CHECK.out.vcfs )

    //ch_filtered_vcfs.view()

    // ch_split_vep_tsv = PREPARE_VCF.out.split_vep
    // ch_split_vep_tsv.view()

    // gather versions
    // ch_filtered_vcfs = PREPARE_VCF.out.vcf

    //
    // MODULE: Run FastQC
    //
    //FASTQC (
    //    INPUT_CHECK.out.reads
    //)
    //ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    /*
    ========================================================================================
       PREPARE INPUT FOR THE DIFFERENT QUERYNATOR QUERIES
    ========================================================================================
    */

    dbs = params.databases?.tokenize(',')
    println(dbs)

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
        // separate gzipped & unzipped files also separate mutations from other input for CIViC
        // ch_input
        //         .branch {
        //             meta, input_file ->
        //                 compressed_files : meta["compressed"] == 'compressed'
        //                     return [ meta, input_file ]
        //                 uncompressed_files : meta["compressed"] == 'uncompressed'
        //                     return [ meta, input_file ]

        //             }
        //         .set { ch_input_compressed_split }

        // // MODULE: gunzip compressed files
        // GUNZIP( ch_input_compressed_split.compressed_files )

        // ch_versions = ch_versions.mix(GUNZIP.out.versions)

        // // Recombine the channels & Create input to split different file types 
        // ch_input_compressed_split.uncompressed_files
        //     .mix(GUNZIP.out.gunzip)
        //     .set { ch_uncompressed_input }

        
        //separate different filetypes for cgi input (mutations, translocations, cnas)
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
        
    
        ch_input.branch {
                meta, input_file ->
                compressed_mutations : meta["compressed"] == 'compressed' & meta["filetype"] == 'mutations'
                    return [ meta, input_file ]
                uncompressed_mutations : meta["compressed"] == 'uncompressed' & meta["filetype"] == 'mutations'
                    return [ meta, input_file ] 
        }
        .set { ch_input_mutation_compressed_split }
        
        
        // Tabix compressed files
        TABIX_TABIX( ch_input_mutation_compressed_split.compressed_mutations )
        
        ch_versions = ch_versions.mix(TABIX_TABIX.out.versions)
        
        // //bgzip & tabix uncompressed files
        TABIX_BGZIPTABIX( ch_input_mutation_compressed_split.uncompressed_mutations )

        ch_versions = ch_versions.mix(TABIX_BGZIPTABIX.out.versions)



        // Recombine the channels & Create input for bcftools norm
        TABIX_BGZIPTABIX.out.gz_tbi
            .mix(TABIX_TABIX.out.tbi)
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
    

    //
    // MODULE: MultiQC

    //workflow_summary    = WorkflowVariantmtb.paramsSummaryMultiqc(workflow, summary_params)
    //ch_workflow_summary = Channel.value(workflow_summary)

    //ch_multiqc_files = Channel.empty()
    //ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    //ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    //ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    //ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    //ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    //MULTIQC (
    //    ch_multiqc_files.collect()
    //)
    //multiqc_report = MULTIQC.out.report.toList()
    //ch_versions    = ch_versions.mix(MULTIQC.out.versions)

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
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
