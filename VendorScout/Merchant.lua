local _, V = ...
-- Adds positive sightings only. Missing entries in a filtered merchant window
-- never remove bundled inventory; last-seen stock is explicitly timestamped.
function V:ObserveMerchant()
    if not self.db or not C_MerchantFrame or not C_MerchantFrame.GetItemInfo then return end
    local guid=UnitGUID and UnitGUID("npc")
    if issecretvalue and issecretvalue(guid) then return end
    if type(guid)~="string" then return end
    local id=tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    if not id then return end
    local count=GetMerchantNumItems and GetMerchantNumItems()
    if not self:Number(count) or count<1 then return end
    local obs=self.db.observed[id]
    if not obs then
        local n=0; for _ in pairs(self.db.observed) do n=n+1 end
        if n>=2000 then return end
        local name=UnitName("npc"); if type(name)~="string" or (issecretvalue and issecretvalue(name)) then return end
        local faction=UnitFactionGroup("player")
        obs={name=name,offers={},reaction=faction=="Alliance" and "A" or "H"}
        self.db.observed[id]=obs
    end
    local loc=self:PlayerLocation()
    if loc then loc.observed=true; obs.location=loc end
    local vendor=self.vendors[id]
    if not vendor then
        vendor={name=obs.name,offers={},reaction=obs.reaction,locations=loc and {loc} or {}}
        self.vendors[id]=vendor
    elseif #vendor.locations==0 and loc then vendor.locations={loc} end
    local changed=false
    for index=1,math.min(count,500) do
        local iid=GetMerchantItemID and GetMerchantItemID(index)
        local ok,info=pcall(C_MerchantFrame.GetItemInfo,index)
        if self:Number(iid) and iid>0 and ok and info and type(info.name)=="string" and not (issecretvalue and issecretvalue(info.name)) then
            if not self.items[iid] then
                local item={name=info.name}
                if C_Item and C_Item.GetItemInfoInstant then
                    local _,_,_,_,_,class,subClass=C_Item.GetItemInfoInstant(iid)
                    if self:Number(class) then item.class=class end
                    if self:Number(subClass) then item.subClass=subClass end
                end
                self.items[iid]=item; self.db.items[iid]=item
            end
            local stock=self:Number(info.numAvailable) and info.numAvailable or nil
            obs.offers[iid]={stock=stock,time=time()}
            vendor.offers[iid]=vendor.offers[iid] or 0; changed=true
        end
    end
    if changed then self:Reindex(); self.searchDirty=true end
end
