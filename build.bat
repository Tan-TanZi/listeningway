@echo off
setlocal

REM ============================================================
REM  build.bat: produces dual-arch (x64 + x86) Listeningway addons.
REM
REM  Configures build-x64/ and build-x86/ on demand (CMake-generated,
REM  fully regeneratable). Delete them any time to force a clean
REM  reconfigure on the next run.
REM
REM  prepare.bat handles the once-per-machine bootstrap (clone
REM  reshade/vcpkg, install vcpkg deps for both triplets).
REM ============================================================

set RESHADE_SDK_PATH=%CD%\third_party\reshade\include
set VCPKG_TOOLCHAIN_FILE=%CD%\tools\vcpkg\scripts\buildsystems\vcpkg.cmake
set CMAKE_GENERATOR="Visual Studio 17 2022"

REM Sanity check: prepare.bat must have been run.
if not exist "%RESHADE_SDK_PATH%\reshade.hpp" (
    echo ReShade SDK not found at %RESHADE_SDK_PATH%. Run prepare.bat first.
    exit /b 1
)
if not exist "tools\vcpkg\vcpkg.exe" (
    echo vcpkg.exe not found. Run prepare.bat first.
    exit /b 1
)

REM === Generate ListeningwayUniforms.fxh from template ===
REM NUM_BANDS is extracted from DEFAULT_NUM_BANDS in src\listeningway_constants.h.
REM It defines the compile-time size of the Listeningway_FreqBands[] array in
REM shaders and is also the runtime default band count. The live band count
REM the addon is currently publishing is exposed via the Listeningway_NumBands
REM uniform so shaders iterate only populated entries.
set CONSTANTS_H=src\listeningway_constants.h
if not exist %CONSTANTS_H% (
    echo Constants file %CONSTANTS_H% not found!
    exit /b 1
)
set NB_TMP=%TEMP%\lw_num_bands.txt
powershell -NoProfile -Command "$m = Get-Content '%CONSTANTS_H%' | Select-String 'constexpr\s+size_t\s+DEFAULT_NUM_BANDS\s*=\s*(\d+)' | Select-Object -First 1; if ($m) { $m.Matches.Groups[1].Value } else { '' }" > %NB_TMP%
set /p NUM_BANDS=<%NB_TMP%
del %NB_TMP%
if "%NUM_BANDS%"=="" (
    echo Could not extract DEFAULT_NUM_BANDS from %CONSTANTS_H%!
    exit /b 1
)
echo Using DEFAULT_NUM_BANDS = %NUM_BANDS% from %CONSTANTS_H%
set TEMPLATE=templates\ListeningwayUniforms.fxh.template
set OUTPUT=assets\ListeningwayUniforms.fxh
if exist %TEMPLATE% (
    powershell -Command "(Get-Content %TEMPLATE%) -replace '\{\{NUM_BANDS\}\}', '%NUM_BANDS%' | Set-Content %OUTPUT%"
) else (
    echo Template %TEMPLATE% not found!
    exit /b 1
)

REM === Generate listeningway.rc from template and current-version.txt ===
set RC_TEMPLATE=templates\listeningway.rc.template
set RC_OUTPUT=assets\listeningway.rc
set VERSION_FILE=current-version.txt
if not exist %RC_TEMPLATE% (
    echo Template %RC_TEMPLATE% not found!
    exit /b 1
)
if not exist %VERSION_FILE% (
    echo Version file %VERSION_FILE% not found!
    exit /b 1
)
for /f "usebackq delims=" %%v in (%VERSION_FILE%) do set VERSION_DOT=%%v
set VERSION_COMMA=%VERSION_DOT:.=,%
powershell -Command "(Get-Content %RC_TEMPLATE%) -replace '\{\{VERSION_DOT\}\}', '%VERSION_DOT%' -replace '\{\{VERSION_COMMA\}\}', '%VERSION_COMMA%' | Set-Content %RC_OUTPUT%"

