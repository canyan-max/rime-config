-- 整数边界查询：u16max、i32min；支持 8/16/32/64 位有符号和无符号整数。
-- 数值使用字符串保存，避免 64 位边界溢出或浮点精度损失。
-- 负数的十六进制候选表示相应位宽的补码位模式。
local M = {}
local limits = {
  ["8"] = { unsigned = "255", max = "127", min = "-128" },
  ["16"] = { unsigned = "65535", max = "32767", min = "-32768" },
  ["32"] = { unsigned = "4294967295", max = "2147483647", min = "-2147483648" },
  ["64"] = {
    unsigned = "18446744073709551615",
    max = "9223372036854775807",
    min = "-9223372036854775808",
  },
}

function M.func(input, seg, _env)
  if not seg:has_tag("numeric_limits") then
    return
  end
  local signedness, bits, bound = input:match("^([ui])(%d+)(%l+)$")
  local values = limits[bits]
  if not values or (bound ~= "min" and bound ~= "max") then
    return
  end

  local unsigned = signedness == "u"
  local count = tonumber(bits) / 4
  local decimal, hex
  if unsigned then
    decimal = bound == "max" and values.unsigned or "0"
    hex = string.rep(bound == "max" and "F" or "0", count)
  else
    decimal = values[bound]
    hex = bound == "max" and ("7" .. string.rep("F", count - 1))
      or ("8" .. string.rep("0", count - 1))
  end

  local typename = (unsigned and "uint" or "int") .. bits .. "_t"
  local description = typename .. (bound == "max" and " 最大值" or " 最小值")
  local macro = (unsigned and "UINT" or "INT") .. bits .. "_" .. bound:upper()
  local results = {
    { decimal, description .. " · 十进制" },
    { "0x" .. hex, description .. (decimal:sub(1, 1) == "-" and " · 补码" or " · 十六进制") },
  }
  -- <stdint.h> 只定义 UINT*_MAX，没有 UINT*_MIN。
  if not unsigned or bound == "max" then
    results[#results + 1] = { macro, "<stdint.h> · " .. description }
  end
  for _, result in ipairs(results) do
    local cand = Candidate("numeric_limits", seg.start, seg._end, result[1], result[2])
    cand.quality = 100
    yield(cand)
  end
end

return M
