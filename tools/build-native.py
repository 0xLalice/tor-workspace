#!/usr/bin/env python3
"""Build selected Qt modules from source, without changing desktop or Tor state."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MODULES = {"circuit": "libtorcircuit.so", "gpu": "libtorsparks.so",
           "performance": "libtorperformance.so"}


def build(destination=None):
    modules = tuple(MODULES)
    destination = Path(destination or ROOT).resolve()
    if not shutil.which("cmake"):
        raise RuntimeError("Native builds need CMake, a C++17 compiler, qt6-declarative and qt6-shadertools development files")
    runtime = ROOT
    spec = importlib.util.spec_from_file_location('native_readiness', runtime/'install/setup_status.py')
    readiness = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(readiness)
    source_hash = readiness.native_source_hash(runtime)
    # Do not publish any output until every selected module has built successfully.
    with tempfile.TemporaryDirectory(prefix="tor-native-") as folder:
        subprocess.run(["cmake", "-S", str(ROOT / "native"), "-B", folder,
                        "-DCMAKE_BUILD_TYPE=Release",
                        *[f"-DTOR_BUILD_{name.upper()}={'ON' if name in modules else 'OFF'}"
                          for name in MODULES]], check=True)
        subprocess.run(["cmake", "--build", folder, "--parallel", "2"], check=True)
        for name in modules:
            info = Path(folder)/'artifacts'/name/'build-info.json'
            metadata = json.loads(info.read_text())
            metadata['sources'] = source_hash
            info.write_text(json.dumps(metadata, indent=2)+'\n')
        for name in modules:
            target = (destination / 'build/qml' / name)
            target.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT/'native'/name/'qmldir', target/'qmldir')
            for filename in (MODULES[name], "build-info.json"):
                # A fresh inode avoids truncating a library mapped by a running shell.
                fd, temporary = tempfile.mkstemp(prefix=filename + ".", dir=target)
                os.close(fd)
                try:
                    shutil.copy2(Path(folder) / "artifacts" / name / filename, temporary)
                    os.replace(temporary, target / filename)
                finally:
                    Path(temporary).unlink(missing_ok=True)
    return [(destination / 'build/qml' / name) / MODULES[name] for name in modules]


def build_verified(destination):
    """Verify source integrity before compiling; generated files never alter source hashes."""
    destination = Path(destination).resolve()
    hashes_path = destination / "source-hashes.json"
    hashes = json.loads(hashes_path.read_text())
    for name, digest in hashes.items():
        path = Path(name)
        if path.is_absolute() or ".." in path.parts or (destination / path).is_symlink():
            raise ValueError("Unsafe release path: " + name)
        if hashlib.sha256((destination / path).read_bytes()).hexdigest() != digest:
            raise ValueError("Release integrity mismatch: " + name)
    return build(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    if os.geteuid() == 0:
        raise SystemExit("Build native modules as the desktop user, never root")
    for path in build_verified(ROOT):
        print(path)
