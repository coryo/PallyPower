PallyPower = {};
PP_Assignments = {};
PP_PerUser = {
    scalemain = 1,	-- corner of main window docked to
    scalebar = 1,	-- corner menu window is docked from
    scanfreq = 1,
    scanperframe = 1,
    smartbuffs = false,
}
backdrop = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true,
    tileSize = 16
}
backdropWithEdge = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12
}

local UnitAura = _G.UnitAura

local LCD = LibStub("LibClassicDurations", true)
if LCD then
    LCD:Register("PallyPower") -- tell library it's being used and should start working
    UnitAura = LCD.UnitAuraWrapper
end

PP_PREFIX = "PLPWR";
C_ChatInfo.RegisterAddonMessagePrefix(PP_PREFIX)

local initalized = false
local AllPallys = {};
local PP_Symbols = 0
local PP_ScanInfo = nil
local PP_NextScan = PP_PerUser.scanfreq
local CurrentBuffs = {};

local spellInfo = {
    [0] = {
        ["spellId"] = {19742, 19850, 19852, 19853, 19854, 25290, 27142},
        ["icon"] = 135912,   -- Greater Blessing of Wisdom
    },
    [1] = {
        ["spellId"] = {19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140},
        ["icon"] = 135908,   -- Greater Blessing of Might
    },
    [2] = {
        ["spellId"] = {1038},
        ["icon"] = 135910,   -- Greater Blessing of Salvation
    },
    [3] = {
        ["spellId"] = {19977, 19978, 19979, 27144},
        ["icon"] = 135909,   -- Greater Blessing of Light
    },
    [4] = {
        ["spellId"] = {20217},
        ["icon"] = 135993,   -- Greater Blessing of Kings
    },
    [5] = {
        ["spellId"] = {20911, 20912, 20913, 20914, 27168},
        ["icon"] = 135911,   -- Greater Blessing of Sanctuary
    },
    [6] = {
        ["spellId"] = {25894, 25918, 27143},
        ["icon"] = 135970,   -- Blessing of Wisdom
    },
    [7] = {
        ["spellId"] = {25782, 25916, 27141},
        ["icon"] = 135906,   -- Blessing of Might
    },
    [8] = {
        ["spellId"] = {25895},
        ["icon"] = 135967,   -- Blessing of Salvation
    },
    [9] = {
        ["spellId"] = {25890, 27145},
        ["icon"] = 135943,   -- Blessing of Light
    },
    [10] = {
        ["spellId"] = {25898},
        ["icon"] = 135995,   -- Blessing of Kings
    },
    [11] = {
        ["spellId"] = {25899, 27169},
        ["icon"] = 136051,   -- Blessing of Sanctuary
    }
}

local PallyPower_classIDEnglishClass = {
    [0] = "WARRIOR",
    [1] = "ROGUE",
    [2] = "PRIEST",
    [3] = "DRUID",
    [4] = "PALADIN",
    [5] = "HUNTER",
    [6] = "MAGE",
    [7] = "WARLOCK",
    [8] = "SHAMAN",
    [9] = "PET",
}


local function PP_Debug(string)
    if not string then string = "(nil)" end
    if (PP_DebugEnabled) then
        DEFAULT_CHAT_FRAME:AddMessage("[PP] "..string,1,0,0);
    end
end


function PallyPower_OnLoad(self)
    self:RegisterEvent("SPELLS_CHANGED");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    self:RegisterEvent("CHAT_MSG_ADDON");
    -- self:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH");
    self:RegisterEvent("PLAYER_LOGIN");
    self:RegisterEvent("GROUP_ROSTER_UPDATE");
    self:RegisterEvent("PLAYER_REGEN_ENABLED");
    if (BackdropTemplateMixin) then
        Mixin(self, BackdropTemplateMixin)
    end
    self:SetBackdrop(backdropWithEdge)
    self:SetBackdropColor(0.0, 0.0, 0.0, 0.5);
    self:SetScale(1);
    SlashCmdList["PALLYPOWER"] = function(msg)
        PallyPower_SlashCommandHandler(msg)
    end
end


function PallyPower_OnUpdate(self, elapsed)
    --  PP_Debug("OnUpdate "..tdiff);
    if (not PP_PerUser.scanfreq) then
        PP_PerUser.scanfreq = 1;
        PP_PerUser.scanperframe = 1;
    end
    PP_NextScan = PP_NextScan - elapsed
    if PP_NextScan < 0 and PP_IsPally() then
        PP_Debug("Scanning");
        PallyPower_ScanRaid()
        PallyPower_UpdateUI()
    end
end


