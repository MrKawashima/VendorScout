"""Lua 5.1 tests with simulated WoW APIs. Run: python -m unittest discover -s tests -v"""
from pathlib import Path
import json
import time
import unittest
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
ADDON=ROOT/'VendorScout'
API=ROOT.parent/'wow-ui-source/Interface/AddOns/Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua'

def runtime(full=False,locale='enUS'):
    rt=LuaRuntime(unpack_returned_tuples=True)
    rt.execute((ROOT/'tests/wow_mock.lua').read_text('utf-8'))
    rt.execute('function GetLocale() return '+json.dumps(locale)+' end')
    rt.execute('V = {}')
    load=rt.eval('function(code) assert(loadstring(code))("VendorScout",V) end')
    for name in ['Data.lua','Locales.lua','Filters.lua','Search.lua']:
        load((ADDON/name).read_text('utf-8'))
    if full:
        if API.exists(): rt.execute(API.read_text('utf-8'))
        else:
            rt.execute('''MapCanvasDataProviderMixin={OnAdded=function(s,m)s.owningMap=m end,GetMap=function(s)return s.owningMap end}
            MapCanvasPinMixin={SetScalingLimits=function()end,UseFrameLevelType=function(s,k)s.pinFrameLevelType=k end,OnReleased=function()end}''')
        rt.execute('makeMap()')
        for name in ['UI.lua','Map.lua','Merchant.lua','Core.lua']:load((ADDON/name).read_text('utf-8'))
        rt.execute('fire("PLAYER_LOGIN")')
    else: rt.execute('V:InitData({})')
    return rt

FIXTURE='''
V.Data.items={ [1]={name="Cool Water",class=0,subClass=5},[2]={name="Recipe: Pie",class=9},[3]={name="Horde Gear",class=4,side="H"} }
V.Data.vendors={
 [11]={name="Near",reaction="AH",offers={[1]=0,[2]=1},locations={{map=1,x=.51,y=.5}}},
 [12]={name="Far",reaction="A",offers={[1]=0},locations={{map=1,x=.9,y=.9},{map=1,x=.6,y=.5}}},
 [13]={name="Horde",reaction="H",offers={[1]=0,[3]=0},locations={{map=1,x=.5,y=.5}}},
 [14]={name="Cross zone",reaction="AH",offers={[1]=0},locations={{map=2,x=0,y=.5}}},
 [15]={name="Other continent",reaction="AH",offers={[1]=0},locations={{map=3,x=.5,y=.5}}},
 [16]={name="Unknown",reaction="AH",offers={[1]=0},locations={}},
 [17]={name="Hostile",offers={[1]=0},locations={{map=1,x=.5,y=.5}}},
 [18]={name="Map unavailable",reaction="AH",offers={[2]=0},locations={{map=999,x=.5,y=.5}}}
}
V.Locale={items={},vendors={}};V.worldCache={};playerMap=1;playerX=.5;playerY=.5
V:InitData({});V.query="Water"
'''

