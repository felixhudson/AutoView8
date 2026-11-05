# AutoView8 - Automated Build System for the V8 Decompiler

A fully automated build system for the V8 disassembler (v8dasm). It compiles for multiple platforms and multiple V8 versions, and publishes the results to GitHub Releases automatically.

## 🚀 Quick Start

### Automated Build Workflow (Recommended)

1. **Clone the repository**

   ```bash
   git clone <your-repo-url>
   cd AutoView8
   ```

2. **Configure the V8 versions to build**

   Edit [`configs/v8-versions.json`](configs/v8-versions.json):

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

3. **Commit and push**

   ```bash
   git add configs/v8-versions.json
   git commit -m "Update V8 versions to build"
   git push origin main
   ```

4. **Done automatically!** 🎉
   - GitHub Actions detects the configuration change
   - Builds all platforms in parallel (Linux, macOS Intel, macOS ARM, Windows)
   - Creates a GitHub Release automatically
   - Uploads the binaries for every platform

5. **Download the build artifacts**
   - Go to the repository's [Releases page](../../releases)
   - Download the archive for your platform and version
   - Extract it and it's ready to use

---

## 📁 Project Structure

```
AutoView8/
├── .github/workflows/
│   └── build-v8dasm.yml         # GitHub Actions workflow
├── configs/
│   └── v8-versions.json         # Version config file (edit this!)
├── scripts/v8dasm-builders/
│   ├── build-linux.sh           # Linux build script
│   ├── build-macos-intel.sh     # macOS Intel build script
│   ├── build-macos-arm.sh       # macOS ARM build script
│   └── build-windows.cmd        # Windows build script
├── view8-jsc-decode/
│   └── Disassembler/
│       ├── v8dasm.cpp           # Disassembler source code
│       └── v8.patch             # V8 patch
├── view8.py                     # View8 decompiler main program
├── Parser/                      # V8 cache parser
├── Translate/                   # Bytecode translator
├── Simplify/                    # Code simplifier
├── BUILD.md                     # Local build guide
└── README.md                    # This file (Chinese)
```

---

## 🎯 Supported Platforms and Versions

### Build Platforms

- ✅ Linux x64
- ✅ macOS Intel (x86_64)
- ✅ macOS Apple Silicon (ARM64)
- ✅ Windows x64

### V8 Versions Supported by Default

- **9.4.146.24** - Node.js v16.x
- **10.2.154.26** - Node.js v18.x
- **11.3.244.8** - Node.js v20.x

---

## 📝 Usage

### Option 1: Use the Automatically Built Binaries (Recommended)

1. Download the matching v8dasm version from [Releases](../../releases)
2. Extract and run:

```bash
# Disassemble a JSC file
./v8dasm-10.2.154.26 input.jsc > output.txt

# Full decompilation together with View8
python view8.py input.jsc output.js --path ./v8dasm-10.2.154.26
```

### Option 2: Build Locally (Advanced Users)

See the [Local Build Guide](BUILD.md) to build locally.

---

## ⚙️ Adding a New V8 Version

Edit [`configs/v8-versions.json`](configs/v8-versions.json) and add the new version:

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

**Committing the change triggers a build automatically!**

### How Do I Find the V8 Version Number?

1. **From your Node.js version**

   ```bash
   node -p process.versions.v8
   ```

