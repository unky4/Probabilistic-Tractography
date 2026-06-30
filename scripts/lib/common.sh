#!/usr/bin/env bash

# Shared helper functions only. No project constants are defined here.

# All paths and settings are resolved from config.yaml or a pipeline YAML at runtime.
project_python() {
    local root
    root="$(project_root)"

    if [[ -x "${root}/.venv/bin/python" ]]; then
        printf '%s\n' "${root}/.venv/bin/python"
    else
        command -v python3
    fi
}
script_dir() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }
project_root() { cd "$(script_dir)/.." && pwd; }
config_path() { printf '%s\n' "${CONFIG_YAML:-$(project_root)/config.yaml}"; }
pipeline_path() { printf '%s\n' "${PIPELINE_YAML:?PIPELINE_YAML is not set}"; }
yaml_get() { "$(project_python)" "$(script_dir)/yaml_query.py" "$(config_path)" "$1"; }
pipeline_get() { "$(project_python)" "$(script_dir)/yaml_query.py" "$(pipeline_path)" "$1"; }
expand_path() { "$(project_python)" - "$1" <<'PY'
import os, sys
print(os.path.abspath(os.path.expandvars(os.path.expanduser(sys.argv[1]))))
PY
}
config_value() { "$(project_python)" "$(script_dir)/resolve_config.py" "$(config_path)" "$1"; }
results_dir() { config_value project.results_dir; }
bids_dir() { config_value project.bids_dir; }
mni_template() { config_value software.mni_template; }
jobs() { yaml_get resources.jobs; }
require_command() { command -v "$1" >/dev/null 2>&1 || { echo "Required command not found: $1" >&2; exit 127; }; }
require_file() { [[ -f "$1" ]] || { echo "Required file not found: $1" >&2; exit 1; }; }
subject_ids() { "$(project_python)" "$(script_dir)/list_subjects.py" --config "$(config_path)"; }
