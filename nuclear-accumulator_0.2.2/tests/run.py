#!/usr/bin/env python3
"""Run real headless acceptance tests in isolated directories; never alters installed user mods."""
import argparse, json, pathlib, re, shutil, subprocess, time, zipfile
parser=argparse.ArgumentParser()
parser.add_argument('--factorio',required=True,help='Path to headless Factorio binary')
parser.add_argument('--work',default='work/na-tests',help='Fresh intermediate test directory')
parser.add_argument('--suite',choices=['all','acceptance','lifecycle','tags','queue'],default='all')
parser.add_argument('--mod-zip',help='Install this exact ZIP instead of copying/adapting the source')
args=parser.parse_args()
exe=pathlib.Path(args.factorio).resolve(); root=pathlib.Path(__file__).resolve().parent.parent
work=pathlib.Path(args.work).resolve();work.mkdir(parents=True,exist_ok=True)
version=subprocess.check_output([str(exe),'--version'],text=True)
match=re.search(r'Version: (2\.[01])\.',version)
if not match: raise SystemExit('Only Factorio 2.0 / 2.1 are supported by this test runner')
minor=match[1]
for suite in ['acceptance','lifecycle','tags','queue']:
 if args.suite not in ['all',suite]:continue
 folder=work/suite
 if folder.exists():raise SystemExit(f'{folder} already exists; use a fresh --work path to preserve logs')
 mods=folder/'mods';mods.mkdir(parents=True)
 if args.mod_zip:
  artifact=pathlib.Path(args.mod_zip).resolve()
  with zipfile.ZipFile(artifact) as archive:
   infos=[name for name in archive.namelist() if name.endswith('/info.json') and name.count('/')==1]
   if len(infos)!=1:raise SystemExit('ZIP must contain exactly one top-level mod directory')
   main_info=json.loads(archive.read(infos[0]))
   if main_info['name']!='nuclear-accumulator' or main_info['factorio_version']!=minor:
    raise SystemExit('ZIP manifest does not match Nuclear Accumulator and the tested engine')
  shutil.copyfile(artifact,mods/artifact.name)
 else:
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
 for stage,tail in [('create',['--create',str(save)]),('runtime',['--benchmark',str(save),'--benchmark-ticks',{'acceptance':'3200','lifecycle':'4900','tags':'16000','queue':'350'}[suite],'--benchmark-runs','1'])]:
  logfile=folder/(stage+'.log')
  with logfile.open('w') as out:
   result=subprocess.run(common+tail,stdout=out,stderr=subprocess.STDOUT)
  logtext=logfile.read_text()
  if result.returncode or 'NA TEST FAIL:' in logtext or 'Error Util.cpp' in logtext or 'Error: The mod' in logtext:
   raise SystemExit(f'{suite}/{stage} failed: inspect {logfile}')
  if stage=='runtime':
   marker={'acceptance':'NA TEST COMPLETE','lifecycle':'NA LIFECYCLE COMPLETE','tags':'NA TAG COMPLETE','queue':'NA QUEUE COMPLETE'}[suite]
   if marker not in logtext:raise SystemExit(f'Missing completion marker in {logfile}')
  print(f'PASS {minor} {suite}/{stage}: {logfile}')


 if suite in ['tags','queue']:
  # Benchmark mode intentionally does not write autosaves; briefly run a private local server.
  settings=folder/'server-settings.json'
  server_settings=json.loads((exe.parents[2]/'data/server-settings.example.json').read_text())
  server_settings.update({'name':'Nuclear Accumulator queue test','visibility':{'public':False,'lan':False},
   'require_user_verification':False,'auto_pause':False,'autosave_interval':0,'non_blocking_saving':False})
  settings.write_text(json.dumps(server_settings))
  (runtime/'saves').mkdir(exist_ok=True)
  serverlog=folder/'save-server.log'
  with serverlog.open('w') as out:
   server=subprocess.Popen(common+['--start-server',str(save),'--server-settings',str(settings),'--port',str(34290 if minor=='2.0' else 34291),'--bind','127.0.0.1'],stdin=subprocess.PIPE,stdout=out,stderr=subprocess.STDOUT)
   try:
    deadline=time.monotonic()+45; saved=None
    while time.monotonic()<deadline and server.poll() is None:
     files=list((runtime/'saves').glob('*'+('na-inflight' if suite=='queue' else 'na-tags-recovered')+'*.zip'))
     if files:
      try:
       with zipfile.ZipFile(files[0]) as archive:
        if archive.testzip() is None:saved=files[0];break
      except (zipfile.BadZipFile,OSError):pass
     time.sleep(.1)
    if not saved:raise SystemExit(f'Missing mid-run {suite} server save: inspect {serverlog}')
   finally:
    server.terminate()
    try:server.wait(timeout=10)
    except subprocess.TimeoutExpired:server.kill();server.wait()
  logfile=folder/'resume.log'
  with logfile.open('w') as out:
   result=subprocess.run(common+['--benchmark',str(saved),'--benchmark-ticks',('350' if suite=='queue' else '14000'),'--benchmark-runs','1'],stdout=out,stderr=subprocess.STDOUT)
  logtext=logfile.read_text()
  marker='NA QUEUE COMPLETE' if suite=='queue' else 'NA TAG COMPLETE'
  if result.returncode or 'NA TEST FAIL:' in logtext or marker not in logtext:
   raise SystemExit(f'Mid-run {suite} reload failed: inspect {logfile}')
  print(f'PASS {minor} {suite}/mid-run-resume: {logfile}')
