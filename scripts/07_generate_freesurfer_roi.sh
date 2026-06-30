#!/usr/bin/env bash

# Step 07: generate one or two native-DWI ROIs from a FreeSurfer segmentation.
#
# Supported ROI layouts:
#   1. Midline/non-lateralised ROI:
#      07_generate_freesurfer_roi.sh ROI_NAME SOURCE_MGZ --indices IDS
#
#   2. Left/right ROI pair:
#      07_generate_freesurfer_roi.sh ROI_NAME SOURCE_MGZ --left-indices IDS --right-indices IDS
#
# The final ProbtrackX ROI is resampled to the extracted 3D DWI b0 reference,
# matching the original MNI ROI conversion method and avoiding 4D bedpostx
# reference images.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

if [[ $# -lt 4 ]]; then
    echo "Usage: 07_generate_freesurfer_roi.sh ROI_NAME SOURCE_MGZ --indices IDS" >&2
    echo "   or: 07_generate_freesurfer_roi.sh ROI_NAME SOURCE_MGZ --left-indices IDS --right-indices IDS" >&2
    exit 1
fi

ROI_NAME="$1"
SOURCE_REL="$2"
shift 2

FREESURFER_HOME="$(config_value software.freesurfer_home)"
ANTS_DIR="$(config_value software.ants_dir)"
SUBJECTS_DIR="$(results_dir)/01_FreeSurfer"
ROI_DIR="$(results_dir)/05_ROIs"
REG_DIR="$(results_dir)/03_Image_Registrations"

require_file "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
require_file "${ANTS_DIR}/bin/antsApplyTransforms"
require_command fslmaths
require_command fslstats

source "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
export SUBJECTS_DIR
export PATH="${ANTS_DIR}/bin:${PATH}"

mkdir -p "${ROI_DIR}"

while IFS= read -r SUBJECT_ID; do
    SUBJECT_ROI_DIR="${ROI_DIR}/${SUBJECT_ID}"
    SOURCE_MGZ="${SUBJECTS_DIR}/${SUBJECT_ID}/${SOURCE_REL}"
    REFERENCE_T1="$(bids_dir)/sub-${SUBJECT_ID}/anat/sub-${SUBJECT_ID}_T1w.nii.gz"
    DWI_REFERENCE="${REG_DIR}/${SUBJECT_ID}/${SUBJECT_ID}_DWI_B0.nii.gz"
    DWI_TO_T1_AFFINE="${REG_DIR}/${SUBJECT_ID}/${SUBJECT_ID}_DWI_to_T1_0GenericAffine.mat"

    echo "Generating FreeSurfer ROI '${ROI_NAME}' for subject ${SUBJECT_ID}"

    require_file "${SOURCE_MGZ}"
    require_file "${REFERENCE_T1}"
    require_file "${DWI_REFERENCE}"
    require_file "${DWI_TO_T1_AFFINE}"

    # Create the subject ROI directory before writing any ROI files.
    mkdir -p "${SUBJECT_ROI_DIR}"

    # Delegate label extraction and DWI-space resampling to the shared helper.
    "$(script_dir)/resample_and_save.sh" \
        "${SUBJECT_ROI_DIR}" \
        "${SOURCE_MGZ}" \
        "${REFERENCE_T1}" \
        "${DWI_REFERENCE}" \
        "${DWI_TO_T1_AFFINE}" \
        "${ROI_NAME}" \
        "$@"
done < <(subject_ids)
