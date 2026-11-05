@echo off
REM Set V8DASM_DEBUG=1 to echo every command before it runs.
if "%V8DASM_DEBUG%"=="1" echo on
setlocal enabledelayedexpansion

REM The tilde form strips surrounding quotes; the workflow passes build args
REM quoted ("a=true b=true"), and leftover quotes break later if checks.
set "V8_VERSION=%~1"
set "BUILD_ARGS=%~2"

echo ==========================================
echo Building v8dasm for Windows x64
echo V8 Version: %V8_VERSION%
echo Build Args: %BUILD_ARGS%
echo ==========================================

REM 检测运行环境 (GitHub Actions 或本地)
if "%GITHUB_WORKSPACE%"=="" (
    echo 检测到本地环境
    set WORKSPACE_DIR=%~dp0..\..
    set IS_LOCAL=true
    echo 本地环境，跳过依赖安装 (请确保已安装: git, python, Visual Studio/clang^)
) else (
    echo 检测到 GitHub Actions 环境
    set WORKSPACE_DIR=%GITHUB_WORKSPACE%
    set IS_LOCAL=false
)

echo 工作空间: %WORKSPACE_DIR%

REM 配置 Git
git config --global user.name "V8 Disassembler Builder"
git config --global user.email "v8dasm.builder@localhost"
git config --global core.autocrlf false
git config --global core.filemode false

REM V8_ROOT: where depot_tools and the V8 checkout live (cached by CI).
REM V8DASM_STAGE: all (default) | sync (fetch/checkout/gclient sync only)
REM               | build (skip sync, use an existing checkout)
if not defined V8_ROOT set "V8_ROOT=%USERPROFILE%"
if not defined V8DASM_STAGE set "V8DASM_STAGE=all"
echo V8_ROOT: %V8_ROOT%
echo Stage: %V8DASM_STAGE%
if not exist "%V8_ROOT%" mkdir "%V8_ROOT%"
cd /d "%V8_ROOT%"

REM 获取 Depot Tools
if not exist depot_tools (
    echo =====[ Getting Depot Tools ]=====
    powershell -command "Invoke-WebRequest https://storage.googleapis.com/chrome-infra/depot_tools.zip -O depot_tools.zip"
    powershell -command "Expand-Archive depot_tools.zip -DestinationPath depot_tools"
    del depot_tools.zip
)

set PATH=%CD%\depot_tools;%PATH%
set DEPOT_TOOLS_WIN_TOOLCHAIN=0
call gclient

REM 创建工作目录
if not exist v8 mkdir v8
cd v8

if /i "%V8DASM_STAGE%"=="build" goto :skip_sync

REM 获取 V8 源码
if not exist v8 (
    echo =====[ Fetching V8 ]=====
    call fetch v8
    echo target_os = ['win'] >> .gclient
)

cd v8
set V8_DIR=%CD%

REM Checkout 指定版本
echo =====[ Checking out V8 %V8_VERSION% ]=====
call git fetch --all --tags
call git checkout %V8_VERSION%
call gclient sync
if errorlevel 1 (
    echo [ERROR] gclient sync failed
    exit /b 1
)

if /i "%V8DASM_STAGE%"=="sync" (
    echo [OK] V8 source synced, stopping after sync stage
    exit /b 0
)
goto :after_sync

:skip_sync
if not exist v8 (
    echo [ERROR] No V8 checkout in %V8_ROOT%\v8 - run the sync stage first
    exit /b 1
)
cd v8
set V8_DIR=%CD%

:after_sync

REM 应用补丁（使用多级退避策略）
echo =====[ Applying v8.patch ]=====
set PATCH_FILE=%WORKSPACE_DIR%\Disassembler\v8.patch
set PATCH_LOG=%WORKSPACE_DIR%\scripts\v8dasm-builders\patch-utils\patch-state.log

REM 调用统一的 patch 应用脚本
call "%WORKSPACE_DIR%\scripts\v8dasm-builders\patch-utils\apply-patch.cmd" ^
    "%PATCH_FILE%" ^
    "%V8_DIR%" ^
    "%PATCH_LOG%" ^
    "true"

