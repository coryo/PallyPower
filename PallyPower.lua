PallyPower = {};

local LCD = LibStub("LibClassicDurations")
LCD:Register("PallyPower") -- tell library it's being used and should start working

local initalized = false

BINDING_HEADER_PALLYPOWER_HEADER = "Pally Power";
BINDING_NAME_TOGGLE = "Toggle Buff Bar";
BINDING_NAME_REPORT = "Report Assignments";

 AllPallys = { };

 PallyPower_Assignments = { };



 BlessingIcon = {};
BlessingIcon[0] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom";
BlessingIcon[1] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings";
BlessingIcon[2] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSalvation";
BlessingIcon[3] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofLight";
BlessingIcon[4] = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings";
BlessingIcon[5] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSanctuary";

 BuffIcon = {};
--filler?
BuffIcon[-1] = "Interface\\Icons\\Ability_Stealth"
--greater blessings
BuffIcon[0] = "Greater Blessing of Wisdom"
BuffIcon[1] = "Greater Blessing of Might"
BuffIcon[2] = "Greater Blessing of Salvation"
BuffIcon[3] = "Greater Blessing of Light"
BuffIcon[4] = "Greater Blessing of Kings"
BuffIcon[5] = "Greater Blessing of Sanctuary"
--lesser blessings
BuffIcon[6] = "Blessing of Wisdom"
BuffIcon[7] = "Blessing of Might"
BuffIcon[8] = "Blessing of Salvation"
BuffIcon[9] = "Blessing of Light"
BuffIcon[10] = "Blessing of Kings"
BuffIcon[11] = "Blessing of Sanctuary"


LastCast = { };
LastCastOn = { };
PP_Symbols = 0

 PallyPower_ClassTexture = { };
PallyPower_ClassTexture[0] = "Interface\\AddOns\\PallyPower\\Icons\\Warrior";
PallyPower_ClassTexture[1] = "Interface\\AddOns\\PallyPower\\Icons\\Rogue";
PallyPower_ClassTexture[2] = "Interface\\AddOns\\PallyPower\\Icons\\Priest";
PallyPower_ClassTexture[3] = "Interface\\AddOns\\PallyPower\\Icons\\Druid";
PallyPower_ClassTexture[4] = "Interface\\AddOns\\PallyPower\\Icons\\Paladin";
PallyPower_ClassTexture[5] = "Interface\\AddOns\\PallyPower\\Icons\\Hunter";
PallyPower_ClassTexture[6] = "Interface\\AddOns\\PallyPower\\Icons\\Mage";
PallyPower_ClassTexture[7] = "Interface\\AddOns\\PallyPower\\Icons\\Warlock";

PP_PerUser = {
	scalemain = 1,	-- corner of main window docked to
	scalebar = 1,	-- corner menu window is docked from
	scanfreq = 10,
	scanperframe = 1,
        smartbuffs = 1,
}
PP_NextScan = PP_PerUser.scanfreq

 Assignment = { };

 CurrentBuffs = { };

PP_PREFIX = "PLPWR";
successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(PP_PREFIX)

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
  self:SetBackdropColor(0.0, 0.0, 0.0, 0.5);
  self:SetScale(1);
  SlashCmdList["PALLYPOWER"] = function(msg)
    PallyPower_SlashCommandHandler(msg)
  end

end

function PallyPower_OnUpdate(self, elapsed)
--  PP_Debug("OnUpdate "..tdiff);
  if (not PP_PerUser.scanfreq) then
    PP_PerUser.scanfreq = 10;
    PP_PerUser.scanperframe = 1;
  end
  PP_NextScan = PP_NextScan - elapsed
  if PP_NextScan < 0 and PP_IsPally() then
    PP_Debug("Scanning");
    PallyPower_ScanRaid()
    PallyPower_UpdateUI()
  end
  for i,k in pairs(LastCast) do
    LastCast[i] = k - elapsed
  end
end


