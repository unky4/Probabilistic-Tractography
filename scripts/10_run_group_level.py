#!/usr/bin/env python3
"""Run tract-level group analyses.

This script uses the MNI-space probability maps created by step 09:

    results/07_MNI_Probability_Maps/<analysis>/<subject>.nii.gz

For regression analyses, the clinical CSV is expected to have:
    column 1: subject ID
    column 2: group name
    column 3+: numeric regression scores

For each score, subjects with missing scores or missing MNI probability maps are
excluded. The retained maps are merged into images.nii.gz, a mask is created, and
FSL randomise is run using a two-column design matrix: intercept + score.
"""

from __future__ import annotations

import csv
import os
import shlex
import subprocess
from pathlib import Path
from typing import Any

import yaml


def read_yaml(path: Path) -> dict[str, Any]:
    return yaml.safe_load(path.read_text()) or {}


def run(command: list[str]) -> None:
    print("\n$ " + " ".join(shlex.quote(part) for part in command), flush=True)
    subprocess.run(command, check=True)



def normalise_fslmaths_options(options: str) -> list[str]:
    """Return FSL-compatible fslmaths options.

    Pipeline YAML files are user-facing, so allow readable aliases such as
    ``--threshold`` while converting them to the actual FSL command-line option
    ``-thr`` before execution.
    """
    replacements = {
        "--threshold": "-thr",
        "threshold": "-thr",
        "--upper-threshold": "-uthr",
        "upper-threshold": "-uthr",
        "--lower-threshold-percentage": "-thrp",
        "lower-threshold-percentage": "-thrp",
        "--upper-threshold-percentage": "-uthrp",
        "upper-threshold-percentage": "-uthrp",
    }

    tokens = shlex.split(options)
    return [replacements.get(token, token) for token in tokens]

def config_path_value(config_path: Path, raw_value: str) -> Path:
    path = Path(os.path.expandvars(os.path.expanduser(raw_value)))
    if not path.is_absolute():
        path = config_path.parent / path
    return path.resolve()


def read_clinical_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        if reader.fieldnames is None:
            raise RuntimeError(f"Clinical CSV has no header: {path}")
        return reader.fieldnames, rows


def get_group_settings(pipeline: dict[str, Any], analysis_type: str) -> dict[str, Any]:
    return pipeline.get("group_level", {}).get(analysis_type, {}) or {}


