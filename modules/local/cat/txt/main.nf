// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process CAT_TXT {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::sed=4.2.3.dev0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sed:4.2.3.dev0--0"
    } else {
        container "quay.io/biocontainers/sed:4.2.3.dev0--0"
    }

    input:
    tuple val(meta), path(txt)

    output:
    tuple val(meta), path("*.merged.txt"), emit: txt
    path "*.version.txt"          , emit: version

    script:
    def software = getSoftwareName(task.process)
    def prefix   = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    """
    cat *.txt > ${prefix}.merged.txt

    echo \$(cat --version 2>&1) | head -n 1 > ${software}.version.txt
    """
}
