#!/usr/bin/env bash

# Step 05: prepare and run FSL bedpostx_gpu for each subject.

# This is the final preprocessing stage and should only be run after registration QC passes.
# BedpostX is intentionally run sequentially because the GPU job should not be
# launched for multiple subjects at the same time from this script.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

OUT="$(results_dir)/04_FSL_BedpostX"
BEDPOSTX_OPTIONS="$(yaml_get bedpostx.options)"

require_command bedpostx_gpu

mkdir -p "${OUT}"

# Process each subject one at a time to avoid launching multiple GPU jobs.
while IFS= read -r SUBJECT_ID; do
    SUBJECT_DIR="${OUT}/${SUBJECT_ID}"
    SUBJECT_BIDS_DIR="$(bids_dir)/sub-${SUBJECT_ID}/dwi"
    SUBJECT_REG_DIR="$(results_dir)/03_Image_Registrations/${SUBJECT_ID}"

    DWI_IMAGE="${SUBJECT_BIDS_DIR}/sub-${SUBJECT_ID}_dwi.nii.gz"
    BVEC_FILE="${SUBJECT_BIDS_DIR}/sub-${SUBJECT_ID}_dwi.bvec"
    BVAL_FILE="${SUBJECT_BIDS_DIR}/sub-${SUBJECT_ID}_dwi.bval"
    BRAIN_MASK="${SUBJECT_REG_DIR}/${SUBJECT_ID}_DWI_B0_BrainExtractionMask.nii.gz"

    echo "Preparing bedpostx_gpu input for ${SUBJECT_ID}"

    # Confirm that the BIDS DWI image exists before copying it.
    require_file "${DWI_IMAGE}"

    # Confirm that the BIDS b-vector file exists before copying it.
    require_file "${BVEC_FILE}"

    # Confirm that the BIDS b-value file exists before copying it.
    require_file "${BVAL_FILE}"

    # Confirm that the DWI-space brain mask exists before copying it.
    require_file "${BRAIN_MASK}"

    # Create the subject-specific bedpostx input directory.
    mkdir -p \
        "${SUBJECT_DIR}"

    # Copy the BIDS DWI image into the filename expected by bedpostx_gpu.
    cp \
        "${DWI_IMAGE}" \
        "${SUBJECT_DIR}/data.nii.gz"

    # Copy the BIDS b-vector file into the filename expected by bedpostx_gpu.
    cp \
        "${BVEC_FILE}" \
        "${SUBJECT_DIR}/bvecs"

    # Copy the BIDS b-value file into the filename expected by bedpostx_gpu.
    cp \
        "${BVAL_FILE}" \
        "${SUBJECT_DIR}/bvals"

    # Copy the DWI-space brain mask into the filename expected by bedpostx_gpu.
    cp \
        "${BRAIN_MASK}" \
        "${SUBJECT_DIR}/nodif_brain_mask.nii.gz"

    echo "Running bedpostx_gpu for ${SUBJECT_ID}"

    # Fit crossing-fibre diffusion models using the GPU implementation.
    bedpostx_gpu \
        "${SUBJECT_DIR}" \
        ${BEDPOSTX_OPTIONS}
done < <(subject_ids)
