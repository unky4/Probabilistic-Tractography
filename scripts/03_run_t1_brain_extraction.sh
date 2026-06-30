#!/usr/bin/env bash

# Step 03: extract each subject's T1w brain using ANTs.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
ANTS_DIR="$(config_value software.ants_dir)"
NKI_TEMPLATE="$(config_value preprocessing.ants.nki_template)"
NKI_MASK="$(config_value preprocessing.ants.nki_mask)"
OUT="$(results_dir)/03_Image_Registrations"
require_file "${ANTS_DIR}/bin/antsBrainExtraction.sh"
require_file "${NKI_TEMPLATE}"
require_file "${NKI_MASK}"
export PATH="${ANTS_DIR}/bin:${PATH}"
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS="$(yaml_get preprocessing.ants.itk_threads_per_subject)"
mkdir -p "${OUT}"

# Create one registration folder per subject.
subject_ids | parallel --jobs "$(jobs)" mkdir -p "${OUT}/{}"

# Estimate the T1w brain mask and skull-stripped image.
subject_ids | parallel --jobs "$(jobs)" \
    antsBrainExtraction.sh \
        -d 3 \
        -a "$(bids_dir)/sub-{}/anat/sub-{}_T1w.nii.gz" \
        -e "${NKI_TEMPLATE}" \
        -m "${NKI_MASK}" \
        -o "${OUT}/{}/{}_T1w_"
