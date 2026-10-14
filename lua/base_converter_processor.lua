-- 让进制转换候选支持使用主键盘或小键盘回车上屏。
-- 普通输入的回车行为仍由 editor/bindings/Return 决定。
local M = {}

function M.func(key, env)
  if key:release() then
    return 2
  end

  local key_repr = key:repr()
  if key_repr ~= "Return" and key_repr ~= "KP_Enter" then
    return 2
  end

  local context = env.engine.context
  if not context:has_menu() then
    return 2
  end

  local candidate = context:get_selected_candidate()
  if not candidate or candidate.type ~= "base_conversion" then
    return 2
  end

  env.engine:commit_text(candidate.text)
  context:clear()
  return 1
end

return M
