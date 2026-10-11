-- Flat runtime state store shared by all modules. Deliberately simple.
return function(U)
    local store = { tickRate = 0.15 }
    local C = {}

    function C.get(k) return store[k] end
    function C.set(k, v) store[k] = v end

    -- small toggle registry so modules and UI can stay decoupled
    C.toggles = {}
    function C.on(name) return C.toggles[name] == true end
    function C.toggle(name, cb)
        C.toggles[name] = not C.toggles[name]
        if cb then cb(C.toggles[name]) end
        return C.toggles[name]
    end

    return C
end
