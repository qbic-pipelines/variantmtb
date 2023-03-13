nextflow.enable.dsl = 2


include { QUERYNATOR_CIVICAPI } from '../../modules/local/querynator/civicapi'



workflow  {

    input = [
        [ id:'test' ], // meta map
        "/mnt/volume/workdir/masterthesis/vcf_files/variants_head.vcf.gz",
        "/mnt/volume/workdir/masterthesis/vcf_files/variants_head.vcf.gz.tbi"
    ]
    
    QUERYNATOR_CIVICAPI( input )

}
    