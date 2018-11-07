HELP = [[
    Use the AHK script with hotkey Ctrl-Windows-D.

    See testdps.bat for an example of running it directly.
]]


local BUILD_XML = arg[1];
if BUILD_XML == nil then
    print("Usage: SearchDPS.lua <build xml>")
    os.exit(1)
end

local _,_,SCRIPT_PATH=string.find(arg[0], "(.+[/\\]).-")
dofile(SCRIPT_PATH.."mockui.lua")

xml = require("xml")
inspect = require("inspect")

function findRelevantStat()
    local calcFunc, stats = build.calcsTab:GetMiscCalculator()
    if (stats['CombinedDPS']) then return 'CombinedDPS' end
    if (stats['AverageHit']) then return 'AverageHit' end
    print("Don't know how to deal with this build's damage output type")
    os.exit(1)
end

function findModEffect(modLine, statField)
    -- Construct an empty passive socket node to test in
    local testNode = {id="temporary-test-node", type="Socket", alloc=false, sd={"Temp Test Socket"}, modList={}}

    -- Construct jewel with the mod just to use its mods in the passive node
    local itemText = "Test Jewel\nMurderous Eye Jewel\n"..modLine
    local item = common.New("Item", build.targetVersion, itemText)
    testNode.modList = item.modList

    -- Calculate stat differences
    local calcFunc, baseStats = build.calcsTab:GetMiscCalculator()
    local newStats = calcFunc({ addNodes={ [testNode]=true } })

    -- Pull out the difference in DPS
    local statVal1 = newStats[statField] or 0
    local statVal2 = baseStats[statField] or 0
    local diff = statVal1 - statVal2

    return diff
end

modData = {
    {name="flat accuracy", desc="+100 to Accuracy Rating", count=100},
    {name="% accuracy", desc="10% increased Global Accuracy Rating", count=10},
    {name="% physical", desc="12% increased Physical Damage", count=12},
    {name="% lightning", desc="12% increased Lightning Damage", count=12},
    {name="% cold", desc="12% increased Cold Damage", count=12},
    {name="% fire", desc="12% increased Fire Damage", count=12},
    {name="% elemental", desc="12% increased Elemental Damage", count=12},
    {name="% chaos", desc="12% increased Chaos Damage", count=12},
    {name="% generic", desc="12% increased Damage", count=12},
    {name="crit chance", desc="16% increased Global Critical Strike Chance", count=16},
    {name="crit multi", desc="+16% to Global Critical Strike Multiplier", count=16},
    {name="attack speed", desc="10% increased Attack Speed", count=10},
    {name="cast speed", desc="10% increased Cast Speed", count=10},
    {name="pen all", desc="Damage Penetrates 8% Elemental Resistances", count=8},
    {name="pen lightning", desc="Damage Penetrates 8% Lightning Resistance", count=8},
    {name="pen cold", desc="Damage Penetrates 8% Cold Resistance", count=8},
    {name="pen fire", desc="Damage Penetrates 8% Fire Resistance", count=8},
    {name="flat phys", desc="Adds 5 to 7 Physical Damage", count=6},
    {name="flat lightning", desc="Adds 6 to 68 Lightning Damage", count=37},
    {name="flat cold", desc="Adds 14 to 31 Cold Damage", count=22.5},
    {name="flat fire", desc="Adds 21 to 34 Fire Damage", count=27.5},
    {name="flat chaos", desc="Adds 4 to 7 Chaos Damage", count=5.5},
    {name="extra lightning", desc="15% of Physical Damage as Extra Lightning Damage", count=15},
    {name="extra cold", desc="15% of Physical Damage as Extra Cold Damage", count=15},
    {name="extra fire", desc="15% of Physical Damage as Extra Fire Damage", count=15},
    {name="extra chaos", desc="Gain 15% of Non-Chaos damage as Extra Chaos Damage", count=15},
    {name="ele as chaos", desc="Gain 15% of Elemental Damage as Extra Chaos Damage", count=15},
    {name="+1 power charge", desc="+1 to Maximum Power Charges", count=1},
    {name="+1 frenzy charge", desc="+1 to Maximum Frenzy Charges", count=1},
    {name="+1 endurance charge", desc="+1 to Maximum Endurance Charges", count=1},
    {name="20 dex", desc="+20 to Dexterity", count=20},
    {name="20 int", desc="+20 to Intelligence", count=20},
    {name="20 str", desc="+20 to Strength", count=20},
    {name="damage per dex", desc="1% increased Damage per 15 Dexterity", count=1},
    {name="damage per int", desc="1% increased Damage per 15 Intelligence", count=1},
    {name="damage per str", desc="1% increased Damage per 15 Strength", count=1},
    {name="% dex", desc="+10% Dexterity", count=10},
    {name="% int", desc="+10% Intelligence", count=10},
    {name="% str", desc="+10% Strength", count=10},
    {name="% lowest", desc="1% increased Damage per 5 of your lowest Attribute", count=1}
}

function char_to_hex(c)
    return string.format("%%%02X", string.byte(c))
end

function urlencode(url)
    if url == nil then
        return
    end
    url = url:gsub("([^%w])", char_to_hex)
    return url
end


-- Load a specific build file or use the default
if BUILD_XML ~= "CURRENT" then
    local buildXml = loadText(BUILD_XML)
    loadBuildFromXML(buildXml)
end

