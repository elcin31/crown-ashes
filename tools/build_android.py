#!/usr/bin/env python3
"""Use the existing Godot APK exporter, with machine-local paths kept out of git.

--coexist keeps an older installation intact when its signing key is unavailable.
The release package ID in export_presets.cfg remains unchanged for its owner.
"""
import argparse, os, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--coexist',action='store_true')
parser.add_argument('--template',default=str(ROOT/'.build/export-templates/templates/android_debug.apk'))
args=parser.parse_args()
preset=ROOT/'export_presets.cfg';original=preset.read_text()
try:
 text=original.replace('custom_template/debug=""','custom_template/debug="'+args.template+'"',1)
 if args.coexist:
  text=text.replace('package/unique_name="org.crownandashes.firstcrown"','package/unique_name="org.crownandashes.livingkingdoms"').replace('package/name="Crown & Ashes"','package/name="Crown & Ashes 0.4"')
 preset.write_text(text)
 subprocess.run(['godot','--headless','--editor','--import','--quit'],cwd=ROOT,check=True)
 subprocess.run(['godot','--headless','--path',str(ROOT),'--export-debug','Android',str(ROOT/'exports/CrownAndAshes-v0.4.0-android.apk')],cwd=ROOT,check=True)
finally:preset.write_text(original)