2. **Look it up online**
   - [Node.js Releases](https://nodejs.org/en/download/releases/)
   - [V8 version list](https://chromium.googlesource.com/v8/v8.git/+refs)

3. **Electron versions**
   - [Electron Releases](https://www.electronjs.org/releases)

---

## 🔧 Workflow Triggers

GitHub Actions runs automatically in the following cases:

1. **Push to the main branch** that changes any of these files:
   - `configs/v8-versions.json` ⭐ **most common**
   - `view8-jsc-decode/Disassembler/**`
   - `scripts/v8dasm-builders/**`
   - `.github/workflows/build-v8dasm.yml`

2. **Pull Request** to the main branch

3. **Manual trigger**
   - Go to the [Actions page](../../actions)
   - Select the "Build V8 Disassembler" workflow
   - Click "Run workflow"
   - Optionally specify a single version to build

---

## 💡 Core Features

### ✅ Fully Automated

- No manual steps — just edit the config file
- Detects version changes automatically
- Creates Releases automatically

### ✅ Parallel Multi-Platform Builds

- 4 platforms build at the same time
- About 60–90 minutes to finish everything

### ✅ Smart Caching

- Depot Tools cache
- V8 source cache
- Incremental builds save 50–70% of build time

### ✅ Version-Based Naming

- Build artifacts are named after the version number automatically
- For example: `v8dasm-10.2.154.26`
- Makes managing multiple versions easy

### ✅ Local + Cloud Modes

- Supports automated builds on GitHub Actions
- Supports manual local builds
- Scripts detect the runtime environment automatically

---

## 📊 Checking Build Status

### On GitHub

1. Go to the repository's [Actions tab](../../actions)
2. Open the latest workflow run
3. Click into each platform to see detailed logs

### Workflow Steps

```
Prepare build matrix
    ↓
┌────────────────────┬────────────────────┬────────────────────┬────────────────────┐
│   Linux x64        │  macOS Intel       │  macOS ARM64       │   Windows x64      │
│  (ubuntu-20.04)    │  (macos-12)        │  (macos-14)        │  (windows-2022)    │
└────────────────────┴────────────────────┴────────────────────┴────────────────────┘
                                    ↓
                          Create GitHub Release
                                    ↓
                    Upload ZIP archives for all platforms
```

---

## 🛠️ Advanced Configuration

### Custom Build Arguments

Change `build_args` in `configs/v8-versions.json`:

```json
{
  "v8_version": "10.8.168.25",
  "node_version": "Electron v22.x",
  "build_args": "v8_enable_pointer_compression=true v8_enable_sandbox=true"
}
```

**Common arguments:**

- `v8_enable_pointer_compression=false` - Disable pointer compression (Node.js)
- `v8_enable_pointer_compression=true` - Enable pointer compression (Electron)
- `v8_enable_sandbox=true` - Enable the sandbox (Electron)

### Build Only a Specific Version

When triggering the workflow manually, enter a version number:

1. Go to the [Actions page](../../actions)
2. Select "Build V8 Disassembler"
3. Click "Run workflow"
4. Enter the V8 version number (e.g. `10.2.154.26`)
5. Click "Run workflow"

---

## 📖 Decompiling JSC Files with View8

```bash
# Basic usage
python view8.py input.jsc output.js

# Specify the v8dasm path
python view8.py input.jsc output.js --path ./v8dasm-10.2.154.26

# Show help
python view8.py --help
```

For full documentation, see the [View8 README](README-View8.md).

---

## 🐛 Troubleshooting

### GitHub Actions Build Failed?

1. **Check the logs**
   - Open the Actions page to see the detailed logs
   - Focus on the red error messages

2. **Patch failed to apply**
   - The V8 version may be incompatible
   - See [Patch Compatibility](#patch-compatibility)

3. **Out of memory**
   - GitHub Actions has a 7 GB memory limit
   - Consider building locally

### Local Build Problems?

See the "FAQ" section of the [Local Build Guide](BUILD.md).

---

## 🔗 Related Links

- [GitHub Actions workflow](.github/workflows/build-v8dasm.yml)
- [Version config file](configs/v8-versions.json)
- [Local Build Guide](BUILD.md)
- [View8 README](README-View8.md)
- [Official V8 documentation](https://v8.dev/docs)

---

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.

---

## 🤝 Contributing

Issues and Pull Requests are welcome!

### Contribution Guide

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

**Last updated**: 2026-01-30
**Version**: 1.0.0
