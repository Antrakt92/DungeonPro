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
 def test_overview_real_model_metadata_and_visible_support(self):
  for locale in ('enUS','ruRU'):
   for collapsed in ('','collapsed'):
    r=lua(CAPTURE,'overview:dm',locale,'',collapsed,'','155')
    self.assertEqual(r.returncode,0,r.stderr);s=json.loads(r.stdout)
    self.assertEqual(s['mode'],'overview');self.assertNotIn('questID',s);self.assertFalse(s['fixtureRewards'])
    self.assertEqual(s['overview']['shownRoots'],9);self.assertEqual(s['overview']['counts']['READY'],0)
    self.assertTrue(s['overview']['unknown']);self.assertFalse(s['overview']['knownPrepared'])
    self.assertEqual(s['overview']['steps'],[{'id':155,'kind':'turnin','status':'READY','listedTarget':False}])
    self.assertTrue(any(('Supporting quest'if locale=='enUS'else'Вспомогательное задание')in row.get('text','')and not row['hidden']for row in s['objects']))
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
  for args in [('--ready-quest','155'),('--overview','dm','--quest','166'),('--overview','dm','--detail-tab','quest'),('--overview','dm','--ready-quest','0'),('--overview','dm','--ready-quest','4294967296'),('--overview',''),('--overview','not-existing'),('--overview','bad!'),('--overview','dm','--ready-quest','4294967295')]:
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
if __name__=='__main__':unittest.main()
