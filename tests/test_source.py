"""Optional full source audit. Requires the pinned ../NorgannonDB checkout."""
from pathlib import Path
import hashlib
import json
import unittest
from lupa.lua51 import LuaRuntime
from test_addon import runtime, ROOT

SOURCE=ROOT.parent/'NorgannonDB'
if not SOURCE.exists(): SOURCE=ROOT/'source-data/NorgannonDB'

@unittest.skipUnless((SOURCE/'data/npcs.lua').exists(),'Pinned upstream checkout not present')
class SourceAuditTests(unittest.TestCase):
    def test_source_hashes(self):
        manifest=json.loads((ROOT/'database-manifest.json').read_text())
        for name,digest in manifest['sha256'].items():
            self.assertEqual(hashlib.sha256((SOURCE/name).read_bytes()).hexdigest(),digest,name)

    def test_complete_relationship_union_and_faction_variant(self):
        upstream=LuaRuntime();upstream.execute('GetLocale=function()return "enUS"end')
        for name in ['core/api.lua','data/world.lua','data/npcs.lua','data/items.lua','data/variants.lua']:
            upstream.execute((SOURCE/name).read_text('utf-8'))
        db=upstream.globals().NorgannonDB
        built=runtime();v=built.globals().V
        for faction in ['Alliance','Horde']:
            if faction=='Horde':db.ApplyPlayerVariants(db,'Horde','WARRIOR')
            built.execute('faction="'+faction+'";V:InitData({})')
            expected={}
            for nid,raw in db.npcs.items():
                n=db.Get(db,'npcs',nid)
                if n.sells:
                    for iid,stock in n.sells.items():expected[nid,iid]=stock
            for iid,raw in db['items'].items():
                it=db.Get(db,'items',iid)
                if it.vendors:
                    for nid,stock in it.vendors.items():expected.setdefault((nid,iid),stock)
            actual={(nid,iid):stock for nid,n in v.vendors.items() for iid,stock in n.offers.items()}
            self.assertEqual({k:s for k,s in expected.items() if actual.get(k)!=s},
                             {k:s for k,s in actual.items() if expected.get(k)!=s},faction)
            # Every usable generated coordinate matches an upstream spawn + map mapping.
            for nid,n in v.vendors.items():
                src=db.Get(db,'npcs',nid)
                for loc in n.locations.values():
                    if loc.x is None:continue
                    points=src.spawns[loc.area]
                    self.assertEqual(loc.map,db.maps.areaToUiMap[loc.area])
                    self.assertTrue(any(abs(loc.x-p[1]/100)<.000001 and abs(loc.y-p[2]/100)<.000001 for p in points.values()))