function PallyPower_OnEvent(self, event, ...)
    local args = {...}
    local type, id;

    if event=="SPELLS_CHANGED" or event=="PLAYER_ENTERING_WORLD" then
        PallyPower_ScanSpells()
    end

    if event=="PLAYER_ENTERING_WORLD" and (not PP_Assignments[UnitName("player")]) then
        PP_Assignments[UnitName("player")] = {};
        if UnitName("player") == "Aznamir" then PP_DebugEnabled = true end
    end

    if event=="CHAT_MSG_ADDON" and args[1]==PP_PREFIX and (args[3]=="PARTY" or args[3]=="RAID") then
        -- sender is "PlayerName-Realm"
        local r = {}
        for word in args[4]:gmatch("[^-]+") do
            table.insert(r, word)
        end

        PallyPower_ParseMessage(r[1], args[2])
    end

    if event=="CHAT_MSG_COMBAT_FRIENDLY_DEATH" and PP_NextScan > 1 then
        PP_NextScan = 1
    end

    if event == "PLAYER_LOGIN" then PallyPower_UpdateUI() end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
        PallyPower_ScanRaid()
        PallyPower_UpdateUI()
    end

end


function PallyPower_SlashCommandHandler(msg)
    if (msg == "debug") then
        if PP_DebugEnabled then
            PP_DebugEnabled = nil
        else
            PP_DebugEnabled = true
        end
    end

    if (msg == "report") then
        PallyPower_Report()
        return true
    end

    if PallyPowerFrame:IsVisible() then
        PallyPowerFrame:Hide()
    else
        PallyPowerFrame:Show()
    end

    PallyPower_UpdateUI()
end


function PallyPower_Report()
    if not PallyPower_CanControl(UnitName("player")) then return end

    local type;

    if IsInRaid() then
        type = "RAID"
    else
        type = "PARTY"
    end
    PP_Debug(type);
    SendChatMessage(PP_Assignments1, type)
    for name, t in pairs(AllPallys) do
        local blessings
        local list = { }
        list[0]=0;
        list[1]=0;
        list[2]=0;
        list[3]=0;
        list[4]=0;
        list[5]=0;
        PP_Debug(list[0]);
        for id = 0, 9 do
            local bid = PP_Assignments[name][id]
            if bid >= 0 then
                list[bid] = list[bid] + 1
            end
        end
        for id = 0, 5 do
            if (list[id] > 0) then
                if (blessings) then
                    blessings = blessings .. ", "
                else
                    blessings = ""
                end
                blessings = blessings .. PallyPower_BlessingID[id]
            end
        end
        if not (blessings) then
            blessings = "Nothing"
        end
        SendChatMessage(name ..": ".. blessings, type)
        PP_Debug(name ..": ".. blessings)
    end
    SendChatMessage(PP_Assignments2, type)
end


local function formatTime(time)
    if not time or time < 0 then
        return "";
    end
    mins = floor(time / 60)
    secs = time - (mins * 60)
    return string.format("%d:%02d", mins, secs);
end


function PallyPowerGrid_Update()
    if not initalized then PallyPower_ScanSpells() end
    -- Pally 1 is always myself
    local i = 1;
    local numPallys = 0
    local name,skills
    if PallyPowerFrame:IsVisible() then
        PallyPowerFrame:SetScale(PP_PerUser.scalemain);
        for name,skills in pairs(AllPallys) do
            _G["PallyPowerFramePlayer"..i.."Name"]:SetText(name)
            _G["PallyPowerFramePlayer"..i.."Symbols"]:SetText(skills["symbols"])
            _G["PallyPowerFramePlayer"..i.."Symbols"]:SetTextColor(1,1,0.5)
            if (PallyPower_CanControl(name)) then
                _G["PallyPowerFramePlayer"..i.."Name"]:SetTextColor(1,1,1)
            else
                if (PallyPower_CheckRaidLeader(name)) then
                    _G["PallyPowerFramePlayer"..i.."Name"]:SetTextColor(0,1,0)
                else
                    _G["PallyPowerFramePlayer"..i.."Name"]:SetTextColor(1,0,0)
                end
            end
            for id = 0, 5 do
                if (skills[id]) then
                    _G["PallyPowerFramePlayer"..i.."Icon"..id]:Show()
                    _G["PallyPowerFramePlayer"..i.."Skill"..id]:Show()
                    local txt = skills[id]["rank"];
                    if (skills[id]["talent"]+0 > 0) then txt = txt.."+"..skills[id]["talent"] end
                    _G["PallyPowerFramePlayer"..i.."Skill"..id]:SetText(txt)
                else
                    _G["PallyPowerFramePlayer"..i.."Icon"..id]:Hide()
                    _G["PallyPowerFramePlayer"..i.."Skill"..id]:Hide()
                end
            end
            for id = 0, 9 do
                local info = spellInfo[PP_Assignments[name][id]]
                if (PP_Assignments[name] and info) then
                    _G["PallyPowerFramePlayer"..i.."Class"..id.."Icon"]:SetTexture(info["icon"])
                else
                    _G["PallyPowerFramePlayer"..i.."Class"..id.."Icon"]:SetTexture(nil)
                end
            end
            i = i + 1
            numPallys = numPallys + 1
        end
    PallyPowerFrame:SetHeight(14 + 24 + 56 + (numPallys*56) + 22 ) -- 14 from border, 24 from Title, 56 from space for class icons, 56 per paladin, 22 for Buttons at bottom
    for i = 1, 12 do
        if i <= numPallys then
            _G["PallyPowerFramePlayer"..i]:Show()
        else
            _G["PallyPowerFramePlayer"..i]:Hide()
        end
    end
    end
