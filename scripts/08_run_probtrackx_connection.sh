#!/usr/bin/env bash

# Step 08: run one flexible probtrackx2_gpu analysis across all subjects.
#
# This script intentionally mirrors the flexibility of the original project
# script. The pipeline supplies ROI names, not full subject-specific paths.
# For each subject, ROI names are resolved to:
#
#   results/05_ROIs/<subject>/<ROI_NAME>.nii.gz
#
# Automatically managed options are not allowed as user arguments:
# -s, -m, -l, --forcedir, --opd, and --dir are set by this script.
# All subjects are processed sequentially because this script uses the GPU.
#
# Usage:
#   08_run_probtrackx_connection.sh ANALYSIS_NAME --seed=ROI_NAME [probtrackx2 options]
#
# Flexible ROI arguments supported:
#   --waypoints=ROI_A,ROI_B
#   --targetmasks=ROI_A,ROI_B
#   --avoid=ROI_NAME
#   --stop=ROI_NAME
#   --wtstop=ROI_NAME
#   --target2=ROI_NAME
#   --target3=ROI_NAME
#   --colmask4=ROI_NAME
#   --target4=ROI_NAME

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
    cat >&2 <<'EOF'
Error: missing or invalid probtrackx2_gpu arguments.

Usage:
  08_run_probtrackx_connection.sh ANALYSIS_NAME --seed=ROI_NAME [probtrackx2 options]

Do not provide these options because they are set automatically:
  -s, -m, -l, --forcedir, --opd, --dir

ROI arguments should be ROI names, not paths. For example:
  --seed=MediodorsalThalamus_Left
  --stop=FrontalPole_Left
  --waypoints=Waypoint1_Left,Waypoint2_Left

For midline ROIs without hemispheres, use the exact ROI name created by the ROI
step, for example:
  --seed=MidlineSeed
EOF
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

ANALYSIS_NAME="$1"
shift

SEED_NAME=""
WAYPOINTS_NAME=""
TARGETMASKS_NAME=""
AVOID_NAME=""
STOP_NAME=""
WTSTOP_NAME=""
TARGET2_NAME=""
TARGET3_NAME=""
COLMASK4_NAME=""
TARGET4_NAME=""
OTHER_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|-m|-l|--forcedir|--opd|--dir|--dir=*)
            echo "Error: -s, -m, -l, --forcedir, --opd, and --dir are set automatically." >&2
            exit 2
            ;;
        -x)
            [[ $# -ge 2 ]] || usage
            SEED_NAME="$2"
            shift
            ;;
        --seed=*)
            SEED_NAME="${1#*=}"
            ;;
        --waypoints=*)
            WAYPOINTS_NAME="${1#*=}"
            ;;
        --targetmasks=*)
            TARGETMASKS_NAME="${1#*=}"
            ;;
        --avoid=*)
            AVOID_NAME="${1#*=}"
            ;;
        --stop=*)
            STOP_NAME="${1#*=}"
            ;;
        --wtstop=*)
            WTSTOP_NAME="${1#*=}"
            ;;
        --target2=*)
            TARGET2_NAME="${1#*=}"
            ;;
        --target3=*)
            TARGET3_NAME="${1#*=}"
            ;;
        --colmask4=*)
            COLMASK4_NAME="${1#*=}"
            ;;
        --target4=*)
            TARGET4_NAME="${1#*=}"
            ;;
        *)
            OTHER_ARGS+=("$1")
            ;;
    esac
    shift
done

if [[ -z "${SEED_NAME}" ]]; then
    usage
fi

require_command probtrackx2_gpu

ROI_DIR="$(results_dir)/05_ROIs"
BEDPOST_DIR="$(results_dir)/04_FSL_BedpostX"
ANALYSIS_DIR="$(results_dir)/06_FSL_ProbtrackX/${ANALYSIS_NAME}"

mkdir -p \
    "${ANALYSIS_DIR}"

write_roi_list() {
    local output_file="$1"
    local subject_id="$2"
    local roi_names="$3"

    : > "${output_file}"

    IFS=',' read -r -a roi_array <<< "${roi_names}"

    for roi_name in "${roi_array[@]}"; do
        roi_name="${roi_name//[[:space:]]/}"
        roi_path="${ROI_DIR}/${subject_id}/${roi_name}.nii.gz"

        require_file "${roi_path}"

        printf '%s\n' "${roi_path}" >> "${output_file}"
    done
}

