#!/usr/bin/env python3
# vocab_stats.py  ——  生词本统计（青简“统计页”的等价物）
#
# 读取小狼毫用户根下的 vocab.tsv（由 en_glossary filter 写出），打印学习摘要：
#   已见词数、眼熟（看到 >= 3）、生词（看到 < 3）、本周新词、最常看到 Top N。
#
# 用法：
#   python vocab_stats.py                 # 自动找 %AppData%\Rime\vocab.tsv
#   python vocab_stats.py /path/vocab.tsv # 指定路径
#   python vocab_stats.py --top 30        # Top 30
#   python vocab_stats.py --fresh         # 只列还没看熟的生词

import sys
import os
import datetime
from collections import defaultdict

FRESH_UNTIL = 3          # 与 en_vocab.lua 一致
RECENT_DAYS = 7


def default_path():
    appdata = os.environ.get("APPDATA")
    if appdata:
        return os.path.join(appdata, "Rime", "vocab.tsv")
    return os.path.expanduser("~/.config/ibus/rime/vocab.tsv")


def parse(path):
    entries = []
    if not os.path.exists(path):
        return entries
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            fld = line.split("\t")
            if len(fld) < 7 or not fld[0] or not fld[1]:
                continue
            try:
                seen = int(fld[2]); committed = int(fld[3]); used = int(fld[4])
            except ValueError:
                continue
            entries.append({
                "zh": fld[0], "en": fld[1],
                "seen": seen, "committed": committed, "used": used,
                "first": fld[5], "last": fld[6],
            })
    return entries


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    path = args[0] if args else default_path()
    top = 20
    only_fresh = "--fresh" in sys.argv
    for a in sys.argv[1:]:
        if a == "--top" and sys.argv.index(a) + 1 < len(sys.argv):
            top = int(sys.argv[sys.argv.index(a) + 1])

    entries = parse(path)
    if not entries:
        print(f"没读到生词记录：{path}")
        print("先打几个字（候选旁出现译词）再跑本脚本。")
        return

    today = datetime.date.today()
    recent_from = today - datetime.timedelta(days=RECENT_DAYS - 1)

    def to_date(s):
        try:
            return datetime.date.fromisoformat(s)
        except ValueError:
            return None

    total = len(entries)
    familiar = sum(1 for e in entries if e["seen"] >= FRESH_UNTIL)
    fresh = total - familiar
    committed = sum(1 for e in entries if e["committed"] > 0)
    new_week = 0
    for e in entries:
        d = to_date(e["first"])
        if d and recent_from <= d <= today:
            new_week += 1

    print(f"生词本：{path}")
    print(f"  已见词数 : {total}")
    print(f"  眼熟      : {familiar}  （看到 >= {FRESH_UNTIL} 次）")
    print(f"  生词      : {fresh}  （看到 <  {FRESH_UNTIL} 次）")
    print(f"  上屏过    : {committed}")
    print(f"  本周新词  : {new_week}")
    print()

    if only_fresh:
        rows = [e for e in entries if e["seen"] < FRESH_UNTIL]
        rows.sort(key=lambda e: e["first"], reverse=True)
        print(f"还没看熟的生词（最近优先），共 {len(rows)} 个：")
        for e in rows[:top]:
            print(f"  {e['zh']}\t{e['en']}\t看到{e['seen']}\t首见{e['first']}")
        return

    rows = sorted(entries, key=lambda e: e["seen"], reverse=True)
    print(f"最常看到 Top {top}:")
    for e in rows[:top]:
        mark = "熟" if e["seen"] >= FRESH_UNTIL else "生"
        print(f"  [{mark}] {e['zh']}\t{e['en']}\t看到{e['seen']}\t上屏{e['committed']}")


if __name__ == "__main__":
    main()
