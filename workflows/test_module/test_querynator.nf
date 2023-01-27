#!/usr/bin/env nextflow

nextflow.enable.dsl = 2


include { QUERYNATOR_CGIAPI } from '../modules/local/querynator/cgiapi'



workflow  {

    input = [
        [ id:'test' ], // meta map
        "/mnt/volume/workdir/masterthesis/vcf_files/variants_dev.vcf",
        [],
        [],
        '"Any cancer type"',
        'GRCh37',
        '29dec4da958311bb8e28',
        'mark.polster@uni-tuebingen.de'
    ]
    
    QUERYNATOR_CGIAPI( input )
    
}