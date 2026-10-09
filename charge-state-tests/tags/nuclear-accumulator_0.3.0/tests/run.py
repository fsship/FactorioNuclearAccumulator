#!/usr/bin/env python3
"""Run real headless acceptance tests in isolated directories; never alters installed user mods."""
import argparse, json, pathlib, re, shutil, subprocess
parser=argparse.ArgumentParser()
parser.add_argument('--factorio',required=True,help='Path to headless Factorio binary')
parser.add_argument('--work',default='work/na-tests',help='Fresh intermediate test directory')
parser.add_argument('--suite',choices=['ammo'],default='ammo')
args=parser.parse_args()
exe=pathlib.Path(args.factorio).resolve(); root=pathlib.Path(__file__).resolve().parent.parent
work=pathlib.Path(args.work).resolve();work.mkdir(parents=True,exist_ok=True)
version=subprocess.check_output([str(exe),'--version'],text=True)
match=re.search(r'Version: (2\.[01])\.',version)
if not match: raise SystemExit('Only Factorio 2.0 / 2.1 are supported by this test runner')
minor=match[1]
for suite in ['ammo']:
 if args.suite not in ['all',suite]:continue
 folder=work/suite
 if folder.exists():raise SystemExit(f'{folder} already exists; use a fresh --work path to preserve logs')
 mods=folder/'mods';mods.mkdir(parents=True)
 main_info=json.loads((root/'info.json').read_text())
 main_folder=mods/f"nuclear-accumulator_{main_info['version']}"
 shutil.copytree(root,main_folder,ignore=shutil.ignore_patterns('tests','__pycache__'))
 main_info['factorio_version']=minor
 main_info['dependencies']=['base >= '+('2.0.77' if minor=='2.0' else '2.1.21')]
 (main_folder/'info.json').write_text(json.dumps(main_info,indent=2))
 harness=next((root/'tests'/suite).glob('zz-*'))
 harness_copy=mods/harness.name;shutil.copytree(harness,harness_copy)
 info=json.loads((harness_copy/'info.json').read_text());info['factorio_version']=minor
 (harness_copy/'info.json').write_text(json.dumps(info,indent=2))
 names=['base','nuclear-accumulator',info['name']]
 mod_list={'mods':[{'name':n,'enabled':True} for n in names]+[{'name':n,'enabled':False} for n in ['space-age','quality','elevated-rails']]}
 (mods/'mod-list.json').write_text(json.dumps(mod_list))
 config=folder/'config.ini'; runtime=folder/'runtime';runtime.mkdir()
 config.write_text(f'[path]\nread-data=__PATH__executable__/../../data\nwrite-data={runtime}\n')
 common=[str(exe),'--config',str(config),'--mod-directory',str(mods)]
 save=folder/'test.zip'
 for stage,tail in [('create',['--create',str(save)]),('runtime',['--benchmark',str(save),'--benchmark-ticks',('2900' if suite=='acceptance' else '16000'),'--benchmark-runs','1'])]:
  logfile=folder/(stage+'.log')
  with logfile.open('w') as out:
   result=subprocess.run(common+tail,stdout=out,stderr=subprocess.STDOUT)
  logtext=logfile.read_text()
  if result.returncode or 'NA TEST FAIL:' in logtext or 'Error Util.cpp' in logtext or 'Error: The mod' in logtext:
   raise SystemExit(f'{suite}/{stage} failed: inspect {logfile}')
  if stage=='runtime':
   marker='NA TEST COMPLETE' if suite=='acceptance' else 'NA AMMO COMPLETE'
   if marker not in logtext:raise SystemExit(f'Missing completion marker in {logfile}')
  print(f'PASS {minor} {suite}/{stage}: {logfile}')
