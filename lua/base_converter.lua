-- 进制转换：hexFF、dec255、bin1010。
-- 仅处理明确前缀；最多 64 位，使用逐位运算避免大整数精度损失。
local M = {}
local digits = "0123456789ABCDEF"
local sources = {
  hex = { base = 16, pattern = "^[0-9a-fA-F]+$" },
  dec = { base = 10, pattern = "^[0-9]+$" },
  bin = { base = 2, pattern = "^[01]+$" },
}
local targets = {
  { base = 10, prefix = "", comment = "十进制" },
  { base = 16, prefix = "0x", comment = "十六进制" },
  { base = 2, prefix = "0b", comment = "二进制" },
}

local function convert(value, source_base, target_base)
  -- 目标进制的小端数位数组；每步中间值始终很小。
  local result = { 0 }
  for i = 1, #value do
    local carry = digits:find(value:sub(i, i):upper(), 1, true) - 1
    for j = 1, #result do
      local n = result[j] * source_base + carry
      result[j] = n % target_base
      carry = math.floor(n / target_base)
    end
    while carry > 0 do
      result[#result + 1] = carry % target_base
      carry = math.floor(carry / target_base)
    end
  end
  local text = {}
  for i = #result, 1, -1 do
    text[#text + 1] = digits:sub(result[i] + 1, result[i] + 1)
  end
  return table.concat(text)
end

local function signed_hex_to_decimal(value)
  local high_digit = digits:find(value:sub(1, 1):upper(), 1, true) - 1
  if high_digit < 8 then
    return nil
  end

  -- 在输入位宽内求二进制补码的绝对值：逐位取反后加一。
  local magnitude = {}
  local carry = 1
  for i = #value, 1, -1 do
    local digit = digits:find(value:sub(i, i):upper(), 1, true) - 1
    local complemented = 15 - digit + carry
    if complemented >= 16 then
      complemented = complemented - 16
      carry = 1
    else
      carry = 0
    end
    magnitude[i] = digits:sub(complemented + 1, complemented + 1)
  end
  return "-" .. convert(table.concat(magnitude), 16, 10)
end

function M.func(input, seg, _env)
  local source = sources[input:sub(1, 3)]
  if not source or not seg:has_tag("base_conversion") then
    return
  end
  local value = input:sub(4)
  if #value == 0 or #value > 64 or not value:match(source.pattern) then
    return
  end
  for _, target in ipairs(targets) do
    if target.base ~= source.base then
      local text = target.prefix .. convert(value, source.base, target.base)
      local cand = Candidate("base_conversion", seg.start, seg._end, text, target.comment)
      cand.quality = 100
      yield(cand)
      if source.base == 16 and target.base == 10 then
        local signed_text = signed_hex_to_decimal(value)
        if signed_text then
          local signed_comment = "有符号 " .. (#value * 4) .. " 位十进制（补码）"
          local signed_cand = Candidate(
            "base_conversion",
            seg.start,
            seg._end,
            signed_text,
            signed_comment
          )
          signed_cand.quality = 100
          yield(signed_cand)
        end
      end
    end
  end
end

return M
