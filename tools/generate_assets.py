#!/usr/bin/env python3
"""Current Crown & Ashes art generation entry point. Sources are retained locally."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).with_name('reforge_assets.py')),run_name='__main__')