function PallyPower_OnEvent(self, event, ...)
  local args = {...}
  local type, id;
  if (event=="SPELLS_CHANGED"  or  event=="PLAYER_ENTERING_WORLD") then
    PallyPower_ScanSpells()
  end

  if (event=="PLAYER_ENTERING_WORLD" and (not PallyPower_Assignments[UnitName("player")])) then
    PallyPower_Assignments[UnitName("player")] = {};
    if UnitName("player") == "Aznamir" then PP_DebugEnabled = true end
  end

  if event=="CHAT_MSG_ADDON" and args[1]==PP_PREFIX and (args[3]=="PARTY" or args[3]=="RAID")  then
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

  if event == "GROUP_ROSTER_UPDATE" then
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
  if PallyPower_CanControl(UnitName("player")) then
    local type
    if IsInRaid() then
      type = "RAID"
    else
      type = "PARTY"
    end
    PP_Debug(type);
    SendChatMessage(PallyPower_Assignments1, type)
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
      for id = 0, 7 do
        local bid = PallyPower_Assignments[name][id]
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
    SendChatMessage(PallyPower_Assignments2, type)
  end
end

function PallyPower_FormatTime(time)
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
      getglobal("PallyPowerFramePlayer"..i.."Name"):SetText(name)
      getglobal("PallyPowerFramePlayer"..i.."Symbols"):SetText(skills["symbols"])
      getglobal("PallyPowerFramePlayer"..i.."Symbols"):SetTextColor(1,1,0.5)
      if (PallyPower_CanControl(name)) then
        getglobal("PallyPowerFramePlayer"..i.."Name"):SetTextColor(1,1,1)
      else
        if (PallyPower_CheckRaidLeader(name)) then
          getglobal("PallyPowerFramePlayer"..i.."Name"):SetTextColor(0,1,0)
        else
          getglobal("PallyPowerFramePlayer"..i.."Name"):SetTextColor(1,0,0)
        end
      end
      for id = 0, 5 do
        if (skills[id]) then
          getglobal("PallyPowerFramePlayer"..i.."Icon"..id):Show()
          getglobal("PallyPowerFramePlayer"..i.."Skill"..id):Show()
          local txt = skills[id]["rank"];
          if (skills[id]["talent"]+0 > 0) then txt = txt.."+"..skills[id]["talent"] end
          getglobal("PallyPowerFramePlayer"..i.."Skill"..id):SetText(txt)
        else
          getglobal("PallyPowerFramePlayer"..i.."Icon"..id):Hide()
          getglobal("PallyPowerFramePlayer"..i.."Skill"..id):Hide()
        end
      end
      for id = 0, 7 do
        if (PallyPower_Assignments[name]) then
          getglobal("PallyPowerFramePlayer"..i.."Class"..id.."Icon"):SetTexture(BlessingIcon[PallyPower_Assignments[name][id]])
        else
          getglobal("PallyPowerFramePlayer"..i.."Class"..id.."Icon"):SetTexture(nil)
        end
      end
      i = i + 1
      numPallys = numPallys + 1
    end
    PallyPowerFrame:SetHeight(14 + 24 + 56 + (numPallys*56) + 22 ) -- 14 from border, 24 from Title, 56 from space for class icons, 56 per paladin, 22 for Buttons at bottom
    for i = 1, 12 do
       if i <= numPallys then
         getglobal("PallyPowerFramePlayer"..i):Show()
       else
         getglobal("PallyPowerFramePlayer"..i):Hide()
       end
    end
  end
end


