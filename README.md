# AutoView8 - V8 反编译器自动构建系统

一个全自动的 V8 反汇编器 (v8dasm) 构建系统，支持多平台、多版本编译，并自动发布到 GitHub Releases。

[English instructions](READMEENGLISH.md)

## 🚀 快速开始

### 自动化构建流程（推荐）

1. **克隆仓库**

   ```bash
   git clone <your-repo-url>
   cd AutoView8
   ```

2. **配置要编译的 V8 版本**

   编辑 [`configs/v8-versions.json`](configs/v8-versions.json)：

   ```json
   {
     "versions": [
       {
         "v8_version": "10.2.154.26",
         "node_version": "v18.x",
         "build_args": "v8_enable_pointer_compression=false"
       }
     ]
   }
   ```

3. **提交并推送**

   ```bash
   git add configs/v8-versions.json
   git commit -m "Update V8 versions to build"
   git push origin main
   ```

4. **自动完成!** 🎉
   - GitHub Actions 自动检测配置变化
   - 并行编译所有平台 (Linux, macOS Intel, macOS ARM, Windows)
   - 自动创建 GitHub Release
   - 上传所有平台的二进制文件

5. **下载编译产物**
   - 访问仓库的 [Releases 页面](../../releases)
   - 下载对应平台和版本的压缩包
   - 解压即可使用

---

## 📁 项目结构

```
AutoView8/
├── .github/workflows/
│   └── build-v8dasm.yml         # GitHub Actions 工作流
├── configs/
│   └── v8-versions.json         # 版本配置文件 (修改这里!)
├── scripts/v8dasm-builders/
│   ├── build-linux.sh           # Linux 编译脚本
│   ├── build-macos-intel.sh     # macOS Intel 编译脚本
│   ├── build-macos-arm.sh       # macOS ARM 编译脚本
│   └── build-windows.cmd        # Windows 编译脚本
├── view8-jsc-decode/
│   └── Disassembler/
│       ├── v8dasm.cpp           # 反汇编器源码
│       └── v8.patch             # V8 补丁
├── view8.py                     # View8 反编译器主程序
├── Parser/                      # V8 缓存解析器
├── Translate/                   # 字节码翻译器
├── Simplify/                    # 代码简化器
├── BUILD.md                     # 本地编译指南
└── README.md                    # 本文件
```

---

## 🎯 支持的平台和版本

### 编译平台

- ✅ Linux x64
- ✅ macOS Intel (x86_64)
- ✅ macOS Apple Silicon (ARM64)
- ✅ Windows x64

### 默认支持的 V8 版本

- **9.4.146.24** - Node.js v16.x
- **10.2.154.26** - Node.js v18.x
- **11.3.244.8** - Node.js v20.x

---

## 📝 使用方法

### 方法一：使用自动编译的二进制文件（推荐）

1. 从 [Releases](../../releases) 下载对应版本的 v8dasm
2. 解压并使用：

```bash
# 反汇编 JSC 文件
./v8dasm-10.2.154.26 input.jsc > output.txt

# 配合 View8 完整反编译
python view8.py input.jsc output.js --path ./v8dasm-10.2.154.26
```

### 方法二：本地编译（高级用户）

参考 [本地编译指南](BUILD.md) 进行本地编译。

---

## ⚙️ 添加新的 V8 版本

编辑 [`configs/v8-versions.json`](configs/v8-versions.json)，添加新版本：

```json
{
  "versions": [
    {
      "v8_version": "12.4.254.14",
      "node_version": "v22.x",
      "build_args": "v8_enable_pointer_compression=false"
    }
  ]
}
```

**提交后自动触发编译！**

### 如何查找 V8 版本号？

1. **Node.js 版本对应表**

   ```bash
   node -p process.versions.v8
   ```

