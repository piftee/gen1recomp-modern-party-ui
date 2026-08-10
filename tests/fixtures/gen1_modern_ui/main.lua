-- Public adapter surface from Gen1 Modern UI 0.8.4. The real compositor only
-- suppresses a matched source screen when canSuppressNative is explicitly
-- true; Modern Party UI deliberately publishes false so its custom renderer
-- remains authoritative for party and summary screens.
return function(mod)
  mod.exports.registrations = {}

  mod.exports.registerAdapter = function(spec)
    mod.exports.registrations[#mod.exports.registrations + 1] = spec
    return true
  end

  mod.exports.shouldSuppress = function(state)
    for _, spec in ipairs(mod.exports.registrations) do
      for _, screen in pairs(spec.contract.screens or {}) do
        if screen.match(state) then
          return screen.canSuppressNative == true
        end
      end
    end
    return nil
  end
end
