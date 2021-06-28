////////////////////////////////////////////////////
/* --         LOCAL PARAMETER VALUES           -- */
////////////////////////////////////////////////////

params.summary_params = [:]

////////////////////////////////////////////////////
/* --          VALIDATE INPUTS                 -- */
////////////////////////////////////////////////////

// Validate input parameters
Workflow.validateWorkflowParams(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.database, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) {
    Channel.
        fromPath(params.input)
        .set { ch_input }
    
} else { 
    exit 1, 'Input samplesheet not specified!' 
}

if (params.fasta) {
    Channel
        .value(file(params.fasta))
        .set { ch_fasta }
} else {
    exit 1, 'Input fasta not specified!'
}

if (params.database) {
    Channel
        .value(file(params.database))
        .set { ch_database }
} else {
    exit 1, 'Input database not specified!'
}


////////////////////////////////////////////////////
/* --          CONFIG FILES                    -- */
////////////////////////////////////////////////////

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

////////////////////////////////////////////////////
/* --       IMPORT MODULES / SUBWORKFLOWS      -- */
////////////////////////////////////////////////////

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

def multiqc_options   = modules['multiqc']
multiqc_options.args += params.multiqc_title ? " --title \"$params.multiqc_title\"" : ''

// Modules: local
include { GET_SOFTWARE_VERSIONS } from '../modules/local/get_software_versions'                addParams( options: [publish_files : ['csv':'']] )

// Modules: nf-core/modules
include { BEDTOOLS_GETFASTA     } from '../modules/nf-core/software/bedtools/getfasta/main'    addParams( options: modules['getfasta'] )
include { GSTAMA_ORFSEEKER      } from '../modules/nf-core/software/gstama/orfseeker/main'     addParams( options: modules['orfseeker'] )
include { GSTAMA_FASTASPLITTER  } from '../modules/nf-core/software/gstama/fastasplitter/main' addParams( options: [ args:"${params.n}", publish_dir:"3a_fastasplitter" ] )
include { BLAST_MAKEBLASTDB     } from '../modules/nf-core/software/blast/makeblastdb/main'    addParams( options: modules['makeblastdb'] )
include { BLAST_BLASTP          } from '../modules/nf-core/software/blast/blastp/main'         addParams( options: [ args:"-evalue ${params.evalue}" ] )
include { CAT_TXT               } from '../modules/nf-core/software/cat/txt/main'              addParams( options: modules['cattxt'] )
include { GSTAMA_ORFPARSER      } from '../modules/nf-core/software/gstama/orfparser/main'     addParams( options: modules['orfparser'] )
include { GSTAMA_ADDCDS         } from '../modules/nf-core/software/gstama/addcds/main'        addParams( options: modules['addcds'] )

include { FASTQC                } from '../modules/nf-core/software/fastqc/main'               addParams( options: modules['fastqc']            )
include { MULTIQC               } from '../modules/nf-core/software/multiqc/main'              addParams( options: multiqc_options              )

// Subworkflows: local
include { INPUT_CHECK           } from '../subworkflows/local/input_check'                     addParams( options: [:]                          )

////////////////////////////////////////////////////
/* --           RUN MAIN WORKFLOW              -- */
////////////////////////////////////////////////////

// Info required for completion email and summary
def multiqc_report = []

workflow TAMANMD {

    ch_software_versions = Channel.empty()

    BEDTOOLS_GETFASTA(ch_input, ch_fasta)
    BEDTOOLS_GETFASTA.out.fasta
        .map { fasta_file -> 
            [
                [ id:fasta_file.toString().replaceAll(/.+\//, '').replaceAll(/.fa$/, '') ],  
                fasta_file
            ]
        }
        .set { transcript_fasta }
    
    GSTAMA_ORFSEEKER(transcript_fasta)
    GSTAMA_FASTASPLITTER(GSTAMA_ORFSEEKER.out.orfs)

    GSTAMA_FASTASPLITTER.out.fa
        .map { 
            out = []
            for ( i in it[1] ) { out << [ it[0], i ] }
            return out
        }
        .flatten()
        .buffer( size: 2 )
        .set { ch_blp_input }

    BLAST_MAKEBLASTDB(params.database)

    BLAST_BLASTP(ch_blp_input, BLAST_MAKEBLASTDB.out.db)

    BLAST_BLASTP.out.txt
        .groupTuple(by: 0, size: params.n)
        .set { ch_grouped_blp }

    CAT_TXT(ch_grouped_blp)

    GSTAMA_ORFPARSER(CAT_TXT.out.txt)

    // GSTAMA_ORFPARSER.out.txt.view()
    // ch_input.view()
    // BEDTOOLS_GETFASTA.out.fasta.view()
    GSTAMA_ORFPARSER.out.txt
        .combine(ch_input)
        .combine(BEDTOOLS_GETFASTA.out.fasta)
        .set { ch_bed_add }
    ch_bed_add.view()

    GSTAMA_ADDCDS(ch_bed_add)

    // /*
    //  * SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //  */
    // INPUT_CHECK ( 
    //     ch_input
    // )

    // /*
    //  * MODULE: Run FastQC
    //  */
    // FASTQC (
    //     INPUT_CHECK.out.reads
    // )
    // ch_software_versions = ch_software_versions.mix(FASTQC.out.version.first().ifEmpty(null))
    

    // /*
    //  * MODULE: Pipeline reporting
    //  */
    // // Get unique list of files containing version information
    // ch_software_versions
    //     .map { it -> if (it) [ it.baseName, it ] }
    //     .groupTuple()
    //     .map { it[1][0] }
    //     .flatten()
    //     .collect()
    //     .set { ch_software_versions }
    // GET_SOFTWARE_VERSIONS ( 
    //     ch_software_versions
    // )

    // /*
    //  * MODULE: MultiQC
    //  */
    // workflow_summary    = Workflow.paramsSummaryMultiqc(workflow, params.summary_params)
    // ch_workflow_summary = Channel.value(workflow_summary)

    // ch_multiqc_files = Channel.empty()
    // ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    // ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    // ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    // ch_multiqc_files = ch_multiqc_files.mix(GET_SOFTWARE_VERSIONS.out.yaml.collect())
    // ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
    
    // MULTIQC (
    //     ch_multiqc_files.collect()
    // )
    // multiqc_report       = MULTIQC.out.report.toList()
    // ch_software_versions = ch_software_versions.mix(MULTIQC.out.version.ifEmpty(null))
}

////////////////////////////////////////////////////
/* --              COMPLETION EMAIL            -- */
////////////////////////////////////////////////////

workflow.onComplete {
    Completion.email(workflow, params, params.summary_params, projectDir, log, multiqc_report)
    Completion.summary(workflow, params, log)
}

////////////////////////////////////////////////////
/* --                  THE END                 -- */
////////////////////////////////////////////////////