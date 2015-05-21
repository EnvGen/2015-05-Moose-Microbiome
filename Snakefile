__author__ = "Inodb, Alneberg"
__license__ = "MIT"


configfile: "config.json"

import os
import glob
from subprocess import check_output

# Dynamically generate the missing items in the config dicionary here
# i.e. load config["bowtie2_rules"]["units"] with a dictionary of 
# the fastq files, pair is an unit. Collect the units originating to the
# same sample in the config["bowtie2_rules"]["samples"].

# Example:   
config["bowtie2_rules"]["samples"] = {}
config["bowtie2_rules"]["units"] = {}
for read_dir in config["fastq_dirs"]:
    for sample in os.listdir(read_dir):
        sample_dir_path = os.path.join(read_dir, sample)
        config["bowtie2_rules"]["samples"][sample] = []

        # Every sample should have a subdirectory for each unit
        for unit in os.listdir(sample_dir_path):
            # Every unit dir should have exactly 2 fastq files
            # the units list store the path to these files
            units = [os.path.join(sample_dir_path, unit, fastq_file) for fastq_file in os.listdir(os.path.join(sample_dir_path, unit))]

            config["bowtie2_rules"]["samples"][sample].append(unit)
            config["bowtie2_rules"]["units"][unit] = units

# Add the assembly to bowtie2_rules
config["assemblies"] = []
for assembly_dir in config["assembly_dir"]:
    for assembly in os.listdir(assembly_dir):
        config["assemblies"].append(os.path.join(assembly_dir,assembly))

# add assemblies to concoct assemblies
config["concoct_rules"]["assemblies"] = {os.path.basename(p).replace(".fasta", ""): p for p in config["assemblies"]}

# Check that no git repo is dirty
submodules = ["snakemake-workflows", "toolbox"]
for submodule in submodules:
    submodule_status = check_output(["git", "status", "--porcelain", submodule])
    if not submodule_status == b"":
        print(submodule_status)
        raise Exception("Submodule {} is dirty. Commit changes before proceeding.".format(submodule))

# Annotate approved bins with prokka_extended (will only work after 
# the approved bins have been created)
for contigs_f in glob.glob("concoct/approved_scg_bins/*.fa"):
    contigs = contigs_f.split('/')[-1].split('.')[0]
    config["prokka_extended_rules"]["contigs"][contigs] = contigs_f

SM_WORKFLOW_LOC="snakemake-workflows/"
include: SM_WORKFLOW_LOC + "common/rules/track_dir.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/assembly/report.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/mapping/bowtie2.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/mapping/samtools.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/mapping/report.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/binning/concoct.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/binning/concoct_eval.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/annotation/prodigal.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/blast/rpsblast.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/annotation/hmmer.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/annotation/prokka.rules"
localrules: track_changes

#  add regular assemblies for prodigal to predict genes for
for a_name, a in config["concoct_rules"]["assemblies"].items():
    config["prodigal_rules"]["assemblies"][a_name] = a 

#  add prodigal predicted genes as query for rpsblast
config["rpsblast_rules"]["query_aas"] = {a: "annotation/prodigal/default-meta/{a}/proteins/proteins.faa".format(a=a) for a in config["prodigal_rules"]["assemblies"]}

#  add prodigal predicted genes as query for hmmer
config["hmmer_rules"]["query_aas"] = config["rpsblast_rules"]["query_aas"]

rule track_changes:
    input:
        "results_track.txt"