end


function PallyPower_UpdateUI()
    if not initalized then PallyPower_ScanSpells() end

    local inLockdown = InCombatLockdown()

    if not PP_IsPally() then
        if not inLockdown then
            PallyPowerBuffBar:Hide()
        end
        return
    end

    if not inLockdown then
        PallyPowerBuffBar:SetScale(PP_PerUser.scalebar);
        PallyPowerBuffBar:Show()
    end

    PallyPowerBuffBarTitleText:SetText(format(PallyPower_BuffBarTitle, PP_Symbols));
    local BuffNum = 1
    local assign = PP_Assignments[UnitName("player")]
    if assign then
        for class = 0, 9 do
            if (assign[class] and assign[class] ~= -1) then

                local classIconFrame = _G["PallyPowerBuffBarBuff"..BuffNum.."ClassIcon"]
                if class < 9 then
                    classIconFrame:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES");
                    classIconFrame:SetTexCoord(unpack(CLASS_ICON_TCOORDS[PallyPower_classIDEnglishClass[class]]))
                else
                    classIconFrame:SetTexture(132267); -- aspect of the pack icon for pets
                    classIconFrame:SetTexCoord(0, 1, 0, 1)
                end

                _G["PallyPowerBuffBarBuff"..BuffNum.."BuffIcon"]:SetTexture(spellInfo[assign[class]]["icon"]);
                local btn = _G["PallyPowerBuffBarBuff"..BuffNum];
                btn.classID = class;
                btn.buffID = assign[class];
                btn.need = {};
                btn.have = {};
                btn.range = {};
                btn.dead = {};

                if not inLockdown then
                    btn:SetAttribute("spell-buff1", nil)
                    btn:SetAttribute("spell-buff2", nil)
                    btn:SetAttribute("unit", nil)
                end

                -- Calculate number of people who need buff.
                local nneed = 0;
                local nhave = 0;
                local ndead = 0;
                local next_expiration = -1;
                if CurrentBuffs[class] then
                    for member, stats in pairs(CurrentBuffs[class]) do
                        local exp = stats["expiration"][btn.buffID]

                        if exp and stats[assign[class]] and exp > 0 then
                            if next_expiration < 0 then
                                next_expiration = exp
                            elseif exp < next_expiration then
                                next_expiration = exp
                            end
                        end

                        local currentUnit = btn:GetAttribute("unit")

                        if stats["visible"] then
                            if not stats[assign[class]] then
                                if UnitIsDeadOrGhost(member) then
                                    ndead = ndead + 1;
                                    tinsert(btn.dead, stats["name"]);
                                else
                                    if not inLockdown then
                                        btn:SetAttribute("unit", stats["unitid"])
                                    end
                                    nneed = nneed + 1
                                    tinsert(btn.need, stats["name"]);
                                end
                            else
                                if not inLockdown and currentUnit == nil then
                                    btn:SetAttribute("unit", stats["unitid"])
                                end
                                tinsert(btn.have, stats["name"]);
                                nhave = nhave + 1
                            end
                        else
                            tinsert(btn.range, stats["name"]);
                            nhave = nhave + 1
                        end
                    end
                end
                if ndead > 0 then
                    _G["PallyPowerBuffBarBuff"..BuffNum.."Text"]:SetText(nneed.." ("..ndead..")");
                else
                    _G["PallyPowerBuffBarBuff"..BuffNum.."Text"]:SetText(nneed);
                end

                _G["PallyPowerBuffBarBuff"..BuffNum.."Time"]:SetText(formatTime(next_expiration - GetTime()))

                if not (nneed > 0 or nhave > 0) then
                else
                    BuffNum = BuffNum + 1
                    if (nhave == 0) then
                        if (BackdropTemplateMixin) then
                            Mixin(btn, BackdropTemplateMixin)
                        end
                        btn:SetBackdrop(backdrop)
                        btn:SetBackdropColor(1.0, 0.0, 0.0, 0.5);
                    elseif (nneed > 0) then
                        if (BackdropTemplateMixin) then
                            Mixin(btn, BackdropTemplateMixin)
                        end
                        btn:SetBackdrop(backdrop)
                        btn:SetBackdropColor(1.0, 1.0, 0.5, 0.5);
                    else
                        if (BackdropTemplateMixin) then
                            Mixin(btn, BackdropTemplateMixin)
                        end
                        btn:SetBackdrop(backdrop)
                        btn:SetBackdropColor(0.0, 0.0, 0.0, 0.5);
                    end
                    if not inLockdown then
                        btn:SetAttribute("type", "spell");
                        btn:SetAttribute("*helpbutton1", "buff1")
                        btn:SetAttribute("*helpbutton2", "buff2")
                        local buff1, rank, _, _, _, _, _ = GetSpellInfo(spellInfo[btn.buffID+6]["spellId"][1])
                        local buff2, rank, _, _, _, _, _ = GetSpellInfo(spellInfo[btn.buffID]["spellId"][1])
                        btn:SetAttribute("spell-buff1", buff1)
                        btn:SetAttribute("spell-buff2", buff2)
                        btn:Show();
                    end
                end
            end
        end
    end

    if not inLockdown then
        for rest = BuffNum, 10 do
            local btn = _G["PallyPowerBuffBarBuff"..rest];
            btn:SetAttribute("spell-buff1", nil)
            btn:SetAttribute("spell-buff2", nil)
            btn:SetAttribute("unit", nil)
            btn:Hide();
        end
        PallyPowerBuffBar:SetHeight(30 + (34 * (BuffNum-1)));
    end
