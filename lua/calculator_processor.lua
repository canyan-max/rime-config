-- 让计算器候选使用回车上屏“表达式 = 结果”。
-- 空格仍按编辑器默认行为上屏当前候选。
local M = {}

function M.init(env)
  local config = env.engine.schema.config
  env.prefix = config:get_string("calculator/prefix") or "cC"
end

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
  if not candidate or candidate.type ~= "calc" or candidate.comment ~= "" then
    return 2
  end

  local input = context.input
  if input:sub(1, #env.prefix) ~= env.prefix then
    return 2
  end
  local expression = input:sub(#env.prefix + 1)
  if expression == "" then
    return 2
  end

  local result = candidate.text
  local combined_prefix = expression .. "="
  if result:sub(1, #combined_prefix) == combined_prefix then
    result = result:sub(#combined_prefix + 1)
  end
  if result == "" then
    return 2
  end

  env.engine:commit_text(expression .. " = " .. result)
  context:clear()
  return 1
end

return M
