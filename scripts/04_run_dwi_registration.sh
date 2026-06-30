#!/usr/bin/env bash

# Step 04: extract b0, register DWI-to-T1, and register T1-to-MNI.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
ANTS_DIR="$(config_value software.ants_dir)"
OUT="$(results_dir)/03_Image_Registrations"
MNI="$(mni_template)"
require_command fslroi
require_file "${ANTS_DIR}/bin/antsBrainExtraction.sh"
require_file "${ANTS_DIR}/bin/antsRegistrationSyN.sh"
require_file "${MNI}"
export PATH="${ANTS_DIR}/bin:${PATH}"
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS="$(yaml_get preprocessing.ants.itk_threads_per_subject)"

# Extract the first DWI volume as the b0 reference image.
subject_ids | parallel --jobs "$(jobs)" \
    fslroi \
        "$(bids_dir)/sub-{}/dwi/sub-{}_dwi.nii.gz" \
        "${OUT}/{}/{}_DWI_B0.nii.gz" \
        0 \
        1

# Skull-strip the b0 using the T1-derived brain mask as anatomical guidance.
subject_ids | parallel --jobs "$(jobs)" \
    antsBrainExtraction.sh \
        -d 3 \
        -a "${OUT}/{}/{}_DWI_B0.nii.gz" \
        -e "$(bids_dir)/sub-{}/anat/sub-{}_T1w.nii.gz" \
        -m "${OUT}/{}/{}_T1w_BrainExtractionMask.nii.gz" \
        -o "${OUT}/{}/{}_DWI_B0_"

# Register DWI b0 to the subject T1w image with a rigid transform.
subject_ids | parallel --jobs "$(jobs)" \
    antsRegistrationSyN.sh \
        -d 3 \
        -f "${OUT}/{}/{}_T1w_BrainExtractionBrain.nii.gz" \
        -m "${OUT}/{}/{}_DWI_B0_BrainExtractionBrain.nii.gz" \
        -o "${OUT}/{}/{}_DWI_to_T1_" \
        -t r

# Register the subject T1w image to MNI space.
subject_ids | parallel --jobs "$(jobs)" \
    antsRegistrationSyN.sh \
        -d 3 \
        -f "${MNI}" \
        -m "${OUT}/{}/{}_T1w_BrainExtractionBrain.nii.gz" \
        -o "${OUT}/{}/{}_T1w_to_MNI_"
