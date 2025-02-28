﻿local mod	= DBM:NewMod("Anub'arak_Coliseum", "DBM-Coliseum")
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4435 $"):sub(12, -3))
mod:SetCreatureID(34564)  

mod:RegisterCombat("yell", L.YellPull)

mod:RegisterEvents(
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_REFRESH", 	
	"SPELL_AURA_REMOVED",
	"SPELL_CAST_START",
	"CHAT_MSG_RAID_BOSS_EMOTE"
)

mod:SetUsedIcons(3, 4, 5, 6, 7, 8)


mod:AddBoolOption("RemoveHealthBuffsInP3", false)

-- Adds
local warnAdds				= mod:NewAnnounce("warnAdds", 3, 45419)
local timerAdds				= mod:NewTimer(45, "timerAdds", 45419)
local Burrowed				= false 

-- Pursue
local warnPursue			= mod:NewTargetAnnounce(67574, 4)
local specWarnPursue		= mod:NewSpecialWarning("SpecWarnPursue")
local warnHoP				= mod:NewTargetAnnounce(10278, 2, nil, false)--Heroic strat revolves around kiting pursue and using Hand of Protection.
local timerHoP				= mod:NewBuffActiveTimer(10, 10278, nil, false)--So we will track bops to make this easier.
mod:AddBoolOption("PlaySoundOnPursue")
mod:AddBoolOption("PursueIcon")