function PallyPower_UpdateUI()
  if not initalized then PallyPower_ScanSpells() end
  -- Buff Bar
  PallyPowerBuffBar:SetScale(PP_PerUser.scalebar);
  if GetNumGroupMembers() == 0 or not PP_IsPally() then
    PallyPowerBuffBar:Hide()
  else
    PallyPowerBuffBar:Show()
    PallyPowerBuffBarTitleText:SetText(format(PallyPower_BuffBarTitle, PP_Symbols));
    BuffNum = 1
    if PallyPower_Assignments[UnitName("player")] then
      local assign = PallyPower_Assignments[UnitName("player")]
      for class = 0, 7 do
        if (assign[class] and assign[class] ~= -1) then
          getglobal("PallyPowerBuffBarBuff"..BuffNum.."ClassIcon"):SetTexture(PallyPower_ClassTexture[class]);
          getglobal("PallyPowerBuffBarBuff"..BuffNum.."BuffIcon"):SetTexture(BlessingIcon[assign[class]]);
          local btn = getglobal("PallyPowerBuffBarBuff"..BuffNum);
          btn.classID = class;
          btn.buffID = assign[class];
          btn.need = {};
          btn.have = {};
          btn.range = {};
          btn.dead = {};
          -- Calculate number of people who need buff.
          local nneed = 0;
          local nhave = 0;
          local ndead = 0;
          local next_expiration = -1;
          if CurrentBuffs[class] then
            for member, stats in pairs(CurrentBuffs[class]) do
              -- print(stats["name"], stats['expiration'])
              local exp = stats["expiration"][btn.buffID]

              if exp and stats[assign[class]] and exp > 0 then
                if next_expiration < 0 then
                  next_expiration = exp
                elseif exp < next_expiration then
                  next_expiration = exp
                end
              end

              if stats["visible"] then
                if not stats[assign[class]] then
                  if UnitIsDeadOrGhost(member) then
                    ndead = ndead + 1;
                    tinsert(btn.dead, stats["name"]);
                  else
                    nneed = nneed + 1
                    tinsert(btn.need, stats["name"]);
                  end
                else
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
            getglobal("PallyPowerBuffBarBuff"..BuffNum.."Text"):SetText(nneed.." ("..ndead..")");
          else
            getglobal("PallyPowerBuffBarBuff"..BuffNum.."Text"):SetText(nneed);
          end

          getglobal("PallyPowerBuffBarBuff"..BuffNum.."Time"):SetText(PallyPower_FormatTime(next_expiration - GetTime()))

          if not (nneed > 0 or nhave > 0) then
          else
            BuffNum = BuffNum + 1
            if (nhave == 0) then
              btn:SetBackdropColor(1.0, 0.0, 0.0, 0.5);
            elseif (nneed > 0) then
              btn:SetBackdropColor(1.0, 1.0, 0.5, 0.5);
            else
              btn:SetBackdropColor(0.0, 0.0, 0.0, 0.5);
            end
            btn:Show();
          end
        end
      end
    end
    for rest = BuffNum, 8 do
        local btn = getglobal("PallyPowerBuffBarBuff"..rest);
        btn:Hide();
    end
    PallyPowerBuffBar:SetHeight(30 + (34 * (BuffNum-1)));
  end

end

function PallyPower_ScanSpells()
    local RankInfo = {}
    local i = 1
    while true do
       local spellName, spellRank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
       if not spellName then
          do break end
       end

       if not spellRank or spellRank == "" then spellRank = PallyPower_Rank1 end
       local _,_,bless = string.find(spellName, PallyPower_BlessingSpellSearch)
       if bless then
          for id,name in pairs(PallyPower_BlessingID) do
            if name==bless then
              local _,_,rank = string.find(spellRank, PallyPower_RankSearch);
              if (RankInfo[id] and spellRank < RankInfo[id]["rank"]) then
                -- Do Nothing
              else
                RankInfo[id] = {};
                RankInfo[id]["rank"] = rank;
                RankInfo[id]["id"] = i;
                RankInfo[id]["name"] = name;
                RankInfo[id]["talent"] = 0;
              end
            end
          end
       end
       i = i + 1
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
      -- PP_IsPally = true
    else
      PP_Debug("I'm not a paladin?? "..class);
      -- PP_IsPally = nil
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
  for name, skills in pairs(PallyPower_Assignments) do
    if (PallyPower_CheckRaidLeader(who) or name==who) then
      for class, id in pairs(PallyPower_Assignments[name]) do
        PallyPower_Assignments[name][class]=-1
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
  for id=0,7 do
    if (not PallyPower_Assignments[UnitName("player")]) or (not PallyPower_Assignments[UnitName("player")][id]) or PallyPower_Assignments[UnitName("player")][id] == -1 then
      msg = msg .. "n"
    else
      msg = msg .. PallyPower_Assignments[UnitName("player")][id]
    end
  end
  PallyPower_SendMessage(msg)
  PallyPower_SendMessage("SYMCOUNT "..PP_Symbols);
end

function PallyPower_SendMessage(msg)
    success = C_ChatInfo.SendAddonMessage(PP_PREFIX, msg, "RAID");
    -- print(msg)
end

