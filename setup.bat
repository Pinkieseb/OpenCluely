@echo off
setlocal enabledelayedexpansion

:: Default values
set DO_BUILD=1
set DO_RUN=1
set USE_CI=0
set INSTALL_SYSTEM_DEPS=0
set SETUP_WHISPER=1

:: Default Whisper Settings
if "%WHISPER_MODEL%"=="" set WHISPER_MODEL=base
if "%WHISPER_LANGUAGE%"=="" set WHISPER_LANGUAGE=en
if "%WHISPER_SEGMENT_MS%"=="" set WHISPER_SEGMENT_MS=4000
set WHISPER_VENV_DIR=.venv-whisper
set WHISPER_MODEL_DIR=.whisper-models

set SCRIPT_DIR=%~dp0
set OS_NAME=windows
set PLATFORM_BUILD_SCRIPT=build:win
set PYTHON_BIN=python
set WHISPER_PIP_PATH=%WHISPER_VENV_DIR%\Scripts\pip.exe
set WHISPER_COMMAND_PATH=%WHISPER_VENV_DIR%\Scripts\whisper.exe

:: Process Arguments
:parse_args
if "%~1"=="" goto end_parse
if /I "%~1"=="--build" (set DO_BUILD=1 & shift & goto parse_args)
if /I "%~1"=="--no-run" (set DO_RUN=0 & shift & goto parse_args)
if /I "%~1"=="--run" (set DO_RUN=1 & shift & goto parse_args)
if /I "%~1"=="--ci" (set USE_CI=1 & shift & goto parse_args)
if /I "%~1"=="--install-system-deps" (set INSTALL_SYSTEM_DEPS=1 & shift & goto parse_args)
if /I "%~1"=="--skip-whisper" (set SETUP_WHISPER=0 & shift & goto parse_args)
if /I "%~1"=="-h" (goto usage)
if /I "%~1"=="--help" (goto usage)
echo Unknown option: %~1
goto usage

:usage
echo Usage: setup.bat [options]
echo.
echo This script will:
echo 1. Create .env from env.example when needed
echo 2. Install Node dependencies
echo 3. Optionally set up local Whisper in %WHISPER_VENV_DIR%
echo 4. Optionally install system audio dependencies
echo 5. Optionally build the app
echo 6. Optionally run OpenCluely
echo.
echo Options:
echo   --build                 Build a distributable for this OS
echo   --no-run                Do not start the app after setup
echo   --run                   Start the app after setup (default)
echo   --ci                    Use 'npm ci' instead of 'npm install'
echo   --install-system-deps   Attempt to install sox where possible
echo   --skip-whisper          Skip local Whisper environment setup
echo   -h, --help              Show this help
echo.
echo Environment variables:
echo   GEMINI_API_KEY          If provided, writes into .env
echo   WHISPER_MODEL           Whisper model to configure (default: turbo)
echo   WHISPER_LANGUAGE        Whisper language to configure (default: en)
echo   WHISPER_SEGMENT_MS      Segment size in ms (default: 4000)
echo.
echo Example:
echo   set GEMINI_API_KEY=your_key_here ^&^& setup.bat --install-system-deps
exit /b 1

:end_parse

call :print_header
cd /d "%SCRIPT_DIR%"

:: Check Dependencies
call :require_command node "Node.js 18+ is required." || exit /b 1
call :require_command npm "npm is required." || exit /b 1
for /f "delims=" %%i in ('node -v') do echo Node: %%i
for /f "delims=" %%i in ('npm -v') do echo npm:  %%i

call :ensure_env_file
call :ensure_gemini_key
call :install_system_deps
call :install_node_deps
call :setup_whisper_env
call :build_app
call :run_app

exit /b 0

:: Functions
:print_header
echo ========================================
echo  OpenCluely Setup
echo ========================================
exit /b 0

:require_command
where %1 >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: %~2
    exit /b 1
)
exit /b 0

:ensure_env_file
if not exist ".env" (
    if exist "env.example" (
        echo Creating .env from env.example
        copy env.example .env >nul
    ) else (
        echo Error: env.example is missing
        exit /b 1
    )
)
exit /b 0

:upsert_env
set "key=%~1"
set "value=%~2"
findstr /b /c:"%key%=" .env >nul 2>nul
if %errorlevel% equ 0 (
    :: Update existing key (using powershell for robust replacement)
    powershell -Command "(Get-Content .env) -replace '^%key%=.*', '%key%=%value%' | Set-Content .env"
) else (
    :: Add new key
    echo %key%=%value%>> .env
)
exit /b 0

