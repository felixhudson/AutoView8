@echo off
REM apply-patch.cmd - multi-level fallback V8 patch application (Windows)
REM
REM Usage: apply-patch.cmd <patch_file> <v8_dir> <log_file> [abort_on_failure]
REM
REM   patch_file        - absolute path to the patch file
REM   v8_dir            - absolute path to the V8 source directory
REM   log_file          - absolute path to the log file
REM   abort_on_failure  - abort on failure (true/false, default: true)
REM
REM NOTE: keep this file pure ASCII. cmd.exe misparses / crashes (0xC0000005)
REM on multi-byte UTF-8 characters such as emoji inside ( ) blocks when the
REM console code page is 65001, which is the case on GitHub Actions runners.
REM
REM Every git / python call uses "call": depot_tools puts git.bat and
REM python3.bat on PATH, and running a .bat without "call" never returns.
REM
REM Set V8DASM_DEBUG=1 to echo every command before it runs.

if "%V8DASM_DEBUG%"=="1" echo on
setlocal enabledelayedexpansion

set "PATCH_FILE=%~1"
set "V8_DIR=%~2"
set "LOG_FILE=%~3"
set "ABORT_ON_FAILURE=%~4"
if "%ABORT_ON_FAILURE%"=="" set "ABORT_ON_FAILURE=true"

if "%PATCH_FILE%"=="" goto :usage
if "%V8_DIR%"=="" goto :usage
if "%LOG_FILE%"=="" goto :usage

if not exist "%PATCH_FILE%" (
    echo ERROR: patch file not found: %PATCH_FILE%
    exit /b 1
)
if not exist "%V8_DIR%" (
    echo ERROR: V8 directory not found: %V8_DIR%
    exit /b 1
)

for %%F in ("%LOG_FILE%") do set "LOG_DIR=%%~dpF"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo =====[ V8 Patch Application - Multi-level Fallback ]===== > "%LOG_FILE%"
call :log "Patch file: %PATCH_FILE%"
call :log "V8 dir: %V8_DIR%"
call :log "Log file: %LOG_FILE%"
call :log "Abort on failure: %ABORT_ON_FAILURE%"
call :log "Timestamp: %date% %time%"
call :log ""

cd /d "%V8_DIR%"
if errorlevel 1 (
    call :log "ERROR: cannot cd to %V8_DIR%"
    exit /b 1
)

REM Record which git / python will actually run (a .bat shim vs a real .exe)
echo [ENV] git resolves to:
where git
echo [ENV] python3 resolves to:
where python3
call git --version

REM ---- Level 0: reset to a clean state ----
call :reset_repo

REM ---- Already applied? (reverse check) ----
call :log "[CHECK] Checking whether the patch is already applied..."
call git apply --check --reverse "%PATCH_FILE%" >nul 2>&1
if not errorlevel 1 (
    call :log "[CHECK] OK: patch already applied, skipping"
    exit /b 0
)
call :log "[CHECK] Patch not applied yet"
call :log ""

REM ---- Level 1: git apply ----
call :log "[LEVEL 1] Trying git apply..."
call git apply --check "%PATCH_FILE%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto :level1_failed
call :log "[LEVEL 1] Check passed, applying..."
call git apply --verbose "%PATCH_FILE%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto :level1_failed
call :log "[LEVEL 1] SUCCESS: patch applied with git apply"
exit /b 0

:level1_failed
call :log "[LEVEL 1] FAILED: git apply"
call :log ""
call :reset_repo

REM ---- Level 2: git apply -3 (three-way merge) ----
call :log "[LEVEL 2] Trying git apply -3 (three-way merge)..."
call git apply -3 --verbose "%PATCH_FILE%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto :level2_failed
REM Any unmerged paths mean conflicts
set "HAS_CONFLICTS="
for /f "delims=" %%U in ('git diff --name-only --diff-filter=U 2^>nul') do set "HAS_CONFLICTS=1"
if defined HAS_CONFLICTS (
    call :log "[LEVEL 2] FAILED: three-way merge produced conflicts"
    goto :level2_failed
)
call :log "[LEVEL 2] SUCCESS: patch applied with three-way merge"
exit /b 0

:level2_failed
call :log "[LEVEL 2] FAILED: git apply -3"
call :log ""
call :reset_repo

REM ---- Level 3: git apply --ignore-whitespace ----
call :log "[LEVEL 3] Trying git apply --ignore-whitespace..."
call git apply --ignore-whitespace --verbose "%PATCH_FILE%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto :level3_failed
call :log "[LEVEL 3] SUCCESS: patch applied with --ignore-whitespace"
exit /b 0

:level3_failed
call :log "[LEVEL 3] FAILED: git apply --ignore-whitespace"
call :log ""
call :reset_repo

REM ---- Level 4: semantic replacement (Python) ----
call :log "[LEVEL 4] Trying semantic replacement..."
set "SEMANTIC_SCRIPT=%~dp0semantic-patches.py"
if not exist "%SEMANTIC_SCRIPT%" (
    call :log "[LEVEL 4] FAILED: script not found: %SEMANTIC_SCRIPT%"
    goto :all_failed
)

set "PYTHON_CMD="
where python3 >nul 2>&1
if not errorlevel 1 set "PYTHON_CMD=python3"
if not defined PYTHON_CMD (
    where python >nul 2>&1
    if not errorlevel 1 set "PYTHON_CMD=python"
)
if not defined PYTHON_CMD (
    call :log "[LEVEL 4] FAILED: Python not found"
    goto :all_failed
)

call :log "[LEVEL 4] Running semantic replacement script..."
call %PYTHON_CMD% "%SEMANTIC_SCRIPT%" "%V8_DIR%" "%LOG_FILE%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :log "[LEVEL 4] FAILED: semantic replacement"
    goto :all_failed
)
call :log "[LEVEL 4] SUCCESS: patch applied with semantic replacement"
exit /b 0

:all_failed
call :log ""
call :log "========================================"
call :log "FAILED: all patch application methods failed"
call :log "========================================"
echo.
echo =====[ Full contents of %LOG_FILE% ]=====
type "%LOG_FILE%"
echo =====[ end of log ]=====
if /i "%ABORT_ON_FAILURE%"=="true" (
    call :log "Build aborted because the patch could not be applied."
    call :log "See log file: %LOG_FILE%"
    exit /b 1
)
call :log "WARNING: continuing build WITHOUT the patch; v8dasm may be incomplete"
exit /b 0

:usage
echo ERROR: missing required argument
echo Usage: %~nx0 ^<patch_file^> ^<v8_dir^> ^<log_file^> [abort_on_failure]
exit /b 1

REM ================= subroutines =================

REM :log "message" - print to console and append to the log file
REM Uses delayed expansion and no ( ) block so messages may contain ( ).
:log
@set "LOG_MSG=%~1"
@echo(!LOG_MSG!
@>> "%LOG_FILE%" echo(!LOG_MSG!
goto :eof

REM :reset_repo - discard any local changes in the V8 checkout
:reset_repo
call :log "[LEVEL 0] Resetting V8 repository to a clean state..."
call git diff --quiet >nul 2>&1
if errorlevel 1 (
    call :log "[RESET] Uncommitted changes detected, resetting..."
    call git reset --hard HEAD >> "%LOG_FILE%" 2>&1
    call git clean -fd >> "%LOG_FILE%" 2>&1
    call :log "[RESET] OK: repository reset"
) else (
    call :log "[RESET] OK: repository already clean"
)
call :log ""
goto :eof