end


function PallyPower_ScanSpells()
    local RankInfo = {}

    for id, name in pairs(PallyPower_BlessingID) do
        for rank, spellid in pairs(spellInfo[id]["spellId"]) do
            local isKnown = IsPlayerSpell(spellid)
            if isKnown then
                if not RankInfo[id] then
                    RankInfo[id] = {}
                end
                RankInfo[id]["rank"] = rank;
                RankInfo[id]["name"] = name;
                RankInfo[id]["talent"] = 0;
            end
        end
    end

    local numTabs = GetNumTalentTabs();
    for t=1, numTabs do
        local numTalents = GetNumTalents(t);
        for i=1, numTalents do
            nameTalent, icon, iconx, icony, currRank, maxRank= GetTalentInfo(t,i);
            local _,_,bless = string.find(nameTalent, PallyPower_BlessingTalentSearch)
            if bless then
                initalized=true;
                for id,name in pairs(PallyPower_BlessingID) do
                    if name==bless then
                        if (RankInfo[id]) then
                            RankInfo[id]["talent"] = currRank;
                        end
                    end
                end
            end
        end
    end
    _,class=UnitClass("player");
    if class=="PALADIN" then
        AllPallys[UnitName("player")] = RankInfo;
        if initalized then PallyPower_SendSelf(); end
    else
        PP_Debug("I'm not a paladin?? "..class);
        initalized=true;
    end
    PallyPower_ScanInventory()
end


function PP_IsPally()
    local _,classFilename = UnitClass("player")
    return classFilename == "PALADIN"
end


function PallyPower_Refresh(self)
    AllPallys = {}
    PallyPower_ScanSpells()
    PallyPower_SendSelf()
    PallyPower_RequestSend()
    PallyPower_UpdateUI()
end


function PallyPower_Clear(self, fromupdate, who)
    if not who then who=UnitName("player") end
    for name, skills in pairs(PP_Assignments) do
        if (PallyPower_CheckRaidLeader(who) or name==who) then
            for class, id in pairs(PP_Assignments[name]) do
                PP_Assignments[name][class]=-1
            end
        end
    end
    PallyPower_UpdateUI()
    if not fromupdate then PallyPower_SendMessage("CLEAR") end
end


function PallyPower_RequestSend()
    PallyPower_SendMessage("REQ")
end


function PallyPower_SendSelf()
    if not initalized then PallyPower_ScanSpells() end
    if not AllPallys[UnitName("player")] then return end
    msg = "SELF "
    local RankInfo = AllPallys[UnitName("player")]
    local i
    for id=0, 5 do
        if (not RankInfo[id]) then
            msg=msg.."nn";
        else
            msg = msg .. RankInfo[id]["rank"]
            msg = msg .. RankInfo[id]["talent"]
        end
    end
    msg = msg .. "@"
    for id=0,9 do
        if (not PP_Assignments[UnitName("player")]) or (not PP_Assignments[UnitName("player")][id]) or PP_Assignments[UnitName("player")][id] == -1 then
            msg = msg .. "n"
        else
            msg = msg .. PP_Assignments[UnitName("player")][id]
        end
    end
    PallyPower_SendMessage(msg)
    PallyPower_SendMessage("SYMCOUNT "..PP_Symbols);
end


function PallyPower_SendMessage(msg)
    success = C_ChatInfo.SendAddonMessage(PP_PREFIX, msg, "RAID");