-- Emerge
local warnEmerge			= mod:NewAnnounce("WarnEmerge", 3, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendUnBurrow.blp")
local warnEmergeSoon		= mod:NewAnnounce("WarnEmergeSoon", 1, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendUnBurrow.blp")
local timerEmerge			= mod:NewTimer(62, "TimerEmerge", "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendUnBurrow.blp")

-- Submerge
local warnSubmerge			= mod:NewAnnounce("WarnSubmerge", 3, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendBurrow.blp")
local warnSubmergeSoon		= mod:NewAnnounce("WarnSubmergeSoon", 1, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendBurrow.blp")
local specWarnSubmergeSoon	= mod:NewSpecialWarning("specWarnSubmergeSoon", mod:IsTank())
local timerSubmerge			= mod:NewTimer(80, "TimerSubmerge", "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendBurrow.blp")

-- Phases
local warnPhase3			= mod:NewPhaseAnnounce(3)
local enrageTimer			= mod:NewBerserkTimer(570)	-- 9:30 ? hmpf (no enrage while submerged... this sucks)
local isPhase3  			= false

-- Penetrating Cold
local specWarnPCold			= mod:NewSpecialWarningYou(68510, false)
local timerPCold			= mod:NewBuffActiveTimer(18, 68509)
local PColdCountdown		= mod:NewCountdown(68509, "PlayPColdCountdown", false)
local timerNextPCold		= mod:NewCDTimer(20, 68509, nil, true, false)

mod:AddBoolOption("SetIconsOnPCold", true)
mod:AddBoolOption("AnnouncePColdIcons", false)
mod:AddBoolOption("AnnouncePColdIconsRemoved", false)

-- Freezing Slash
local warnFreezingSlash		= mod:NewTargetAnnounce(66012, 2, nil, mod:IsHealer() or mod:IsTank())
local timerFreezingSlash	= mod:NewCDTimer(20, 66012, nil, mod:IsHealer() or mod:IsTank())

-- Shadow Strike
local timerShadowStrike		= mod:NewNextTimer(25, 66134)
local preWarnShadowStrike	= mod:NewSoonAnnounce(66134, 3)
local warnShadowStrike		= mod:NewSpellAnnounce(66134, 4)
local specWarnShadowStrike	= mod:NewSpecialWarning("SpecWarnShadowStrike", mod:IsTank())

function mod:OnCombatStart(delay)
	Burrowed = false
	isPhase3 = false
	timerAdds:Start(10-delay)
	warnAdds:Schedule(10-delay)
	self:ScheduleMethod(10-delay, "Adds")
	warnSubmergeSoon:Schedule(70-delay)
	specWarnSubmergeSoon:Schedule(70-delay)
	timerSubmerge:Start(-delay)
	enrageTimer:Start(-delay)
	timerFreezingSlash:Start(-delay)
	if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
		timerShadowStrike:Start()
		preWarnShadowStrike:Schedule(20-delay)
		self:ScheduleMethod(25-delay, "ShadowStrike")
	end
end

function mod:Adds() 
	if self:IsInCombat() then 
		if not Burrowed then 
			timerAdds:Start() 
			warnAdds:Schedule(45) 
			self:ScheduleMethod(45, "Adds") 
		end 
	end 
end

function mod:ShadowStrike()
	if self:IsInCombat() then
		timerShadowStrike:Start()
		preWarnShadowStrike:Cancel()
		preWarnShadowStrike:Schedule(20)
		self:UnscheduleMethod("ShadowStrike")
		self:ScheduleMethod(25, "ShadowStrike")
	end
end

local PColdTargets = {}
do
	local function sort_by_group(v1, v2)
		return DBM:GetRaidSubgroup(UnitName(v1)) < DBM:GetRaidSubgroup(UnitName(v2))
	end
	function mod:SetPcoldIcons()
		if DBM:GetRaidRank() > 0 then
			table.sort(PColdTargets, sort_by_group)
			local PColdIcon = 7
			for i, v in ipairs(PColdTargets) do
				if self.Options.AnnouncePColdIcons then
					SendChatMessage(L.PcoldIconSet:format(PColdIcon, UnitName(v)), "RAID")
				end
				self:SetIcon(UnitName(v), PColdIcon)
				PColdIcon = PColdIcon - 1
			end
			table.wipe(PColdTargets)	
		end
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(67574) then			-- Pursue
		if args:IsPlayer() then
			specWarnPursue:Show()
			if self.Options.PlaySoundOnPursue then
				PlaySoundFile("Sound\\Creature\\HoodWolf\\HoodWolfTransformPlayer01.wav")
			end
		end
		if self.Options.PursueIcon then
			self:SetIcon(args.destName, 8, 15)
		end
		warnPursue:Show(args.destName)
		if Burrowed == false then  -- Submerge timer does not start if player doesn't receive Anub's emote (range?).
			self:submerge(-4)
		end

	elseif args:IsSpellID(66013, 67700, 68509, 68510) then		-- Penetrating Cold
		if args:IsPlayer() and isPhase3 then
			specWarnPCold:Show()
		end
		if self.Options.SetIconsOnPCold then
			table.insert(PColdTargets, DBM:GetRaidUnitId(args.destName))
			-- Set icons after 0.2s to wait for last application.
			-- We can't rely on count here since the debuff can miss.
			self:UnscheduleMethod("SetPcoldIcons")
			self:ScheduleMethod(0.2, "SetPcoldIcons")
		end
		timerPCold:Show()

		if isPhase3 then
			timerNextPCold:Start()
			PColdCountdown:Cancel()
			PColdCountdown:Schedule(17, 3)
		end
	elseif args:IsSpellID(66012) then							-- Freezing Slash
		warnFreezingSlash:Show(args.destName)
		timerFreezingSlash:Start()
	elseif args:IsSpellID(10278) and self:IsInCombat() then		-- Hand of Protection
		warnHoP:Show(args.destName)
		timerHoP:Start(args.destName)
	end
end

mod.SPELL_AURA_REFRESH = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(66013, 67700, 68509, 68510) then			-- Penetrating Cold
		mod:SetIcon(args.destName, 0)
		if (self.Options.AnnouncePColdIcons and self.Options.AnnouncePColdIconsRemoved) and DBM:GetRaidRank() >= 1 then
			SendChatMessage(L.PcoldIconRemoved:format(args.destName), "RAID")
		end
	elseif args:IsSpellID(10278) and self:IsInCombat() then		-- Hand of Protection
		timerHoP:Cancel(args.destName)
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(66118, 67630, 68646, 68647) then			-- Swarm (start p3)
		warnPhase3:Show()
		isPhase3 = true
		warnEmergeSoon:Cancel()
		warnSubmergeSoon:Cancel()
		specWarnSubmergeSoon:Cancel()
		timerEmerge:Stop()
		timerSubmerge:Stop()
		if self.Options.RemoveHealthBuffsInP3 then
			mod:ScheduleMethod(0.1, "RemoveBuffs")
		end
		if mod:IsDifficulty("normal10") or mod:IsDifficulty("normal25") then
			timerAdds:Cancel()
			warnAdds:Cancel()
			self:UnscheduleMethod("Adds")
		end
	elseif args:IsSpellID(66134) then							-- Shadow Strike
		self:ShadowStrike()
		specWarnShadowStrike:Show()
		warnShadowStrike:Show()
	end
end

function mod:submerge(delay)
	Burrowed = true
	timerAdds:Cancel()
	warnAdds:Cancel()
	warnSubmerge:Show()
	warnEmergeSoon:Schedule(52 + delay)
	timerEmerge:Start(delay)
	timerFreezingSlash:Stop()
	self:ScheduleMethod(62 + delay, "emerge")
end

function mod:emerge()
	Burrowed = false
	timerAdds:Start(5)
	warnAdds:Schedule(5)
	self:ScheduleMethod(5, "Adds")
	warnEmerge:Show()
	warnSubmergeSoon:Schedule(65)
	specWarnSubmergeSoon:Schedule(65)
	timerSubmerge:Start()
	if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
		timerShadowStrike:Start(20)  -- Comes 20s after emerge, 5s off normal cd.
		preWarnShadowStrike:Cancel()
		preWarnShadowStrike:Schedule(15)
		self:UnscheduleMethod("ShadowStrike")
		self:ScheduleMethod(20, "ShadowStrike")  -- Schedule regular event for next cast.
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg and msg:find(L.Burrow) then
		self:submerge(0)
	end
end

function mod:RemoveBuffs()
	CancelUnitBuff("player", (GetSpellInfo(47440)))		-- Commanding Shout
	CancelUnitBuff("player", (GetSpellInfo(48161)))		-- Power Word: Fortitude
	CancelUnitBuff("player", (GetSpellInfo(48162)))		-- Prayer of Fortitude
	CancelUnitBuff("player", (GetSpellInfo(69377)))		-- Runescroll of Fortitude
end

