#!/usr/bin/env python3
"""Sequential baseline/new comparison of the same native acceptance scenario (no concurrent runs)."""
import argparse,json,pathlib,re,shutil,subprocess
p=argparse.ArgumentParser()
p.add_argument('--factorio',required=True)
p.add_argument('--baseline',required=True,help='Unmodified 0.1.0 or 0.1.1 source directory')
p.add_argument('--work',required=True,help='Fresh directory for logs and saves')
a=p.parse_args();exe=pathlib.Path(a.factorio).resolve();work=pathlib.Path(a.work).resolve()
if work.exists():raise SystemExit('Use a fresh work directory')
work.mkdir(parents=True)
version=subprocess.check_output([str(exe),'--version'],text=True)
m=re.search(r'Version: (2\.[01])\.',version)
if not m:raise SystemExit('Factorio 2.0/2.1 required')
minor=m[1];new=pathlib.Path(__file__).resolve().parent.parent
results={}
for label,source in [('baseline',pathlib.Path(a.baseline).resolve()),('batched',new)]:
 d=work/label;mods=d/'mods';mods.mkdir(parents=True)
 info=json.loads((source/'info.json').read_text());main=mods/f"nuclear-accumulator_{info['version']}"
 shutil.copytree(source,main,ignore=shutil.ignore_patterns('tests','__pycache__'))
 info['factorio_version']=minor;info['dependencies']=['base >= '+('2.0.77' if minor=='2.0' else '2.1.21')]
 (main/'info.json').write_text(json.dumps(info))
 h=next((source/'tests/acceptance').glob('zz-*'));shutil.copytree(h,mods/h.name)
 hi=json.loads((mods/h.name/'info.json').read_text());hi['factorio_version']=minor
 (mods/h.name/'info.json').write_text(json.dumps(hi))
 # Use byte-identical runtime scenario on both sides; keep each source's appropriate prototype assertions.
 baseline_scenario=pathlib.Path(a.baseline).resolve()/'tests/acceptance'/h.name/'control.lua'
 shutil.copyfile(baseline_scenario,mods/h.name/'control.lua')
 (mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in ['base','nuclear-accumulator',hi['name']]]+[
  {'name':n,'enabled':False} for n in ['space-age','quality','elevated-rails']]}))
 runtime=d/'runtime';runtime.mkdir();config=d/'config.ini'
 config.write_text(f'[path]\nread-data=__PATH__executable__/../../data\nwrite-data={runtime}\n')
 common=[str(exe),'--config',str(config),'--mod-directory',str(mods)]
 save=d/'test.zip'
 for stage,tail in [('create',['--create',str(save)]),('runtime',['--benchmark',str(save),'--benchmark-ticks','3200','--benchmark-runs','1'])]:
  path=d/(stage+'.log')
  with path.open('w') as out:result=subprocess.run(common+tail,stdout=out,stderr=subprocess.STDOUT)
  s=path.read_text()
  if result.returncode or 'NA TEST FAIL:' in s:raise SystemExit(f'Failure in {path}')
  if stage=='runtime':
   if 'NA TEST COMPLETE' not in s:raise SystemExit(f'Missing completion in {path}')
   metrics=re.search(r'avg: ([\d.]+) ms, min: ([\d.]+) ms, max: ([\d.]+) ms',s)
   if not metrics:raise SystemExit(f'Missing timings in {path}')
   results[label]=dict(zip(['avg_ms','min_ms','max_ms'],map(float,metrics.groups())))
   print(label,results[label],flush=True)
results['max_reduction_percent']=100*(1-results['batched']['max_ms']/results['baseline']['max_ms'])
results['engine_version']=version.strip();results['ticks']=3200
(work/'results.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
