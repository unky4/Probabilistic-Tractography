#!/usr/bin/env bash

# Check that all external neuroimaging software paths can be resolved.
#
# This script does not run any analysis. It reads config.yaml and prints the
# resolved locations for FSL, FreeSurfer, BrainSuite, ANTs, and template files.


source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

# Resolve software folders from config.yaml.
FSLDIR_PATH="$(config_value software.fsldir)"
FREESURFER_HOME="$(config_value software.freesurfer_home)"
BRAINSUITE_DIR_PATH="$(config_value software.brainsuite_dir)"
ANTS_DIR_PATH="$(config_value software.ants_dir)"
MNI_TEMPLATE_PATH="$(config_value software.mni_template)"
NKI_TEMPLATE_PATH="$(config_value preprocessing.ants.nki_template)"
NKI_MASK_PATH="$(config_value preprocessing.ants.nki_mask)"

# Print the resolved paths so the user can confirm the intended installations.
printf 'Resolved FSLDIR:          %s\n' "${FSLDIR_PATH}"
printf 'Resolved FreeSurfer:      %s\n' "${FREESURFER_HOME}"
printf 'Resolved BrainSuite:      %s\n' "${BRAINSUITE_DIR_PATH}"
printf 'Resolved ANTs:            %s\n' "${ANTS_DIR_PATH}"
printf 'Resolved MNI template:    %s\n' "${MNI_TEMPLATE_PATH}"
printf 'Resolved NKI template:    %s\n' "${NKI_TEMPLATE_PATH}"
printf 'Resolved NKI mask:        %s\n' "${NKI_MASK_PATH}"

# Check the executable and template files required by the project scripts.
require_file "${FSLDIR_PATH}/bin/fslmaths"
require_file "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
require_file "${BRAINSUITE_DIR_PATH}/bin/bse"
require_file "${BRAINSUITE_DIR_PATH}/bin/bfc"
require_file "${BRAINSUITE_DIR_PATH}/bdp/bdp.sh"
require_file "${ANTS_DIR_PATH}/bin/antsBrainExtraction.sh"
require_file "${ANTS_DIR_PATH}/bin/antsRegistrationSyN.sh"
require_file "${ANTS_DIR_PATH}/bin/antsApplyTransforms"
require_file "${MNI_TEMPLATE_PATH}"
require_file "${NKI_TEMPLATE_PATH}"
require_file "${NKI_MASK_PATH}"

# Report success only after every required file has been found.
printf '\nAll configured software paths are valid.\n'