end


function PallyPower_ParseMessage(sender, msg)
    if not (sender == UnitName("player")) then
        if msg == "REQ" then
            PallyPower_SendSelf()
        end
        if string.find(msg, "^SELF") then
            PP_Assignments[sender] = {}
            AllPallys[sender] = {}
            _, _, numbers, assign = string.find(msg, "SELF ([0-9n]*)@?([0-9n]*)")
            for id = 0,5 do
                rank = string.sub(numbers, id*2 + 1, id*2 + 1)
                talent = string.sub(numbers, id*2 + 2, id * 2 + 2)
                if not (rank == "n") then
                    AllPallys[sender][id] = { }
                    AllPallys[sender][id]["rank"] = rank
                    AllPallys[sender][id]["talent"] = talent
                end
            end
            if assign then
                for id = 0, 9 do
                    tmp = string.sub(assign, id+1, id+1)
                    if (tmp == "n" or tmp == "") then tmp = -1 end
                    PP_Assignments[sender][id] = tmp + 0
                end
            end
            PallyPower_UpdateUI()
        end
        if string.find(msg, "^ASSIGN") then
            _, _, name, class, skill = string.find(msg, "^ASSIGN (.*) (.*) (.*)")
            if (not(name==sender)) and (not PallyPower_CheckRaidLeader(sender)) then return false end
            if (not PP_Assignments[name]) then PP_Assignments[name] = {} end
            class=class+0
            skill=skill+0
            PP_Assignments[name][class] = skill;
            PallyPower_UpdateUI()
        end
        if string.find(msg, "^MASSIGN") then
            _, _, name, skill = string.find(msg, "^MASSIGN (.*) (.*)")
            if (not(name==sender)) and (not PallyPower_CheckRaidLeader(sender)) then return false end
            if (not PP_Assignments[name]) then PP_Assignments[name] = {} end
            skill=skill+0
            for class=0, 9 do
                PP_Assignments[name][class] = skill;
            end
            PallyPower_UpdateUI()
        end
        if string.find(msg, "^SYMCOUNT ([0-9]*)") then
            _, _, count = string.find(msg, "^SYMCOUNT ([0-9]*)")
            if AllPallys[sender] then
                AllPallys[sender]["symbols"] = count;
            else
                PallyPower_SendMessage("REQ");
            end
        end
        if string.find(msg, "^CLEAR") then
            PallyPower_Clear(nil, true, sender)
        end
    end
end


