#!/usr/bin/env python3
"""Car behavior report of the current checkout against the port branch, not against comma master.

Upstream's car_diff.py compares a PR to master refs and exits 0 even when behavior changes. The port
intentionally differs from master, so here refs are generated from a port checkout (--base) and the
current tree is replayed against them. Any changed segment or error fails.
"""
import argparse
import contextlib
import io
import os
import shutil
import subprocess
import sys
from pathlib import Path


def generate_refs(base: Path, platform: str, segments: int) -> None:
  env = {**os.environ, "PYTHONPATH": str(base)}
  subprocess.run([sys.executable, "opendbc/car/tests/car_diff.py", "--update-refs",
                  "--platform", platform, "--segments-per-platform", str(segments)],
                 cwd=base, env=env, check=True)


def main() -> int:
  parser = argparse.ArgumentParser()
  parser.add_argument("platforms", nargs="+")
  parser.add_argument("--base", required=True, type=Path, help="checkout of the port branch")
  parser.add_argument("--segments", type=int, default=10)
  parser.add_argument("--report", type=Path, required=True)
  args = parser.parse_args()

  from comma_car_segments import get_comma_car_segments_database
  from opendbc.car.car_helpers import interfaces
  import opendbc.car.tests.car_diff as car_diff

  database = get_comma_car_segments_database()
  ref_dir = args.base / car_diff.DIFF_BUCKET
  failures, sections = [], []

  def copy_refs(ref_path, platforms, segments):
    for platform in platforms:
      for seg in segments.get(platform, []):
        name = f"{platform}_{seg.replace('/', '_')}.zst"
        shutil.copy(ref_dir / name, Path(ref_path) / name)

  results = []
  run_replay = car_diff.run_replay

  def capture_replay(*a, **kw):
    out = run_replay(*a, **kw)
    results.extend(out)
    return out

  car_diff.download_refs = copy_refs
  car_diff.run_replay = capture_replay

  for platform in args.platforms:
    if platform not in interfaces or platform not in database:
      failures.append(platform)
      sections.append(f"#### {platform}\n\n❌ not found after the merge (renamed or removed upstream?)\n")
      continue
    try:
      generate_refs(args.base, platform, args.segments)
    except subprocess.CalledProcessError:
      failures.append(platform)
      sections.append(f"#### {platform}\n\n❌ could not generate refs on port\n")
      continue

    results.clear()
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
      rc = car_diff.main(platform=platform, segments_per_platform=args.segments)
    print(buf.getvalue())
    changed = [r for r in results if r[2]]
    errors = [r for r in results if r[5]]
    if rc or changed or errors:
      failures.append(platform)
      body = buf.getvalue().split("\n", 3)[-1]  # drop upstream's "compared to master" header
      sections.append(f"#### {platform}\n\n{len(changed)} changed, {len(errors)} errors of {len(results)} segments\n\n{body}\n")
    else:
      sections.append(f"#### {platform}\n\n✅ {len(results)} segments identical to port\n")

  args.report.write_text("### Car behavior report (integration vs port)\n\n" + "\n".join(sections))
  return 1 if failures else 0


if __name__ == "__main__":
  sys.exit(main())
