#!/usr/bin/env python3
"""
semantic-patches.py - 语义化 Patch 应用脚本

针对简单的代码删除/替换使用正则表达式实现，避免对行号的依赖。
这是多级退避策略的第4级，当 git apply 和 wiggle 都失败时使用。

用法: semantic-patches.py <v8_dir> <log_file>

处理的文件:
1. src/objects/string.cc - 删除字符串截断逻辑
2. src/snapshot/deserializer.cc - 删除魔数检查
3. src/snapshot/code-serializer.cc - 绕过完整性检查
"""

import os
import re
import sys
from pathlib import Path
from typing import Tuple

# Console output may be redirected to a file with a legacy code page (cp1252
# on Windows CI); never let a log message crash the script.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding='utf-8', errors='replace')
    except (AttributeError, ValueError):
        pass


def read_source(path: Path) -> str:
    """Read a source file without translating line endings."""
    with open(path, 'r', encoding='utf-8', newline='') as f:
        return f.read()


def write_source(path: Path, content: str) -> None:
    """Write a source file without translating line endings (no LF -> CRLF)."""
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(content)


class SemanticPatcher:
    """语义化 Patch 应用器"""

    def __init__(self, v8_dir: str, log_file: str):
        self.v8_dir = Path(v8_dir)
        self.log_file = Path(log_file)
        self.success_count = 0
        self.failure_count = 0

    def log(self, message: str):
        """记录日志到文件和标准输出"""
        print(message)
        with open(self.log_file, 'a', encoding='utf-8') as f:
            f.write(message + '\n')

    def patch_string_cc(self) -> bool:
        """
        修改 src/objects/string.cc
        删除字符串截断逻辑（7行代码）

        原始代码:
          if (len > kMaxShortPrintLength) {
            accumulator->Add("...<truncated>>");
            accumulator->Add(SuffixForDebugPrint());
            accumulator->Put('>');
            return;
          }
        """
        file_path = self.v8_dir / 'src/objects/string.cc'

        if not file_path.exists():
            self.log(f"[SEMANTIC] ✗ 文件不存在: {file_path}")
            return False

        try:
            content = read_source(file_path)
        except Exception as e:
            self.log(f"[SEMANTIC] ✗ 读取文件失败: {e}")
            return False

        # 匹配要删除的代码块（使用正则，允许空白变化）
        # 匹配整个 if 块，包括花括号内的所有内容
        pattern = r'\s*if\s*\(\s*len\s*>\s*kMaxShortPrintLength\s*\)\s*\{[^}]*\}\s*\n?'

        # 检查是否存在
        match = re.search(pattern, content, re.DOTALL)
        if not match:
            self.log("[SEMANTIC] ⚠️  string.cc: 未找到匹配模式（可能已经应用过）")
            return True  # 可能已经应用过，返回成功

        # 删除匹配的代码块
        new_content = re.sub(pattern, '\n', content, flags=re.DOTALL)

        # 验证修改
        if content == new_content:
            self.log("[SEMANTIC] ⚠️  string.cc: 内容未改变")
            return True

        # 写回文件
        try:
            write_source(file_path, new_content)
            self.log("[SEMANTIC] ✅ string.cc 已成功应用语义化 patch")
            return True
        except Exception as e:
            self.log(f"[SEMANTIC] ✗ 写入文件失败: {e}")
            return False

    def patch_deserializer_cc(self) -> bool:
        """
        修改 src/snapshot/deserializer.cc
        删除魔数检查（1行）

        原始代码:
          CHECK_EQ(magic_number_, SerializedData::kMagicNumber);
        """
        file_path = self.v8_dir / 'src/snapshot/deserializer.cc'

        if not file_path.exists():
            self.log(f"[SEMANTIC] ✗ 文件不存在: {file_path}")
            return False

        try:
            content = read_source(file_path)
        except Exception as e:
            self.log(f"[SEMANTIC] ✗ 读取文件失败: {e}")
            return False

        # 匹配要删除的行（允许空白变化）
        # Remove the whole line only; don't swallow neighbouring newlines.
        pattern = re.compile(
            r'^[ \t]*CHECK_EQ\s*\(\s*magic_number_\s*,\s*SerializedData::kMagicNumber\s*\)\s*;?[ \t]*\r?\n?',
            re.MULTILINE)

        if not re.search(pattern, content):
            self.log("[SEMANTIC] ⚠️  deserializer.cc: 未找到匹配模式（可能已经应用过）")
            return True

        new_content = re.sub(pattern, '', content)

        # 验证修改
        if content == new_content:
            self.log("[SEMANTIC] ⚠️  deserializer.cc: 内容未改变")
            return True

        try:
            write_source(file_path, new_content)
            self.log("[SEMANTIC] ✅ deserializer.cc 已成功应用语义化 patch")
            return True
        except Exception as e:
            self.log(f"[SEMANTIC] ✗ 写入文件失败: {e}")
            return False

    def patch_code_serializer_cc(self) -> bool:
        """
        修改 src/snapshot/code-serializer.cc
        替换 SanityCheck 函数实现，绕过完整性检查

        原始代码:
          SerializedCodeSanityCheckResult result = SanityCheckWithoutSource();
          if (result != SerializedCodeSanityCheckResult::kSuccess) return result;
          return SanityCheckJustSource(expected_source_hash);

        替换为:
          return SerializedCodeSanityCheckResult::kSuccess;
        """
        file_path = self.v8_dir / 'src/snapshot/code-serializer.cc'

        if not file_path.exists():
            self.log(f"[SEMANTIC] ✗ 文件不存在: {file_path}")
            return False

        try:
            content = read_source(file_path)
        except Exception as e:
            self.log(f"[SEMANTIC] ✗ 读取文件失败: {e}")
            return False

        # 匹配 SanityCheck 函数体（3行替换为1行）
        # 需要匹配函数签名后的花括号内的内容
        pattern = (
            r'(SerializedCodeSanityCheckResult\s+SerializedCodeData::SanityCheck\s*'
            r'\([^)]*\)\s*const\s*\{)\s*'
            r'SerializedCodeSanityCheckResult\s+result\s*=\s*SanityCheckWithoutSource\s*\(\s*\)\s*;\s*'
            r'if\s*\([^)]*\)\s*return\s+result\s*;\s*'
            r'return\s+SanityCheckJustSource\s*\([^)]*\)\s*;'
        )

        replacement = r'\1\n  return SerializedCodeSanityCheckResult::kSuccess;'

        if not re.search(pattern, content, re.DOTALL):
            self.log("[SEMANTIC] ⚠️  code-serializer.cc: 未找到匹配模式（可能已经应用过）")
            # 检查是否已经是目标状态
            if 'return SerializedCodeSanityCheckResult::kSuccess;' in content:
                self.log("[SEMANTIC] ⚠️  code-serializer.cc: 已经是目标状态")
                return True
            return True  # 宽松处理，可能已经修改过

        new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

        # 验证修改
        if content == new_content:
            self.log("[SEMANTIC] ⚠️  code-serializer.cc: 内容未改变")
            return True

        try:
            write_source(file_path, new_content)
            self.log("[SEMANTIC] ✅ code-serializer.cc 已成功应用语义化 patch")
            return True
        except Exception as e:
            self.log(f"[SEMANTIC] ✗ 写入文件失败: {e}")
            return False

    def apply_all(self) -> bool:
        """应用所有语义化 patch"""
        self.log("[SEMANTIC] 开始应用语义化 patch...")
        self.log("")

        patches = [
            ("string.cc", self.patch_string_cc),
            ("deserializer.cc", self.patch_deserializer_cc),
            ("code-serializer.cc", self.patch_code_serializer_cc),
        ]

        for name, patch_func in patches:
            self.log(f"[SEMANTIC] 正在处理 {name}...")
            try:
                if patch_func():
                    self.success_count += 1
                else:
                    self.failure_count += 1
            except Exception as e:
                self.log(f"[SEMANTIC] ✗ 处理 {name} 时发生异常: {e}")
                self.failure_count += 1
            self.log("")

        self.log(f"[SEMANTIC] 结果: {self.success_count} 成功, {self.failure_count} 失败")
        self.log("")

        # 如果至少有一个成功，返回成功（部分成功也算）
        # 注意：这里的策略是宽松的，因为某些文件可能已经被修改过
        return self.success_count > 0


def main():
    if len(sys.argv) < 3:
        print("用法: semantic-patches.py <v8_dir> <log_file>")
        print("")
        print("参数:")
        print("  v8_dir   - V8 源码目录的绝对路径")
        print("  log_file - 日志文件的绝对路径")
        sys.exit(1)

    v8_dir = sys.argv[1]
    log_file = sys.argv[2]

    # 验证参数
    if not os.path.isdir(v8_dir):
        print(f"错误: V8 目录不存在: {v8_dir}")
        sys.exit(1)

    patcher = SemanticPatcher(v8_dir, log_file)
    success = patcher.apply_all()

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
