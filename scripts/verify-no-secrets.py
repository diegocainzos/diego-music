#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / ".env"
EXCLUDED_PARTS = {".git", "DerivedData", "build", "node_modules", "xcuserdata"}
EXCLUDED_FILES = {ENV.resolve(), (ROOT / "Config/Secrets.xcconfig").resolve()}

if not ENV.exists():
    print("No existe .env; no hay valor local que comparar.")
    raise SystemExit(0)

value = None
for raw in ENV.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if line.startswith("export "):
        line = line[7:].lstrip()
    match = re.match(r"^YOUTUBE_DATA_KEY\s*=\s*(.*)$", line)
    if match:
        value = match.group(1).strip().strip("\"'")
        break

if not value:
    print("YOUTUBE_DATA_KEY no está configurada; no hay valor que comparar.")
    raise SystemExit(0)

leaks = []
for path in ROOT.rglob("*"):
    if not path.is_file() or path.resolve() in EXCLUDED_FILES:
        continue
    if any(part in EXCLUDED_PARTS for part in path.parts):
        continue
    try:
        data = path.read_bytes()
    except OSError:
        continue
    if b"\0" in data[:4096]:
        continue
    if value.encode("utf-8") in data:
        leaks.append(path.relative_to(ROOT))

if leaks:
    print("La clave local aparece en archivos no permitidos:")
    for path in leaks:
        print(f"- {path}")
    raise SystemExit(1)

print("Comprobación superada: la clave local no aparece en archivos versionables.")
