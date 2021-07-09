// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process GSTAMA_ORFPARSER {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::gs-tama=1.0.1" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/gs-tama:1.0.1--hdfd78af_0"
    } else {
        container "quay.io/biocontainers/gs-tama:1.0.1--hdfd78af_0"
    }

    input:
    tuple val(meta), path(txt)

    output:
    tuple val(meta), path("*.orf.txt"), emit: txt
    path "*.version.txt"              , emit: version

    script:
    def software = getSoftwareName(task.process)
    def prefix   = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    """
    tama_orf_blastp_parser.py \\
        -b $txt \\
        -o ${prefix}.orf.txt \\
        $options.args

    echo '1.0' > ${software}.version.txt
    """
}
