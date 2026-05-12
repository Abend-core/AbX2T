@echo off
setlocal

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%src\DesktopEditor\AllFontsGen
set BUILD_EXE=%PROJECT_DIR%\build\x64\Release\allfontsgen_modern.exe
set BUNDLE_EXE=%SCRIPT_DIR%bin\Release\allfontsgen_modern.exe

if not exist "%PROJECT_DIR%\AllFontsGen.vcxproj" (
  echo Project not found: %PROJECT_DIR%\AllFontsGen.vcxproj
  exit /b 1
)

pushd "%PROJECT_DIR%"
msbuild AllFontsGen.vcxproj /p:Configuration=Release /p:Platform=x64 /m
if errorlevel 1 (
  popd
  exit /b 1
)
popd

if exist "%BUILD_EXE%" (
  copy /Y "%BUILD_EXE%" "%BUNDLE_EXE%" >nul
)

echo.
echo Build completed.
echo Build output: %BUILD_EXE%
echo Bundled executable: %BUNDLE_EXE%
endlocal
