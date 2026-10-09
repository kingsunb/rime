-- rime.lua  ——  librime-lua 组件注册
--
-- 放在 %AppData%\Rime\rime.lua（用户根）。
-- 如果你已经有 rime.lua，只需把下面这行加进去（en_vocab 由 en_glossary 内部 require，不用单独注册）。
-- 如果你没有 rime.lua，本文件可直接用。

en_glossary = require("en_glossary")