REM Use Release config by default
set CONFIG=Release
if not "%1"=="" set CONFIG=%1

set DIST=dist
if not exist %DIST% mkdir %DIST%

REM === Build both architectures ===
call :build_arch x64 x64 x64-windows-static
if errorlevel 1 goto build_failed

call :build_arch x86 Win32 x86-windows-static
if errorlevel 1 goto build_failed

REM === Copy shared shader assets to dist ===
copy /Y assets\Listeningway.fx %DIST%\Listeningway.fx
copy /Y assets\ListeningwayUniforms.fxh %DIST%\ListeningwayUniforms.fxh

REM Extract FileVersion from listeningway.rc and write to dist/VERSION.txt
powershell -Command "Select-String 'FileVersion' assets/listeningway.rc | Select-Object -ExpandProperty Line | Where-Object { $_ -like '*VALUE*' } | ForEach-Object { if ($_ -match '"([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"') { $matches[1] } }" > %DIST%\VERSION.txt

echo.
echo --- Build, Rename, and Move Successful (x64 + x86) ---

REM Default deploy target. Override by setting LISTENINGWAY_DEPLOY_DIR.
if not defined LISTENINGWAY_DEPLOY_DIR (
    set "LISTENINGWAY_DEPLOY_DIR=E:\Games\SquareEnix\FINAL FANTASY XIV - A Realm Reborn\game"
)

REM Auto-deploy. deploy.bat skips with a message if the path doesn't exist.
REM Defaults to x64; set LISTENINGWAY_DEPLOY_ARCH=x86 for a 32-bit test rig.
if exist .\deploy.bat (
    echo.
    echo --- Automatically deploying to %LISTENINGWAY_DEPLOY_DIR% ---
    call .\deploy.bat
)

endlocal
exit /b 0

:build_failed
echo.
echo --- Build Failed ---
endlocal
exit /b 1

REM ============================================================
REM  Subroutine: build_arch
REM    %1 = arch tag      (x64 / x86)
REM    %2 = cmake -A      (x64 / Win32)
REM    %3 = vcpkg triplet (x64-windows-static / x86-windows-static)
REM ============================================================
:build_arch
set "ARCH_TAG=%~1"
set "CMAKE_PLATFORM=%~2"
set "VCPKG_TRIPLET=%~3"
set "BUILD_DIR=build-%ARCH_TAG%"

REM Configure if the build dir is missing or stale (no CMakeCache.txt).
if not exist "%BUILD_DIR%\CMakeCache.txt" (
    echo.
    echo === Configuring %ARCH_TAG% (%CMAKE_PLATFORM%, %VCPKG_TRIPLET%) ===
    if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
    cmake -S . -B "%BUILD_DIR%" -G %CMAKE_GENERATOR% -A %CMAKE_PLATFORM% -DRESHADE_SDK_PATH="%RESHADE_SDK_PATH%" -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN_FILE%" -DVCPKG_TARGET_TRIPLET=%VCPKG_TRIPLET%
    if errorlevel 1 (
        echo CMake configuration for %ARCH_TAG% failed.
        exit /b 1
    )
)

echo.
echo === Building %ARCH_TAG% (%CONFIG%) ===
msbuild "%BUILD_DIR%\Listeningway.sln" /p:Configuration=%CONFIG% /m
if errorlevel 1 (
    echo Build for %ARCH_TAG% failed.
    exit /b 1
)

set "OUTDLL=%BUILD_DIR%\%CONFIG%\Listeningway.dll"
set "OUTADDON=%DIST%\Listeningway-%ARCH_TAG%.addon"
if exist "%OUTADDON%" del "%OUTADDON%"
if exist "%OUTDLL%" copy /Y "%OUTDLL%" "%OUTADDON%" >nul
if not exist "%OUTADDON%" (
    echo Expected output %OUTADDON% missing after build.
    exit /b 1
)
exit /b 0
