#!/usr/bin/env bash

snakemake -j 999 --debug --immediate-submit --cluster 'python Snakefile_sbatch.py {dependencies}' prokka_extended_all