append_optional_roi_argument() {
    local argument_name="$1"
    local roi_names="$2"
    local subject_id="$3"
    local subject_output_dir="$4"
    local -n output_array_ref="$5"

    if [[ -z "${roi_names}" ]]; then
        return 0
    fi

    local list_file="${subject_output_dir}/${argument_name}.txt"

    write_roi_list \
        "${list_file}" \
        "${subject_id}" \
        "${roi_names}"

    output_array_ref+=("--${argument_name}=${list_file}")
}

while IFS= read -r SUBJECT_ID; do
    SUBJECT_OUT="${ANALYSIS_DIR}/${SUBJECT_ID}"
    LIST_DIR="${ANALYSIS_DIR}/_roi_lists/${SUBJECT_ID}"
    BEDPOST_MERGED="${BEDPOST_DIR}/${SUBJECT_ID}.bedpostX/merged"
    BEDPOST_MASK="${BEDPOST_DIR}/${SUBJECT_ID}/nodif_brain_mask"
    SUBJECT_ARGS=("${OTHER_ARGS[@]}")

    echo "Running probtrackx2_gpu analysis '${ANALYSIS_NAME}' for subject ${SUBJECT_ID}"

    [[ -d "${BEDPOST_DIR}/${SUBJECT_ID}.bedpostX" ]] || {
        echo "Required bedpostx_gpu output directory not found: ${BEDPOST_DIR}/${SUBJECT_ID}.bedpostX" >&2
        exit 1
    }

    require_file "${BEDPOST_MASK}.nii.gz"

    # Store ROI list files outside the probtrackx output directory.
    # probtrackx2_gpu is called with --forcedir, so files already inside --dir may be deleted.
    mkdir -p \
        "${SUBJECT_OUT}" \
        "${LIST_DIR}"

    write_roi_list \
        "${LIST_DIR}/seed.txt" \
        "${SUBJECT_ID}" \
        "${SEED_NAME}"

    append_optional_roi_argument "waypoints" "${WAYPOINTS_NAME}" "${SUBJECT_ID}" "${LIST_DIR}" SUBJECT_ARGS
    append_optional_roi_argument "targetmasks" "${TARGETMASKS_NAME}" "${SUBJECT_ID}" "${LIST_DIR}" SUBJECT_ARGS
    append_optional_roi_argument "avoid" "${AVOID_NAME}" "${SUBJECT_ID}" "${LIST_DIR}" SUBJECT_ARGS
    append_optional_roi_argument "stop" "${STOP_NAME}" "${SUBJECT_ID}" "${LIST_DIR}" SUBJECT_ARGS
    append_optional_roi_argument "wtstop" "${WTSTOP_NAME}" "${SUBJECT_ID}" "${LIST_DIR}" SUBJECT_ARGS
    append_optional_roi_argument "target2" "${TARGET2_NAME}" "${SUBJECT_ID}" "${LIST_DIR}" SUBJECT_ARGS
    append_optional_roi_argument "target3" "${TARGET3_NAME}" "${SUBJECT_ID}" "${LIST_DIR}" SUBJECT_ARGS
    append_optional_roi_argument "colmask4" "${COLMASK4_NAME}" "${SUBJECT_ID}" "${LIST_DIR}" SUBJECT_ARGS
    append_optional_roi_argument "target4" "${TARGET4_NAME}" "${SUBJECT_ID}" "${LIST_DIR}" SUBJECT_ARGS

    probtrackx2_gpu \
        -s "${BEDPOST_MERGED}" \
        -m "${BEDPOST_MASK}" \
        -x "${LIST_DIR}/seed.txt" \
        -l \
        --forcedir \
        --opd \
        --dir="${SUBJECT_OUT}" \
        "${SUBJECT_ARGS[@]}"

    # Keep the exact ROI list files used for this run inside the subject output folder.
    cp \
        "${LIST_DIR}"/*.txt \
        "${SUBJECT_OUT}/"
done < <(subject_ids)
