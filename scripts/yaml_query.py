#!/usr/bin/env python3
"""Read a dotted key from YAML and expand environment variables."""
import os, sys, yaml
from pathlib import Path
with Path(sys.argv[1]).open() as f:
    data=yaml.safe_load(f) or {}
value=data
for part in sys.argv[2].split('.'):
    value=value[int(part)] if isinstance(value, list) else value[part]
if value is None:
    print('')
elif isinstance(value, bool):
    print(str(value).lower())
elif isinstance(value, (list, dict)):
    print(yaml.safe_dump(value, default_flow_style=True).strip())
else:
    print(os.path.expandvars(str(value)))