if %errorlevel% neq 0 (
    echo [ERROR] Patch application failed. Build aborted.
    echo 请检查日志文件: %PATCH_LOG%
    exit /b 1
)

echo [OK] Patch applied successfully


REM 配置构建
echo =====[ Configuring V8 Build ]=====
REM 构建 GN 参数字符串
REM treat_warnings_as_errors=false: our non-default config (sandbox, object
REM print, monolith) trips warnings such as -Winvalid-offsetof that upstream
REM never sees; with /WX they would abort the build.
REM No v8_static_library=true: it turns header-only source sets into empty
REM static libraries that lld-link then cannot find (v8_heap_base_headers.lib).
REM v8_monolith already bundles v8_libbase and v8_libplatform.
REM v8_generate_external_defines_header=true writes gen\include\v8-gn.h with
REM the defines (pointer compression, sandbox, ...) embedders must match.
set GN_ARGS=target_os=\"win\" target_cpu=\"x64\" is_component_build=false is_debug=false use_custom_libcxx=false v8_monolithic=true v8_generate_external_defines_header=true v8_enable_disassembler=true v8_enable_object_print=true v8_use_external_startup_data=false dcheck_always_on=false symbol_level=0 is_clang=true treat_warnings_as_errors=false

REM 如果有额外的构建参数，追加
REM (delayed expansion, no ( ) block: the values contain = and quotes)
if defined BUILD_ARGS set "GN_ARGS=!GN_ARGS! !BUILD_ARGS!"

echo GN Args: !GN_ARGS!

REM Optionally pin the MSVC toolset (e.g. 14.29): V8's bundled clang is too
REM old for the newest MSVC STL headers on the runners.
if defined V8DASM_MSVC_TOOLSET (
    call python3 "%WORKSPACE_DIR%\scripts\v8dasm-builders\pin-msvc-toolset.py" "%V8_DIR%" "%V8DASM_MSVC_TOOLSET%"
    if errorlevel 1 (
        echo [ERROR] could not pin MSVC toolset %V8DASM_MSVC_TOOLSET%
        exit /b 1
    )
)

REM 直接使用 gn gen 生成构建配置
call gn gen out.gn\x64.release --args="!GN_ARGS!"
if errorlevel 1 (
    echo [ERROR] gn gen failed
    exit /b 1
)

REM 构建 V8 静态库
echo =====[ Building V8 Monolith ]=====
call ninja -C out.gn\x64.release v8_monolith
if errorlevel 1 (
    echo [ERROR] ninja build of v8_monolith failed
    exit /b 1
)

REM 编译 v8dasm
echo =====[ Compiling v8dasm ]=====
set DASM_SOURCE=%WORKSPACE_DIR%\Disassembler\v8dasm.cpp
set OUTPUT_NAME=v8dasm-%V8_VERSION%.exe

REM -DV8_GN_HEADER + gen\include: use the same V8 config defines as the build.
REM -fms-runtime-lib=static: V8 is built with /MT; mixing CRTs fails to link.
REM winmm/dbghelp/ws2_32/advapi32: system libs v8_libbase needs.
REM -I. because v8dasm.cpp includes "include/v8.h"; -Iinclude for V8's own
REM headers, which include each other as "v8config.h", "libplatform/...".
clang++ %DASM_SOURCE% ^
    -std=c++20 ^
    -O2 ^
    -DV8_GN_HEADER ^
    -I. ^
    -Iinclude ^
    -Iout.gn\x64.release\gen\include ^
    -fms-runtime-lib=static ^
    -Lout.gn\x64.release\obj ^
    -lv8_monolith ^
    -lwinmm ^
    -ldbghelp ^
    -lws2_32 ^
    -ladvapi32 ^
    -o %OUTPUT_NAME%
if errorlevel 1 (
    echo [ERROR] compiling/linking v8dasm failed
    exit /b 1
)

REM 验证编译
if exist %OUTPUT_NAME% (
    echo =====[ Build Successful ]=====
    dir %OUTPUT_NAME%
    echo.
    echo [OK] 编译完成: %OUTPUT_NAME%
    echo    位置: %CD%\%OUTPUT_NAME%
) else (
    echo ERROR: %OUTPUT_NAME% not found!
    exit /b 1
)
