-- en_glossary.lua  ——  候选旁显示英文译词（“顺便学一个词”）
--
-- 对齐青简 qingjian 的核心功能：每个中文候选旁边追加一条英文译词，
-- 让英文学习自然发生在日常输入里。译词只是辅助信息，不替换候选本身。
--
-- 数据：en_glossary.tsv，格式  词 \t [词性. ]译词（取第一义），UTF-8、LF。
--   放在脚本同目录（lua/）或上一级（用户根 %AppData%\Rime）均可，自动查找。
-- 生词本：vocab.tsv，写到用户根；曝光计数由 en_vocab.lua 负责。
--
-- 在方案里启用：engine/filters 末尾加  - lua_filter@en_glossary
-- 可选配置（写进 default.custom.yaml 的 patch）：
--   en_glossary/enabled: true        # 关掉就设 false
--   en_glossary/separator: ' ｜ '    # 译词与原注释之间的分隔
--   en_glossary/with_pos: true       # 译词带词性（v. develop）；false 则只显示 develop
--   en_glossary/data_path: ''        # 释义表绝对路径，留空则自动查找
--   en_glossary/vocab_path: ''       # 生词本绝对路径，留空则用 用户根/vocab.tsv

local vocab = require("en_vocab")

local M = {}

-- 模块级缓存：整个 Lua VM 生命周期只加载一次（切方案不重读）
local glossary = nil     -- 中文 -> 英文串（含词性）
local book = nil         -- 生词本
local cfg = nil          -- {enabled, separator, with_pos}
local inited = false

-- 捕获本脚本路径（用于定位数据文件）
local _script_src = debug.getinfo(1, "S").source
if _script_src and _script_src:sub(1, 1) == "@" then
  _script_src = _script_src:sub(2)
end

-- 去掉最后一段路径，得到目录
local function parent_dir(path)
  if not path then return nil end
  local stripped = path:gsub("[/\\][^/\\]*$", "")
  if stripped == path then return nil end
  return stripped
end

-- 在若干候选位置里找一个已存在的文件
local function find_existing(name)
  if not _script_src then return nil end
  local dir = parent_dir(_script_src)
  if dir then
    local p = dir .. "/" .. name
    local f = io.open(p, "r")
    if f then f:close(); return p end
    local parent = parent_dir(dir)
    if parent then
      p = parent .. "/" .. name
      f = io.open(p, "r")
      if f then f:close(); return p end
    end
  end
  return nil
end

-- 取一个可写目录（用户根优先）
local function writable_dir()
  if not _script_src then return nil end
  local dir = parent_dir(_script_src)
  if not dir then return nil end
  local parent = parent_dir(dir)
  return parent or dir
end

-- 安全读配置
local function cfg_str(env, key, default)
  local ok, val = pcall(function()
    return env.engine.schema.config:get_string(key)
  end)
  if ok and val ~= nil and val ~= "" then return val end
  return default
end
local function cfg_bool(env, key, default)
  local ok, val = pcall(function()
    return env.engine.schema.config:get_bool(key)
  end)
  if ok and val ~= nil then return val end
  return default
end

-- 去掉词性前缀：“v. develop” -> “develop”
local function strip_pos(s)
  return (s:gsub("^%a+%.%s+", ""))
end

-- 加载释义表到内存哈希
local function load_glossary(path)
  local t = {}
  local f = io.open(path, "r")
  if not f then return t end
  for line in f:lines() do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local pos = line:find("\t", 1, true)
      if pos then
        local zh = line:sub(1, pos - 1)
        local en = line:sub(pos + 1)
        -- 去掉行内多余的分义（只取第一义，已由转换保证；此处再兜底）
        local p2 = en:find("\t", 1, true)
        if p2 then en = en:sub(1, p2 - 1) end
        if zh ~= "" and en ~= "" then
          t[zh] = en
        end
      end
    end
  end
  f:close()
  return t
end

function M.init(env)
  if inited then return end
  inited = true

  cfg = {
    enabled = cfg_bool(env, "en_glossary/enabled", true),
    separator = cfg_str(env, "en_glossary/separator", " ｜ "),
    with_pos = cfg_bool(env, "en_glossary/with_pos", true),
  }
  if not cfg.enabled then return end

  -- 释义表路径：配置 > 自动查找
  local data_path = cfg_str(env, "en_glossary/data_path", "")
  if data_path == "" then
    data_path = find_existing("en_glossary.tsv")
  end
  if data_path then
    glossary = load_glossary(data_path)
  end

  -- 生词本路径：配置 > 用户根/vocab.tsv
  local vocab_path = cfg_str(env, "en_glossary/vocab_path", "")
  if vocab_path == "" then
    local d = writable_dir()
    if d then vocab_path = d .. "/vocab.tsv" end
  end
  if vocab_path then
    book = vocab.open(vocab_path)
  end
end

function M.fini(env)
  -- 切方案 / 引擎退出时落盘
  if book then
    vocab.save(book)
  end
end

function M.func(input, env)
  if not inited then M.init(env) end
  if not cfg or not cfg.enabled or not glossary then
    for cand in input:iter() do
      yield(cand)
    end
    return
  end

  local sep = cfg.separator
  local with_pos = cfg.with_pos
  for cand in input:iter() do
    local zh = cand.text
    local en = zh and glossary[zh] or nil
    if en then
      if not with_pos then
        en = strip_pos(en)
      end
      if en ~= "" then
        local existing = cand.comment or ""
        local genuine = cand:get_genuine()
        if existing ~= "" then
          genuine.comment = existing .. sep .. en
        else
          genuine.comment = en
        end
        if book then
          vocab.record_exposure(book, zh, en)
        end
      end
    end
    yield(cand)
  end
end

return M
