#!/usr/bin/env nextflow

nextflow.enable.dsl = 2


include { QUERYNATOR_CGIAPI } from '../modules/local/querynator/cgiapi'



workflow {
    mutations = '/mnt/volume/workdir/masterthesis/vcf_files/00483_short.vcf'
    output = 'out_test'
    cancer = '"Colon carcinoma"'
    genome = 'hg19'
    token = '29dec4da958311bb8e28'
    email = 'mark.polster@uni-tuebingen.de'

    QUERYNATOR_CGIAPI( mutations, output, cancer, genome, token, email)
}