function PallyPower_ParseMessage(sender, msg)
    if not (sender == UnitName("player")) then
      if msg == "REQ" then
        PallyPower_SendSelf()
      end
      if string.find(msg, "^SELF") then
        PallyPower_Assignments[sender] = {}
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
          for id = 0,7 do
            tmp = string.sub(assign, id+1, id+1)
            if (tmp == "n" or tmp == "") then tmp = -1 end
            PallyPower_Assignments[sender][id] = tmp + 0
          end
        end
        PallyPower_UpdateUI()
      end
      if string.find(msg, "^ASSIGN") then
         _, _, name, class, skill = string.find(msg, "^ASSIGN (.*) (.*) (.*)")
         if (not(name==sender)) and (not PallyPower_CheckRaidLeader(sender)) then return false end
         if (not PallyPower_Assignments[name]) then PallyPower_Assignments[name] = {} end
         class=class+0
         skill=skill+0
         PallyPower_Assignments[name][class] = skill;
         PallyPower_UpdateUI()
      end
      if string.find(msg, "^MASSIGN") then
         _, _, name, skill = string.find(msg, "^MASSIGN (.*) (.*)")
         if (not(name==sender)) and (not PallyPower_CheckRaidLeader(sender)) then return false end
         if (not PallyPower_Assignments[name]) then PallyPower_Assignments[name] = {} end
         skill=skill+0
	 for class=0, 7 do
	   PallyPower_Assignments[name][class] = skill;
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
   GameTooltip:SetText(PallyPower_Credits1, 1, 1, 1)
   GameTooltip:AddLine(PallyPower_Credits2,1,1,1);
   GameTooltip:AddLine(PallyPower_Credits3);
   GameTooltip:AddLine(PallyPower_Credits4,0,1,0);
   GameTooltip:AddLine(PallyPower_Credits5);
   GameTooltip:AddLine(PallyPower_Credits6);
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
  pname = getglobal("PallyPowerFramePlayer"..pnum.."Name"):GetText()
  if not PallyPower_CanControl(pname) then return false end

  if (mouseBtn=="RightButton") then
    PallyPower_Assignments[pname][class]=-1
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

  if not PallyPower_Assignments[name][class] then
    cur=6
  else
    cur=PallyPower_Assignments[name][class]
    if cur==-1 then cur=6 end
  end

  PallyPower_Assignments[name][class] = -1

  for test = cur-1,-1,-1 do
    cur = test
    if PallyPower_CanBuff(name, test) and (PallyPower_NeedsBuff(class, test) or shift) then
      do break end
    end
  end

  if shift then
    for test=0, 7 do
        PallyPower_Assignments[name][test] = cur
    end
    PallyPower_SendMessage("MASSIGN "..name.." "..cur)
  else
    PallyPower_Assignments[name][class] = cur
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

  if not PallyPower_Assignments[name][class] then
    cur=-1
  else
    cur=PallyPower_Assignments[name][class]
  end
  PallyPower_Assignments[name][class] = -1
  for test = cur+1,6 do
    if PallyPower_CanBuff(name, test) and (PallyPower_NeedsBuff(class, test) or shift) then
      cur = test
      do break end
    end
  end

  if (cur==6) then cur=-1 end

  if shift then
    for test=0, 7 do
        PallyPower_Assignments[name][test] = cur
    end
    PallyPower_SendMessage("MASSIGN "..name.." "..cur)
  else
    PallyPower_Assignments[name][class] = cur
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
    if (class == 2 or class == 5 or class == 6 or class == 7) and test == 1 then
      return false
    end
  end

  for name,skills in pairs(PallyPower_Assignments) do
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
  for bag = 0,  4 do
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

PP_ScanInfo = nil

function PallyPower_ScanRaid()
  if not PP_IsPally() then return end
  if not (PP_ScanInfo) then
    PP_Scanners = {}
    PP_ScanInfo = {}
    if GetNumGroupMembers() > 0 and IsInRaid() then
      for i = 1, GetNumGroupMembers() do
        tinsert(PP_Scanners, "raid"..i)
      end
    else
      tinsert(PP_Scanners, "player");
      for i = 1, GetNumGroupMembers() do
        tinsert(PP_Scanners, "party"..i)
      end
    end
  end
  local tests = PP_PerUser.scanperframe
  if (not tests) then
    tests = 1
  end

  while PP_Scanners[1] do
    unit = PP_Scanners[1]
    local name=UnitName(unit)
    local class=UnitClass(unit)
    if ( name and class ) then
      local cid = PallyPower_GetClassID(class)
      if not PP_ScanInfo[cid] then
        PP_ScanInfo[cid] = {}
      end
      PP_ScanInfo[cid][unit] = {};
      PP_ScanInfo[cid][unit]["name"] = name;
      PP_ScanInfo[cid][unit]["visible"] = UnitIsVisible(unit);
      PP_ScanInfo[cid][unit]["expiration"] = {};

      local j=1
      while UnitBuff(unit, j) do
        local name, _, _, _, _, expiration =  LCD:UnitAura(unit, j, "HELPFUL")
        local txtID = PallyPower_GetBuffTextureID(name)
        if txtID >=0 and expiration > 0 then
            PP_ScanInfo[cid][unit]["expiration"][txtID] = expiration
        end
        if txtID >5 then
	        txtID = txtID - 6
        end

        PP_ScanInfo[cid][unit][txtID] = true
        j=j+1
      end
    end
    tremove(PP_Scanners, 1)
    tests = tests - 1
    PP_Debug("Scanning "..unit.." and "..tests.." remain");
    if (tests <= 0) then return end
  end
  CurrentBuffs = PP_ScanInfo
  PP_ScanInfo = nil
  PP_NextScan = PP_PerUser.scanfreq
  PallyPower_ScanInventory()
