#!/usr/bin/env python3
"""Run upstream's test_models.py (panda safety vs CarState on real routes) for selected platforms only.

test_models.py only builds its test classes when invoked directly and shards by NUM_JOBS/JOB_ID, which
cannot select platforms; this builds the same classes for the given platforms from routes.py.
"""
import sys
import unittest

import opendbc.car.tests.test_models as test_models


def main(platforms: list[str]) -> int:
  suite = unittest.TestSuite()
  found = set()
  for index, (platform, route) in enumerate(test_models.get_test_cases()):
    if platform in platforms and route is not None:
      name = f"TestCarModel_{index}_{platform}"
      cls = type(name, (test_models.TestCarModelBase,), {"platform": platform, "test_route": route})
      suite.addTests(unittest.defaultTestLoader.loadTestsFromTestCase(cls))
      found.add(platform)

  missing = sorted(set(platforms) - found)
  if missing:
    print(f"no test route in routes.py for: {', '.join(missing)}")
    return 1
  result = unittest.TextTestRunner(verbosity=2).run(suite)
  return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
