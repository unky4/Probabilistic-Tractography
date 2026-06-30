#!/usr/bin/env bash

# Step 01: run FreeSurfer recon-all for every BIDS subject.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
FREESURFER_HOME="$(config_value software.freesurfer_home)"
SUBJECTS_DIR="$(results_dir)/01_FreeSurfer"
RECON_ALL_OPTIONS="$(yaml_get preprocessing.freesurfer.recon_all_options)"
require_file "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
source "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
export SUBJECTS_DIR
mkdir -p "${SUBJECTS_DIR}"

# Run recon-all against each subject's BIDS T1w image.
subject_ids | parallel --jobs "$(jobs)" \
    recon-all \
        -s {} \
        -i "$(bids_dir)/sub-{}/anat/sub-{}_T1w.nii.gz" \
        ${RECON_ALL_OPTIONS}