def run_regression(
    *,
    analysis_name: str,
    group_analysis_dir: Path,
    mni_maps_dir: Path,
    clinical_columns: list[str],
    clinical_rows: list[dict[str, str]],
    mask_options: str,
    randomise_options: str,
) -> None:
    if len(clinical_columns) < 3:
        raise RuntimeError("Clinical CSV must have subject ID, group name, and at least one score column.")

    subject_column = clinical_columns[0]
    score_columns = clinical_columns[2:]
    regression_root = group_analysis_dir / "regression"
    regression_root.mkdir(parents=True, exist_ok=True)

    for score_name in score_columns:
        score_dir = regression_root / score_name
        score_dir.mkdir(parents=True, exist_ok=True)

        images: list[Path] = []
        subjects: list[str] = []
        scores: list[str] = []

        for row in clinical_rows:
            subject_id = (row.get(subject_column) or "").strip()
            score = (row.get(score_name) or "").strip()

            if not subject_id or not score:
                continue

            image_path = mni_maps_dir / f"{subject_id}.nii.gz"

            if not image_path.exists():
                print(f"Skipping {subject_id} for {analysis_name}/{score_name}: missing {image_path}")
                continue

            images.append(image_path)
            subjects.append(subject_id)
            scores.append(score)

        (score_dir / "subjects.txt").write_text("\n".join(subjects) + ("\n" if subjects else ""))
        (score_dir / "scores.txt").write_text("\n".join(scores) + ("\n" if scores else ""))
        (score_dir / "images_list.txt").write_text("\n".join(str(path) for path in images) + ("\n" if images else ""))

        if len(images) < 3:
            print(f"Skipping regression {analysis_name}/{score_name}: only {len(images)} valid images.")
            continue

        design_file = score_dir / "regression_design.mat"
        contrast_file = score_dir / "regression_contrast.con"

        with design_file.open("w") as handle:
            handle.write("/NumWaves 2\n")
            handle.write(f"/NumPoints {len(images)}\n")
            handle.write("/PPheights 1 1\n\n")
            handle.write("/Matrix\n")
            for score in scores:
                handle.write(f"1 {score}\n")

        with contrast_file.open("w") as handle:
            handle.write(f"/ContrastName1 {score_name}_Positive\n")
            handle.write(f"/ContrastName2 {score_name}_Negative\n")
            handle.write("/NumWaves 2\n")
            handle.write("/NumContrasts 2\n")
            handle.write("/PPheights 1 1\n\n")
            handle.write("/Matrix\n")
            handle.write("0 1\n")
            handle.write("0 -1\n")

        merged = score_dir / "images.nii.gz"
        mask = score_dir / "mask_file.nii.gz"

        run(["fslmerge", "-t", str(merged), *map(str, images)])

        run([
            "fslmaths",
            str(merged),
            "-Tmean",
            *normalise_fslmaths_options(mask_options),
            "-bin",
            str(mask),
        ])

        randomise_prefix = score_dir / "regression"
        run([
            "randomise",
            "-i",
            str(merged),
            "-o",
            str(randomise_prefix),
            "-m",
            str(mask),
            "-d",
            str(design_file),
            "-t",
            str(contrast_file),
            *shlex.split(randomise_options),
        ])

        for old_name, new_name in [
            ("regression_tstat1.nii.gz", f"regression_tstat_{score_name}_Positive.nii.gz"),
            ("regression_tstat2.nii.gz", f"regression_tstat_{score_name}_Negative.nii.gz"),
        ]:
            old_path = score_dir / old_name
            if old_path.exists():
                old_path.rename(score_dir / new_name)


def main() -> None:
    config_path = Path(os.environ["CONFIG_YAML"]).resolve()
    pipeline_path = Path(os.environ["PIPELINE_YAML"]).resolve()

    config = read_yaml(config_path)
    pipeline = read_yaml(pipeline_path)

    results_dir = config_path_value(config_path, config["project"]["results_dir"])
    clinical_csv = config_path_value(config_path, config["project"]["clinical_scores"])

    if not clinical_csv.exists():
        raise RuntimeError(f"Clinical scores CSV not found: {clinical_csv}")

    clinical_columns, clinical_rows = read_clinical_rows(clinical_csv)

    group_root = results_dir / "09_Group_Level_Analysis" / pipeline["name"]
    group_root.mkdir(parents=True, exist_ok=True)

    requested_analyses = pipeline.get("group_level", {}).get("analyses", [])

    for analysis in pipeline.get("probtrackx", {}).get("analyses", []):
        analysis_name = analysis["name"]
        analysis_group_dir = group_root / analysis_name
        analysis_group_dir.mkdir(parents=True, exist_ok=True)

        mni_maps_dir = results_dir / "07_MNI_Probability_Maps" / analysis_name

        if not mni_maps_dir.exists():
            print(f"Skipping group-level analysis for {analysis_name}: missing {mni_maps_dir}")
            continue

        if "regression" in requested_analyses:
            regression_settings = get_group_settings(pipeline, "regression")
            run_regression(
                analysis_name=analysis_name,
                group_analysis_dir=analysis_group_dir,
                mni_maps_dir=mni_maps_dir,
                clinical_columns=clinical_columns,
                clinical_rows=clinical_rows,
                mask_options=str(regression_settings.get("mask_options", "-thr 0.0001")),
                randomise_options=str(regression_settings.get("randomise_options", "-D -n 5000 -v 10")),
            )

    print(f"Group-level analysis completed: {group_root}")


if __name__ == "__main__":
    main()
