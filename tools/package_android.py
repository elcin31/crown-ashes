#!/usr/bin/env python3
from pathlib import Path
import zipfile,hashlib,json
base=Path(__file__).resolve().parents[1]/'exports'
apk=base/'CrownAndAshes-v0.3.1-android.apk'
assert apk.is_file() and apk.stat().st_size>1_000_000,'APK missing or empty'
with zipfile.ZipFile(apk) as z:
 assert z.testzip() is None
 assert 'AndroidManifest.xml' in z.namelist()
 assert 'classes.dex' in z.namelist()
 assert any(p.endswith('libgodot_android.so') for p in z.namelist())
 assert any('terrain_cache' in p or p.startswith('assets/') for p in z.namelist())
archive=base/'CrownAndAshes-v0.3.1-android.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_STORED) as z:z.write(apk,apk.name)
with zipfile.ZipFile(archive) as z:assert z.namelist()==[apk.name] and z.testzip() is None
sha=hashlib.sha256(apk.read_bytes()).hexdigest()
checksums=base/'SHA256SUMS.txt'
old=checksums.read_text().splitlines() if checksums.exists() else []
old=[line for line in old if not line.endswith(apk.name)]
checksums.write_text('\n'.join(old+[sha+'  '+apk.name])+'\n')
print(json.dumps({'apk':str(apk),'bytes':apk.stat().st_size,'sha256':sha,'zip':str(archive)},indent=2))
