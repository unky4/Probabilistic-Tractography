#!/usr/bin/env python3
"""Run a project YAML pipeline.

This runner keeps the user-facing workflow simple: global settings live in
config.yaml, while each preprocessing stage or tract analysis is defined in a
small pipeline YAML file.
"""

import argparse
import os
import subprocess
from pathlib import Path

import yaml


PREPROCESSING_STEPS = {
    "freesurfer_recon_all": "01_run_freesurfer_preprocessing.sh",
    "brainsuite_preprocessing": "02_run_brain_suite_preprocessing.sh",
    "t1_brain_extraction": "03_run_t1_brain_extraction.sh",
    "view_check_t1_brain_extraction": "view_check_T1_brain_extraction.sh",
    "dwi_registration": "04_run_dwi_registration.sh",
    "run_check_dwi_to_mni": "run_check_DWI_to_MNI.sh",
    "view_check_dwi_to_mni": "view_check_DWI_to_MNI.sh",
    "bedpostx": "05_run_bedpostx.sh",
}

FREESURFER_EXTRA_STEPS = {
    "aparc2aseg": "06_extra_aparc2aseg.sh",
    "segment_thalamic_nuclei": "06_extra_segment_thalamic_nuclei.sh",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a preprocessing or tract pipeline.")
    parser.add_argument("--pipeline", required=True, help="Pipeline YAML file to run.")
    parser.add_argument("--config", default="config.yaml", help="Global config YAML file.")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without running them.")
    return parser.parse_args()


def script_path(project_root: Path, script_name: str) -> str:
    return str(project_root / "scripts" / script_name)


def run_command(command: list[str], env: dict[str, str], dry_run: bool) -> None:
    print("\n$ " + " ".join(command), flush=True)

    if not dry_run:
        subprocess.run(command, check=True, env=env)


def run_preprocessing_pipeline(project_root: Path, pipeline: dict, env: dict[str, str], dry_run: bool) -> None:
    for step_name in pipeline.get("steps", []):
        script_name = PREPROCESSING_STEPS[step_name]
        run_command([script_path(project_root, script_name)], env, dry_run)


def run_tract_pipeline(project_root: Path, pipeline: dict, env: dict[str, str], dry_run: bool) -> None:
    steps = pipeline.get("steps", [])

    if "freesurfer_extra" in steps:
        for extra_step in pipeline.get("freesurfer_extra", []):
            script_name = FREESURFER_EXTRA_STEPS[extra_step]
            run_command([script_path(project_root, script_name)], env, dry_run)

    if "roi_generation" in steps:
        for roi in pipeline.get("rois", {}).get("freesurfer", []):
            command = [
                script_path(project_root, "07_generate_freesurfer_roi.sh"),
                roi["name"],
                roi["source"],
            ]

            if "indices" in roi:
                command.extend(["--indices", ",".join(map(str, roi["indices"]))])
            elif "left_indices" in roi and "right_indices" in roi:
                command.extend(["--left-indices", ",".join(map(str, roi["left_indices"]))])
                command.extend(["--right-indices", ",".join(map(str, roi["right_indices"]))])
            else:
                raise ValueError(
                    f"FreeSurfer ROI '{roi.get('name', '<unnamed>')}' must define either "
                    "indices for a single ROI or left_indices/right_indices for a lateralised ROI pair."
                )

            run_command(command, env, dry_run)

        for roi in pipeline.get("rois", {}).get("mni", []):
            run_command(
                [
                    script_path(project_root, "07_convert_mni_roi.sh"),
                    roi["name"],
                    str(project_root / roi["path"]),
                ],
                env,
                dry_run,
            )

    if "probtrackx" in steps:
        for analysis in pipeline.get("probtrackx", {}).get("analyses", []):
            command = [
                script_path(project_root, "08_run_probtrackx_connection.sh"),
                analysis["name"],
            ]

            roi_arguments = {
                "seed": analysis.get("seed"),
                "waypoints": analysis.get("waypoints"),
                "targetmasks": analysis.get("targetmasks"),
                "avoid": analysis.get("avoid"),
                "stop": analysis.get("stop"),
                "wtstop": analysis.get("wtstop"),
                "target2": analysis.get("target2"),
                "target3": analysis.get("target3"),
                "colmask4": analysis.get("colmask4"),
                "target4": analysis.get("target4"),
            }

            for argument_name, value in roi_arguments.items():
                if value is None or value == "":
                    continue
                if isinstance(value, list):
                    value = ",".join(map(str, value))
                command.append(f"--{argument_name}={value}")

            command.extend(map(str, analysis.get("other_args", [])))

            run_command(command, env, dry_run)

    if "warp_to_mni" in steps:
        mni_settings = pipeline.get("mni_probability_maps", {})

        for analysis in pipeline.get("probtrackx", {}).get("analyses", []):
            run_command(
                [
                    script_path(project_root, "09_warp_paths_to_mni_normalised.sh"),
                    analysis["name"],
                    str(mni_settings.get("normalise_by_waytotal", True)).lower(),
                    str(mni_settings.get("threshold", 0.0001)),
                ],
                env,
                dry_run,
            )

    if "group_level" in steps:
        run_command([script_path(project_root, "10_run_group_level.py")], env, dry_run)


def main() -> None:
    args = parse_args()
    project_root = Path(__file__).resolve().parents[1]
    config_path = (project_root / args.config).resolve()
    pipeline_path = (project_root / args.pipeline).resolve()

    pipeline = yaml.safe_load(pipeline_path.read_text()) or {}

    env = os.environ.copy()
    env["CONFIG_YAML"] = str(config_path)
    env["PIPELINE_YAML"] = str(pipeline_path)

    if pipeline.get("kind") == "preprocessing":
        run_preprocessing_pipeline(project_root, pipeline, env, args.dry_run)
    else:
        run_tract_pipeline(project_root, pipeline, env, args.dry_run)


if __name__ == "__main__":
    main()
