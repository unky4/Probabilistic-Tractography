#!/usr/bin/env bash

# Extract FreeSurfer labels and save tractography-ready ROIs in native DWI space.
#
# The original scripts generated FreeSurfer ROIs from subject-specific segmentation
# files and used those ROI names directly in probtrackx. This helper keeps that
# behaviour, but makes the final output explicit:
#
#   OUT/ROI_NAME.nii.gz          native DWI-space ROI used by probtrackx2_gpu
#   OUT/ROI_NAME_T1.nii.gz       native T1-space QC copy
#   OUT/ROI_NAME.mgz            temporary FreeSurfer-space binary ROI
#
# Both single/midline ROIs and left/right ROI pairs are supported.

if [[ $# -lt 8 ]]; then
    echo "Usage: resample_and_save.sh OUT SOURCE_MGZ REFERENCE_T1 DWI_B0_REFERENCE DWI_TO_T1_AFFINE ROI_NAME --indices IDS" >&2
    echo "   or: resample_and_save.sh OUT SOURCE_MGZ REFERENCE_T1 DWI_B0_REFERENCE DWI_TO_T1_AFFINE ROI_NAME --left-indices IDS --right-indices IDS" >&2
    exit 1
fi

OUT_DIR="$1"
SOURCE_MGZ="$2"
REFERENCE_T1="$3"
DWI_B0_REFERENCE="$4"
DWI_TO_T1_AFFINE="$5"
ROI_NAME="$6"
shift 6

SINGLE_INDICES=""
LEFT_INDICES=""
RIGHT_INDICES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --indices)
            [[ $# -ge 2 ]] || { echo "Missing value for --indices" >&2; exit 1; }
            SINGLE_INDICES="$2"
            shift 2
            ;;
        --indices=*)
            SINGLE_INDICES="${1#*=}"
            shift
            ;;
        --left-indices)
            [[ $# -ge 2 ]] || { echo "Missing value for --left-indices" >&2; exit 1; }
            LEFT_INDICES="$2"
            shift 2
            ;;
        --left-indices=*)
            LEFT_INDICES="${1#*=}"
            shift
            ;;
        --right-indices)
            [[ $# -ge 2 ]] || { echo "Missing value for --right-indices" >&2; exit 1; }
            RIGHT_INDICES="$2"
            shift 2
            ;;
        --right-indices=*)
            RIGHT_INDICES="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown ROI argument: $1" >&2
            exit 1
            ;;
    esac
done

mkdir -p "${OUT_DIR}"

command -v fslstats >/dev/null 2>&1 || { echo "Required command not found: fslstats" >&2; exit 1; }

check_nonempty_mask() {
    local mask_path="$1"
    local voxel_count

    voxel_count="$(fslstats "${mask_path}" -V | awk '{print $1}')"

    if [[ "${voxel_count}" == "0" ]]; then
        echo "Error: generated ROI is empty: ${mask_path}" >&2
        exit 1
    fi
}

make_roi() {
    local output_stem="$1"
    local label_indices="$2"

    if [[ -z "${label_indices}" ]]; then
        echo "No label indices supplied for ${output_stem}" >&2
        exit 1
    fi

    # Binarise the requested FreeSurfer labels into a temporary MGZ ROI.
    mri_binarize \
        --i "${SOURCE_MGZ}" \
        --match ${label_indices//,/ } \
        --o "${OUT_DIR}/${output_stem}.mgz"

    # Save a T1-space QC copy using FreeSurfer header registration.
    mri_vol2vol \
        --mov "${OUT_DIR}/${output_stem}.mgz" \
        --targ "${REFERENCE_T1}" \
        --regheader \
        --nearest \
        --o "${OUT_DIR}/${output_stem}_T1.nii.gz"

    # Resample the T1-space ROI onto the exact DWI/bedpostx grid used by probtrackx.
    antsApplyTransforms \
        -d 3 \
        -i "${OUT_DIR}/${output_stem}_T1.nii.gz" \
        -r "${DWI_B0_REFERENCE}" \
        -o "${OUT_DIR}/${output_stem}.nii.gz" \
        -t "[${DWI_TO_T1_AFFINE},1]" \
        -n NearestNeighbor

    # Binarise after resampling so interpolation/header quirks cannot leave non-binary masks.
    fslmaths \
        "${OUT_DIR}/${output_stem}.nii.gz" \
        -bin \
        "${OUT_DIR}/${output_stem}.nii.gz"

    # Binarise the T1-space QC copy as well.
    fslmaths \
        "${OUT_DIR}/${output_stem}_T1.nii.gz" \
        -bin \
        "${OUT_DIR}/${output_stem}_T1.nii.gz"

    # Stop immediately if the DWI-space ROI is empty.
    check_nonempty_mask \
        "${OUT_DIR}/${output_stem}.nii.gz"
}

if [[ -n "${SINGLE_INDICES}" ]]; then
    if [[ -n "${LEFT_INDICES}" || -n "${RIGHT_INDICES}" ]]; then
        echo "Use either --indices or --left-indices/--right-indices, not both." >&2
        exit 1
    fi

    # Create a single non-lateralised ROI without adding a hemisphere suffix.
    make_roi \
        "${ROI_NAME}" \
        "${SINGLE_INDICES}"
else
    if [[ -z "${LEFT_INDICES}" || -z "${RIGHT_INDICES}" ]]; then
        echo "Left/right ROI generation requires both --left-indices and --right-indices." >&2
        exit 1
    fi

    # Create the left hemisphere ROI using the requested left-side label IDs.
    make_roi \
        "${ROI_NAME}_Left" \
        "${LEFT_INDICES}"

    # Create the right hemisphere ROI using the requested right-side label IDs.
    make_roi \
        "${ROI_NAME}_Right" \
        "${RIGHT_INDICES}"
fi
