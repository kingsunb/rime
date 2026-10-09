-- en_vocab.lua  ——  生词本（候选曝光计数）
--
-- 对齐青简 qingjian 的 VocabularyBook：记录每个中文候选被“看到”的轮次，
-- 落盘到 vocab.tsv。看到轮次 < FRESH_UNTIL 算“生词”，>= 算“眼熟”。
--
-- 文件格式（TSV，UTF-8、LF，首行注释）：
--   中文 \t 英文 \t 看到 \t 上屏 \t 用过 \t 首见 \t 末见
-- 英文可能含空格（如 "thankless task"），但不含制表符；按 \t 切分即可。
-- 坏行跳过，读不了就只在内存里记。
--
-- 落盘策略：按时间节流，默认每 30 秒至多写一次，避免每次按键都写盘；
-- fini 时再强制写一次。崩溃最多丢 30 秒的曝光，对学习日志可接受。

local M = {}

M.FRESH_UNTIL = 3        -- 与青简一致：看到 >= 3 次算眼熟
local FLUSH_INTERVAL = 30  -- 落盘节流（秒）

-- 按 \t 切分一行（字段里允许空格）
local function tsv_split(line)
  local fields = {}
  local rest = line
  while true do
    local pos = rest:find("\t", 1, true)
    if not pos then
      fields[#fields + 1] = rest
      break
    end
    fields[#fields + 1] = rest:sub(1, pos - 1)
    rest = rest:sub(pos + 1)
  end
  return fields
end

local function today()
  return os.date("%Y-%m-%d")
end

local function now()
  return os.time()
end

-- 打开（或新建）一本生词记录。path 为 vocab.tsv 的完整路径。
function M.open(path)
  local book = {
    path = path,
    entries = {},      -- 中文 -> {en, seen, committed, used, first, last}
    dirty = false,
    last_flush = nil,
  }
  local f = io.open(path, "r")
  if f then
    for line in f:lines() do
      if line ~= "" and line:sub(1, 1) ~= "#" then
        local fld = tsv_split(line)
        if #fld >= 7 and fld[1] ~= "" and fld[2] ~= "" then
          book.entries[fld[1]] = {
            en = fld[2],
            seen = tonumber(fld[3]) or 0,
            committed = tonumber(fld[4]) or 0,
            used = tonumber(fld[5]) or 0,
            first = fld[6],
            last = fld[7],
          }
        end
      end
    end
    f:close()
  end
  return book
end

-- 记一次曝光（候选被看到）。
function M.record_exposure(book, zh, en)
  if not book or zh == nil or zh == "" or en == nil or en == "" then
    return
  end
  local d = today()
  local e = book.entries[zh]
  if e then
    e.seen = e.seen + 1
    e.last = d
    if en ~= e.en then e.en = en end
  else
    book.entries[zh] =
      { en = en, seen = 1, committed = 0, used = 0, first = d, last = d }
  end
  book.dirty = true
  -- 时间节流落盘
  local t = now()
  if not book.last_flush or t - book.last_flush >= FLUSH_INTERVAL then
    M.save(book)
    book.last_flush = t
  end
end

-- 记一次上屏（候选被选中输出）。可选：由 processor 调用。
function M.record_commit(book, zh, en)
  if not book or zh == nil or zh == "" then
    return
  end
  local d = today()
  local e = book.entries[zh]
  if e then
    e.committed = e.committed + 1
    e.used = e.used + 1
    e.last = d
    if en and en ~= "" and en ~= e.en then e.en = en end
  elseif en and en ~= "" then
    book.entries[zh] =
      { en = en, seen = 0, committed = 1, used = 1, first = d, last = d }
  end
  book.dirty = true
end

-- 落盘（没改动就不写）。
function M.save(book)
  if not book or not book.dirty or not book.path then
    return
  end
  local f = io.open(book.path, "w")
  if not f then
    return
  end
  f:write("# 中文\t英文\t看到\t上屏\t用过\t首见\t末见\n")
  local keys = {}
  for k in pairs(book.entries) do
    keys[#keys + 1] = k
  end
  table.sort(keys)  -- 按字节序，稳定输出
  for _, zh in ipairs(keys) do
    local e = book.entries[zh]
    f:write(string.format("%s\t%s\t%d\t%d\t%d\t%s\t%s\n",
      zh, e.en, e.seen, e.committed, e.used, e.first, e.last))
  end
  f:close()
  book.dirty = false
end

return M
