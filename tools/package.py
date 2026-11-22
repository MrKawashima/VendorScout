"""Produce the install ZIP and a complete reproducible-source ZIP."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[1]
VERSION='0.1.7-beta'

def main():
    dest=(Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'dist').resolve()
    dest.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((ROOT/'database-manifest.json').read_text())
    source=ROOT/'source-data/NorgannonDB'
    if not source.exists():source=ROOT.parent/'NorgannonDB'
    install=dest/f'VendorScout-Forever-{VERSION}.zip'
    bundle=dest/f'VendorScout-{VERSION}-source.zip'
    with zipfile.ZipFile(install,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for p in sorted((ROOT/'VendorScout').iterdir()):
            if p.is_file():z.write(p,'VendorScout/'+p.name)
    with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for p in sorted(ROOT.rglob('*')):
            rel=p.relative_to(ROOT)
            if not p.is_file() or any(x in rel.parts for x in ('__pycache__','.git','dist','preview','source-data')):continue
            if p.suffix in ('.zip','.pyc'):continue
            z.write(p,'VendorScout/'+rel.as_posix())
        for name in sorted(set(manifest['sha256'])|{'LICENSE','NOTICE.md','SPEC.md','README.md'}):
            data=(source/name).read_bytes()
            if name in manifest['sha256']:
                assert hashlib.sha256(data).hexdigest()==manifest['sha256'][name],name
            z.writestr('VendorScout/source-data/NorgannonDB/'+name,data)
        z.writestr('VendorScout/source-data/NorgannonDB/.snapshot-commit',manifest['commit']+'\n')
    for path in (install,bundle):
        with zipfile.ZipFile(path) as z:assert z.testzip() is None
        print(path.name,path.stat().st_size,'bytes',hashlib.sha256(path.read_bytes()).hexdigest())

if __name__=='__main__':main()
