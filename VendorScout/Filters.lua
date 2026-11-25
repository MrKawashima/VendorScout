local _, V = ...
-- Labels and bilingual vocabulary are independent of the client's item language.
V.Categories={
    {"all","All"},{"consumables","Consumables"},{"food","Food & drink"},
    {"potions","Potions & elixirs"},{"bandages","Bandages"},{"bags","Bags"},
    {"supplies","Materials & tools"},{"reagents","Spell reagents"},{"ammo","Ammunition"},
    {"recipes","Recipes"},{"gear","Gear"},{"weapons","Weapons"},{"armor","Armor"},
}
V.Professions={
    {"all","All professions"},{171,"Alchemy"},{164,"Blacksmithing"},
    {333,"Enchanting"},{202,"Engineering"},{165,"Leatherworking"},{197,"Tailoring"},
    {185,"Cooking"},{129,"First Aid"},{356,"Fishing"},{186,"Mining"},
    {182,"Herbalism"},{393,"Skinning"},
}
local professionWords={
    [171]="alchemy alkymi",[164]="blacksmithing smiing smed",[333]="enchanting fortrylling",
    [202]="engineering ingenior ingeniorfag",[165]="leatherworking laerarbeid skinnarbeid",
    [197]="tailoring skreddersom skredder",[185]="cooking matlaging kokk",
    [129]="first aid forstehjelp",[356]="fishing fiske",[186]="mining gruvedrift",
    [182]="herbalism urtesanking",[393]="skinning flaaing skinnflaaing",
}
local categoryWords={
    consumables="consumable consumables forbruk forbruksvarer",
    food="food drink mat drikke",potions="potion potions elixir elixirs flask flasks eliksir eliksirer",
    bandages="bandage bandages bandasje bandasjer",bags="bag bags veske vesker sekk sekker",
    supplies="materials material supplies tools materialer forsyninger verktoy",
    reagents="reagent reagents reagens reagenser",ammo="ammo ammunition ammunisjon",
    recipes="recipe recipes pattern patterns plans schematic schematics formula formulas oppskrift oppskrifter",
    gear="gear equipment utstyr",weapons="weapon weapons vaapen",armor="armor armour rustning",
}
-- Whole-word expansion prevents e.g. 'mat' from matching 'formula'.
local synonyms={
    {"bag","bags","veske","vesker","sekk","sekker"},
    {"water","vann"},{"bread","brod"},{"meat","kjott"},{"fish","fisk"},
    {"cheese","ost"},{"fruit","frukt"},{"milk","melk"},{"beer","ol"},{"wine","vin"},
    {"healing","heal","helse","helbredelse"},{"thread","traad"},{"dye","farge","fargestoff"},
    {"vial","glass","hetteglass"},{"cloth","toy","stoff"},{"leather","laer","skinn"},
    {"herb","herbs","urt","urter"},{"ore","malm"},{"bar","bars","barre","barrer"},
    {"arrow","arrows","pil","piler"},{"bullet","bullets","shot","kule","kuler"},
    {"sword","sverd"},{"axe","okse"},{"dagger","dolk"},{"bow","bue"},
    {"shield","skjold"},{"hammer","hamrer"},{"rod","stav"},{"pole","fiskestang"},
    {"bait","agn"},{"spice","spices","krydder"},{"flour","mel"},{"salt"},
    {"coarse","grov"},{"fine","fin"},{"simple","enkel"},{"empty","tom"},
    {"heavy","tung"},{"light","lett"},{"strong","sterk"},
}
V.searchVocabulary={}
for _,words in pairs(categoryWords) do for word in words:gmatch("%S+") do V.searchVocabulary[word]=true end end
for _,words in pairs(professionWords) do for word in words:gmatch("%S+") do V.searchVocabulary[word]=true end end
for _,group in ipairs(synonyms) do for _,word in ipairs(group) do V.searchVocabulary[word]=true end end
function V:FoldWords(text)
    text=tostring(text or "")
    for a,b in pairs({["Æ"]="ae",["æ"]="ae",["Ø"]="o",["ø"]="o",["Å"]="aa",["å"]="aa"}) do text=text:gsub(a,b) end
    return string.lower(text)
end
function V:ItemCategories(it)
    local c,s=it.class or 0,it.subClass or 0
    local name=self:Normalize(it.name)
    local bag=c==1 or c==11
    local potion=c==0 and (name:find("potion",1,true) or name:find("elixir",1,true) or name:find("flask",1,true))
    local bandage=c==0 and name:find("bandage",1,true)
    local food=c==0 and not potion and not bandage and (it.foodType and it.foodType>0)
    if c==0 and not potion and not bandage then
        for _,word in ipairs({"water","milk","juice","tea","coffee","wine","beer","ale","rum","bourbon","mead","cider","nectar","soda","grog"}) do
            if (" "..name:gsub("%p"," ").." "):find(" "..word.." ",1,true) then food=true end
        end
    end
    return {all=true,consumables=c==0,food=not not food,potions=not not potion,bandages=not not bandage,
        bags=bag,supplies=c==7 or it.craftMaterial==true or (c==2 and (s==14 or s==20)),reagents=c==5 or (c==15 and s==1),
        ammo=c==6,recipes=c==9,gear=c==2 or c==4,weapons=c==2,armor=c==4}
end
function V:ItemKeywords(it)
    local tags={}
    for category,on in pairs(self:ItemCategories(it)) do if on and categoryWords[category] then tags[#tags+1]=categoryWords[category] end end
    for _,skill in ipairs(it.professions or {}) do tags[#tags+1]=professionWords[skill] or "" end
    local words=" "..self:Normalize(it.name):gsub("%p"," ").." "
    for _,group in ipairs(synonyms) do
        for _,word in ipairs(group) do
            if words:find(" "..word.." ",1,true) then tags[#tags+1]=table.concat(group," ");break end
        end
    end
    return table.concat(tags," ")
end
function V:ProfessionMatches(it)
    if not self.profession or self.profession=="all" then return true end
    for _,skill in ipairs(it.professions or {}) do if skill==self.profession then return true end end
    return false
end
function V:FilterName(options,id)
    for _,entry in ipairs(options) do if entry[1]==id then return entry[2] end end
    return options[1][2]
end
function V:SetFilter(kind,id)
    local options=kind=="category" and self.Categories or kind=="profession" and self.Professions
    if not options then return end
    local valid=false;for _,entry in ipairs(options) do if entry[1]==id then valid=true end end
    if not valid then return end
    self[kind]=id;self.page=1;self.mapPage=1;self.offerPage=1
    if self.mapSearch then self.mapSearch.mapPage=1 end
    -- Keep the selected result consistent with the newly filtered nearest-first list.
    self.selected=nil;self.targetLocation=nil
    self.selectionMode=self.pinsSuppressed and "none" or "auto"
    self:RefreshSearch()
end
function V:ResetFilters()
    self.category="all";self.profession="all";self:SetFilter("category","all")
end
