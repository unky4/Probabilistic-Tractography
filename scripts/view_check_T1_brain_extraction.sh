#!/usr/bin/env bash

# Open all ANTs-extracted T1w brain images in FSLeyes.

# Inspect these images before running DWI registration.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

REG_DIR="$(results_dir)/03_Image_Registrations"

# Collect all extracted T1w brain images in a deterministic subject order.
mapfile -t IMAGES < <(find "${REG_DIR}" -name '*_T1w_BrainExtractionBrain.nii.gz' | sort)

if [[ "${#IMAGES[@]}" -eq 0 ]]; then
    echo "No extracted T1w brain images found under ${REG_DIR}." >&2
    exit 1
fi

# Open all extracted images for visual quality control.
fsleyes     "${IMAGES[@]}"
