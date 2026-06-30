#!/usr/bin/env bash

# QC: warp each subject's b0 image into MNI space and merge the outputs.

# The merged 4D file is used by view_check_DWI_to_MNI.sh for visual inspection.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

ANTS_DIR="$(config_value software.ants_dir)"
REG_DIR="$(results_dir)/03_Image_Registrations"
MNI="$(mni_template)"
QC_DIR="$(results_dir)/qc/dwi_to_mni"

require_file "${ANTS_DIR}/bin/antsApplyTransforms"
require_command fslmerge
require_file "${MNI}"

export PATH="${ANTS_DIR}/bin:${PATH}"

mkdir -p "${QC_DIR}"

# Apply the complete DWI-to-MNI transform chain to each subject's b0 image.
subject_ids | parallel --jobs "$(jobs)"     antsApplyTransforms         -d 3         -i "${REG_DIR}/{}/{}_DWI_B0.nii.gz"         -r "${MNI}"         -o "${QC_DIR}/{}_DWI_B0_in_MNI.nii.gz"         -t "${REG_DIR}/{}/{}_T1w_to_MNI_1Warp.nii.gz"         -t "${REG_DIR}/{}/{}_T1w_to_MNI_0GenericAffine.mat"         -t "${REG_DIR}/{}/{}_DWI_to_T1_0GenericAffine.mat"

# Collect the warped b0 images in a deterministic subject order.
mapfile -t QC_IMAGES < <(find "${QC_DIR}" -name '*_DWI_B0_in_MNI.nii.gz' | sort)

# Merge all warped b0 images into one 4D file for rapid visual inspection.
fslmerge     -t "${QC_DIR}/DWI_B0_in_MNI_All_4D.nii.gz"     "${QC_IMAGES[@]}"
