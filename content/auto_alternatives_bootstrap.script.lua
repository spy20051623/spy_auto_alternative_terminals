-- 此资源由 MainModButtonAreaExtension 加载，处于实际 React UI Lua 状态。
local react = ug_require("::/gui/main/react.lua")
local area = ug_require("::/gui/main/main_mod_button_area.tl")

local hooks = ug_require("spy_auto_alternative_terminals::/auto_alternatives.lua")
-- 在插件资源加载时安装，不依赖按钮点击或游戏脚本 GUI update。
-- 引擎已经提供当前模组参数，无需 postRun 写资源作为中转。
local ok, allParams = pcall(function() return api.engine.config.getModParams() end)
local params = ok and allParams and allParams.spy_auto_alternative_terminals
-- 旧 activationModifier 的第二项是 Shift，不能复用为新选项中的 Alt。
-- 使用新参数键；未重新选择的旧配置统一回到默认 Ctrl。
local keyboardAction = params and params.activationKey == 2 and 'IA_ENHANCED_SNAP' or 'IA_SECONDARY_MODE'
if not ok then
  print('[spy_auto_alternative_terminals] Could not read keyboard activation key parameter; using Ctrl.')
end
hooks.install(keyboardAction)

local plugin = react.RegisterPluginRecipe(
  area.MainModButtonAreaExtension,
  "LocalAutoAlternativeTerminalsBootstrap",
  function()
    -- 同时启用键盘和手柄修饰动作，覆盖尚未添加第一站的情况。
    -- 各组件的输入配置独立；原版线路工具仍处理 R1/RB 的途经点操作。
    -- 实际新增时按当前输入模式采样，避免将同动作的 Shift 当作手柄 R1/RB。
    react.useInputAction(keyboardAction, react.iaHandler(function() end))
    react.useInputAction('IA_PRECISION_MODE', react.iaHandler(function() end))
    -- 不添加按钮或占用界面空间；插件仅用于进入正确的 UI Lua 状态。
    return nil
  end
)

-- .script.lua 资源由 util.useFn 调用 data()，与 ug_require 的普通模块不同。
function data()
  return {BootstrapPlugin = plugin}
end
