-- Public adapter and naming-screen behavior from Gen1 Modern UI 0.9.2. It
-- checks registered source screens before classifying its built-in presenters.
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
    -- 0.9.2 added a built-in NamingScreen presenter. When Menu UI is on it
    -- otherwise suppresses the native screen after no adapter claims it.
    if type(state) == "table" and state.screenId == "NamingScreen" then
      return true
    end
    return nil
  end
end
