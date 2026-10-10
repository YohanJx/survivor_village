#!/usr/bin/env python3
"""Small lexical GDScript policy check; not a parser, formatter, or game test.

Checks explicit declarations, loops, function/signal signatures and bare
containers. Strings/comments are masked so documentation is not treated as code.
Godot must still validate syntax, resource references and behavior separately.
"""

import argparse
import re
from pathlib import Path
from typing import List, Tuple


Finding = Tuple[int, str, str]
ROOT = Path(__file__).resolve().parents[1]


def mask_text(source: str) -> str:
    """Preserve character offsets/newlines while masking comments and strings."""
    result = list(source)
    index = 0
    while index < len(source):
        end = index
        if source[index] == "#":
            end = source.find("\n", index)
            if end < 0:
                end = len(source)
        elif source[index] in ("'", '"'):
            delimiter = source[index]
            if source.startswith(delimiter * 3, index):
                delimiter *= 3
            end = index + len(delimiter)
            while end < len(source):
                if source[end] == "\\":
                    end += 2
                elif source.startswith(delimiter, end):
                    end += len(delimiter)
                    break
                else:
                    end += 1
        else:
            index += 1
            continue
        for position in range(index, min(end, len(source))):
            if source[position] not in "\r\n":
                result[position] = " "
        index = end
    return "".join(result)


def split_parameters(parameters: str) -> List[str]:
    parts = []
    depth = 0
    start = 0
    for index, character in enumerate(parameters):
        if character in "([{":
            depth += 1
        elif character in ")]}":
            depth -= 1
        elif character == "," and depth == 0:
            parts.append(parameters[start:index])
            start = index + 1
    parts.append(parameters[start:])
    return [part.strip() for part in parts if part.strip()]


def inspect_source(source: str) -> List[Finding]:
    code = mask_text(source)
    findings = []

    def add(offset: int, rule: str, message: str) -> None:
        findings.append((code.count("\n", 0, offset) + 1, rule, message))

    patterns = [
        (r"\b(?:var|const)\s+\w+\s*(?::=|=(?!=))", "TYPE001", "声明必须显式写出类型，不能使用 := 或省略类型"),
        (r"\bfor\s+\w+\s+in\b", "TYPE002", "循环变量必须显式写出类型"),
        (r"(?::|->)\s*(?:Array|Dictionary)\b(?!\s*\[)", "TYPE003", "容器必须注明元素/键值类型；边界例外需人工复核"),
    ]
    for pattern, rule, message in patterns:
        for match in re.finditer(pattern, code):
            add(match.start(), rule, message)

    headers = re.compile(r"\b(?P<kind>func|signal)\s*(?:\w+\s*)?\(")
    for match in headers.finditer(code):
        begin = match.end()
        end = begin
        depth = 1
        while end < len(code) and depth:
            depth += (code[end] == "(") - (code[end] == ")")
            end += 1
        if depth:
            # Incomplete syntax belongs to the Godot parser; do not guess.
            continue
        for parameter in split_parameters(code[begin:end - 1]):
            if not re.match(r"\w+\s*:\s*[A-Za-z_]", parameter):
                add(match.start(), "TYPE004", "函数、匿名函数和信号参数必须显式写出类型")
        if match.group("kind") == "func" and not re.match(r"\s*->\s*[A-Za-z_]", code[end:]):
            add(match.start(), "TYPE005", "函数和匿名函数必须声明返回类型；无返回值使用 void")

    if "\r" in source:
        findings.append((1, "FORMAT001", "文件必须使用 LF 换行"))
    return sorted(set(findings))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path, help="检查指定 .gd 文件或目录；默认 scripts/ 与 tests/")
    arguments = parser.parse_args()
    paths = arguments.paths or [ROOT / "scripts", ROOT / "tests"]
    files = set()
    for path in paths:
        if not path.exists():
            parser.error("路径不存在：%s" % path)
        if path.is_dir():
            files.update(path.rglob("*.gd"))
        elif path.suffix == ".gd":
            files.add(path)
        else:
            parser.error("仅接受 .gd 文件或目录：%s" % path)
    if not files:
        parser.error("没有找到可检查的 .gd 文件")
    count = 0
    for path in sorted(files):
        try:
            with path.open(encoding="utf-8", newline="") as stream:
                findings = inspect_source(stream.read())
        except (OSError, UnicodeError) as error:
            print("%s:1: IO001 %s" % (path, error))
            count += 1
            continue
        for line, rule, message in findings:
            print("%s:%d: %s %s" % (path, line, rule, message))
        count += len(findings)
    print("规范基础检查：%d 个脚本，%d 项问题。架构、语法与行为仍需单独验证。" % (len(files), count))
    return 1 if count else 0


if __name__ == "__main__":
    raise SystemExit(main())
