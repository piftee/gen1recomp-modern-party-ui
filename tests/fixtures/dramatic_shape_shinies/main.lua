-- Minimal public interface from DramaticShape 1.8.2. The real mod exposes
-- modules through mod.exports.lib.require; Modern Party UI must use that seam
-- because its instance renderer intentionally replaces SummaryMenu's native
-- palette method.
return function(mod)
  local calls = { paletteRequests = 0, colorTransforms = 0 }
  local modules = {
    Shiny = {
      isShiny = function(mon)
        return type(mon) == "table" and mon.shiny == true
      end,
    },
    ShinyPalette = {
      paletteTransform = function(dex)
        calls.paletteRequests = calls.paletteRequests + 1
        if not dex then return nil end
        return function(r, g, b)
          calls.colorTransforms = calls.colorTransforms + 1
          -- Deliberately conspicuous rotation so the regression can prove the
          -- returned transform, not a hard-coded palette, was consumed.
          return b, r, g
        end
      end,
    },
  }

  mod.exports.lib = {
    require = function(name) return modules[name] end,
  }
  mod.exports.fixtureCalls = calls
end
