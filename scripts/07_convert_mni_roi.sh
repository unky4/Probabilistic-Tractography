#!/usr/bin/env bash

# Step 07 alternative: convert a pipeline-supplied MNI ROI into each subject's native DWI space.
#
# This script intentionally follows the original project method:
#   1. copy the MNI ROI into each subject ROI folder as ROI_NAME_MNI.nii.gz;
#   2. transform MNI -> native DWI using the extracted 3D b0 image as reference;
#   3. transform MNI -> native T1 for visual checking;
#   4. binarise the generated masks.
#
# Important: the DWI reference must be the extracted 3D b0 image from the
# registration stage, not the 4D bedpostx input image. Using the 4D image as an
# ANTs reference can produce empty or geometrically invalid masks.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

ROI_NAME="$1"
MNI_ROI="$2"
ANTS_DIR="$(config_value software.ants_dir)"
REG_DIR="$(results_dir)/03_Image_Registrations"
ROI_DIR="$(results_dir)/05_ROIs"

require_file "${MNI_ROI}"
require_file "${ANTS_DIR}/bin/antsApplyTransforms"
require_command fslmaths
require_command fslstats

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1
export PATH="${ANTS_DIR}/bin:${PATH}"

mkdir -p "${ROI_DIR}"

check_nonempty_mask() {
    local mask_path="$1"
    local voxel_count

    voxel_count="$(fslstats "${mask_path}" -V | awk '{print $1}')"

    if [[ "${voxel_count}" == "0" ]]; then
        echo "Error: generated ROI is empty: ${mask_path}" >&2
        echo "Check the MNI ROI, registration transforms, and the DWI b0 reference image." >&2
        exit 1
    fi
}

while IFS= read -r SUBJECT_ID; do
    SUBJECT_ROI_DIR="${ROI_DIR}/${SUBJECT_ID}"
    SUBJECT_REG_DIR="${REG_DIR}/${SUBJECT_ID}"
    SUBJECT_BIDS_T1="$(bids_dir)/sub-${SUBJECT_ID}/anat/sub-${SUBJECT_ID}_T1w.nii.gz"
    DWI_REFERENCE="${SUBJECT_REG_DIR}/${SUBJECT_ID}_DWI_B0.nii.gz"

    echo "Converting MNI ROI '${ROI_NAME}' to native DWI space for subject ${SUBJECT_ID}"

    # Create the subject ROI directory before writing ROI files.
    mkdir -p "${SUBJECT_ROI_DIR}"

    # Confirm that the required registration products exist before conversion.
    require_file "${DWI_REFERENCE}"
    require_file "${SUBJECT_REG_DIR}/${SUBJECT_ID}_DWI_to_T1_0GenericAffine.mat"
    require_file "${SUBJECT_REG_DIR}/${SUBJECT_ID}_T1w_to_MNI_0GenericAffine.mat"
    require_file "${SUBJECT_REG_DIR}/${SUBJECT_ID}_T1w_to_MNI_1InverseWarp.nii.gz"
    require_file "${SUBJECT_BIDS_T1}"

    # Keep a subject-local copy of the original MNI ROI, matching the original script.
    cp \
        "${MNI_ROI}" \
        "${SUBJECT_ROI_DIR}/${ROI_NAME}_MNI.nii.gz"

    # Transform the MNI ROI into native DWI space using the original transform order.
    antsApplyTransforms \
        -d 3 \
        -i "${SUBJECT_ROI_DIR}/${ROI_NAME}_MNI.nii.gz" \
        -r "${DWI_REFERENCE}" \
        -o "${SUBJECT_ROI_DIR}/${ROI_NAME}.nii.gz" \
        -t "[${SUBJECT_REG_DIR}/${SUBJECT_ID}_DWI_to_T1_0GenericAffine.mat,1]" \
        -t "[${SUBJECT_REG_DIR}/${SUBJECT_ID}_T1w_to_MNI_0GenericAffine.mat,1]" \
        -t "${SUBJECT_REG_DIR}/${SUBJECT_ID}_T1w_to_MNI_1InverseWarp.nii.gz" \
        -n NearestNeighbor

    # Transform the MNI ROI into native T1 space for QC.
    antsApplyTransforms \
        -d 3 \
        -i "${SUBJECT_ROI_DIR}/${ROI_NAME}_MNI.nii.gz" \
        -r "${SUBJECT_BIDS_T1}" \
        -o "${SUBJECT_ROI_DIR}/${ROI_NAME}_T1.nii.gz" \
        -t "[${SUBJECT_REG_DIR}/${SUBJECT_ID}_T1w_to_MNI_0GenericAffine.mat,1]" \
        -t "${SUBJECT_REG_DIR}/${SUBJECT_ID}_T1w_to_MNI_1InverseWarp.nii.gz" \
        -n NearestNeighbor

    # Binarise the copied MNI ROI.
    fslmaths \
        "${SUBJECT_ROI_DIR}/${ROI_NAME}_MNI.nii.gz" \
        -bin \
        "${SUBJECT_ROI_DIR}/${ROI_NAME}_MNI.nii.gz"

    # Binarise the native-DWI ROI used by probtrackx2_gpu.
    fslmaths \
        "${SUBJECT_ROI_DIR}/${ROI_NAME}.nii.gz" \
        -bin \
        "${SUBJECT_ROI_DIR}/${ROI_NAME}.nii.gz"

    # Binarise the native-T1 QC ROI.
    fslmaths \
        "${SUBJECT_ROI_DIR}/${ROI_NAME}_T1.nii.gz" \
        -bin \
        "${SUBJECT_ROI_DIR}/${ROI_NAME}_T1.nii.gz"

    # Fail immediately if the DWI-space ROI is empty.
    check_nonempty_mask \
        "${SUBJECT_ROI_DIR}/${ROI_NAME}.nii.gz"
done < <(subject_ids)