function PallyPower_ShowCredits(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(PallyPower_Credits1,1,1,1);
    GameTooltip:AddLine(PallyPower_Credits2,1,1,1);
    GameTooltip:AddLine(PallyPower_Credits3);
    GameTooltip:AddLine(PallyPower_Credits4,0,1,0);
    GameTooltip:AddLine(PallyPower_Credits5);
    GameTooltip:AddLine(PallyPower_Credits6);
    GameTooltip:AddLine(PallyPower_Credits7);
    GameTooltip:Show()
end


function PallyPowerFrame_MouseDown(self, button)
    if ( ( ( not PallyPowerFrame.isLocked ) or ( PallyPowerFrame.isLocked == 0 ) ) and ( button == "LeftButton" ) ) then
        PallyPowerFrame:StartMoving(); PallyPowerFrame.isMoving = true;
    end
end


function PallyPowerFrame_MouseUp(self, button)
    if ( PallyPowerFrame.isMoving ) then
        PallyPowerFrame:StopMovingOrSizing();
        PallyPowerFrame.isMoving = false;
    end
end


function PallyPowerBuffBar_MouseDown(self, button)
    if ( ( ( not PallyPowerBuffBar.isLocked ) or ( PallyPowerBuffBar.isLocked == 0 ) ) and ( button == "LeftButton" ) ) then
        PallyPowerBuffBar:StartMoving();
        PallyPowerBuffBar.isMoving = true;
        PallyPowerBuffBar.startPosX = PallyPowerBuffBar:GetLeft();
        PallyPowerBuffBar.startPosY = PallyPowerBuffBar:GetTop();
    end
end


function PallyPowerBuffBar_MouseUp(self, button)
    if button ~= "LeftButton" then return end

    if ( PallyPowerBuffBar.isMoving ) then
        PallyPowerBuffBar:StopMovingOrSizing();
        PallyPowerBuffBar.isMoving = false;
    end
    if abs(PallyPowerBuffBar.startPosX - PallyPowerBuffBar:GetLeft()) < 2 and abs(PallyPowerBuffBar.startPosY - PallyPowerBuffBar:GetTop()) < 2 then
        PallyPowerFrame:Show();
        PallyPower_UpdateUI()
    end
end


function PallyPowerGridButton_OnLoad(self, btn)
    self:RegisterForClicks("LeftButtonUp","RightButtonUp");
    self:EnableMouseWheel(1)
end


function PallyPowerGridButton_OnClick(self, btn, mouseBtn)
    _,_,pnum,class = string.find(self:GetName(), "PallyPowerFramePlayer(.+)Class(.+)");
    pnum = pnum + 0;
    class = class + 0;
    pname = _G["PallyPowerFramePlayer"..pnum.."Name"]:GetText()
    if not PallyPower_CanControl(pname) then return false end

    if (mouseBtn=="RightButton") then
        PP_Assignments[pname][class]=-1
        PallyPower_UpdateUI()
        PallyPower_SendMessage("ASSIGN "..pname.." "..class.." -1")
    else
        PallyPower_PerformCycle(pname, class)
    end
end


function PallyPowerGridButton_OnLeave(btn)
end


function PallyPowerGridButton_OnEnter(btn)
end


function PallyPower_PerformCycleBackwards(name, class)
    shift=IsShiftKeyDown()

    --force pala (all buff possible) when shift wheeling
    if shift then
        class=4
    end

    if not PP_Assignments[name][class] then
        cur=6
    else
        cur=PP_Assignments[name][class]
        if cur==-1 then cur=6 end
    end

    PP_Assignments[name][class] = -1

    for test = cur-1,-1,-1 do
        cur = test
        if PallyPower_CanBuff(name, test) and (PallyPower_NeedsBuff(class, test) or shift) then
            break
        end
    end

    if shift then
        for test=0, 9 do
            PP_Assignments[name][test] = cur
        end
        PallyPower_SendMessage("MASSIGN "..name.." "..cur)
    else
        PP_Assignments[name][class] = cur
        PallyPower_SendMessage("ASSIGN "..name.." "..class.." "..cur)
    end

    PallyPower_UpdateUI()
end


function PallyPower_PerformCycle(name, class)

    shift=IsShiftKeyDown()

    --force pala (all buff possible) when shift wheeling
    if shift then
        class=4
    end

    if not PP_Assignments[name][class] then
        cur=-1
    else
        cur=PP_Assignments[name][class]
    end
    PP_Assignments[name][class] = -1
    for test = cur+1,6 do
        if PallyPower_CanBuff(name, test) and (PallyPower_NeedsBuff(class, test) or shift) then
            cur = test
            break
        end
    end

    if (cur==6) then cur=-1 end

    if shift then
        for test = 0, 9 do
            PP_Assignments[name][test] = cur
        end
        PallyPower_SendMessage("MASSIGN "..name.." "..cur)
    else
        PP_Assignments[name][class] = cur
        PallyPower_SendMessage("ASSIGN "..name.." "..class.." "..cur)
    end

    PallyPower_UpdateUI()
end


function PallyPower_CanBuff(name, test)
    if test==6 then
        return true
    end
    if (not AllPallys[name][test]) or (AllPallys[name][test]["rank"]==0) then
        return false
    end
    return true
end


function PallyPower_NeedsBuff(class, test)
    if test==6 then
        return true
    end
    if test==-1 then
        return true
    end
    if PP_PerUser.smartbuffs then
        -- no wisdom for warriors and rogues
        if (class == 0 or class==1) and test == 0 then
            return false
        end
        -- no salv for warriors
        if class == 0 and test == 2 then
            return false
        end
        -- no might for casters
        if (class == 2 or class == 6 or class == 7) and test == 1 then
            return false
        end
    end

    for name,skills in pairs(PP_Assignments) do
        if (AllPallys[name]) and ((skills[class]) and (skills[class]==test)) then
            return false
        end
    end
    return true
end


function PallyPower_CheckRaidLeader(nick)
    if GetNumGroupMembers() == 0 then
        for i= 1, GetNumGroupMembers(), 1 do
            if nick==UnitName("party"..i) and UnitIsGroupLeader("party"..i) then
                return true
            end
        end
        return false
    end
    for i = 1, GetNumGroupMembers(), 1 do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i)
        if ( rank >= 1 and name == nick ) then
            return true
        end
    end
    return false
end


function PallyPower_CanControl(name)
    return (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or (name==UnitName("player")))
end


function PallyPower_ScanInventory()
    if not PP_IsPally() then return end
    PP_Debug("Scanning for symbols");
    oldcount = PP_Symbols
    PP_Symbols = 0
    for bag = 0, 4 do
        local bagslots = GetContainerNumSlots(bag);
        if (bagslots) then
            for slot = 1, bagslots do
                local link = GetContainerItemLink(bag, slot)
                if (link and string.find(link, PallyPower_Symbol)) then
                    local _, count, locked = GetContainerItemInfo(bag, slot);
                    PP_Symbols = PP_Symbols + count
                end
            end
        end
    end
    if PP_Symbols ~= oldcount then
        PallyPower_SendMessage("SYMCOUNT "..PP_Symbols);
    end
    AllPallys[UnitName("player")]["symbols"] = PP_Symbols;
