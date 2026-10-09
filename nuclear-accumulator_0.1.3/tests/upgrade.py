#!/usr/bin/env python3
"""Create an actual old-version save with a pending carrier, then load it with this version."""
import argparse,json,pathlib,re,shutil,subprocess
p=argparse.ArgumentParser();p.add_argument('--factorio',required=True);p.add_argument('--baseline',required=True);p.add_argument('--work',required=True)
a=p.parse_args();exe=pathlib.Path(a.factorio).resolve();old=pathlib.Path(a.baseline).resolve();new=pathlib.Path(__file__).resolve().parent.parent
work=pathlib.Path(a.work).resolve()
if work.exists():raise SystemExit('Use a fresh work directory')
mods=work/'mods';mods.mkdir(parents=True)
minor=re.search(r'Version: (2\.[01])\.',subprocess.check_output([str(exe),'--version'],text=True))[1]
h=next((new/'tests/upgrade').glob('zz-*'));shutil.copytree(h,mods/h.name)
hi=json.loads((mods/h.name/'info.json').read_text());hi['factorio_version']=minor;(mods/h.name/'info.json').write_text(json.dumps(hi))
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in ['base','nuclear-accumulator',hi['name']]]+[
 {'name':n,'enabled':False} for n in ['space-age','quality','elevated-rails']]}))
runtime=work/'runtime';runtime.mkdir();config=work/'config.ini';save=work/'old-save.zip'
config.write_text(f'[path]\nread-data=__PATH__executable__/../../data\nwrite-data={runtime}\n')
common=[str(exe),'--config',str(config),'--mod-directory',str(mods)]
for label,source,tail in [('old-create',old,['--create',str(save)]),('upgraded-runtime',new,['--benchmark',str(save),'--benchmark-ticks','150','--benchmark-runs','1'])]:
 for f in mods.glob('nuclear-accumulator_*'):shutil.rmtree(f)
 info=json.loads((source/'info.json').read_text());folder=mods/f"nuclear-accumulator_{info['version']}"
 shutil.copytree(source,folder,ignore=shutil.ignore_patterns('tests','__pycache__'))
 info['factorio_version']=minor;info['dependencies']=['base >= '+('2.0.77' if minor=='2.0' else '2.1.21')];(folder/'info.json').write_text(json.dumps(info))
 path=work/(label+'.log')
 with path.open('w') as out:r=subprocess.run(common+tail,stdout=out,stderr=subprocess.STDOUT)
 text=path.read_text()
 if r.returncode or 'NA TEST FAIL:' in text:raise SystemExit(f'Failure: inspect {path}')
 if label=='upgraded-runtime' and 'NA UPGRADE COMPLETE' not in text:raise SystemExit(f'Missing completion in {path}')
 print('PASS',minor,label,path)
