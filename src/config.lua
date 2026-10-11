--[[ config.lua - flat state store. Toggles are plain booleans/numbers/strings
     keyed by name, shared by the UI rows and the feature modules. ]]

local C = {}

C.values = {
    -- farm
    farm = false,
    autoquest = true,
    farmtool = "Melee",
    farmdistance = 20,
    orbit = true,
    bring = true,
    bringdist = 250,
    autoclick = true,
    clickdelay = 0.18,
    -- travel
    tween = true,
    tweenspeed = 170,
    portalhop = false,
    hover = true,
    noclip = true,
    -- combat
    method = "m1",
    fastattack = true,
    attackdist = 60,
    killaura = false,
    aura = 120,
    autobuso = true,
    autoken = true,
    healthskill = 25,
    -- mastery / stats
    automastery = false,
    masterytool = "Blox Fruit",
    masteryvalue = 300,
    autostat = false,
    stat = "Melee",
    statpoints = 1,
    -- races / misc
    autoracev2 = false,
    heal = false,
    esp = false,
    espplayers = false,
    lowend = false,
    antiafk = true,
    walkonwater = false,
    webhook = "",
}

function C.get(k) return C.values[k] end

function C.set(k, v)
    C.values[k] = v
    if C.onChange then pcall(C.onChange, k, v) end
end

function C.toggle(k)
    C.set(k, not C.get(k))
    return C.get(k)
end

return C
