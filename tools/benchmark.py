#!/usr/bin/env python3
"""Measure the actual plugin in an isolated Qt window; keep captures outside package."""
import argparse,json,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def ticks(pid):
 try:
  fields=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
  return int(fields[11])+int(fields[12])
 except (OSError,ValueError):return 0
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--themes',nargs='+',default=['original']);p.add_argument('--scenarios',nargs='+',choices=['steady','renewal','interaction','illumination'],default=['steady','renewal','interaction','illumination']);p.add_argument('--original-preset',type=Path);p.add_argument('--seconds',type=int,default=60);p.add_argument('--runs',type=int,default=3);a=p.parse_args()
 a.output.mkdir(parents=True,exist_ok=True)
 env=dict(os.environ,QML_XHR_ALLOW_FILE_READ='1',QT_QPA_PLATFORM='wayland',QT_QPA_PLATFORMTHEME='',QSG_RHI_BACKEND='opengl',QT_QUICK_CONTROLS_STYLE='Basic')
 for theme in a.themes:
  for scenario in a.scenarios:
   for run in range(a.runs):
    path=a.output/f'{theme}-{scenario}-{run+1}.json'
    if path.exists():continue
    cmd=['/usr/lib/qt6/bin/qml','--verbose',str(ROOT/'tools/ThemeBenchmark.qml'),'--','--scenario',scenario,'--seconds',str(a.seconds),'--preset',(a.original_preset.resolve() if theme=='original' and a.original_preset else ROOT/f'assets/themes/{theme}.json').as_uri()]
    log=path.with_suffix('.log')
    captures=Path.home()/'.local/state/omarchy/tor-panel/performance'
    shells=[int(x) for x in subprocess.check_output(['pgrep','-x','quickshell'],text=True).split()]
    shell_before={pid:ticks(pid) for pid in shells}
    existing=set(captures.glob('frames-*.json'))
    with log.open('w') as f:
     proc=subprocess.Popen(cmd,stdout=f,stderr=f,env=env);start=time.monotonic();before=ticks(proc.pid);peak=0;last=before
     try:
      while proc.poll() is None:
       last=ticks(proc.pid) or last
       try:
        status=Path(f'/proc/{proc.pid}/status').read_text();peak=max(peak,int(re.search(r'VmRSS:\s+(\d+)',status)[1]))
       except (OSError,TypeError):pass
       if time.monotonic()-start>a.seconds+20:proc.kill()
       time.sleep(.5)
     finally:
      if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
    output=log.read_text();match=re.search(r'BENCHMARK_CAPTURE\s+(\S+)',output)
    generated=list(set(captures.glob('frames-*.json'))-existing)
    if proc.returncode or (not match and len(generated)!=1):raise RuntimeError(f'Benchmark failed: {log}\n{output[-2000:]}')
    capture=json.loads((Path(match[1]) if match else generated[0]).read_text());elapsed=time.monotonic()-start
    assert capture['metadata'].get('nativeRenderer') is True, 'Circuit renderer missing'
    assert capture['summary']['fps']>0 and not capture.get('interruption'), 'Invalid frame capture'
    frames=capture['frameTimestampsMs']
    assert frames and frames[0]<1000 and capture['summary']['seconds']*1000-frames[-1]<1000, 'Window visibility interrupted capture'
    assert max(b-a for a,b in zip(frames,frames[1:]))<1000, 'Window visibility interrupted frame stream'
    capture['wholeShellObservation']={'scope':'whole Quickshell process; other plugins and desktop activity included','cpuPercent':100*sum(ticks(pid)-shell_before[pid] for pid in shells)/os.sysconf('SC_CLK_TCK')/elapsed}
    capture['resources']={'scope':'isolated plugin Qt process','cpuPercent':100*(last-before)/os.sysconf('SC_CLK_TCK')/elapsed,'peakRssKiB':peak,'elapsedSeconds':elapsed}
    path.write_text(json.dumps(capture,indent=2)+'\n');print(path.name,capture['summary'],capture['resources'],flush=True)
if __name__=='__main__':main()
