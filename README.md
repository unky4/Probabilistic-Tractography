# Probabilistic Tractography Pipeline — Version 1

This project provides a BIDS-based probabilistic tractography workflow using reusable shell/Python scripts and small YAML pipeline files. The repository is organised so preprocessing can be run once, quality-controlled in stages, and tract-specific analyses can be run independently afterwards.

## Example command sequence

```bash
scripts/run_pipeline.sh --pipeline pipelines/preprocessing_T1.yaml
scripts/run_pipeline.sh --pipeline pipelines/preprocessing_brain_extraction.yaml
scripts/view_check_T1_brain_extraction.sh

scripts/run_pipeline.sh --pipeline pipelines/preprocessing_registration.yaml
scripts/run_check_DWI_to_MNI.sh
scripts/view_check_DWI_to_MNI.sh

scripts/run_pipeline.sh --pipeline pipelines/preprocessing_fsl.yaml
scripts/run_pipeline.sh --pipeline pipelines/tracts/anterior_thalamic_radiation.yaml
```

## Pipeline

<img width="4795" height="2692" alt="diagram" src="https://github.com/user-attachments/assets/f22d6749-360e-4c94-9d15-f32add36cc45" />



## Folder layout

```text
config.yaml                  # global settings only
pipelines/                   # user-facing pipeline definitions
pipelines/tracts/            # one YAML file per tract or analysis
scripts/                     # implementation scripts
data/images/                 # BIDS image dataset
data/rois_mni/               # hand-drawn MNI-space ROI masks
data/clinical_scores.csv     # clinical/demographic scores for group analyses
results/                     # all pipeline outputs
```

## Software paths

`config.yaml` defines software locations with the value `auto` by default:

```yaml
software:
  fsldir: auto
  freesurfer_home: auto
  brainsuite_dir: auto
  ants_dir: auto
  mni_template: auto
```

When a value is `auto`, the scripts try to resolve it from environment variables, installed command locations, or common installation folders. If automatic detection is wrong, replace `auto` with an absolute path.

Check the resolved paths before running an analysis:

```bash
scripts/check_software_paths.sh
```

## BIDS input assumption

The project expects image data in BIDS format:

```text
data/images/sub-001/anat/sub-001_T1w.nii.gz
data/images/sub-001/dwi/sub-001_dwi.nii.gz
data/images/sub-001/dwi/sub-001_dwi.bvec
data/images/sub-001/dwi/sub-001_dwi.bval
```

## Python environment

The first call to `scripts/run_pipeline.sh` creates a local `.venv` folder and installs the Python dependencies from `requirements.txt`.

## Run order

Preprocessing is split into four checkpointed stages so brain extraction and registration can be checked before later stages are run.

```bash
scripts/run_pipeline.sh --pipeline pipelines/preprocessing_T1.yaml
scripts/run_pipeline.sh --pipeline pipelines/preprocessing_brain_extraction.yaml
scripts/run_pipeline.sh --pipeline pipelines/preprocessing_registration.yaml
scripts/run_pipeline.sh --pipeline pipelines/preprocessing_fsl.yaml
```

The brain-extraction pipeline opens `view_check_T1_brain_extraction.sh` after brain extraction. Inspect these images before running registration.

The registration pipeline runs `run_check_DWI_to_MNI.sh` and then opens `view_check_DWI_to_MNI.sh`. Inspect the DWI-to-MNI overlay before running FSL BedpostX.

After preprocessing has passed QC, run tract-specific pipelines independently:

```bash
scripts/run_pipeline.sh --pipeline pipelines/tracts/anterior_thalamic_radiation.yaml
scripts/run_pipeline.sh --pipeline pipelines/tracts/amygdala_example.yaml
scripts/run_pipeline.sh --pipeline pipelines/tracts/mni_only_midline_example.yaml
```

Preview any pipeline without running commands:

```bash
scripts/run_pipeline.sh --pipeline pipelines/tracts/mni_only_midline_example.yaml --dry-run
```

## Configuration design

