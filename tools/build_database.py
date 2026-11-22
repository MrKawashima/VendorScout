"""Compile EVERY vendor relationship in a pinned NorgannonDB snapshot.

Usage: python tools/build_database.py ../NorgannonDB
Requires lupa (Lua 5.1). Input is trusted open-source Lua, executed in an isolated
Lua runtime without os/io/package/debug. Output is deterministic and self-contained.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SOURCE_COMMIT = "cae6d644952b9b12fbd1e3a500211893336cc219"

def lua(value):
    if value is None: return "nil"
    if isinstance(value, bool): return "true" if value else "false"
    if isinstance(value, str):
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r') + '"'
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, list): return "{" + ",".join(lua(v) for v in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join("["+lua(k)+"]="+lua(v) for k,v in sorted(value.items(),key=lambda x:(str(type(x[0])),x[0]))) + "}"
    raise TypeError(type(value))

def plain(t):
    if hasattr(t, "items"): return {k:plain(v) for k,v in t.items()}
    return t

def item_record(db,iid):
    it=db.Get(db,"items",iid)
    result={"name":it.name if it else f"Item #{iid}"}
    if it:
        for key in ("class","subClass","requiredLevel","side","repFaction","repStanding","pvpRank"):
            if it[key] is not None: result[key]=it[key]
    return result

def vendor_record(db,nid):
    n=db.Get(db,"npcs",nid)
    v={"name":n.name if n else f"Vendor #{nid}","offers":{},"locations":[]}
    if n:
        for key in ("subName","reaction","zone"):
            if n[key] is not None: v[key]=n[key]
        seen=set()
        for area,points in sorted(n.spawns.items() if n.spawns else []):
            mapid=db.maps.areaToUiMap[area]
            for _,p in sorted(points.items()):
                x,y=p[1],p[2];loc={"area":int(area)}
                if mapid: loc["map"]=int(mapid)
                if x is not None and y is not None and 0<=x<=100 and 0<=y<=100:
                    loc.update(x=round(x/100,6),y=round(y/100,6))
                if p[4]: loc['phase']=p[4]
                key=json.dumps(loc,sort_keys=True)
                if key not in seen: v["locations"].append(loc); seen.add(key)
        if n.waypoints: v['wanders']=True
    if not v['locations']: v['locations']=[{"area":int(n.zone)}] if n and n.zone else []
    return v

def main():
    src = (Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'source-data/NorgannonDB').resolve()
    if (src/'.git').exists():
        commit = subprocess.check_output(["git", "-C", str(src), "rev-parse", "HEAD"], text=True).strip()
    else:
        commit=(src/'.snapshot-commit').read_text().strip()
    if commit != SOURCE_COMMIT:
        raise SystemExit("Unexpected source commit: review coverage before changing SOURCE_COMMIT")
    manifest_path=ROOT/'database-manifest.json'
    if manifest_path.exists():
        expected=json.loads(manifest_path.read_text('utf-8'))
        if expected['commit']==commit:
            for name,digest in expected['sha256'].items():
                if hashlib.sha256((src/name).read_bytes()).hexdigest()!=digest:
                    raise SystemExit('Source hash mismatch: '+name)
    rt = LuaRuntime(unpack_returned_tuples=True)
    rt.execute("os=nil;io=nil;package=nil;debug=nil;dofile=nil;loadfile=nil; GetLocale=function() return 'enUS' end")
    files = ["core/api.lua", "data/info.lua", "data/world.lua", "data/npcs.lua", "data/items.lua", "data/variants.lua"]
    hashes = {}
    for name in files:
        raw=(src/name).read_bytes(); hashes[name]=hashlib.sha256(raw).hexdigest()
        rt.execute(raw.decode('utf-8-sig'))
    db=rt.globals().NorgannonDB
    vendors={}; items={}; links={}; unresolved=[]
    # Union both indexes: no item or vendor relation is lost to asymmetric input.
    for ident, raw in db.npcs.items():
        n=db.Get(db,"npcs",ident)
        if n.sells:
            for iid,stock in n.sells.items(): links[(int(ident),int(iid))]=stock
    for iid,raw in db['items'].items():
        it=db.Get(db,"items",iid)
        if it.vendors:
            for nid,stock in it.vendors.items(): links.setdefault((int(nid),int(iid)),stock)
    for nid,iid in sorted(links):
        if iid not in items:
            items[iid]=item_record(db,iid)
        if nid not in vendors:
            v=vendor_record(db,nid)
            if not any(l.get('map') and 'x' in l for l in v['locations']): unresolved.append(nid)
            vendors[nid]=v
        vendors[nid]['offers'][iid]=links[nid,iid]
    # Compile faction-specific locations/inventory, preserving both profiles.
    horde={}
    db.ApplyPlayerVariants(db,"Horde","WARRIOR")
    for nid,patch in db.variants.faction.Horde.npcs.items():
        n=db.Get(db,"npcs",nid)
        if nid in vendors or (n and n.sells):
            v=vendor_record(db,nid)
            v['offers']={int(i):s for i,s in n.sells.items()} if n and n.sells else {}
            # Reconcile both indexes after applying the variant as well. The
            # source can remove npc.sells while retaining item.vendors links.
            for iid,raw in db['items'].items():
                it=db.Get(db,"items",iid)
                if it.vendors and it.vendors[nid] is not None:
                    v['offers'].setdefault(int(iid),it.vendors[nid])
            for iid,stock in v['offers'].items():
                links[nid,iid]=stock
                if iid not in items: items[iid]=item_record(db,iid)
            if v!=vendors.get(nid): horde[int(nid)]=v
    usedareas={loc['area'] for v in list(vendors.values())+list(horde.values()) for loc in v['locations']}
    zones={int(a):db.zones[a].name if db.zones[a] else f"Area #{a}" for a in usedareas}
    # Include all available vendor/item translations; only the active locale loads.
    locales={}
    for path in sorted((src/'locales').glob('*.lua')):
        loc=path.stem
        rt.globals().GetLocale=rt.eval('function() return '+lua(loc)+' end')
        raw=path.read_bytes(); hashes[str(path.relative_to(src)).replace('\\','/')]=hashlib.sha256(raw).hexdigest()
        rt.execute(raw.decode('utf-8-sig'))
        data=db.locales[loc]
        if not data: continue
        result={"items":{},"vendors":{}}
        for kind,target,ids in (("items","items",items),("npcs","vendors",vendors)):
            if data[kind]:
                for ident in ids:
                    entry=data[kind][ident]
                    name=entry if isinstance(entry,str) else (entry.name if entry else None)
                    if name: result[target][ident]=name
        locales[loc]=result
    stats={"items":len(items),"vendors":len(vendors),"relationships":len(links),
           "locations":sum(len(v['locations']) for v in vendors.values()),
           "mappedLocations":sum(1 for v in vendors.values() for l in v['locations'] if l.get('map') and 'x' in l),
           "vendorsWithoutCoordinates":len(unresolved),"hordeOverrides":len(horde)}
    manifest={"source":"https://github.com/zmarotrix/NorgannonDB","commit":commit,
              "generated":db.info.generated,"build":db.info.build,"schema":plain(db.schema),
              "stats":stats,"vendorsWithoutCoordinates":unresolved,"sha256":hashes,
              "coverage":"Complete vendor relationship extract of this snapshot; not a guarantee of all live Forever vendors or stock."}
    out=ROOT/'VendorScout'; out.mkdir(parents=True,exist_ok=True)
    lines=['-- Generated by tools/build_database.py; GPL-3.0. See DATA-SOURCES.txt.',
           'local _, V = ...', 'V.Data = {items={},vendors={},horde='+lua(horde)+',zones='+lua(zones)+',meta='+lua({"commit":commit,"generated":db.info.generated,**stats})+'}']
    for iid,it in sorted(items.items()): lines.append(f'V.Data.items[{iid}]='+lua(it))
    for nid,v in sorted(vendors.items()): lines.append(f'V.Data.vendors[{nid}]='+lua(v))
    (out/'Data.lua').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    lines=['local _, V = ...', 'local locale = GetLocale()', 'V.Locale = {items={},vendors={}}']
    for name,data in locales.items():
        lines.append('if locale == '+lua(name)+' then')
        for kind in ('items','vendors'):
            for ident,value in sorted(data[kind].items()): lines.append(f'V.Locale.{kind}[{ident}]='+lua(value))
        lines.append('end')
    (out/'Locales.lua').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    (ROOT/'database-manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    (out/'LICENSE').write_bytes((src/'LICENSE').read_bytes())
    (out/'UPSTREAM-NOTICE.txt').write_bytes((src/'NOTICE.md').read_bytes())
    print(json.dumps(stats,indent=2))

if __name__ == '__main__': main()
