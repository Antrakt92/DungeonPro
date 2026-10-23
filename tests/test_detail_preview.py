from pathlib import Path
import json,shutil,subprocess,sys,unittest
ROOT=Path(__file__).resolve().parents[1]
LUA=shutil.which('lua5.1') or shutil.which('lua5.1.exe')
if not LUA:raise SystemExit('Lua 5.1 is required for preview contract tests; put lua5.1 on PATH')
CAPTURE='tests/detail_visual.lua'
RUN='scripts/render-detail-preview.py'
def lua(path,*args):
 return subprocess.run([LUA,path,*map(str,args)],cwd=ROOT,text=True,encoding='utf-8',capture_output=True)
class OverviewPreview(unittest.TestCase):
 def test_default_quest_panes_keep_sample_content_contract(self):
  for locale in ('enUS','ruRU'):
   for tab in ('quest','sources','story'):
    args=('',locale,'','',''if tab=='quest'else tab)
    result=lua(CAPTURE,*args)
    self.assertEqual(result.returncode,0,result.stderr);snapshot=json.loads(result.stdout)
    self.assertEqual(snapshot['questID'],4764);self.assertEqual(snapshot['mode'],'quest')
    self.assertTrue(snapshot['fixtureRewards']);self.assertEqual(snapshot['detailTab'],'quest')
    self.assertEqual(snapshot['locale'],locale);self.assertFalse(snapshot['catalogCollapsed'])
    objects={row['id']:row for row in snapshot['objects']}
    def visible(row):
     seen=set()
     while row:
      if row['id']in seen or row['hidden']:return False
      seen.add(row['id']);row=objects.get(row.get('parent'))
     return True
    text=[row.get('text','')for row in objects.values()if visible(row)]
    rewards=('Guaranteed reward','First reward choice','Second reward choice')if locale=='enUS'else('Гарантированная награда','Первый вариант награды','Второй вариант награды')
    prose='Enter the dungeon, recover the missing relic'if locale=='enUS'else'Отправляйтесь в подземелье, найдите пропавшую реликвию'
    for label in rewards:self.assertEqual(text.count(label),1)
    self.assertEqual(sum(prose in value for value in text),1,"authentic prose appears exactly once in every legacy alias")
    for key,ident in snapshot['roles'].items():
     if key.startswith('detailTab_'):self.assertFalse(visible(objects[ident]))
 def test_overview_actual_image_only_panel_and_retained_central_plan(self):
  for locale in ('enUS','ruRU'):
   for collapsed in ('','collapsed'):
    r=lua(CAPTURE,'overview:dm',locale,'',collapsed,'','155')
    self.assertEqual(r.returncode,0,r.stderr);s=json.loads(r.stdout)
    self.assertEqual(s['mode'],'overview');self.assertNotIn('questID',s);self.assertFalse(s['fixtureRewards'])
    self.assertNotIn('overview',s,"removed rendered summary must not be fabricated as preview metadata")
    panel=s['compactOverview'];self.assertEqual(panel['centralPlanRowCount'],9)
    self.assertFalse(panel['texts'],"image-only overview has no title, range or prompt text")
    self.assertGreater(panel['artWidth'],40);self.assertGreater(panel['artHeight'],40)
    self.assertGreater(panel['artTexture'],0)
    for provider in ('Description','QuestObjectives','QuestRewards','DialogueRewards'):
     self.assertFalse(s['providerCalls'].get(provider),"overview must not hydrate selected-quest narrative or rewards")
    objects={row['id']:row for row in s['objects']}
    def visible(row):
     seen=set()
     while row:
      if row['id']in seen or row['hidden']:return False
      seen.add(row['id']);row=objects.get(row.get('parent'))
     return True
    detail=s['roles']['detail']
    actual=[row.get('text','')for row in objects.values()if row.get('parent')==detail and row.get('text')and visible(row)]
    self.assertEqual(actual,[],"actual visible detail FontStrings must be empty, not merely omitted from metadata")
    art=objects[s['roles']['overviewArt']]
    self.assertTrue(visible(art));self.assertEqual(art['parent'],detail);self.assertEqual(art['kind'],'Texture')
    self.assertEqual(art['texture'],panel['artTexture'])
    self.assertEqual(art['width'],panel['artWidth']);self.assertEqual(art['height'],panel['artHeight'])
    self.assertEqual(s['catalogCollapsed'],bool(collapsed));self.assertEqual(s['locale'],locale)
 def test_legacy_and_overview_check_commands(self):
  for args in [('check',),('overview:dm','enUS','','','','155','check'),('overview:dm','ruRU','','collapsed','','155','check')]:
   r=lua(CAPTURE,*args);self.assertEqual(r.returncode,0,r.stderr);self.assertIn('PASS',r.stdout)
 def test_invalid_cli_inputs_rejected_before_pillow(self):
  code='''import builtins,runpy
original=builtins.__import__
def guarded(name,*a,**kw):
 if name=='PIL'or name.startswith('PIL.'):raise RuntimeError('PIL_IMPORT_FORBIDDEN')
 return original(name,*a,**kw)
builtins.__import__=guarded
runpy.run_path('scripts/render-detail-preview.py',run_name='__main__')
'''
  for args in [('--ready-quest','155'),('--overview','dm','--quest','166'),('--overview','dm','--detail-tab','quest'),('--overview','dm','--ready-quest','0'),('--overview','dm','--ready-quest','4294967296'),('--quest','0'),('--quest','-1'),('--quest','4294967296'),('--overview',''),('--overview','not-existing'),('--overview','bad!'),('--overview','dm','--ready-quest','4294967295')]:
   r=subprocess.run([sys.executable,'-c',code,'--lua',LUA,*args],cwd=ROOT,text=True,encoding='utf-8',capture_output=True)
   self.assertEqual(r.returncode,2,(args,r.stderr));self.assertNotIn('PIL_IMPORT_FORBIDDEN',r.stderr)
 def test_repeat_ready_ids_normalized(self):
  code="""import builtins,subprocess,runpy,sys
original_run=subprocess.run
def run(args,*a,**kw):
 if isinstance(args,list)and any(str(v).endswith('detail_visual.lua')for v in args):print('CAPTURE_READY_IDS='+args[-1],file=sys.stderr)
 return original_run(args,*a,**kw)
subprocess.run=run
original_import=builtins.__import__
def guarded(name,*a,**kw):
 if name=='PIL'or name.startswith('PIL.'):raise RuntimeError('EXPECTED_PIL_STOP')
 return original_import(name,*a,**kw)
builtins.__import__=guarded
runpy.run_path('scripts/render-detail-preview.py',run_name='__main__')
"""
  r=subprocess.run([sys.executable,'-c',code,'--lua',LUA,'--overview','dm','--ready-quest','155','--ready-quest','155'],cwd=ROOT,text=True,encoding='utf-8',capture_output=True)
  self.assertNotEqual(r.returncode,0);self.assertIn('CAPTURE_READY_IDS=155\n',r.stderr);self.assertIn('EXPECTED_PIL_STOP',r.stderr)
 def test_repeat_quest_ids_normalized(self):
  code="""import subprocess,runpy,sys
original_run=subprocess.run
def run(args,*a,**kw):
 if isinstance(args,list)and any(str(v).endswith('detail_visual.lua')for v in args):print('CAPTURE_QUEST='+str(args[2]),file=sys.stderr)
 return original_run(args,*a,**kw)
subprocess.run=run
runpy.run_path('scripts/render-detail-preview.py',run_name='__main__')
"""
  import tempfile
  with tempfile.TemporaryDirectory()as tmp:
   r=subprocess.run([sys.executable,'-c',code,'--lua',LUA,'--output',tmp,'--quest','4764','--quest','4764'],cwd=ROOT,text=True,encoding='utf-8',capture_output=True)
   self.assertEqual(r.returncode,0,(r.stdout,r.stderr))
   lines=[line for line in r.stderr.splitlines()if line.startswith('CAPTURE_QUEST=')]
   self.assertEqual(len(lines),4,lines);self.assertEqual(set(lines),{'CAPTURE_QUEST=4764'})
