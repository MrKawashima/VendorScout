import unittest
from test_addon import runtime

class ItemTooltipTests(unittest.TestCase):
    def setUp(self):
        self.rt=runtime(full=True)
        self.rt.execute('''tooltip={lines={}}
          GameTooltip.SetOwner=function(_,owner)tooltip.owner=owner end
          GameTooltip.SetText=function(_,text)tooltip.title=text;tooltip.lines={};tooltip.link=nil end
          GameTooltip.AddLine=function(_,text)table.insert(tooltip.lines,text)end
          GameTooltip.SetHyperlink=function(_,link)tooltip.link=link;tooltip.lines={} end
          GameTooltip.Show=function()tooltip.visible=true end
          GameTooltip.Hide=function()tooltip.visible=false end
          V:SetQuery("159");V.window:Show()''')
    def check(self,code):self.rt.execute(code)
    def test_item_hover_in_standalone_and_map_and_clear(self):
        self.check('''local b=V.window.detail.offers[1];b.scripts.OnEnter(b);assert(tooltip.link=="item:159" and tooltip.owner==b)
          V:OpenMapSearch();pointerClick(V.mapPanel.items);local row=V.mapItems.offers[1]
          pointerClick(row);row.scripts.OnEnter(row);assert(tooltip.link=="item:159" and tooltip.owner==row)
          assert(#tooltip.lines>=3);V:RefreshSearch();assert(tooltip.visible)
          V:ClearSelection();assert(not V.mapItems:IsShown() and not tooltip.visible and not V.hoveredItem)''')
    def test_uncached_item_uses_snapshot_then_updates_after_loading(self):
        self.check('''C_Item.GetItemInfo=function()return nil end;local requested=0
          C_Item.RequestLoadItemDataByID=function(id)assert(id==159);requested=requested+1 end
          local b=V.window.detail.offers[1];b.scripts.OnEnter(b)
          assert(tooltip.title=="Refreshing Spring Water" and tooltip.visible and requested==1)
          V:RefreshSearch();assert(requested==1 and tooltip.visible)
          C_Item.GetItemInfo=function()return "Refreshing Spring Water","item:159" end
          fire("GET_ITEM_INFO_RECEIVED",159);assert(tooltip.link=="item:159")
          b.scripts.OnLeave(b);assert(not tooltip.visible and not V.hoveredItem)''')
    def test_missing_or_failed_tooltip_api_keeps_name_and_notes(self):
        self.check('''GameTooltip.SetHyperlink=function()error("not cached")end
          local b=V.window.detail.offers[1];b.scripts.OnEnter(b)
          assert(tooltip.title=="Refreshing Spring Water" and tooltip.visible)
          C_Item=nil;b.scripts.OnEnter(b);assert(tooltip.visible);V.window:Hide();assert(not tooltip.visible)''')
    def test_map_item_paging_refreshes_hover_and_closes_with_map(self):
        self.check('''V:SetQuery("Innkeeper Farley");V:OpenMapSearch();pointerClick(V.mapPanel.items)
          local p=V.mapItems;assert(#V.selected.offers>5);local b=p.offers[1];local first=b.itemID;b.scripts.OnEnter(b)
          pointerClick(p.next);assert(p.page==2 and b.itemID~=first and tooltip.link=="item:"..b.itemID)
          HideUIPanel(WorldMapFrame);assert(not p:IsShown() and not tooltip.visible)''')
