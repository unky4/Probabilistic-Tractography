#!/usr/bin/env bash

# Open the DWI-to-MNI QC image in FSLeyes.

# Inspect whether each subject's b0 image is aligned with the MNI template.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

QC_IMAGE="$(results_dir)/qc/dwi_to_mni/DWI_B0_in_MNI_All_4D.nii.gz"

# Open the MNI template and the merged b0 image for visual quality control.
fsleyes     "$(mni_template)"     "${QC_IMAGE}"
