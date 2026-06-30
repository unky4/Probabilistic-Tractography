#!/usr/bin/env python3
"""Read a config value and resolve project-relative paths and software paths.

The config file may use absolute paths, project-relative paths, environment
variables, or the special value "auto" for external software locations.
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path
from typing import Any

import yaml


COMMON_INSTALLS = {
    "software.fsldir": ["/usr/local/fsl", "/opt/fsl"],
    "software.freesurfer_home": ["/usr/local/freesurfer", "/opt/freesurfer"],
    "software.brainsuite_dir": ["/usr/local/BrainSuite", "/opt/BrainSuite", "/opt/brainsuite"],
    "software.ants_dir": ["/usr/local/ants", "/opt/ants", "/usr/local/ANTs", "/opt/ANTs"],
}

ENV_NAMES = {
    "software.fsldir": ["FSLDIR"],
    "software.freesurfer_home": ["FREESURFER_HOME"],
    "software.brainsuite_dir": ["BRAINSUITE_DIR"],
    "software.ants_dir": ["ANTS_DIR", "ANTSPATH"],
}

COMMANDS = {
    "software.fsldir": "fslmaths",
    "software.freesurfer_home": "recon-all",
    "software.brainsuite_dir": "bse",
    "software.ants_dir": "antsRegistrationSyN.sh",
}


def read_yaml(path: Path) -> dict[str, Any]:
    with path.open() as handle:
        return yaml.safe_load(handle) or {}


def dotted_get(data: dict[str, Any], key: str) -> Any:
    value: Any = data
    for part in key.split("."):
        value = value[int(part)] if isinstance(value, list) else value[part]
    return value


def clean_path(value: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def command_install_root(command: str) -> Path | None:
    executable = shutil.which(command)
    if executable is None:
        return None

    executable_path = Path(executable).resolve()

    if executable_path.parent.name == "bin":
        return executable_path.parent.parent

    return executable_path.parent


def valid_software_root(key: str, root: Path) -> bool:
    if key == "software.fsldir":
        return (root / "bin" / "fslmaths").exists() or (root / "data" / "standard").exists()

    if key == "software.freesurfer_home":
        return (root / "SetUpFreeSurfer.sh").exists() or (root / "bin" / "recon-all").exists()

    if key == "software.brainsuite_dir":
        return (root / "bin" / "bse").exists() or (root / "bdp" / "bdp.sh").exists()

    if key == "software.ants_dir":
        return (root / "bin" / "antsRegistrationSyN.sh").exists() or (root / "antsRegistrationSyN.sh").exists()

    return root.exists()


def resolve_auto_software(key: str) -> Path:
    for env_name in ENV_NAMES.get(key, []):
        env_value = os.environ.get(env_name, "").strip()
        if env_value:
            candidate = clean_path(env_value)
            if valid_software_root(key, candidate):
                return candidate

    command = COMMANDS.get(key)
    if command:
        candidate = command_install_root(command)
        if candidate and valid_software_root(key, candidate):
            return candidate

    for candidate_string in COMMON_INSTALLS.get(key, []):
        candidate = clean_path(candidate_string)
        if valid_software_root(key, candidate):
            return candidate

    raise SystemExit(
        f"Could not resolve {key}. Set it to an absolute path in config.yaml "
        f"or define one of: {', '.join(ENV_NAMES.get(key, []))}."
    )


def resolve_software_value(data: dict[str, Any], key: str, raw_value: Any) -> Path:
    raw_text = str(raw_value).strip()

    if key in COMMON_INSTALLS:
        if raw_text.lower() == "auto" or raw_text == "":
            return resolve_auto_software(key)
        return clean_path(raw_text)

    if key == "software.mni_template":
        if raw_text.lower() == "auto" or raw_text == "":
            fsldir = resolve_software_value(data, "software.fsldir", data["software"]["fsldir"])
            return fsldir / "data" / "standard" / "MNI152_T1_1mm_brain.nii.gz"
        return clean_path(raw_text)

    if key == "preprocessing.ants.nki_template":
        if raw_text.lower() == "auto" or raw_text == "":
            ants_dir = resolve_software_value(data, "software.ants_dir", data["software"]["ants_dir"])
            return ants_dir / "NKI" / "T_template.nii.gz"
        return clean_path(raw_text)

    if key == "preprocessing.ants.nki_mask":
        if raw_text.lower() == "auto" or raw_text == "":
            ants_dir = resolve_software_value(data, "software.ants_dir", data["software"]["ants_dir"])
            return ants_dir / "NKI" / "T_template_BrainCerebellumProbabilityMask.nii.gz"
        return clean_path(raw_text)

    return clean_path(raw_text)


def format_value(value: Any) -> str:
    if value is None:
        return ""

    if isinstance(value, bool):
        return str(value).lower()

    if isinstance(value, (list, dict)):
        return yaml.safe_dump(value, default_flow_style=True).strip()

    return str(value)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: resolve_config.py CONFIG.yaml dotted.key")

    config_path = Path(sys.argv[1]).resolve()
    key = sys.argv[2]
    data = read_yaml(config_path)
    raw_value = dotted_get(data, key)

    if key.startswith("software.") or key in {
        "preprocessing.ants.nki_template",
        "preprocessing.ants.nki_mask",
    }:
        print(resolve_software_value(data, key, raw_value))
        return

    if key in {"project.bids_dir", "project.results_dir", "project.clinical_scores"}:
        path = Path(os.path.expandvars(os.path.expanduser(str(raw_value))))
        if not path.is_absolute():
            path = config_path.parent / path
        print(path.resolve())
        return

    print(format_value(raw_value))


if __name__ == "__main__":
    main()
