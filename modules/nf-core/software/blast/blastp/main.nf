// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process BLAST_BLASTP {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::blast=2.11.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/blast:2.11.0--pl5262h3289130_1"
    } else {
        container "quay.io/biocontainers/blast:2.11.0--pl5262h3289130_1"
    }

    input:
    tuple val(meta), path(fasta)
    path  db

    output:
    tuple val(meta), path("*.blastp.txt"), emit: txt
    path "*.version.txt"                 , emit: version

    script:
    def software = getSoftwareName(task.process)
    def prefix   = fasta.toString().replaceAll(/.fa$/, '')
    """
    DB=`find -L ./ -name "*.pdb" | sed 's/.pdb//'`
    blastp \\
        -num_threads $task.cpus \\
        -db \$DB \\
        -query $fasta \\
        $options.args \\
        -out ${prefix}.blastp.txt
    echo \$(blastp -version 2>&1) | sed 's/^.*blastp: //; s/ .*\$//' > ${software}.version.txt
    """
}
