# 小狼毫「候选旁英文译词 + 生词本」

把青简（qingjian）「好好输入，顺便多认识一个词」的功能搬进小狼毫（Weasel / RIME）：
打中文时，每个候选旁边多一条英文译词；同时把你看过的词记进生词本，可查学习统计。

```
1  开发  ｜ v. develop
2  编程  ｜ v. program
3  架构  ｜ n. architecture
```

**不改小狼毫 C++ 源码、不用编译**，全部走 RIME 方案层（librime-lua filter），丢进 `%AppData%\Rime` 即用。

## 原理

小狼毫把 RIME 引擎产出的候选原样画到候选窗，每个候选有个 `comment`（注释）字段画在右侧
（拼音方案里就是那行拼音）。本方案用一个 Lua filter，在候选产出时查中→英释义表，把英文
追加到 `comment`，并记一笔曝光到生词本。释义表直接复用青简的 `glossary-en.tsv`（23.2 万词）。

- 译词显示：`lua/en_glossary.lua`（filter）
- 生词本：`lua/en_vocab.lua`（曝光计数 + 落盘 `vocab.tsv`）
- 释义表：`en_glossary.tsv`（由青简 `assets/glossary/glossary-en.tsv` 转换，取第一义）

## 前置：装 librime-lua 插件

本功能依赖 librime 的 Lua 插件。新版小狼毫通常已自带；若候选旁不出现译词且日志报
`unknown component: lua_filter`，按需安装：

- 用 plum（小狼毫菜单 » 重新部署 / 設定工具）：
  `rime.plum` 里装 `librime-lua`；或手动把 `rime.dll` 同目录的 lua 插件补齐。
- 社区方案（rime-ice 等）一般已带 lua 依赖，装了这类方案通常就有了。

## 安装

1. 把 `lua\` 目录整个复制到 `%AppData%\Rime\lua\`
   （即 `en_glossary.lua`、`en_vocab.lua` 放进 `%AppData%\Rime\lua\`）。
2. 把 `en_glossary.tsv` 复制到 `%AppData%\Rime\en_glossary.tsv`。
3. 把 `rime.lua` 的内容并进 `%AppData%\Rime\rime.lua`
   （没有就直接用本文件；有就在末尾加一行 `en_glossary = require("en_glossary")`）。
4. 把 `default.custom.yaml` 复制到 `%AppData%\Rime\default.custom.yaml`
   （已有同名文件就把 `patch` 里的内容并进去）。
5. 小狼毫菜单 » **重新部署**。
6. 打几个字，候选旁应出现英文译词。

> 路径速查：`%AppData%\Rime` 可由小狼毫菜单 » **用户文件夹** 直接打开。

### 用雾凇拼音（rime-ice）？必看

rime-ice 的方案文件自带一份**完整的 `engine/filters` 列表**，所以 `default.custom.yaml`
里追加的 filter 进不到它里面——表现为打字没译词。改在 `%AppData%\Rime\rime_ice.custom.yaml`：

```yaml
patch:
  engine/filters/+:
    - lua_filter@en_glossary
  en_glossary/separator: ' ｜ '
  en_glossary/with_pos: true
```

已有 `rime_ice.custom.yaml` 就把 `engine/filters/+` 两行并到现有 `patch:` 下（`patch:` 只留一个）。
重新部署后打 `kaifa`，「开发」旁应出现 `｜ v. develop`。

> 仍不显示，多半是 filter 找不到释义表：在 `patch` 下加
> `en_glossary/data_path: 'C:\Users\<你>\AppData\Roaming\Rime\en_glossary.tsv'`（写死真实路径）再部署。

## 使用

- 正常打字即可。候选旁会多一条 `｜ v. develop` 这样的译词。
- 想看学习统计：`python vocab_stats.py`（自动读 `%AppData%\Rime\vocab.tsv`）。
  - `--fresh`：只列还没看熟的生词（最近优先）
  - `--top 50`：Top 50 最常看到
- 生词本 `vocab.tsv` 在 `%AppData%\Rime\vocab.tsv`，纯文本可手改。

## 自定义

在 `default.custom.yaml` 的 `patch` 下改：

| 键 | 默认 | 说明 |
|---|---|---|
| `en_glossary/enabled` | `true` | 设 `false` 临时关掉 |
| `en_glossary/separator` | `' ｜ '` | 原注释与译词的分隔 |
| `en_glossary/with_pos` | `true` | `true` 显示 `v. develop`；`false` 只显示 `develop` |
| `en_glossary/data_path` | 自动 | 释义表绝对路径 |
| `en_glossary/vocab_path` | 自动 | 生词本绝对路径 |

**加自己的词**：直接编辑 `%AppData%\Rime\en_glossary.tsv`，一行 `中文\t英文`，重新部署即可。
（对应青简的 PersonalGlossary 个人释义表。）

**只给某个方案开**：删掉 `default.custom.yaml` 里的 `engine/filters/+`，改写
`<方案id>.custom.yaml`，把同一份 `patch` 放进去。

## 与青简的对应

| 青简 | 本实现 |
|---|---|
| `glossary-en.tsv` 候选旁译词 | `en_glossary.tsv` + Lua filter 写进候选 `comment` |
| `VocabularyBook` 看到/上屏/用过 | `en_vocab.lua` → `vocab.tsv`（看到轮次；上屏可由 RIME 自带 user dict 补） |
| `FRESH_UNTIL = 3`（看熟阈值） | 同 |
| 统计页 | `vocab_stats.py` |

## 已知限制

- 译词取第一义；多义词只显示一个英文。
- 生词本记的是“看到（曝光）”轮次——这是青简判断“眼熟/生词”的主信号。
  “上屏过”计数可另由 RIME 自带用户词典补全（RIME 已记录每个上屏词的频次）。
- 释义表 23.2 万条，首次激活输入法时加载一次（约零点几秒），之后常驻内存。
- 仅在装了 librime-lua 的小狼毫上有效。