end


function PallyPower_ScanRaid()
    if not PP_IsPally() then return end
    if not (PP_ScanInfo) then
        PP_Scanners = {}
        PP_ScanInfo = {}
        if GetNumGroupMembers() > 0 and IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                tinsert(PP_Scanners, {"raid", i})
            end
        else
            tinsert(PP_Scanners, {"player", 0});
            for i = 1, GetNumGroupMembers() do
                tinsert(PP_Scanners, {"party", i})
            end
        end
    end
    local tests = PP_PerUser.scanperframe
    if (not tests) then
        tests = 1
    end

    while PP_Scanners[1] do
        local groupType, groupIndex = unpack(PP_Scanners[1])
        local unitID = groupType
        if groupIndex > 0 then
            unitID = unitID..groupIndex
        end
        local name = UnitName(unitID)
        local class, englishClass = UnitClass(unitID)
        if (name and class) then
            local classID = PallyPower_getClassID(englishClass)
            if not PP_ScanInfo[classID] then PP_ScanInfo[classID] = {} end
            PP_ScanInfo[classID][unitID] = PallyPower_getUnitInfo(unitID);
            if classID == 5 then    -- hunters
                local petUnitID = groupType.."pet"..groupIndex
                local pet_name = UnitName(petUnitID)
                if pet_name then
                    local classID = 9
                    if not PP_ScanInfo[classID] then PP_ScanInfo[classID] = {} end
                    PP_ScanInfo[classID][petUnitID] = PallyPower_getUnitInfo(petUnitID);
                end
            elseif classID == 7 then    -- warlocks
                local petUnitID = groupType.."pet"..groupIndex
                local pet_name = UnitName(petUnitID)
                if pet_name then
                    local i = 1;
                    local phaseShifted = false;
                    local name, icon, _ = UnitBuff(petUnitID, i)
                    while name do
                        if icon == 136164 then phaseShifted = true; break; end
                        i = i + 1;
                        name, icon, _ = UnitBuff(petUnitID, i)
                    end
                    if not phaseShifted then
                        local classID = 9
                        if not PP_ScanInfo[classID] then PP_ScanInfo[classID] = {} end
                        PP_ScanInfo[classID][petUnitID] = PallyPower_getUnitInfo(petUnitID)
                    end
                end
            end
        end
        tremove(PP_Scanners, 1)
        tests = tests - 1
        PP_Debug("Scanning "..unitID.." and "..tests.." remain");
        if (tests <= 0) then return end
    end
    CurrentBuffs = PP_ScanInfo
    PP_ScanInfo = nil
    PP_NextScan = PP_PerUser.scanfreq
    PallyPower_ScanInventory()
end


function PallyPower_getUnitInfo(unitID)
    local info = {}

    info["unitid"] = unitID;
    info["name"] = UnitName(unitID);
    info["visible"] = UnitIsVisible(unitID);
    info["expiration"] = {};

    local j = 1;
    local name, texture, _, _, _, expiration =  UnitAura(unitID, j, "HELPFUL")
    while name do
        local textureID = PallyPower_getBuffID(texture)

        if textureID > 5 then
            textureID = textureID - 6
        end

        if textureID >= 0 and expiration > 0 then
            info["expiration"][textureID] = expiration
        end

        info[textureID] = true
        j=j+1
        name, texture, _, _, _, expiration =  UnitAura(unitID, j, "HELPFUL")
    end
    return info;
end


function PallyPower_getClassID(class)
    for id, name in pairs(PallyPower_classIDEnglishClass) do
        if (name==class) then
            return id
        end
    end
    return -1
end


function PallyPower_getBuffID(text)
    for id, info in pairs(spellInfo) do
        if (info["icon"]==text) then
            return id
        end
    end
    return -2
end


function PallyPowerBuffButton_OnLoad(self, btn)
    if (BackdropTemplateMixin) then
        Mixin(self, BackdropTemplateMixin)
    end
    self:RegisterForClicks("LeftButtonUp","RightButtonUp")
    self:SetBackdrop(backdrop)
    self:SetBackdropColor(0.0, 0.0, 0.0, 0.5);
end


function PallyPowerBuffButton_OnEnter(self, motion)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(PallyPower_ClassID[self.classID]..PallyPower_BuffFrameText..PallyPower_BlessingID[self.buffID], 1, 1, 1)
    GameTooltip:AddLine(PallyPower_Have..table.concat(self.have, ", "), 0.5, 1, 0.5);
    GameTooltip:AddLine(PallyPower_Need..table.concat(self.need, ", "), 1, 0.5, 0.5);
    GameTooltip:AddLine(PallyPower_NotHere..table.concat(self.range, ", "), 0.5, 0.5, 1);
    GameTooltip:AddLine(PallyPower_Dead..table.concat(self.dead, ", "), 1, 0, 0);
    GameTooltip:Show()