2. **在线查询**
   - [Node.js Releases](https://nodejs.org/en/download/releases/)
   - [V8 版本列表](https://chromium.googlesource.com/v8/v8.git/+refs)

3. **Electron 版本**
   - [Electron Releases](https://www.electronjs.org/releases)

---

## 🔧 工作流触发条件

GitHub Actions 在以下情况自动运行：

1. **推送到 main 分支** 且修改了以下文件：
   - `configs/v8-versions.json` ⭐ **最常用**
   - `view8-jsc-decode/Disassembler/**`
   - `scripts/v8dasm-builders/**`
   - `.github/workflows/build-v8dasm.yml`

2. **Pull Request** 到 main 分支

3. **手动触发**
   - 访问 [Actions 页面](../../actions)
   - 选择 "Build V8 Disassembler" 工作流
   - 点击 "Run workflow"
   - 可选择指定单个版本编译

---

## 💡 核心功能

### ✅ 全自动化

- 无需手动操作，修改配置文件即可
- 自动检测版本变化
- 自动创建 Release

### ✅ 多平台并行编译

- 4 个平台同时编译
- 预计 60-90 分钟完成全部

### ✅ 智能缓存

- Depot Tools 缓存
- V8 源码缓存
- 增量构建节省 50-70% 时间

### ✅ 版本号命名

- 编译产物自动以版本号命名
- 例如: `v8dasm-10.2.154.26`
- 便于管理多个版本

### ✅ 本地 + 云端双模式

- 支持 GitHub Actions 自动编译
- 支持本地手动编译
- 脚本自动检测运行环境

---

## 📊 编译状态查看

### 在 GitHub 上查看

1. 访问仓库的 [Actions 标签页](../../actions)
2. 查看最新的工作流运行
3. 点击查看各平台的详细日志

### 工作流步骤

```
准备构建矩阵
    ↓
┌────────────────────┬────────────────────┬────────────────────┬────────────────────┐
│   Linux x64        │  macOS Intel       │  macOS ARM64       │   Windows x64      │
│  (ubuntu-20.04)    │  (macos-12)        │  (macos-14)        │  (windows-2022)    │
└────────────────────┴────────────────────┴────────────────────┴────────────────────┘
                                    ↓
                            创建 GitHub Release
                                    ↓
                         上传所有平台的 ZIP 压缩包
```

---

## 🛠️ 高级配置

### 自定义构建参数

在 `configs/v8-versions.json` 中修改 `build_args`：

```json
{
  "v8_version": "10.8.168.25",
  "node_version": "Electron v22.x",
  "build_args": "v8_enable_pointer_compression=true v8_enable_sandbox=true"
}
```

**常用参数：**

- `v8_enable_pointer_compression=false` - 禁用指针压缩 (Node.js)
- `v8_enable_pointer_compression=true` - 启用指针压缩 (Electron)
- `v8_enable_sandbox=true` - 启用沙箱 (Electron)

### 只编译特定版本

手动触发工作流时，输入版本号：

1. 访问 [Actions 页面](../../actions)
2. 选择 "Build V8 Disassembler"
3. 点击 "Run workflow"
4. 输入 V8 版本号（如 `10.2.154.26`）
5. 点击 "Run workflow"

---

## 📖 使用 View8 反编译 JSC 文件

```bash
# 基本用法
python view8.py input.jsc output.js

# 指定 v8dasm 路径
python view8.py input.jsc output.js --path ./v8dasm-10.2.154.26

# 查看帮助
python view8.py --help
```

详细文档请参考 [View8 说明](README-View8.md)。

---

## 🐛 故障排查

### GitHub Actions 构建失败？

1. **检查日志**
   - 访问 Actions 页面查看详细日志
   - 重点关注红色错误信息

2. **补丁应用失败**
   - 可能是 V8 版本不兼容
   - 查看 [补丁兼容性](#补丁兼容性)

3. **内存不足**
   - GitHub Actions 有 7GB 内存限制
   - 考虑本地编译

### 本地编译问题？

参考 [本地编译指南](BUILD.md) 的"常见问题"部分。

---

## 🔗 相关链接

- [GitHub Actions 工作流](.github/workflows/build-v8dasm.yml)
- [版本配置文件](configs/v8-versions.json)
- [本地编译指南](BUILD.md)
- [View8 说明](README-View8.md)
- [V8 官方文档](https://v8.dev/docs)

---

## 📄 许可证

本项目基于 MIT 许可证。详见 LICENSE 文件。

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 贡献指南

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

---

**最后更新**: 2026-01-30
**版本**: 1.0.0