:ensure_gemini_key
if not "%GEMINI_API_KEY%"=="" (
    call :upsert_env "GEMINI_API_KEY" "%GEMINI_API_KEY%"
)
findstr /b /c:"GEMINI_API_KEY=" .env >nul 2>nul
if %errorlevel% neq 0 (
    echo GEMINI_API_KEY=your_gemini_api_key_here>> .env
)
findstr /c:"your_gemini_api_key_here" .env >nul 2>nul
if %errorlevel% equ 0 (
    echo.
    echo ==========================================
    echo  No Gemini API key detected
    echo ==========================================
    echo.
    echo The app will start, but AI features won't work until you set
    echo GEMINI_API_KEY in .env ^(or via the Settings window on first launch^).
    echo.
    echo Get a free key from: https://aistudio.google.com/
    echo.
    echo Setup will continue without blocking.
    echo.
)
exit /b 0

:install_system_deps
if "%INSTALL_SYSTEM_DEPS%"=="1" (
    echo Attempting to install system audio dependencies
    where sox >nul 2>nul
    if %errorlevel% equ 0 (
        echo sox already installed
    ) else (
        echo Install sox manually on Windows, for example via Chocolatey: choco install sox
    )
)
exit /b 0

:install_node_deps
if exist "package-lock.json" (
    if "%USE_CI%"=="1" (
        echo Installing Node dependencies with npm ci
        call npm ci
        exit /b 0
    )
)
echo Installing Node dependencies with npm install
call npm install
exit /b 0

:setup_whisper_env
if "%SETUP_WHISPER%"=="0" (
    echo Skipping local Whisper setup
    exit /b 0
)
if "%DO_BUILD%"=="1" if "%DO_RUN%"=="0" (
    echo Skipping local Whisper setup ^(build-only mode^)
    exit /b 0
)

call :require_command %PYTHON_BIN% "Python 3 is required for local Whisper setup." || exit /b 1

if not exist "%WHISPER_VENV_DIR%" (
    echo Creating Whisper virtual environment at %WHISPER_VENV_DIR%
    %PYTHON_BIN% -m venv "%WHISPER_VENV_DIR%"
)

echo Installing local Whisper into %WHISPER_VENV_DIR%
call "%WHISPER_PIP_PATH%" install --upgrade pip >nul 2>nul
call "%WHISPER_PIP_PATH%" install openai-whisper
if %errorlevel% neq 0 (
    echo WARNING: pip install openai-whisper failed. Whisper may be unavailable.
    echo Common causes: insufficient disk space ^(needs ~3-5 GB^), missing Python headers, or network issues.
)

if not exist "%WHISPER_MODEL_DIR%" mkdir "%WHISPER_MODEL_DIR%"

set whisper_found=0
if exist "%WHISPER_COMMAND_PATH%" (
    echo Whisper CLI found at: %WHISPER_COMMAND_PATH%
    set whisper_found=1
) else (
    set venv_python=%WHISPER_VENV_DIR%\Scripts\python.exe
    if exist "!venv_python!" (
        !venv_python! -m whisper --help >nul 2>nul
        if !errorlevel! equ 0 (
            echo Whisper CLI not found as standalone script, but 'python -m whisper' works.
            echo Adjusting WHISPER_COMMAND to use venv Python module.
            set WHISPER_COMMAND_PATH=!venv_python! -m whisper
            set whisper_found=1
        ) else (
            goto whisper_not_found
        )
    ) else (
        :whisper_not_found
        echo WARNING: Whisper CLI not found at %WHISPER_COMMAND_PATH%
        echo Speech recognition will be unavailable until Whisper is properly installed.
        echo You can skip this with: setup.bat --skip-whisper
    )
)

call :upsert_env "SPEECH_PROVIDER" "whisper"
call :upsert_env "AZURE_SPEECH_KEY" ""
call :upsert_env "AZURE_SPEECH_REGION" ""
call :upsert_env "WHISPER_COMMAND" "%WHISPER_COMMAND_PATH%"
call :upsert_env "WHISPER_MODEL_DIR" "%WHISPER_MODEL_DIR%"
call :upsert_env "WHISPER_MODEL" "%WHISPER_MODEL%"
call :upsert_env "WHISPER_LANGUAGE" "%WHISPER_LANGUAGE%"
call :upsert_env "WHISPER_SEGMENT_MS" "%WHISPER_SEGMENT_MS%"

if "%whisper_found%"=="1" (
    echo Running Whisper smoke test
    call npm run test-speech
) else (
    echo Skipping Whisper smoke test ^(CLI not found^)
)
exit /b 0

:build_app
if "%DO_BUILD%"=="1" (
    if not exist "dist" mkdir "dist"
    echo Building app for %OS_NAME% with npm run %PLATFORM_BUILD_SCRIPT%
    call npm run %PLATFORM_BUILD_SCRIPT%
    if !errorlevel! neq 0 (
        echo Error: Failed to build binaries and executable.
        exit /b 1
    )
    echo Successfully generated binaries and exe in dist/ directory.
)
exit /b 0

:run_app
if "%DO_RUN%"=="1" (
    echo Starting app
    call npm start
) else (
    echo Setup complete. Skipping run.
)
exit /b 0
