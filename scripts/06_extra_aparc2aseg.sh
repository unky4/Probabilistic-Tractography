#!/usr/bin/env bash

# Optional Step 06a: create aparc.cortical.mgz for cortical label ROIs.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
FREESURFER_HOME="$(config_value software.freesurfer_home)"
SUBJECTS_DIR="$(results_dir)/01_FreeSurfer"
require_file "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
source "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
export SUBJECTS_DIR

# Build cortical aparc/aseg volume used by frontal/temporal pole ROIs.
subject_ids | parallel --jobs "$(jobs)" \
    mri_aparc2aseg \
        --s {} \
        --rip-unknown \
        --volmask \
        --o "${SUBJECTS_DIR}/{}/aparc.cortical.mgz"