class SearchTests(unittest.TestCase):
    def setUp(self): self.rt=runtime();self.rt.execute(FIXTURE)
    def check(self,code):self.rt.execute(code)
    def test_nearest_multiple_spawns_and_world_distance(self):
        self.check('local r=V:Search();assert(#r==5);assert(r[1].id==11);assert(math.abs(r[1].distance-10)<.001);assert(r[2].id==12 and r[2].location.x==.6);assert(r[3].id==14 and r[3].distance==500);assert(r[4].id==15 and not r[4].distance);assert(r[5].id==16)')
    def test_faction_filter(self):
        self.check('faction="Horde";local r=V:Search();assert(r[1].id==13);for _,x in ipairs(r)do assert(x.id~=12 and x.id~=17)end;V.db.friendlyOnly=false;assert(#V:Search()==7)')
    def test_item_side_and_category(self):
        self.check('V.query="";V.category="gear";assert(#V:Search()==0);faction="Horde";assert(#V:Search()==1);V.category="recipes";assert(#V:Search()==2)')
    def test_exact_ids_links_and_plain_special_characters(self):
        self.check('V.query="1";assert(#V:Search()==5);V.query="|cff00ff00|Hitem:1:0:0|h[Cool Water]|h|r";assert(#V:Search()==5);V.query="%[";assert(#V:Search()==0);V.query="  WATER cool  ";assert(#V:Search()==5)')
    def test_vendor_name_search(self):self.check('V.query="Near";local r=V:Search();assert(#r==1 and #r[1].offers==2)')
    def test_locale_names_searchable(self):self.check('V.Locale.items[1]="Kühles Wasser";V:Reindex();V.query="Wasser";assert(#V:Search()==5);V.query="Cool Water";assert(#V:Search()==5)')
    def test_current_map_projection(self):self.check('local r=V:Search(2);assert(#r==1 and r[1].id==14);V.query="Recipe";assert(#V:Search(999)==1)')
    def test_missing_position_keeps_results_without_fake_distances(self):self.check('playerX=nil;local r=V:Search();assert(#r==5);for _,x in ipairs(r)do assert(not x.distance)end')
    def test_secret_coordinates_do_not_crash(self):self.check('playerX="SECRET";assert(#V:Search()==5);assert(V:PlayerLocation()==nil)')
    def test_invalid_transforms_retry_and_player_cache_bounded(self):
        self.check('local f=C_Map.GetWorldPosFromMapPos;C_Map.GetWorldPosFromMapPos=function()return nil end;assert(not V:World({map=1,x=.1,y=.1}));C_Map.GetWorldPosFromMapPos=f;assert(V:World({map=1,x=.1,y=.1})==1);for i=1,50 do playerX=i/100;V:Search()end;local n=0;for _ in pairs(V.worldCache)do n=n+1 end;assert(n<15)')
    def test_new_query_selects_nearest_and_empty_results_clear_target(self):self.check('V:RefreshSearch();V:Select(V.results[2]);V:SetQuery("Recipe");assert(V.selected==V.results[1] and V.selectionMode=="auto");V:SetQuery("missing-123");assert(not V.selected and not V.targetLocation)')
    def test_stable_sort(self):self.check('playerX=nil;local a=V:Search();local b=V:Search();for i=1,#a do assert(a[i].id==b[i].id)end')

class DatabaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.rt=runtime()
    def test_every_relation_and_coordinate(self):
        self.rt.execute('''local ni,nv,nr,nl,nm=0,0,0,0,0
        for id,it in pairs(V.items)do ni=ni+1;assert(type(it.name)=="string" and #it.name>0)end
        for id,v in pairs(V.vendors)do nv=nv+1;assert(type(v.name)=="string")
          for iid,stock in pairs(v.offers)do nr=nr+1;assert(V.items[iid]);assert(stock>=0)end
          for _,l in ipairs(v.locations)do nl=nl+1;if l.x then assert(l.x>=0 and l.x<=1 and l.y>=0 and l.y<=1);if l.map then nm=nm+1 end end end
        end
        assert(ni==3940 and nv==1151 and nr==18010 and nl==1210 and nm==1186)''')
    def test_all_items_resolve_without_cache_download(self):
        self.rt.execute('''V.db.friendlyOnly=false;local n=0
        for id,it in pairs(V.items)do
          assert(V.itemIndex[id] and V:ItemName(id));n=n+1
        end;assert(n==3940);V.query="159";assert(#V:Search()>0)''')
    def test_translations_load_in_isolation(self):
        for loc in ['deDE','frFR','esES','esMX','ruRU','koKR','ptBR','zhCN','zhTW']:
            rt=runtime(locale=loc);rt.execute('local n=0;for _ in pairs(V.Locale.items)do n=n+1 end;assert(n>2000)')
    def test_xml_and_toc(self):
        ET.parse(ADDON/'Pins.xml')
        a=(ADDON/'VendorScout.toc').read_text();b=(ADDON/'VendorScout_Camelot.toc').read_text();self.assertEqual(a,b)
        for line in a.splitlines():
            if line and not line.startswith('#'):self.assertTrue((ADDON/line).exists())
    def test_horde_variant_spawns(self):
        rt=runtime();rt.execute('faction="Horde";V:InitData({});local v=V.vendors[15898];assert(v.locations[3].area==1497);faction="Alliance";V:InitData({});assert(V.vendors[15898].locations[3].area==1519)')
    def test_consumables_include_uncached_water(self):
        rt=runtime();rt.execute('V.category="consumables";V.query="159";assert(#V:Search()>0)')
    def test_lua51_compile_all_files(self):
        for path in ADDON.glob('*.lua'): self.rt.eval('function(s)assert(loadstring(s))end')(path.read_text('utf-8'))

