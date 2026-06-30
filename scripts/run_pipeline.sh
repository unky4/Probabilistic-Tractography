#!/usr/bin/env bash

# Run a YAML pipeline from the project root.

# Examples:

#   scripts/run_pipeline.sh --pipeline pipelines/preprocessing_T1.yaml

#   scripts/run_pipeline.sh --pipeline pipelines/preprocessing_brain_extraction.yaml

#   scripts/run_pipeline.sh --pipeline pipelines/preprocessing_registration.yaml

#   scripts/run_pipeline.sh --pipeline pipelines/preprocessing_fsl.yaml

#   scripts/run_pipeline.sh --pipeline pipelines/tracts/anterior_thalamic_radiation.yaml --dry-run


PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PROJECT_ROOT}/.venv/bin/python"

if [[ ! -x "${PYTHON_BIN}" ]]; then
    "${PROJECT_ROOT}/scripts/setup_python_env.sh"
fi

"${PYTHON_BIN}" "${PROJECT_ROOT}/scripts/run_pipeline.py" "$@"
