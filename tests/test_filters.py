import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime
from test_addon import runtime, FIXTURE, ROOT

class KeywordTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.rt=runtime()
    def check(self,code):
        self.rt.execute('V.category="all";V.profession="all";V.db.friendlyOnly=false;'+code)
    def test_norwegian_and_english_keywords_same_item_and_order(self):
        self.check('''for _,pair in ipairs({{"water","VANN"},{"tailoring thread","skredder TRÅD"},{"bag","vesker"}})do
          V.query=pair[1];local a=V:Search();V.query=pair[2];local b=V:Search();assert(#a>0 and #a==#b)
          for i,r in ipairs(a)do assert(r.id==b[i].id and #r.offers==#b[i].offers) end
        end''')
    def test_keywords_use_whole_words_and_conjunction(self):
        self.check('''V.query="mat";local r=V:Search();assert(#r>0)
          for _,v in ipairs(r)do for _,id in ipairs(v.offers)do assert(V.categoryIndex[id].food) end end
          V.query="skredder tråd";r=V:Search();assert(#r>0)
          for _,v in ipairs(r)do for _,id in ipairs(v.offers)do assert(V.items[id].name:find("Thread")) end end''')
    def test_categories_do_not_confuse_recipes_food_potions_or_bags(self):
        self.check('''assert(V.categoryIndex[159].food and not V.categoryIndex[159].potions)
          assert(V.categoryIndex[858].potions and not V.categoryIndex[858].food)
          assert(V.categoryIndex[4496].bags and not V.categoryIndex[4496].gear)
          V.category="potions";V.query="";local r=V:Search();assert(#r>0)
          for _,v in ipairs(r)do for _,id in ipairs(v.offers)do assert((V.items[id].class or 0)==0) end end''')
    def test_forever_first_aid_recipe_is_not_assigned_to_alchemy(self):
        self.check('''local found=false
          for _,it in pairs(V.items)do if it.name=="Manual: Major Healing Potion" then
            found=true;V.profession=129;assert(V:ProfessionMatches(it));V.profession=171;assert(not V:ProfessionMatches(it))
          end end;assert(found)''')
    def test_profession_recipe_and_material_intersection(self):
        self.check('''V.profession=197;V.category="supplies";V.query="tråd";local r=V:Search();assert(#r>0)
          V.category="recipes";V.query="oppskrift";r=V:Search();assert(#r>0)
          for _,v in ipairs(r)do for _,id in ipairs(v.offers)do assert(V.items[id].class==9 and V:ProfessionMatches(V.items[id])) end end
          V.query="159";assert(#V:Search()==0);V.query="|cff00ff00|Hitem:2320:0|h[Coarse Thread]|h|r";V.category="supplies";assert(#V:Search()>0)''')
    def test_unknown_profession_is_not_guessed(self):
        self.check('V.profession=197;assert(not V:ProfessionMatches({name="Tailoring mystery"}));V.profession="all";assert(V:ProfessionMatches({}))')

class SharedFilterUITests(unittest.TestCase):
    def setUp(self):self.rt=runtime(full=True)
    def check(self,code):self.rt.execute(code)
    def test_both_menus_are_clickable_and_sync_values_and_captions(self):
        self.check('''V.window:Show();pointerClick(V.window.category);pointerClick(V.window.category.menu.options[7])
          assert(V.category=="supplies");V:OpenMapSearch();assert(V.mapPanel.category.caption:GetText():find("Materials"))
          pointerClick(V.mapPanel.profession);pointerClick(V.mapPanel.profession.menu.options[7])
          assert(V.profession==197 and V:GetMapSearch().profession==197 and V.window.profession.caption:GetText():find("Tailoring"))
          V:SetQuery("tråd");assert(#V.results>0 and #V:GetMapSearch().results>0)
          V.db.language="no";V:RefreshUI();assert(V.mapPanel.profession.caption:GetText():find("Skreddersøm"))''')
    def test_clear_pin_query_and_reset_filters_from_both_surfaces(self):
        self.check('''V:OpenMapSearch();V:SetFilter("profession",197);V:SetQuery("tråd");assert(V.selected)
          pointerClick(V.mapPanel.clear);assert(not V.selected and #WorldMapFrame.pins==0)
          pointerClick(V.mapPanel.resetFilters);assert(V.profession=="all" and V.category=="all" and V.pinsSuppressed)
          V:SetQuery("vann");V:SetFilter("category","food");pointerClick(V.mapPanel.clearQuery)
          assert(V.query=="" and V.window.search:GetText()=="" and #WorldMapFrame.pins==0)
          V.mapPanel.open:Click();pointerClick(V.window.resetFilters);assert(V.category=="all" and V:GetMapSearch().category=="all")
          V:SetQuery("vann");pointerClick(V.window.clear);assert(V.mapPanel.search:GetText()=="" and not V.selected)''')
    def test_filters_keep_nearest_first_and_reset_pagination(self):
        self.check(FIXTURE+'''V.Data.items[1].professions={197};V:InitData({});V.window:Show();V:SetQuery("vann");
          V.page=8;V:GetMapSearch().mapPage=8;V:SetFilter("profession",197);assert(V.page==1 and V:GetMapSearch().mapPage==1)
          assert(V.results[1].id==11 and V.selected.id==11);playerX=.61;V:RefreshSearch();assert(V.results[1].id==12 and V.selected.id==12)
          for _,r in ipairs(V.results)do assert(r.offers[1]==1)end''')
    def test_menu_closes_with_parent_and_only_one_menu_opens(self):
        self.check('''V:OpenMapSearch();pointerClick(V.mapPanel.category);local menu=V.mapPanel.category.menu
          pointerClick(V.mapPanel.category);pointerClick(V.mapPanel.profession);assert(not menu:IsShown() and V.mapPanel.profession.menu:IsShown())
          HideUIPanel(WorldMapFrame);assert(not V.mapPanel.profession.menu:IsShown())''')
    def test_filters_alone_do_not_enable_pins_at_login(self):
        self.check('V:OpenMapSearch();V:SetFilter("category","recipes");V:SetFilter("profession",197);assert(V.pinsSuppressed and not V.selected and #WorldMapFrame.pins==0)')

SOURCE=ROOT.parent/'NorgannonDB'
if not SOURCE.exists():SOURCE=ROOT/'source-data/NorgannonDB'
@unittest.skipUnless((SOURCE/'data/recipes.lua').exists(),'Pinned recipe source not present')
class ProfessionSourceAudit(unittest.TestCase):
    def test_all_sold_recipe_items_and_reagents_keep_profession_links(self):
        rt=LuaRuntime();rt.execute('GetLocale=function()return "enUS"end')
        for f in ['core/api.lua','data/world.lua']:rt.execute((SOURCE/f).read_text('utf-8'))
        rt.execute('NorgannonDB.index={};'+(SOURCE/'data/recipes.lua').read_text('utf-8'))
        built=runtime();items=built.globals().V['items']
        count=0
        for recipe in rt.globals().NorgannonDB.recipes.values():
            ids=list(recipe['items'].values()) if recipe['items'] else []
            ids += [r[1] for r in recipe.reagents.values()] if recipe.reagents else []
            for iid in ids:
                if items[iid]:
                    self.assertIn(recipe.skill,list(items[iid].professions.values()),(iid,recipe.name));count+=1
        self.assertGreater(count,1000)
