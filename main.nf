#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/tamanmd
========================================================================================
 nf-core/tamanmd Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/nf-core/tamanmd
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

////////////////////////////////////////////////////
/* --               PRINT HELP                 -- */
////////////////////////////////////////////////////

log.info Utils.logo(workflow, params.monochrome_logs)

def json_schema = "$projectDir/nextflow_schema.json"
if (params.help) {
    // TODO nf-core: Update typical command used to run pipeline
    def command = "nextflow run nf-core/tamanmd --input samplesheet.csv --genome GRCh37 -profile docker"
    log.info NfcoreSchema.paramsHelp(workflow, params, json_schema, command)
    log.info Workflow.citation(workflow)
    log.info Utils.dashedLine(params.monochrome_logs)
    exit 0
}

////////////////////////////////////////////////////
/* --        GENOME PARAMETER VALUES           -- */
////////////////////////////////////////////////////

params.fasta = Workflow.getGenomeAttribute(params, 'fasta')

////////////////////////////////////////////////////
/* --         PRINT PARAMETER SUMMARY          -- */
////////////////////////////////////////////////////

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params, json_schema)
log.info NfcoreSchema.paramsSummaryLog(workflow, params, json_schema)
log.info Workflow.citation(workflow)
log.info Utils.dashedLine(params.monochrome_logs)

////////////////////////////////////////////////////
/* --         VALIDATE PARAMETERS              -- */
////////////////////////////////////////////////////

Workflow.validateMainParams(workflow, params, json_schema, log)

////////////////////////////////////////////////////
/* --            RUN WORKFLOW(S)               -- */
////////////////////////////////////////////////////

workflow {
    include { TAMANMD } from './workflows/pipeline' addParams( summary_params: summary_params )
    TAMANMD ()
}

////////////////////////////////////////////////////
/* --                  THE END                 -- */
////////////////////////////////////////////////////