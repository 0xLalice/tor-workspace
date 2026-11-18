#!/usr/bin/env python3
"""Compare complete native captures; write reports outside the plugin package."""
import argparse
import json
from pathlib import Path
from statistics import median

SCENARIOS = ('steady', 'renewal', 'interaction', 'illumination')
MATCH = ('windowWidth', 'windowHeight', 'devicePixelRatio', 'refreshHz',
         'graphicsApi', 'platform', 'qtVersion', 'requestedSeconds')


def load(folder, theme, scenario):
    captures = []
    for run in range(1, 4):
        path = folder / f'{theme}-{scenario}-{run}.json'
        capture = json.loads(path.read_text())
        frames = capture['frameTimestampsMs']
        assert capture['metadata']['nativeRenderer'] is True, path
        assert not capture.get('interruption') and not capture.get('truncated'), path
        assert frames[0] < 1000 and capture['summary']['seconds'] * 1000 - frames[-1] < 1000, path
        assert max(b - a for a, b in zip(frames, frames[1:])) < 1000, path
        captures.append(capture)
    return captures


def metrics(captures):
    return {
        'fps': median(c['summary']['fps'] for c in captures),
        'p95Ms': median(c['summary']['p95Ms'] for c in captures),
        'cpuPercent': median(c['resources']['cpuPercent'] for c in captures),
        'peakRssKiB': median(c['resources']['peakRssKiB'] for c in captures),
        'wholeShellCpuPercent': median(c['wholeShellObservation']['cpuPercent'] for c in captures),
    }


def compare(baseline, integrated, themes=('original', 'meridian', 'porcelain'), scenarios=SCENARIOS):
    rows = []
    reference = None
    for scenario in scenarios:
        base = load(baseline, 'original', scenario)
        expected = {key: base[0]['metadata'][key] for key in MATCH}
        if reference is None:
            reference = expected
        assert expected == reference, 'Baseline conditions changed'
        before = metrics(base)
        for theme in themes:
            captures = load(integrated, theme, scenario)
            for capture in base + captures:
                assert {key: capture['metadata'][key] for key in MATCH} == expected, 'Capture conditions changed'
            after = metrics(captures)
            ratios = {key: after[key] / before[key] for key in ('fps', 'p95Ms', 'cpuPercent')}
            passed = ratios['fps'] >= .95 and ratios['p95Ms'] <= 1.10 and ratios['cpuPercent'] <= 1.10
            rows.append(dict(theme=theme, scenario=scenario, baseline=before,
                             integrated=after, ratios=ratios, passed=passed))
    return dict(conditions=reference, samplesPerScenario=3, themes=list(themes), scenarios=list(scenarios),
                frameScope='Qt render-thread frame submission intervals; not physical presentation or GPU execution time',
                cpuScope='isolated Qt plugin process, including identical startup and warm-up',
                wholeShellScope='separate observation; other plugins and desktop activity included',
                thresholds=dict(minimumFpsRatio=.95, maximumP95Ratio=1.10, maximumCpuRatio=1.10),
                passed=all(row['passed'] for row in rows), results=rows)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', required=True, type=Path)
    parser.add_argument('--integrated', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--themes', nargs='+', choices=('original', 'meridian', 'porcelain'), default=('original', 'meridian', 'porcelain'))
    parser.add_argument('--scenarios', nargs='+', choices=SCENARIOS, default=SCENARIOS)
    args = parser.parse_args()
    report = compare(args.baseline, args.integrated, args.themes, args.scenarios)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    for row in report['results']:
        print(row['theme'], row['scenario'], 'PASS' if row['passed'] else 'FAIL', row['integrated'])
    raise SystemExit(0 if report['passed'] else 1)
