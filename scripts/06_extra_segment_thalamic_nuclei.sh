#!/usr/bin/env bash

# Optional Step 06b: segment thalamic nuclei for thalamic subregion ROIs.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
FREESURFER_HOME="$(config_value software.freesurfer_home)"
SUBJECTS_DIR="$(results_dir)/01_FreeSurfer"
require_file "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
source "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
export SUBJECTS_DIR

# Create ThalamicNuclei.v13.T1.FSvoxelSpace.mgz for each subject.
subject_ids | parallel --jobs "$(jobs)" \
    segmentThalamicNuclei.sh \
        {} \
        "${SUBJECTS_DIR}"
