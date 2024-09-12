/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { QUERYNATOR_CGIAPI             }   from '../modules/local/querynator/cgiapi'
include { QUERYNATOR_CIVICAPI           }   from '../modules/local/querynator/civicapi'
include { QUERYNATOR_CREATEREPORT       }   from '../modules/local/querynator/createreport'

include { CUSTOM_DUMPSOFTWAREVERSIONS   }   from '../modules/nf-core/custom/dumpsoftwareversions/main.nf'
include { GUNZIP                        }   from '../modules/nf-core/gunzip/main'
include { TABIX_TABIX                   }   from '../modules/nf-core/tabix/tabix/main'
include { TABIX_BGZIPTABIX              }   from '../modules/nf-core/tabix/bgziptabix/main'
include { BCFTOOLS_NORM                 }   from '../modules/nf-core/bcftools/norm/main'

include { softwareVersionsToYAML        }   from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { getGenomeAttribute            }   from '../subworkflows/local/utils_nfcore_variantmtb_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow VARIANTMTB {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    ch_versions    // channel: versions of the software used in the pipeline, emitted by initialization subworkflow


    main:

    /*
    ========================================================================================
                PREPARE INPUT FOR THE DIFFERENT QUERYNATOR QUERIES
    ========================================================================================
    */

    // CHECK PARAMETERS
    if ( params.databases.contains("civic"  )    & !params.fasta & !params.genome   )   { error("No reference provided! use --genome or --fasta"    )}

    // CHECK SECRETS
    if ( params.databases.contains("cgi"    )    & System.getenv("NXF_ENABLE_SECRETS") != 'true') { error("Please enable secrets: export NXF_ENABLE_SECRETS='true'")}

    ch_samplesheet
        .map { meta, input_file ->
            meta["compressed"] = input_file.extension == "gz" ? "compressed" : "uncompressed"
            return [ meta, input_file ] }
        .set { ch_input }

    // if specified, fetch fasta file from --genome parameter, --fasta has priority
    fasta           = params.fasta              ? Channel.fromPath(params.fasta).collect()   : Channel.fromPath(getGenomeAttribute('fasta')).collect()

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
                                    meta["cgi_cancer"],
                                    meta["ref"]
                                    ]
                    translocations : meta["filetype"] == 'translocations'
                        return [    meta,
                                    [],
                                    input_file,
                                    [],
                                    meta["cgi_cancer"],
                                    meta["ref"]
                                    ]
                    cnas : meta["filetype"] == 'cnas'
                        return [    meta,
                                    [],
                                    [],
                                    input_file,
                                    meta["cgi_cancer"],
                                    meta["ref"]
                                    ]
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
                compressed_mutations : meta["compressed"] == 'compressed'       & meta["filetype"] == 'mutations'
                    return [ meta, input_file ]
                uncompressed_mutations : meta["compressed"] == 'uncompressed'   & meta["filetype"] == 'mutations'
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

        ch_bcfnorm_meta2 = ch_bcfnorm_input
            .map{ meta, input_file, index_file -> meta["ref"]}

        // Normalize the vcf input
        BCFTOOLS_NORM (
            ch_bcfnorm_input,
            ch_bcfnorm_meta2.combine(fasta)
        )

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

    // Collate and save software versions

    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }


    emit:

    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}




/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