class IntegrationTests(unittest.TestCase):
    def setUp(self):self.rt=runtime(full=True)
    def check(self,code):self.rt.execute(code)
    def test_fresh_session_stays_unmarked_until_explicit_search(self):
        self.check('assert(not V.selected and V.pinsSuppressed);ShowUIPanel(WorldMapFrame);assert(#WorldMapFrame.pins==0 and not V.selected and V.pinCount==0);V.mapPanel.faction:Click();V.mapPanel.category:Click();WorldMapFrame:SetMapID(1453);V:RefreshSearch();HideUIPanel(WorldMapFrame);ShowUIPanel(WorldMapFrame);assert(#WorldMapFrame.pins==0 and not V.selected);V:SetQuery("159");assert(V.selected and not V.pinsSuppressed and #WorldMapFrame.pins>0);V:InitData(V.db);assert(not V.pinsSuppressed);V:SetQuery("");V:RefreshSearch();assert(not V.selected and #WorldMapFrame.pins==0)')
    def test_login_and_slash_search(self):self.check('assert(V.window and V.minimap);SlashCmdList.VENDORSCOUT("159");assert(V.window:IsShown() and #V.results>0);assert(V.window.rows[1].result)')
    def test_both_search_controls_update_shared_query(self):self.check('V:OpenMapSearch();local m=V:GetMapSearch();m:SetQuery("2320");assert(V.window.search:GetText()=="2320");V:SetQuery("159");assert(V.mapPanel.search:GetText()=="159" and V.window.search:GetText()=="159");assert(m.query=="159" and m.results~=V.results);for _,r in ipairs(m.results)do assert(r.offers[1]==159)end')
    def test_debounce_and_submit(self):self.check('V.window:Show();V.window.search:SetText("159");V.window.search.scripts.OnTextChanged(V.window.search,true);assert(V.pendingText=="159");currentTime=1;for _,f in ipairs(frames)do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,1)end end;assert(V.query=="159")')
    def test_select_map_and_pulse(self):self.check('V:SetQuery("159");V:Select(V.results[1]);assert(V:ShowOnMap());assert(WorldMapFrame:IsShown());assert(#WorldMapFrame.pins>0 and WorldMapFrame.pins[1].selected);assert(WorldMapFrame.pins[1].scripts.OnUpdate);assert(not V.window:IsShown())')
    def test_combat_does_not_open_map(self):self.check('V:SetQuery("159");V:Select(V.results[1]);combat=true;assert(not V:ShowOnMap());assert(not WorldMapFrame:IsShown());assert(#messages==1)')
    def test_unknown_coordinates_no_invented_pin(self):self.check('V:Select({id=1,vendor={locations={}},offers={}});assert(not V:ShowOnMap());assert(not WorldMapFrame:IsShown())')
    def test_pins_cap_and_selected_kept(self):self.check('V:OpenMapSearch();V.db.friendlyOnly=false;V:SetQuery("");V:Select(V.results[1]);assert(V.pinTotal>150);assert(#WorldMapFrame.pins==150);V:Select(V.results[#V.results-50]);V:RefreshPins();assert(#WorldMapFrame.pins<=150)')
    def test_pagination_controls_and_localization(self):self.check('V:SetQuery("159");local total=#V.results;assert(total>7);V.window.next:Click();assert(V.page==2);V.db.language="no";V:RefreshUI();assert(V.window.subtitle:GetText():find("Nærmeste"));V:SetQuery("impossible-abc-987");assert(V.page==1 and V.window.empty:IsShown()==V.window:IsShown())')
    def test_pin_click_and_clear(self):self.check('V:OpenMapSearch();local m=V:GetMapSearch();m:SetQuery("159");local p=WorldMapFrame.pins[1];assert(p);p:OnClick("LeftButton");assert(m.selected);SlashCmdList.VENDORSCOUT("clear");assert(not m.selected and not m.targetLocation);m:RefreshSearch();assert(not m.selected)')
    def test_merchant_learning_and_reload(self):self.check('merchantRows={{id=999002,name="Forever Test Food",numAvailable=3}};fire("MERCHANT_SHOW");assert(V.db.observed[999001].offers[999002].stock==3);V:InitData(V.db);V:SetQuery("999002");assert(#V.results==1 and V.results[1].id==999001);assert(V.results[1].location.observed)')
    def test_partial_merchant_scan_does_not_remove_stock(self):self.check('merchantRows={{id=999002,name="Test Food",numAvailable=0},{id=999003,name="Test Tool",numAvailable=-1}};fire("MERCHANT_SHOW");merchantRows={{id=999002,name="Test Food",numAvailable=0}};fire("MERCHANT_UPDATE");assert(V.vendors[999001].offers[999003]==0);assert(V.db.observed[999001].offers[999002].stock==0)')
    def test_merchant_secret_stock_and_invalid_npc(self):self.check('merchantRows={{id=999002,name="Food",numAvailable="SECRET"}};fire("MERCHANT_SHOW");assert(V.db.observed[999001].offers[999002].stock==nil);UnitGUID=function()return "SECRET"end;fire("MERCHANT_SHOW")')
    def test_map_change_and_scope(self):self.check('V:OpenMapSearch();local m=V:GetMapSearch();m.mapOnly=true;WorldMapFrame:SetMapID(2);assert(#m.results==0);assert(m.mapPage==1)')
    def test_reset_window_and_scale(self):self.check('V.db.ui.scale=8;V:FitWindow();assert(V.window:GetScale()<=1.3);SlashCmdList.VENDORSCOUT("reset");assert(V.db.ui.scale==.9 and V.window:IsShown())')
    def test_movement_reorders_nearest_first(self):
        self.check(FIXTURE+'V.window:Show();V:RefreshSearch();assert(V.results[1].id==11);playerX=.61;for _,f in ipairs(frames)do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,2.1)end end;assert(V.results[1].id==12)')
    def test_floating_search_is_outside_map_without_resizing(self):
        self.check('local c=WorldMapFrame.ScrollContainer;local width=c:GetWidth();V:SetQuery("159");V:ShowOnMap();assert(V.mapPanel.parent==UIParent and V.mapPanel.movable);assert(V.mapPanel:GetLeft()>WorldMapFrame:GetRight());assert(c:GetWidth()==width and not WorldMapFrame.resizeCalls)')
    def test_full_map_category_and_scope_controls(self):
        self.check('V:OpenMapSearch();local m=V:GetMapSearch();V.mapPanel.category:Click();V.mapPanel.category.menu.options[2]:Click();assert(m.category=="consumables" and V.category=="consumables");V.mapPanel.scope:Click();assert(m.mapOnly and not V.mapOnly);V.mapPanel.faction:Click();assert(not m.db.friendlyOnly and not V.db.friendlyOnly)')
    def test_actual_pointer_hits_map_controls_over_high_border(self):
        self.check('V:OpenMapSearch();local m=V:GetMapSearch();pointerClick(V.mapPanel.search);assert(V.mapPanel.search:HasFocus());V.mapPanel.search:Type("Water");currentTime=1;for _,f in ipairs(frames)do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,1)end end;assert(m.query=="Water" and #m.results>0 and V.query=="Water");pointerClick(V.mapPanel.faction);assert(not m.db.friendlyOnly);pointerClick(V.mapPanel.category);pointerClick(V.mapPanel.category.menu.options[2]);assert(m.category=="consumables");pointerClick(V.mapButton);assert(not V.mapPanel:IsShown())')
    def test_previous_medium_stratum_would_intercept_pointer(self):
        self.check('V:OpenMapSearch();V.mapPanel:ClearAllPoints();V.mapPanel:SetPoint("TOPLEFT",WorldMapFrame,"TOPLEFT",50,-100);V.mapPanel:SetFrameStrata("MEDIUM");V.mapPanel:SetFrameLevel(10000);local b=V.mapPanel.search;local x,y,w,h=b:GetBounds();assert(pointerTarget(x+w/2,y+h/2)==WorldMapFrame.BorderFrame)')
    def test_client_fullscreen_map_layer_keeps_controls_clickable(self):
        self.check('WorldMapFrame:SetFrameStrata("FULLSCREEN");V:OpenMapSearch();assert(V.mapPanel:GetFrameStrata()=="FULLSCREEN_DIALOG");pointerClick(V.mapPanel.search);pointerClick(V.mapPanel.faction)')
    def test_standalone_pointer_keyboard_and_buttons(self):
        self.check('V.window:Show();pointerClick(V.window.search);V.window.search:Type("159");V.window.search.scripts.OnEnterPressed(V.window.search);assert(V.query=="159");pointerClick(V.window.faction);assert(not V.db.friendlyOnly)')
    def test_refresh_does_not_reset_caret(self):
        self.check('V:OpenMapSearch();local m=V:GetMapSearch();m:SetQuery("Water");pointerClick(V.mapPanel.search);local b=V.mapPanel.search;b.cursor=2;local writes=b.textWrites;m:RefreshSearch();assert(b.cursor==2 and b.textWrites==writes);b:Type("X");assert(b:GetText()=="WaXter");V:RefreshUI();assert(b:GetText()=="WaXter" and b.cursor==3)')
    def test_map_anchors_unchanged_on_open_close_and_resize(self):
        self.check('local c=WorldMapFrame.ScrollContainer;local points={};for i=1,c:GetNumPoints()do points[i]={c:GetPoint(i)}end;V:OpenMapSearch();for _,width in ipairs({702,1600,1035})do WorldMapFrame:SetSize(width,534);WorldMapFrame.scripts.OnSizeChanged();assert(c:GetNumPoints()==#points);for i,p in ipairs(points)do local q={c:GetPoint(i)};for j=1,5 do assert(p[j]==q[j])end end;pointerClick(V.mapPanel.search)end;V.mapPanel:Hide();assert(not WorldMapFrame.resizeCalls)')
    def test_drag_position_persists_across_reopen_and_resize(self):
        self.check('V:OpenMapSearch();local p=V.mapPanel;local h=p.dragHandle;pointerClick(h);h.scripts.OnDragStart();assert(p.moving);p:ClearAllPoints();p:SetPoint("TOPLEFT",UIParent,"TOPLEFT",1400,-200);h.scripts.OnDragStop();assert(not p.moving and V.db.ui.mapPosition.x==1400 and V.db.ui.mapPosition.y==200);HideUIPanel(WorldMapFrame);ShowUIPanel(WorldMapFrame);WorldMapFrame:SetSize(1200,800);WorldMapFrame.scripts.OnSizeChanged();assert(p:GetLeft()==1400 and p:GetTop()==880);pointerClick(p.search);V:InitData(V.db);p:Hide();p:Show();assert(p:GetLeft()==1400)')
    def test_map_hide_clears_focus_and_close_does_not_close_map(self):
        self.check('V:OpenMapSearch();assert(V.mapPanel.search:HasFocus());pointerClick(V.mapPanel.close);assert(WorldMapFrame:IsShown() and not V.mapPanel:IsShown() and not V.mapPanel.search:HasFocus());pointerClick(V.mapButton);assert(V.mapPanel:IsShown());HideUIPanel(WorldMapFrame);assert(not V.mapPanel:IsShown());ShowUIPanel(WorldMapFrame);assert(V.mapPanel:IsShown())')
    def test_floating_position_fits_left_side_and_clamps_saved_position(self):
        self.check('WorldMapFrame:ClearAllPoints();WorldMapFrame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",800,-100);V:OpenMapSearch();assert(V.mapPanel:GetRight()<WorldMapFrame:GetLeft());V.db.ui.mapPosition={x=9999,y=-500};V:PositionMapSearch();assert(V.mapPanel:GetRight()<=UIParent:GetWidth() and V.mapPanel:GetTop()<=UIParent:GetHeight());pointerClick(V.mapPanel.search)')
    def test_floating_position_accounts_for_map_scale(self):
        self.check('WorldMapFrame:SetScale(.8);V:OpenMapSearch();assert(V.mapPanel:GetLeft()>WorldMapFrame:GetRight()*.8);assert(V.mapPanel:GetScale()==1);pointerClick(V.mapPanel.search)')
    def test_native_map_open_always_shows_working_search(self):
        self.check('V:SetQuery("159");ShowUIPanel(WorldMapFrame);assert(V.mapPanel:IsShown());assert(V.mapPanel.search:GetText()=="159");pointerClick(V.mapPanel.clearQuery);V.mapPanel.search:Type("2320");V.mapPanel.search.scripts.OnEnterPressed(V.mapPanel.search);assert(V:GetMapSearch().query=="2320" and V.query=="2320")')
    def test_minimap_search_show_on_map_without_explicit_selection(self):
        self.check('V.minimap.scripts.OnClick(V.minimap,"LeftButton");pointerClick(V.window.search);V.window.search:Type("159");V.window.search.scripts.OnEnterPressed(V.window.search);assert(V.selected==V.results[1] and V.window.detail.map.enabled);local target=V.selected;pointerClick(V.window.detail.map);assert(WorldMapFrame:IsShown() and V.mapPanel:IsShown());assert(V:GetMapSearch().selected.id==target.id);assert(WorldMapFrame.pins[1].selected)')
    def test_show_on_map_keeps_shared_selection(self):
        self.check('V:SetQuery("159");local chosen=V.results[2];V:Select(chosen);V:ShowOnMap();local m=V:GetMapSearch();assert(m.query=="159" and m.selected.id==chosen.id);m:RefreshSearch();assert(m.selected.id==chosen.id)')
    def test_clear_pin_clears_both_and_stays_cleared(self):
        self.check('V:SetQuery("159");V:ShowOnMap();pointerClick(V.mapPanel.clear);local m=V:GetMapSearch();assert(not m.selected and not V.selected and #WorldMapFrame.pins==0);V:RefreshSearch();assert(not m.selected and not V.mapPanel.clear.enabled and #WorldMapFrame.pins==0);assert(V.mapPanel.target:GetText()=="No vendor selected")')
    def test_pagination_local_but_selection_shared(self):
        self.check('V:SetQuery("159");V.page=3;local chosen=V.results[2];V:Select(chosen);V:OpenMapSearch();local m=V:GetMapSearch();pointerClick(V.mapPanel.next);assert(m.mapPage==2 and V.page==3,"page isolation");local row=V.mapPanel.rows[1];local clickedID=row.result.id;pointerClick(row);assert(V.selected.id==clickedID and m.selected.id==clickedID,"shared selection")')
    def test_clearing_map_query_clears_both_and_pins(self):
        self.check('V:SetQuery("159");V:OpenMapSearch();pointerClick(V.mapPanel.clearQuery);assert(V:GetMapSearch().query=="" and V.query=="");assert(V.window.search:GetText()=="" and V.mapPanel.search:GetText()=="");assert(#WorldMapFrame.pins==0 and not V.selected)')
    def test_clear_cancels_pending_edits_in_both_fields(self):
        self.check('local m=V:GetMapSearch();V.pendingText="159";V.pendingAt=0;m.pendingText="2320";m.pendingAt=0;V:SetQuery("");for _,f in ipairs(frames)do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,1)end end;assert(V.query=="" and m.query=="" and not V.selected)')
    def test_clear_from_minimap_window_clears_map(self):
        self.check('V:SetQuery("159");V:ShowOnMap();V:Toggle();assert(not WorldMapFrame:IsShown());pointerClick(V.window.detail.clear);assert(not V.selected and not V:GetMapSearch().selected);ShowUIPanel(WorldMapFrame);assert(#WorldMapFrame.pins==0)')

if __name__=='__main__': unittest.main()