end

function PallyPower_GetClassID(class)
  for id, name in pairs(PallyPower_ClassID) do
    if (name==class) then
      return id
    end
  end
  return -1
end

function PallyPower_GetBuffTextureID(text)
  for id, name in pairs(BuffIcon) do
    if (name==text) then
      return id
    end
  end
  return -2
end

function PallyPowerBuffButton_OnLoad(self, btn)
  self:RegisterForClicks("LeftButtonUp","RightButtonUp")
  self:SetBackdropColor(0.0, 0.0, 0.0, 0.5);
end

function PallyPowerBuffButton_OnClick(self, btn, mousebtn)
  -- -- temporarily disable auto self cast
  -- local self_cast = GetCVar("autoSelfCast")
  -- SetCVar("autoSelfCast", "0")

  -- ClearTarget()
  -- PP_Debug("Casting "..btn.buffID.." on "..btn.classID)
  -- -- CastSpell(AllPallys[UnitName("player")][btn.buffID]["id"], BOOKTYPE_SPELL);
  -- local RecentCast = false
  -- if LastCast[btn.buffID..btn.classID] and LastCast[btn.buffID..btn.classID] > (15 * 60) - 30 then
  --   RecentCast = true
  -- end
  -- for unit, stats in pairs(CurrentBuffs[btn.classID]) do
  --   if SpellCanTargetUnit(unit) and not (RecentCast and string.find(table.concat(LastCastOn[btn.classID], " "), unit)) then
  --     PP_Debug("Trying to cast on "..unit);
  --     SpellTargetUnit(unit)
  --     PP_NextScan = 1
  --     LastCast[btn.buffID..btn.classID] = 15 * 60;
  --     if not RecentCast then
  --       LastCastOn[btn.classID] = {}
  --     end
  --     tinsert(LastCastOn[btn.classID], unit)
  --     PallyPower_ShowFeedback(format(PallyPower_Casting, PallyPower_BlessingID[btn.buffID], PallyPower_ClassID[btn.classID], UnitName(unit)), 0.0, 1.0, 0.0);
  --     TargetLastTarget()
  --     SetCVar("autoSelfCast", self_cast)
  --     return
  --   end
  -- end
  -- SpellStopTargeting()
  -- TargetLastTarget()
  -- PallyPower_ShowFeedback(format(PallyPower_CouldntFind, PallyPower_BlessingID[btn.buffID], PallyPower_ClassID[btn.classID]), 0.0, 1.0, 0.0);
  -- SetCVar("autoSelfCast", self_cast)
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
  pname = getglobal("PallyPowerFramePlayer"..pnum.."Name"):GetText()
  if not PallyPower_CanControl(pname) then return false end

  if (arg1==-1) then  --mouse wheel down
    PallyPower_PerformCycle(pname, class)
  else
    PallyPower_PerformCycleBackwards(pname, class)
  end
end

function PallyPower_BarToggle()
  if GetNumGroupMembers() == 0 or not PP_IsPally() then
    PallyPower_ShowFeedback(" Not in raid or not a paladin", 0.5, 1, 1, 1)
  else
    if PallyPowerBuffBar:IsVisible() then
      PallyPowerBuffBar:Hide()
      PallyPower_ShowFeedback(" Bar hidden", 0.5, 1, 1, 1)
    else
      PallyPowerBuffBar:Show()
      PallyPower_ShowFeedback(" Bar visible", 0.5, 1, 1, 1)
    end
  end
end