end


function PallyPowerBuffButton_OnLeave(self, btn)
    GameTooltip:Hide()
end

--[[ MainFrame and MenuFrame Scaling ]]--

function PallyPower_StartScaling(self, arg1)
    if arg1=="LeftButton" then
        self:LockHighlight()
        PallyPower.FrameToScale = self:GetParent()
        PallyPower.ScalingWidth = self:GetParent():GetWidth() * PallyPower.FrameToScale:GetParent():GetEffectiveScale()
        PallyPower.ScalingHeight = self:GetParent():GetHeight() * PallyPower.FrameToScale:GetParent():GetEffectiveScale()
        PallyPower_ScalingFrame:Show()
    end
end

function PallyPower_StopScaling(self, arg1)
    if arg1=="LeftButton" then
        PallyPower_ScalingFrame:Hide()
        PallyPower.FrameToScale = nil
        self:UnlockHighlight()
    end
end


local function really_setpoint(frame,point,relativeTo,relativePoint,xoff,yoff)
    frame:SetPoint(point,relativeTo,relativePoint,xoff,yoff)
end


function PallyPower_ScaleFrame(scale)
    local frame = PallyPower.FrameToScale
    local oldscale = frame:GetScale() or 1
    local framex = (frame:GetLeft() or PallyPowerPerOptions.XPos)* oldscale
    local framey = (frame:GetTop() or PallyPowerPerOptions.YPos)* oldscale

    frame:SetScale(scale)
    if frame:GetName() == "PallyPowerFrame" then
        really_setpoint(PallyPowerFrame,"TOPLEFT","UIParent","BOTTOMLEFT",framex/scale,framey/scale)
        PP_PerUser.scalemain = scale
    end
    if frame:GetName() == "PallyPowerBuffBar" then
        really_setpoint(PallyPowerBuffBar,"TOPLEFT","UIParent","BOTTOMLEFT",framex/scale,framey/scale)
        PP_PerUser.scalebar = scale
    end
end


function PallyPower_ScalingFrame_OnUpdate(self, arg1)
    if not PallyPower.ScalingTime then PallyPower.ScalingTime = 0 end
        PallyPower.ScalingTime = PallyPower.ScalingTime + arg1
        if PallyPower.ScalingTime > 0.25 then
            PallyPower.ScalingTime = 0
            local frame = PallyPower.FrameToScale
            local oldscale = frame:GetEffectiveScale()
            local framex, framey, cursorx, cursory = frame:GetLeft() * oldscale, frame:GetTop() * oldscale, GetCursorPosition()
            if PallyPower.ScalingWidth>PallyPower.ScalingHeight then
                if (cursorx-framex)>32 then
                local newscale =  (cursorx-framex)/PallyPower.ScalingWidth
                PallyPower_ScaleFrame(newscale)
                end
            else
                if (framey-cursory)>32 then
            local newscale =  (framey-cursory)/PallyPower.ScalingHeight
            PallyPower_ScaleFrame(newscale)
            end
        end
    end
end


function PallyPower_SetOption(opt, value)
    PP_PerUser[opt] = value
end


function PallyPower_Options()
    PallyPowerFrame:Hide()
    PallyPower_OptionsFrame:Show()
end


function PallyPower_ShowFeedback(msg, r, g, b, a)
    if PP_PerUser.chatfeedback then
        DEFAULT_CHAT_FRAME:AddMessage("[PallyPower] "..msg, r, g, b, a)
    else
        UIErrorsFrame:AddMessage(msg, r, g, b, a)
    end
end


function PallyPowerGridButton_OnMouseWheel(self, arg1)
    _,_,pnum,class = string.find(self:GetName(), "PallyPowerFramePlayer(.+)Class(.+)");
    pnum = pnum + 0;
    class = class + 0;
    pname = _G["PallyPowerFramePlayer"..pnum.."Name"]:GetText()
    if not PallyPower_CanControl(pname) then return false end

    if (arg1==-1) then  --mouse wheel down
        PallyPower_PerformCycle(pname, class)
    else
        PallyPower_PerformCycleBackwards(pname, class)
    end
end


function PallyPower_BarToggle()
    if not PP_IsPally() then
        PallyPower_ShowFeedback(" Not a paladin", 0.5, 1, 1, 1)
    elseif not InCombatLockdown() then
        if PallyPowerBuffBar:IsVisible() then
            PallyPowerBuffBar:Hide()
            PallyPower_ShowFeedback(" Bar hidden", 0.5, 1, 1, 1)
        else
            PallyPowerBuffBar:Show()
            PallyPower_ShowFeedback(" Bar visible", 0.5, 1, 1, 1)
        end
    end
end
