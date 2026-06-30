#!/usr/bin/env bash

# Step 02: run BrainSuite skull stripping, bias correction, and diffusion preprocessing.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
BRAINSUITE_DIR="$(config_value software.brainsuite_dir)"
OUT="$(results_dir)/02_BrainSuite"
BSE_OPTIONS="$(yaml_get preprocessing.brainsuite.bse_options)"
BFC_OPTIONS="$(yaml_get preprocessing.brainsuite.bfc_options)"
BDP_OPTIONS="$(yaml_get preprocessing.brainsuite.bdp_options)"
require_file "${BRAINSUITE_DIR}/bin/bse"
require_file "${BRAINSUITE_DIR}/bin/bfc"
require_file "${BRAINSUITE_DIR}/bdp/bdp.sh"
export OMP_NUM_THREADS=1
mkdir -p "${OUT}"

# Create one output folder per subject.
subject_ids | parallel --jobs "$(jobs)" mkdir -p "${OUT}/{}"

# Extract the brain from the BIDS T1w image.
subject_ids | parallel --jobs "$(jobs)" \
    "${BRAINSUITE_DIR}/bin/bse" \
        -i "$(bids_dir)/sub-{}/anat/sub-{}_T1w.nii.gz" \
        -o "${OUT}/{}/{}_T1w_skull_stripped.nii.gz" \
        -p \
        --trim \
        --mask "${OUT}/{}/{}_T1w_skull_stripped.mask.nii.gz" \
        --auto \
        ${BSE_OPTIONS}

# Correct low-frequency intensity bias in the skull-stripped T1w image.
subject_ids | parallel --jobs "$(jobs)" \
    "${BRAINSUITE_DIR}/bin/bfc" \
        -i "${OUT}/{}/{}_T1w_skull_stripped.nii.gz" \
        -o "${OUT}/{}/{}_T1w_skull_stripped.bfc.nii.gz" \
        ${BFC_OPTIONS}

# Run BrainSuite diffusion preprocessing with BIDS DWI, bvec, and bval files.
subject_ids | parallel --jobs "$(jobs)" \
    "${BRAINSUITE_DIR}/bdp/bdp.sh" \
        "${OUT}/{}/{}_T1w_skull_stripped.bfc.nii.gz" \
        --nii "$(bids_dir)/sub-{}/dwi/sub-{}_dwi.nii.gz" \
        -g "$(bids_dir)/sub-{}/dwi/sub-{}_dwi.bvec" \
        -b "$(bids_dir)/sub-{}/dwi/sub-{}_dwi.bval" \
        ${BDP_OPTIONS}
