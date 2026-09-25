#!/usr/bin/env python3
"""Car behavior report of the current checkout against the port branch, not against comma master.

Upstream's car_diff.py compares a PR to master refs and exits 0 even when behavior changes. The port
intentionally differs from master, so refs are generated from a port checkout (--base, in a subprocess
importing the port's code) and the current tree is replayed against them. Any changed segment or error fails.

Segments come from comma's public segment database. Newer angle-LKAS platforms (SUBARU_OUTBACK_2023,
SUBARU_CROSSTREK_2025, SUBARU_ASCENT_2023) have none there, so their test routes from routes.py are used.
"""
import argparse
import contextlib
import io
import multiprocessing
import os
import shutil
import subprocess
import sys
from pathlib import Path


def route_segments() -> dict[str, list[str]]:
  from opendbc.car.tests.routes import routes
  out: dict[str, list[str]] = {}
  for r in routes:
    for seg in ((r.segment,) if r.segment is not None else (2, 1, 0)):
      out.setdefault(str(r.car_model), []).append(f"{r.route.replace('|', '/')}/{seg}")
  return out


def patch_car_diff():
  """Make car_diff use routes.py segments for platforms missing from the public database."""
  # car_diff replays in worker processes; they only see these patches if forked from this one.
  multiprocessing.set_start_method("fork", force=True)
  import comma_car_segments
  import opendbc.car.tests.car_diff as car_diff
  from opendbc.car.logreader import LogReader
  from opendbc.car.tests.test_models import get_cached_segment

  database = comma_car_segments.get_comma_car_segments_database()
  fallback = {p: segs for p, segs in route_segments().items() if not database.get(p)}
  database.update(fallback)
  from_routes = {s for segs in fallback.values() for s in segs}

  load_from_database = car_diff.load_can_messages

  def load_can_messages(seg: str):
    if seg not in from_routes:
      return load_from_database(seg)
    route, n = seg.rsplit("/", 1)
    msgs = LogReader(str(get_cached_segment(route, int(n))), only_union_types=True, sort_by_time=True)
    return [m for m in msgs if m.which() == 'can']

  comma_car_segments.get_comma_car_segments_database = lambda: database  # ty: ignore[invalid-assignment]
  car_diff.load_can_messages = load_can_messages  # ty: ignore[invalid-assignment]
  return car_diff, database, fallback


def generate(platform: str, segments: int) -> int:
  car_diff, _, _ = patch_car_diff()
  return car_diff.main(platform=platform, segments_per_platform=segments, update_refs=True)


def main() -> int:
  parser = argparse.ArgumentParser()
  parser.add_argument("platforms", nargs="+")
  parser.add_argument("--base", type=Path, help="checkout of the port branch")
  parser.add_argument("--segments", type=int, default=10)
  parser.add_argument("--report", type=Path)
  parser.add_argument("--generate", action="store_true", help="internal: write refs for the tree on PYTHONPATH")
  args = parser.parse_args()

  if args.generate:
    return generate(args.platforms[0], args.segments)

  from opendbc.car.car_helpers import interfaces
  car_diff, database, fallback = patch_car_diff()
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
    source = "routes.py test route" if platform in fallback else "commaCarSegments"
    if platform not in interfaces or not database.get(platform):
      failures.append(platform)
      sections.append(f"#### {platform}\n\n❌ not found after the merge (renamed or removed upstream?)\n")
      continue
    env = {**os.environ, "PYTHONPATH": str(args.base)}
    gen = subprocess.run([sys.executable, __file__, "--generate", "--segments", str(args.segments), platform],
                         cwd=args.base, env=env)
    if gen.returncode:
      failures.append(platform)
      sections.append(f"#### {platform}\n\n❌ could not replay on port ({source})\n")
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
      sections.append(f"#### {platform}\n\n{len(changed)} changed, {len(errors)} errors of {len(results)} segments ({source})\n\n{body}\n")
    else:
      sections.append(f"#### {platform}\n\n✅ {len(results)} segments identical to port ({source})\n")

  if args.report:
    args.report.write_text("### Car behavior report (integration vs port)\n\n" + "\n".join(sections))
  return 1 if failures else 0


if __name__ == "__main__":
  sys.exit(main())