`config.yaml` contains only global settings that should remain stable across tract analyses, such as BIDS input paths, results paths, software paths, resource settings, and preprocessing options.

Tract-specific choices are defined in `pipelines/tracts/*.yaml`, including optional FreeSurfer extra preprocessing, ROI definitions, ProbtrackX analyses, MNI probability-map settings, and group-level analysis options.

## ROI definitions

FreeSurfer ROIs can be defined either as a single non-lateralised ROI or as a left/right pair.

Single midline/non-lateralised ROI example:

```yaml
rois:
  freesurfer:
    - name: MidlineROI
      source: mri/aparc+aseg.mgz
      indices: [10, 11, 12]
```

This creates:

```text
results/05_ROIs/<subject>/MidlineROI.nii.gz
```

Left/right ROI-pair example:

```yaml
rois:
  freesurfer:
    - name: FrontalPole
      source: aparc.cortical.mgz
      left_indices: [1032]
      right_indices: [2032]
```

This creates:

```text
results/05_ROIs/<subject>/FrontalPole_Left.nii.gz
results/05_ROIs/<subject>/FrontalPole_Right.nii.gz
```

MNI ROIs are generated exactly as named. There is no required hemisphere field:

```yaml
rois:
  mni:
    - name: MidlineSeed
      path: data/rois_mni/MidlineSeed.nii.gz
```

This creates:

```text
results/05_ROIs/<subject>/MidlineSeed.nii.gz
```

MNI ROIs are transformed into native DWI space using the 3D DWI b0 image as the ANTs reference:

```text
results/03_Image_Registrations/<subject>/<subject>_DWI_B0.nii.gz
```

The scripts stop with a clear error if a generated native-DWI ROI contains zero voxels.

## Flexible ProbtrackX settings

ProbtrackX analyses are not forced into a seed-to-target structure. Each analysis can use the same flexible ROI arguments as the original script:

```yaml
probtrackx:
  analyses:
    - name: MidlineSeed_to_PosteriorStop
      seed: MidlineSeed
      waypoints:
        - AnteriorWaypoint
      avoid: ExclusionMask
      stop: PosteriorStop
      other_args:
        - --onewaycondition
        - --loopcheck
        - --nsamples=5000
```

Supported ROI arguments are:

```text
seed
waypoints
targetmasks
avoid
stop
wtstop
target2
target3
colmask4
target4
```

Use `stop` for a termination/end mask. Use `targetmasks` only when you intentionally want ProbtrackX classification targets.

The script automatically supplies these options and they should not be put in the tract YAML:

```text
-s
-m
-l
--forcedir
--opd
--dir
```

BedpostX and ProbtrackX use the GPU commands and process subjects sequentially:

```text
bedpostx_gpu
probtrackx2_gpu
```

## MNI probability maps

Step 09 warps subject-level native `fdt_paths.nii.gz` files to MNI space and writes the outputs to:

```text
results/07_MNI_Probability_Maps/<analysis_name>/<subject>.nii.gz
```

The script checks that each subject has the expected native ProbtrackX output before normalisation:

```text
results/06_FSL_ProbtrackX/<analysis_name>/<subject>/fdt_paths.nii.gz
```

## Group-level analysis

Step 10 performs regression group-level analysis using the clinical CSV defined in `config.yaml`.

For each tract analysis and each score column, it writes:

```text
subjects.txt
scores.txt
images_list.txt
regression_design.mat
regression_contrast.con
images.nii.gz
mask_file.nii.gz
randomise outputs
```

The merged 4D image is named:

```text
images.nii.gz
```

inside each score-specific regression folder:

```text
results/09_Group_Level_Analysis/<pipeline_name>/<analysis_name>/regression/<score_name>/
```

Group-level mask options are passed to `fslmaths`. The recommended threshold syntax is:

```yaml
group_level:
  regression:
    mask_options: -thr 0.0001
```

The runner also accepts the readable alias `--threshold 0.0001` and converts it to FSL's `-thr 0.0001` before running `fslmaths`.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
