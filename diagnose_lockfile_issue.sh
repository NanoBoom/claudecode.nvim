#!/bin/bash
# 诊断 lock 文件消失问题

echo "========================================="
echo "🔍 Lock File 问题诊断"
echo "========================================="
echo ""

echo "【步骤 1】在宿主机创建测试 lock 文件"
echo "----------------------------------------"
mkdir -p ~/.claude/ide
cat > ~/.claude/ide/test.lock <<EOF
{
  "pid": $$,
  "workspaceFolders": ["$(pwd)"],
  "ideName": "Neovim-Test",
  "transport": "ws",
  "authToken": "test-token-12345"
}
EOF

echo "✓ 创建测试 lock 文件"
echo "  路径: ~/.claude/ide/test.lock"
echo "  PID: $$"
echo "  工作目录: $(pwd)"
echo ""
echo "文件内容："
cat ~/.claude/ide/test.lock | jq .
echo ""

echo "【步骤 2】检查文件是否存在"
echo "----------------------------------------"
ls -la ~/.claude/ide/
echo ""

echo "【步骤 3】在 devcontainer 中检查"
echo "----------------------------------------"
echo "请在 devcontainer 中运行以下命令："
echo ""
echo "  # 1. 检查路径软链接"
echo "  ls -la /Users/\$USER"
echo "  ls -la /home/\$USER"
echo ""
echo "  # 2. 检查 lock 文件是否可见"
echo "  ls -la ~/.claude/ide/"
echo "  cat ~/.claude/ide/test.lock | jq ."
echo ""
echo "  # 3. 检查 PID 是否存在"
echo "  ps -p $$ || echo 'PID $$ 不存在（这是预期的）'"
echo ""
echo "  # 4. 启动 Claude CLI（观察 lock 文件是否消失）"
echo "  claude  # 启动后按 Ctrl+C 退出"
echo ""
echo "  # 5. 再次检查 lock 文件"
echo "  ls -la ~/.claude/ide/"
echo ""

echo "【步骤 4】Claude CLI 日志检查"
echo "----------------------------------------"
echo "如果 lock 文件消失了，请检查 Claude CLI 的日志："
echo ""
echo "  # 可能的日志位置"
echo "  cat ~/.claude/logs/*.log"
echo "  cat ~/.claude/ide/*.log"
echo ""

echo "========================================="
echo "请把上述输出发给我"
echo "========================================="