-- Gather chosen skill and part
local pickedGroupIndex = build.mainSocketGroup
local socketGroup = build.skillsTab.socketGroupList[pickedGroupIndex]
local pickedGroupName = socketGroup.displayLabel
local pickedActiveSkillIndex = socketGroup.mainActiveSkill
local displaySkill = socketGroup.displaySkillList[pickedActiveSkillIndex]
local activeEffect = displaySkill.activeEffect
local pickedActiveSkillName = activeEffect.grantedEffect.name
local pickedPartIndex = activeEffect.grantedEffect.parts and activeEffect.srcInstance.skillPart
local pickedPartName = activeEffect.grantedEffect.parts and activeEffect.grantedEffect.parts[pickedPartIndex].name

print("Character: "..build.buildName)
print("Current skill group/gem/part: "..pickedGroupName.." / "..pickedActiveSkillName.." / "..(pickedPartName or '-'))

-- Work out which field to use to report damage: CombinedDPS / AverageHit
local statField = findRelevantStat()
print("Using stat: " .. statField)
print()

-- Setup the main actor for gathering data
env = build.calcsTab.calcs.initEnv(build, "CALCULATOR")

-- Get DPS difference for each mod
url = 'http://gw2crafts.net/pobsearch/modsearch.html?'
for _,mod in ipairs(modData) do
    local dps = findModEffect(mod.desc, statField)
    -- dps = dps / tonumber(mod.count) -- only needed if inputting to the original Python script
    url = url .. string.format("%s=%.1f&", urlencode(mod.name), dps)
    -- print(string.format("%s = %.1f", mod.desc, dps))
end

-- Grab flags from main skill
local flags = {}
for skillType,_ in pairs(env.player.mainSkill.skillTypes) do
    for name,type in pairs(SkillType) do
        if type == skillType then
            if name:match("Can[A-Z]") or name:match("Triggerable") or name:match(".+SingleTarget") or name:match("Type[0-9]+") then
                name = nil
            elseif name:match("ManaCost.+") or name:match("Aura.*") or name:match("Buff.*") then
                name = nil
            elseif name == "Instant" then
                name = nil
            elseif name:match(".+Skill") or name:match(".+Spell") then
                name = name:sub(0, #name-5)
            elseif name:match("Causes.+") then
                name = name:sub(7)
            elseif name == "ProjectileAttack" then
                name = "Projectile"
            end
            if name then flags[name] = true end
        end
    end
end

-- Insert flags for weapon types
if env.player.itemList["Weapon 1"] then
    flags[env.player.itemList["Weapon 1"].type] = true
    if env.player.itemList["Weapon 1"].base.tags.two_hand_weapon then flags["Two Handed Weapon"] = true end
    if env.player.itemList["Weapon 1"].base.tags.mace then flags["Mace"] = true end
    if env.player.itemList["Weapon 1"].base.tags.bow then flags["Bow"] = true end
    if env.player.itemList["Weapon 1"].base.tags.wand then flags["Wand"] = true end
    if env.player.itemList["Weapon 1"].base.tags.claw then flags["Claw"] = true end
    if env.player.itemList["Weapon 1"].base.tags.staff then flags["Staff"] = true end
    if env.player.itemList["Weapon 1"].base.tags.sword then flags["Sword"] = true end
    if env.player.itemList["Weapon 1"].base.tags.axe then flags["Axe"] = true end
    if env.player.itemList["Weapon 1"].base.tags.dagger then flags["Dagger"] = true end
    if env.player.itemList["Weapon 1"].base.tags.shield then flags["Shield"] = true end
end
if env.player.itemList["Weapon 2"] then
    flags[env.player.itemList["Weapon 2"].type] = true
    if env.player.itemList["Weapon 2"].base.tags.two_hand_weapon then flags["Two Handed Weapon"] = true end
    if env.player.itemList["Weapon 2"].base.tags.mace then flags["Mace"] = true end
    if env.player.itemList["Weapon 2"].base.tags.bow then flags["Bow"] = true end
    if env.player.itemList["Weapon 2"].base.tags.wand then flags["Wand"] = true end
    if env.player.itemList["Weapon 2"].base.tags.claw then flags["Claw"] = true end
    if env.player.itemList["Weapon 2"].base.tags.staff then flags["Staff"] = true end
    if env.player.itemList["Weapon 2"].base.tags.sword then flags["Sword"] = true end
    if env.player.itemList["Weapon 2"].base.tags.axe then flags["Axe"] = true end
    if env.player.itemList["Weapon 2"].base.tags.dagger then flags["Dagger"] = true end
    if env.player.itemList["Weapon 2"].base.tags.shield then flags["Shield"] = true end
end
if env.player.itemList["Weapon 1"] and env.player.itemList["Weapon 1"].base.tags.one_hand_weapon and
        env.player.itemList["Weapon 2"] and env.player.itemList["Weapon 2"].base.tags.one_hand_weapon then
    flags["Duel Wielding"] = true -- correct spelling when website supports it
end

-- Grab config flags
if env.configInput.useFrenzyCharges then flags["Frenzy"] = true end
if env.configInput.usePowerCharges then flags["Power"] = true end
if env.configInput.useEnduranceCharges then flags["Endurance"] = true end
if env.configInput.conditionCritRecently then flags["Crit"] = true end
if env.configInput.conditionUsingFlask then flags["Flasked"] = true end

-- Grab enemy status flags
for configFlag,_ in pairs(env.configInput) do
    if configFlag:match('conditionEnemy.+') then flags[configFlag:sub(15)] = true end
end

-- Infer some extra flags from what we already have
if flags.Fire or flags.Cold or flags.Lightning then flags.Elemental = true end

-- Add flags to URL
for flag,_ in pairs(flags) do
    url = url .. urlencode(flag) .. "=True&"
    print(flag)
end

print(url)
-- os.execute('start "" "' .. url .. '"')
