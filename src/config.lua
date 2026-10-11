--[[ config.lua - flat state store. Toggles are plain booleans keyed by name,
     shared by the UI rows and the feature modules. ]]

local C = {}

C.values = {
    -- farm
    farm = false,
    autoquest = true,
    farmdistance = 20,
    orbit = true,
    bring = true,
    bringdist = 250,
    -- travel
    tween = true,
    tweenspeed = 170,
    hover = true,
    noclip = true,
    -- combat
    weapon = "Melee",
    method = "m1",
    fastattack = true,
    attackdist = 60,
    killaura = false,
    aura = 120,
    autobuso = true,
    autoken = true,
    -- player
    autostat = false,
    stat = "Melee",
    heal = false,
    -- misc
    esp = false,
    lowend = false,
    antiafk = false,
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
