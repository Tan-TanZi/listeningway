@echo off
cd /d %~dp0 REM Change directory to the script's location
setlocal

REM ============================================================
REM  prepare.bat: once-per-machine bootstrap.
REM  Clones reshade + vcpkg, bootstraps vcpkg, and installs the
REM  dependency set for BOTH x64-windows-static and x86-windows-static
REM  triplets (used by build.bat to produce dual-arch addons).
REM
REM  Build directories (build-x64/, build-x86/) are CMake-generated
REM  artefacts; build.bat creates them on demand. Delete them any
REM  time and build.bat will reconfigure cleanly.
REM ============================================================

set TOOLS_DIR=tools
set RESHADE_DIR=third_party\reshade
set VCPKG_DIR=%TOOLS_DIR%\vcpkg
set RESHADE_REPO_URL=https://github.com/crosire/reshade.git
set VCPKG_REPO_URL=https://github.com/microsoft/vcpkg.git

echo Ensuring tools directory exists...
if not exist "%TOOLS_DIR%" (
    mkdir "%TOOLS_DIR%"
    if errorlevel 1 (
        echo Failed to create %TOOLS_DIR% directory.
        goto failure
    )
)

echo Checking for ReShade repository...
if not exist "%RESHADE_DIR%\.git" (
    echo ReShade repository not found. Cloning from %RESHADE_REPO_URL% at tag v6.3.3...
    git clone --branch v6.3.3 --depth 1 %RESHADE_REPO_URL% "%RESHADE_DIR%"
    if errorlevel 1 (
        echo Failed to clone ReShade repository.
        goto failure
    )
) else (
    echo ReShade repository found at %RESHADE_DIR%.
    pushd "%RESHADE_DIR%"
    git fetch --tags
    git checkout v6.3.3
    popd
)

echo Checking for vcpkg repository...
if not exist "%VCPKG_DIR%\.git" (
    echo vcpkg repository not found. Cloning from %VCPKG_REPO_URL%...
    git clone --depth 1 %VCPKG_REPO_URL% "%VCPKG_DIR%"
    if errorlevel 1 (
        echo Failed to clone vcpkg repository.
        goto failure
    )
) else (
    echo vcpkg repository found at %VCPKG_DIR%.
)

echo Checking for vcpkg executable...
if not exist "%VCPKG_DIR%\vcpkg.exe" (
    echo vcpkg.exe not found. Running bootstrap script...
    call "%VCPKG_DIR%\bootstrap-vcpkg.bat" -disableMetrics
    if errorlevel 1 (
        echo Failed to bootstrap vcpkg.
        goto failure
    )
) else (
    echo vcpkg.exe found.
)

echo.
echo === Installing dependencies for x64-windows-static ===
"%VCPKG_DIR%\vcpkg.exe" install --triplet x64-windows-static
if errorlevel 1 (
    echo Failed to install x64 dependencies with vcpkg.
    goto failure
)

echo.
echo === Installing dependencies for x86-windows-static ===
"%VCPKG_DIR%\vcpkg.exe" install --triplet x86-windows-static
if errorlevel 1 (
    echo Failed to install x86 dependencies with vcpkg.
    goto failure
)

REM --- Ensure correct ImGui version for ReShade (match submodule/commit in ReShade v6.3.3) ---
echo Resetting ImGui in ReShade deps to match v6.3.3...
set IMGUIDIR=%RESHADE_DIR%\deps\imgui
if exist "%IMGUIDIR%\.git" (
    pushd "%RESHADE_DIR%"
    git submodule update --init --recursive deps/imgui
    git -C deps/imgui checkout 19040
    popd
) else (
    echo No .git found in %IMGUIDIR%, skipping ImGui reset.
)

REM --- Ensure ImGui is present in ReShade deps ---
set IMGUI_HEADER=%IMGUIDIR%\imgui.h
if not exist "%IMGUI_HEADER%" (
    echo ImGui not found in %IMGUIDIR%. Cloning from official repository...
    if exist "%IMGUIDIR%" rmdir /s /q "%IMGUIDIR%"
    git clone --branch v1.90.4 --depth 1 https://github.com/ocornut/imgui.git "%IMGUIDIR%"
    if errorlevel 1 (
        echo Failed to clone ImGui repository.
        goto failure
    )
) else (
    echo ImGui found at %IMGUI_HEADER%.
)

echo.
echo --- Preparation Successful ---
echo Run build.bat to produce both x64 and x86 addons.
goto end

:failure
echo.
echo --- Preparation Failed ---
endlocal
exit /b 1

:end
endlocal
exit /b 0
