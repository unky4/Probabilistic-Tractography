#!/usr/bin/env bash

# Step 09: warp native-space probtrackx maps to MNI space.
#
# This step follows the original project logic:
#   1. read each subject's native fdt_paths image from the ProbtrackX result folder;
#   2. warp that image from DWI/native space to the standard MNI template;
#   3. optionally normalise the warped map;
#   4. optionally threshold the warped probability map.
#
# The script now stops with a clear message when an expected fdt_paths image is
# missing instead of letting fslmaths fail later with "No image files match".

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

ANALYSIS_NAME="$1"
NORMALISE="$2"
THRESHOLD="$3"
FILE_NAME="${4:-fdt_paths}"

ANTS_DIR="$(config_value software.ants_dir)"
MNI_TEMPLATE="$(mni_template)"
REGISTRATION_DIR="$(results_dir)/03_Image_Registrations"
PROBTRACKX_DIR="$(results_dir)/06_FSL_ProbtrackX/${ANALYSIS_NAME}"
MNI_OUTPUT_DIR="$(results_dir)/07_MNI_Probability_Maps/${ANALYSIS_NAME}"

require_file "${ANTS_DIR}/bin/antsApplyTransforms"
require_command fslmaths
require_file "${MNI_TEMPLATE}"

export PATH="${ANTS_DIR}/bin:${PATH}"

mkdir -p "${MNI_OUTPUT_DIR}"

while IFS= read -r SUBJECT_ID; do
    SUBJECT_PROBTRACKX_DIR="${PROBTRACKX_DIR}/${SUBJECT_ID}"
    SUBJECT_FDT_PATH="${SUBJECT_PROBTRACKX_DIR}/${FILE_NAME}.nii.gz"
    SUBJECT_OUTPUT_PATH="${MNI_OUTPUT_DIR}/${SUBJECT_ID}.nii.gz"

    DWI_TO_T1_AFFINE="${REGISTRATION_DIR}/${SUBJECT_ID}/${SUBJECT_ID}_DWI_to_T1_0GenericAffine.mat"
    LEGACY_DTI_TO_T1_AFFINE="${REGISTRATION_DIR}/${SUBJECT_ID}/${SUBJECT_ID}_DTI_to_T1_0GenericAffine.mat"
    T1_TO_MNI_AFFINE="${REGISTRATION_DIR}/${SUBJECT_ID}/${SUBJECT_ID}_T1w_to_MNI_0GenericAffine.mat"
    T1_TO_MNI_WARP="${REGISTRATION_DIR}/${SUBJECT_ID}/${SUBJECT_ID}_T1w_to_MNI_1Warp.nii.gz"

    if [[ ! -f "${DWI_TO_T1_AFFINE}" && -f "${LEGACY_DTI_TO_T1_AFFINE}" ]]; then
        DWI_TO_T1_AFFINE="${LEGACY_DTI_TO_T1_AFFINE}"
    fi

    echo "Warping ${ANALYSIS_NAME}/${SUBJECT_ID}/${FILE_NAME}.nii.gz to MNI space"

    require_file "${SUBJECT_FDT_PATH}"
    require_file "${DWI_TO_T1_AFFINE}"
    require_file "${T1_TO_MNI_AFFINE}"
    require_file "${T1_TO_MNI_WARP}"

    antsApplyTransforms \
        -d 3 \
        -i "${SUBJECT_FDT_PATH}" \
        -r "${MNI_TEMPLATE}" \
        -o "${SUBJECT_OUTPUT_PATH}" \
        -t "${T1_TO_MNI_WARP}" \
        -t "${T1_TO_MNI_AFFINE}" \
        -t "${DWI_TO_T1_AFFINE}"

    require_file "${SUBJECT_OUTPUT_PATH}"

    if [[ "${NORMALISE}" == "true" ]]; then
        NORMALISER=""

        if [[ -f "${SUBJECT_PROBTRACKX_DIR}/NumSeeds_of_ROIs" ]]; then
            NORMALISER="$(paste -sd+ "${SUBJECT_PROBTRACKX_DIR}/NumSeeds_of_ROIs" | bc)"
        elif [[ -f "${SUBJECT_PROBTRACKX_DIR}/waytotal" ]]; then
            NORMALISER="$(cat "${SUBJECT_PROBTRACKX_DIR}/waytotal")"
        fi

        if [[ -n "${NORMALISER}" ]] && [[ "${NORMALISER}" != "0" ]]; then
            fslmaths \
                "${SUBJECT_OUTPUT_PATH}" \
                -div "${NORMALISER}" \
                "${SUBJECT_OUTPUT_PATH}"
        else
            echo "Warning: no valid normalisation value for ${SUBJECT_ID}; keeping unnormalised map." >&2
        fi
    fi

    if [[ -n "${THRESHOLD}" ]] && [[ "${THRESHOLD}" != "0" ]]; then
        fslmaths \
            "${SUBJECT_OUTPUT_PATH}" \
            -thr "${THRESHOLD}" \
            "${SUBJECT_OUTPUT_PATH}"
    fi

done < <(subject_ids)
