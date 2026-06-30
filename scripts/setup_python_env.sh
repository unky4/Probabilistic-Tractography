#!/usr/bin/env bash

# Create a local Python virtual environment for pipeline helper scripts.

# This avoids hard-coded user-specific Conda paths.


PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${PROJECT_ROOT}/.venv"

# Create the virtual environment when it does not already exist.
if [[ ! -d "${ENV_DIR}" ]]; then
    python3 -m venv "${ENV_DIR}"
fi

# Install the small Python dependency set used by the pipeline runner.
"${ENV_DIR}/bin/python"     -m pip install     --upgrade pip

# Install project helper-script requirements.
"${ENV_DIR}/bin/python"     -m pip install     -r "${PROJECT_ROOT}/requirements.txt"
