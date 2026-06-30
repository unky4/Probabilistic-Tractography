#!/usr/bin/env python3
"""List BIDS subjects without the sub- prefix."""
import argparse, os, yaml
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--config', required=True); a=p.parse_args()
config_path=Path(a.config).resolve(); cfg=yaml.safe_load(config_path.read_text()) or {}
bids=Path(os.path.expandvars(cfg['project']['bids_dir']))
if not bids.is_absolute(): bids=config_path.parent/bids
include=set(cfg.get('subjects',{}).get('include') or [])
exclude=set(cfg.get('subjects',{}).get('exclude') or [])
subjects=sorted(x.name.replace('sub-','',1) for x in bids.glob('sub-*') if x.is_dir()) if not include else sorted(include)
for s in subjects:
    if s not in exclude: print(s)