class MalformedSnapshotPreview(unittest.TestCase):
 def _snapshot(self):
  result=lua(CAPTURE,'4764','enUS')
  self.assertEqual(result.returncode,0,result.stderr)
  return json.loads(result.stdout)
 def _preview_module(self):
  import importlib.util
  from PIL import Image,ImageDraw,ImageFont
  spec=importlib.util.spec_from_file_location('render_detail_preview',ROOT/'scripts/render-detail-preview.py')
  module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
  module.Image,module.ImageDraw,module.ImageFont=Image,ImageDraw,ImageFont
  return module
 def _run_preview_main(self,tmp,snapshot,args):
  import runpy
  from unittest import mock
  real_run=subprocess.run
  def fake_run(cmd,*a,**kw):
   if isinstance(cmd,list)and any(str(v).endswith('detail_visual.lua')for v in cmd):
    return subprocess.CompletedProcess(cmd,0,stdout=json.dumps(snapshot),stderr='')
   return real_run(cmd,*a,**kw)
  argv=['render-detail-preview.py','--lua',LUA,'--output',tmp,*args]
  with mock.patch.object(sys,'argv',argv),mock.patch.object(subprocess,'run',fake_run):
   runpy.run_path(str(ROOT/RUN),run_name='__main__')
 def test_valid_capture_renders_byte_identical_to_direct_render(self):
  import tempfile
  try:__import__('PIL')
  except ImportError:self.skipTest('Pillow is required for preview rendering')
  snapshot=self._snapshot()
  module=self._preview_module()
  with tempfile.TemporaryDirectory()as tmp:
   direct=Path(tmp)/'direct.png'
   module.render(snapshot,direct)
   expected=direct.read_bytes()
   self._run_preview_main(tmp,snapshot,['--quest','4764'])
   for name in ('4764-enUS.png','4764-ruRU.png','4764-enUS-metrics.lua','4764-ruRU-metrics.lua'):
    self.assertTrue((Path(tmp)/name).exists(),name)
   for name in ('4764-enUS.png','4764-ruRU.png'):
    self.assertEqual((Path(tmp)/name).read_bytes(),expected,name)
 def test_malformed_snapshot_rejected_without_traceback(self):
  import contextlib,copy,io,tempfile
  snapshot=self._snapshot()
  key=next(iter(snapshot['metrics']))
  cases=(
   ('metrics size',lambda s:s['metrics'][key].update(size='big')),
   ('metrics width',lambda s:s['metrics'][key].update(width='wide')),
   ('row id',lambda s:s['objects'][0].pop('id')),
   ('frame role',lambda s:s['roles'].pop('frame')),
   ('quest identity',lambda s:s.pop('questID')),
   ('anchor offset',lambda s:next(row for row in s['objects']if row.get('points'))['points'][0].update(x='bad')),
   ('font size huge',lambda s:s['objects'][0].update(text='hi',size=10**12,width=100)),
   ('text huge',lambda s:s['objects'][0].update(text='x'*200000,size=14,width=100)),
  )
  for label,mutate in cases:
   with self.subTest(label):
    bad=copy.deepcopy(snapshot)
    mutate(bad)
    with tempfile.TemporaryDirectory()as tmp:
     err=io.StringIO()
     with contextlib.redirect_stderr(err),self.assertRaises(SystemExit)as stopped:
      self._run_preview_main(tmp,bad,['--quest','4764'])
     self.assertEqual(stopped.exception.code,2,label)
     self.assertIn('Invalid preview',err.getvalue(),label)
     self.assertNotIn('Traceback',err.getvalue(),label)
 def run_with_fake(self,tmp,fake,err):
  import contextlib
  from unittest import mock
  import runpy
  real_run=subprocess.run
  def dispatch(cmd,*a,**kw):
   if isinstance(cmd,list)and any(str(v).endswith('detail_visual.lua')for v in cmd):return fake(cmd,*a,**kw)
   return real_run(cmd,*a,**kw)
  argv=['render-detail-preview.py','--lua',LUA,'--output',tmp,'--quest','4764']
  with mock.patch.object(sys,'argv',argv),mock.patch.object(subprocess,'run',dispatch),contextlib.redirect_stderr(err):
   runpy.run_path(str(ROOT/RUN),run_name='__main__')
 def test_malformed_stdout_rejected_without_traceback(self):
  import io,tempfile
  for label,stdout in (('non-JSON','NOT JSON{{{'),('truncated JSON','{"objects": [{"id": 1'),('empty stdout','')):
   with self.subTest(label):
    def fake(cmd,*a,_stdout=stdout,**kw):return subprocess.CompletedProcess(cmd,0,stdout=_stdout,stderr='')
    with tempfile.TemporaryDirectory()as tmp:
     err=io.StringIO()
     with self.assertRaises(SystemExit)as stopped:
      self.run_with_fake(tmp,fake,err)
     self.assertEqual(stopped.exception.code,2,label)
     self.assertIn('Invalid preview',err.getvalue(),label)
     self.assertNotIn('Traceback',err.getvalue(),label)
  with self.subTest('non-UTF-8 bytes'):
   def fake_decode(cmd,*a,**kw):raise UnicodeDecodeError('utf-8',b'\xff',0,1,'invalid start byte')
   with tempfile.TemporaryDirectory()as tmp:
    err=io.StringIO()
    with self.assertRaises(SystemExit)as stopped:
     self.run_with_fake(tmp,fake_decode,err)
    self.assertEqual(stopped.exception.code,2)
    self.assertIn('Invalid preview',err.getvalue())
    self.assertNotIn('Traceback',err.getvalue())
if __name__=='__main__':unittest.main()
