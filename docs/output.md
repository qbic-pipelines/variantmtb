# nf-core/variantmtb: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

<!-- nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [nf-core/variantmtb: Output](#nf-corevariantmtb-output)
  - [Introduction](#introduction)
  - [Pipeline overview](#pipeline-overview)
    - [CGI](#cgi)
    - [CIViC](#civic)
    - [Report](#report)

### CGI

CGI is queried by accessing its RESTful API. It takes in a list of variants and returns several output files.
See the [querynator docs](https://querynator.readthedocs.io/en/latest/usage.html#query-the-cancergenomeinterpeter-cgi) for more information

### CIViC

CIViC is queried using the CIViCpy tool. It takes in single variants from a VCF and annotates them.
See the [querynator docs](https://querynator.readthedocs.io/en/latest/usage.html#query-the-clinical-interpretations-of-variants-in-cancer-civic) for more information

### Report

The resuls of the CIViC and CGI are query are combined. The variants are then categorized based on the guidelines proposed by the [AMP](https://www.sciencedirect.com/science/article/pii/S1525157816302239).
