-- 此资源由 MainModButtonAreaExtension 加载，处于实际 React UI Lua 状态。
local react = ug_require("::/gui/main/react.lua")
local area = ug_require("::/gui/main/main_mod_button_area.tl")
local hooks = ug_require("spy_auto_alternative_terminals::/auto_alternatives.lua")

-- 在插件资源加载时安装，不依赖按钮点击或游戏脚本 GUI update。
-- 引擎已经提供当前模组参数，无需 postRun 写资源作为中转。
local actions = {'IA_SECONDARY_MODE', 'IA_PRECISION_MODE', 'IA_ENHANCED_SNAP'}
local ok, allParams = pcall(function() return api.engine.config.getModParams() end)
local params = ok and allParams and allParams.spy_auto_alternative_terminals
local choice = params and params.activationModifier or 1
local activationAction = actions[choice] or actions[1]
if not ok then
  print('[spy_auto_alternative_terminals] Could not read modifier parameter; using Secondary Mode.')
end
hooks.install(activationAction)

local plugin = react.RegisterPluginRecipe(
  area.MainModButtonAreaExtension,
  "LocalAutoAlternativeTerminalsBootstrap",
  function()
    -- 启用修饰键动作，由游戏处理按键绑定和按下/释放状态。
    react.useInputAction(activationAction, react.iaHandler(function() end))
    -- 不添加按钮或占用界面空间；插件仅用于进入正确的 UI Lua 状态。
    return nil
  end
)

-- .script.lua 资源由 util.useFn 调用 data()，与 ug_require 的普通模块不同。
function data()
  return {BootstrapPlugin = plugin}
end
