// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process GSTAMA_ORFSEEKER {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::gs-tama=1.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        //TODO Replace with new version of gstama when available
        // container "https://depot.galaxyproject.org/singularity/gs-tama:1.0--hdfd78af_0"
        container "docker://sguizard/tama"
    } else {
        //TODO Replace with new version of gstama when available
        // container "quay.io/biocontainers/gs-tama:1.0--hdfd78af_0"
        container "docker://sguizard/tama"
    }

    input:
    tuple val(meta), path(fa)

    output:
    tuple val(meta), path("*_orf.fa"), emit: orfs
    path "*.version.txt"          , emit: version

    script:
    def software = getSoftwareName(task.process)
    def prefix   = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    def orfs     = "${meta.id}_orf.fa"
    """
    tama_orf_seeker.py -f $fa -o $orfs

    echo "1.0" > ${software}.version.txt
    """
    //TODO implement version option
}
