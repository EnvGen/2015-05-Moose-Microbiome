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

config["assemblies"] = []
for assembly_dir in config["assembly_dir"]:
    for assembly in os.listdir(assembly_dir):
        config["assemblies"].append(os.path.join(assembly_dir,assembly))

# add assemblies to concoct assemblies
config["concoct_rules"]["assemblies"] = {os.path.basename(p).replace(".fasta", ""): p for p in config["assemblies"]}

SM_WORKFLOW_LOC="snakemake-workflows/"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/annotation/prokka.rules"
include: SM_WORKFLOW_LOC + "bio/ngs/rules/binning/concoct_eval.rules"
