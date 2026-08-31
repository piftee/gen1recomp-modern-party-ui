-- Focused fixture for FAFFO's Moves Manager 1.0.1. It mirrors the public
-- semantic contract and leaves all navigation/mutation on its source state.
return function(mod)
  local Manager = {}
  Manager.__index = Manager
  Manager.screenId = "MovesManager"
  Manager.isOpaque = true

  local function moveDef(state, move)
    return move and state.game.data.moves[move.id] or nil
  end

  function Manager.new(game, mon)
    return setmetatable({
      game = game,
      mon = mon,
      mode = "known",
      slot = 1,
      detailPage = 1,
      pool = {
        { id = "FIX_BITE", name = "BITE" },
        { id = "FIX_GUST", name = "GUST" },
      },
      poolIndex = 1,
      poolScroll = 0,
      swapSlot = nil,
      sourceUpdateCalls = 0,
    }, Manager)
  end

  function Manager:monName()
    return self.mon.nickname or self.mon.species or "POKEMON"
  end

  function Manager:currentMove()
    return self.mon.moves and self.mon.moves[self.slot] or nil
  end

  function Manager:candidate()
    return self.pool[self.poolIndex]
  end

  function Manager:swapMoves(a, b)
    local moves = self.mon.moves or {}
    if a == b or not moves[a] or not moves[b] then return false end
    moves[a], moves[b] = moves[b], moves[a]
    return true
  end

  function Manager:showCurrentDetail()
    if self:currentMove() then
      self.detailPage = 1
      self.mode = "current_detail"
    else
      self.mode = "pool"
    end
  end

  function Manager:openPool()
    self.mode = "pool"
  end

  function Manager:teachCandidate()
    local candidate = self:candidate()
    if not candidate then return false end
    self.mon.moves[self.slot] = { id = candidate.id, pp = 20 }
    self.mode = "known"
    self.swapSlot = nil
    self.mon.movesManagerTeachCalls = (self.mon.movesManagerTeachCalls or 0) + 1
    return true
  end

  function Manager:update()
    self.sourceUpdateCalls = self.sourceUpdateCalls + 1
    local input = self.game.input
    if self.mode == "known" then
      if input:wasPressed("up") then
        self.slot = self.slot > 1 and self.slot - 1 or 4
      elseif input:wasPressed("down") then
        self.slot = self.slot < 4 and self.slot + 1 or 1
      elseif input:wasPressed("select") then
        if self.swapSlot then
          self:swapMoves(self.swapSlot, self.slot)
          self.swapSlot = nil
        elseif self:currentMove() then
          self.swapSlot = self.slot
        end
      elseif input:wasPressed("a") then
        if self.swapSlot then
          self:swapMoves(self.swapSlot, self.slot)
          self.swapSlot = nil
        else
          self:showCurrentDetail()
        end
      elseif input:wasPressed("b") then
        if self.swapSlot then self.swapSlot = nil else self.game.stack:pop() end
      end
    elseif self.mode == "pool" then
      if input:wasPressed("up") then
        self.poolIndex = self.poolIndex > 1 and self.poolIndex - 1 or #self.pool
      elseif input:wasPressed("down") then
        self.poolIndex = self.poolIndex < #self.pool and self.poolIndex + 1 or 1
      elseif input:wasPressed("a") then
        self.detailPage = 1
        self.mode = "candidate_detail"
      elseif input:wasPressed("b") then
        self.mode = "current_detail"
      end
    elseif input:wasPressed("left") then
      self.detailPage = self.detailPage > 1 and self.detailPage - 1 or 3
    elseif input:wasPressed("right") or input:wasPressed("select") then
      self.detailPage = self.detailPage < 3 and self.detailPage + 1 or 1
    elseif input:wasPressed("a") then
      if self.mode == "candidate_detail" then self:teachCandidate()
      else self:openPool() end
    elseif input:wasPressed("b") then
      self.mode = self.mode == "candidate_detail" and "pool" or "known"
      self.detailPage = 1
    end
  end

  function Manager:draw()
    mod.exports.nativeDrawCalls = (mod.exports.nativeDrawCalls or 0) + 1
  end

  local function knownModel(state)
    local rows = {}
    for i = 1, 4 do
      local move = state.mon.moves and state.mon.moves[i]
      local def = moveDef(state, move)
      rows[i] = {
        label = move and ((def and def.name) or move.id) or "EMPTY SLOT",
        value = move and ("PP %d/%d"):format(move.pp or 0,
          (def and def.pp) or move.pp or 0) or "--",
        marker = state.swapSlot == i,
        enabled = true,
      }
    end
    return {
      title = "MOVES - " .. state:monName(),
      rows = rows,
      index = state.slot,
      scroll = 0,
      footer = state.swapSlot
        and { "A/SELECT SWAP", "B CANCEL" }
        or { "A DETAILS", "SELECT SWAP", "B BACK" },
    }
  end

  local function poolModel(state)
    local rows = {}
    for i, entry in ipairs(state.pool) do
      local def = state.game.data.moves[entry.id] or {}
      rows[i] = { label = entry.name, value = def.type or "NORMAL", enabled = true }
    end
    return {
      title = ("REMEMBERED MOVES %d/%d"):format(state.poolIndex, #rows),
      rows = rows,
      index = state.poolIndex,
      scroll = state.poolScroll,
      footer = { "A DETAILS", "L/R PAGE", "B BACK" },
    }
  end

  local function detailModel(state, candidate)
    local entry = candidate and state:candidate() or state:currentMove()
    local id = entry and entry.id
    local def = id and state.game.data.moves[id] or {}
    local rows = {
      { label = def.name or id or "MOVE DATA MISSING", header = true,
        enabled = false },
      { label = "TYPE", value = def.type or "NORMAL", enabled = false },
      { label = "CLASS", value = def.category or "PHYSICAL", enabled = false },
      { label = "POWER", value = def.power or 0, enabled = false },
      { label = "ACCURACY", value = tostring(def.accuracy or 100) .. "%",
        enabled = false },
      { label = "PP", value = def.pp or 0, enabled = false },
      { label = "PRIORITY", value = def.priority or 0, enabled = false },
      { label = "EFFECT", value = def.effect or "NONE", enabled = false },
      { label = candidate and "TEACH MOVE" or "CHANGE MOVE", value = "A",
        marker = true, enabled = true },
    }
    return {
      title = ("MOVE DETAILS %d/3"):format(state.detailPage),
      rows = rows,
      index = #rows,
      scroll = math.max(0, #rows - 7),
      footer = { "L/R PAGE", candidate and "A TEACH" or "A CHANGE", "B BACK" },
    }
  end

  local contract = {
    apiVersion = 1,
    screens = {
      moves_manager = {
        match = function(state)
          return type(state) == "table" and state.screenId == "MovesManager"
            and type(state.mon) == "table" and type(state.mode) == "string"
        end,
        canSuppressNative = true,
        model = function(_, state)
          if state.mode == "known" then return knownModel(state) end
          if state.mode == "pool" then return poolModel(state) end
          return detailModel(state, state.mode == "candidate_detail")
        end,
        actions = {},
      },
    },
  }

  mod.exports.gen1ModernUi = contract
  mod.content.screens:register("MovesManager", {
    new = function(game, mon) return Manager.new(game, mon) end,
  })

  local modern = mod.find("gen1_modern_ui")
  if modern and modern.exports and type(modern.exports.registerAdapter) == "function" then
    modern.exports.registerAdapter({
      owner = "moves_manager",
      version = "1.0.1",
      contract = contract,
    })
  end

  mod.hooks:wrap("ui.party.submenu", function(nextFn, game, items, mon, ctx)
    local out = nextFn(game, items, mon, ctx)
    if not (ctx and ctx.battle) then
      out[#out + 1] = {
        id = "MOVES",
        label = "MOVES",
        onSelect = function(selected, selectedGame)
          mod.ui.push(selectedGame or game, "MovesManager", selected or mon)
        end,
      }
    end
    return out
  end)
end
