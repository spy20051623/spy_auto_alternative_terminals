-- TF3 build 25754343：只在最终提交前的原版站台分配结果上添加备用站台。
-- 原版 autoLoadConfig 与主站台分配的输入、顺序和货物配置保持完整。
local PREFIX = '[spy_auto_alternative_terminals] '
local installed = false
local activationAction = 'IA_SECONDARY_MODE'
local reportedInputError = false
local wrappedActions = setmetatable({}, {__mode = 'k'})
local activeAdd
local unpackValues = table.unpack or unpack
local function pack(...) return {n = select('#', ...), ...} end
local function log(message) print(PREFIX .. message) end

local function collectAlternatives(primary)
  local group = api.engine.getComponent(primary.stationGroup, api.type.ComponentType.STATION_GROUP)
  assert(group and group.stations, 'station group unavailable')
  assert(primary.station >= 0 and primary.terminal >= 0, 'primary terminal unavailable')
  local alternatives, seen = {}, {}
  for _, terminal in ipairs(primary.alternativeTerminals or {}) do
    local key = terminal.station .. ':' .. terminal.terminal
    if not seen[key] then seen[key] = true; alternatives[#alternatives + 1] = terminal end
  end
  for stationIndex1, entity in ipairs(group.stations) do
    local station = api.engine.getComponent(entity, api.type.ComponentType.STATION)
    assert(station and station.terminals, 'station terminals unavailable')
    for terminalIndex1, _ in ipairs(station.terminals) do
      local station0, terminal0 = stationIndex1 - 1, terminalIndex1 - 1
      -- 与原版 getTerminalAlternative 的选择条件一致：同站组，排除主站台。
      -- 不调用其中仅用于绘制界面的线路 COLOR 查询，无需新线路实体特判。
      local key = station0 .. ':' .. terminal0
      if (station0 ~= primary.station or terminal0 ~= primary.terminal) and not seen[key] then
        seen[key] = true
        alternatives[#alternatives + 1] = api.type.StationTerminal.new(station0, terminal0)
      end
    end
  end
  return alternatives
end

local function wrapAction(common, actionName)
  if type(common) ~= 'table' or type(common[actionName]) ~= 'function' then return end
  local wrappers = wrappedActions[common]
  if not wrappers then wrappers = {}; wrappedActions[common] = wrappers end
  if wrappers[actionName] == common[actionName] then return end
  local original = common[actionName]
  local wrapper = function(...)
    -- 在实际新增动作开始时采样，不依赖稍后的提交时按键是否仍按住。
    local ok, held = pcall(function()
      return api.gui.inputAction.modifierOnlyActionIsActive(activationAction)
    end)
    if not ok then
      if not reportedInputError then log('Modifier state unavailable: ' .. tostring(held)); reportedInputError = true end
      return original(...)
    end
    if not held then return original(...) end
    local prior = activeAdd
    local context = {readyForCommit = false, selected = false}
    activeAdd = context
    local args = pack(...)
    local result = pack(pcall(original, unpackValues(args, 1, args.n)))
    activeAdd = prior
    if result[1] and context.newStop and not context.selected then
      log(actionName .. ': final assignment hook was not reached or selection skipped.')
    end
    if not result[1] then error(result[2], 0) end
    return unpackValues(result, 2, result.n)
  end
  common[actionName] = wrapper
  wrappers[actionName] = wrapper
end

local function install(lineUtil)
  assert(type(lineUtil) == 'table' and type(lineUtil.makeLineActionDescriptor) == 'function'
    and type(lineUtil.makeNewStop) == 'function' and type(lineUtil.autoLoadConfig) == 'function'
    and type(lineUtil.autoAssignTerminals) == 'function', 'unsupported LineUtil interface')
  local originalDescriptor = lineUtil.makeLineActionDescriptor
  local originalNewStop = lineUtil.makeNewStop
  local originalLoadConfig = lineUtil.autoLoadConfig
  local originalAssign = lineUtil.autoAssignTerminals
  lineUtil.makeLineActionDescriptor = function(common, ...)
    wrapAction(common, 'addStop')
    wrapAction(common, 'newLine')
    return originalDescriptor(common, ...)
  end
  lineUtil.makeNewStop = function(...)
    local result = pack(originalNewStop(...))
    if activeAdd then activeAdd.newStop = result[1] end
    return unpackValues(result, 1, result.n)
  end
  lineUtil.autoLoadConfig = function(...)
    -- 此包装仅记录阶段，不读取、更改任何参数或装载配置。
    local context = activeAdd
    if context then context.readyForCommit = false end
    local result = pack(originalLoadConfig(...))
    if context then context.readyForCommit = true end
    return unpackValues(result, 1, result.n)
  end
  lineUtil.autoAssignTerminals = function(entity, path, ...)
    local result = pack(originalAssign(entity, path, ...))
    local context = activeAdd
    -- autoLoadConfig 内的中间分配不能添加备用；只处理后续提交时的分配结果。
    if context and context.newStop and context.readyForCommit and not context.selected then
      local ok, message = pcall(function()
        local stopIndex = 0
        local primary
        for _, via in ipairs(path) do
          if via.stop then
            stopIndex = stopIndex + 1
            if via == context.newStop then primary = result[1][stopIndex]; break end
          end
        end
        assert(primary, 'new stop not found in final assignments')
        local alternatives = collectAlternatives(primary)
        -- 全部查询成功后一次写入。主站台、货物、等待时间、途经点不作改动。
        primary.alternativeTerminals = alternatives
        context.newStop.stop.alternativeTerminals = alternatives
        context.selected = true
        log('Selected ' .. #alternatives .. ' alternatives in final assignment at stop ' .. stopIndex .. '.')
      end)
      if not ok then log('Skipped auto-selection: ' .. tostring(message)) end
    end
    return unpackValues(result, 1, result.n)
  end
  installed = true
  log('Installed React UI hooks v1; hold ' .. activationAction .. ' to select alternatives.')
end

return {
  install = function(action)
    if installed then return end
    assert(action == nil or action == 'IA_SECONDARY_MODE' or action == 'IA_PRECISION_MODE'
      or action == 'IA_ENHANCED_SNAP', 'unsupported activation modifier')
    activationAction = action or activationAction
    install(ug_require('::/gui/line_vehicle_mgmt/line_util.tl'))
  end,
}
