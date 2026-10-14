@echo off
cls
echo ==========================================
echo        Lime Fixer - NMV Engine
echo ==========================================
echo [1] Rebuild for Windows (PC)
echo [2] Rebuild for Android (Mobile)
echo [3] Rebuild for Both (Windows and Android)
echo ==========================================
set /p choice="Select an option (1, 2, or 3): "

echo.
echo Updating Git submodules...
cd ../
cd .haxelib/lime/git/
git submodule sync --recursive
git submodule update --init --recursive --force
cd ../../../

if "%choice%"=="1" goto windows
if "%choice%"=="2" goto android
if "%choice%"=="3" goto both
goto invalid

:windows
echo.
echo Rebuilding Lime for Windows...
haxelib run lime rebuild cpp -clean
goto end

:android
echo.
echo Rebuilding Lime for Android...
haxelib run lime rebuild android -clean
goto end

:both
echo.
echo Rebuilding Lime for Windows...
haxelib run lime rebuild cpp -clean
echo.
echo Rebuilding Lime for Android...
haxelib run lime rebuild android -clean
goto end

:invalid
echo.
echo Invalid choice. Please run the script again.
goto end

:end
echo.
echo Finished rebuilding lime!
pause