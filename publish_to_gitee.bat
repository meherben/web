@echo off
rem ===========================================================================
rem  Publish D:\file\hugo\meherDocsy\public to Gitee
rem  Repo : git@gitee.com:ben198901/public.git
rem  Key  : D:\file\key\gitee\gitee  (private) / gitee.pub (public)
rem
rem  How it works:
rem  - Uses a dedicated GIT_SSH_COMMAND pointing at the private key, so the
rem    system-wide SSH config / default key is never touched.
rem  - The public folder is treated as a *deploy target*: if it already has a
rem    .git, we just commit & push; if not, we init one bound to the Gitee
rem    remote. --cleanDestinationDir in the build script only wipes the site
rem    output, so .git survives across rebuilds as long as you don't delete it.
rem  - Accepts an optional commit message as %1. Defaults to a timestamp.
rem ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
pushd "%~dp0" || goto :no_cwd

set "PUBDIR=D:\file\hugo\meherDocsy\public"
set "KEYDIR=D:\file\key\gitee"
set "KEY=%KEYDIR%\gitee"
set "REMOTE=git@gitee.com:ben198901/public.git"
set "BRANCH=master"
set "RC=0"

rem Optional commit message; fall back to a timestamp.
set "MSG=%~1"
if "%MSG%"=="" (
    for /f "tokens=1-2 delims=/ " %%a in ('date /t') do set "D=%%a"
    for /f "tokens=1-2 delims=:." %%a in ('time /t') do set "T=%%a"
    set "MSG=deploy: %DATE% %TIME%"
)

echo ==========================================
echo   Publish public\ to Gitee
echo ==========================================
echo   Source : %PUBDIR%
echo   Remote : %REMOTE%
echo   Branch : %BRANCH%
echo   Key    : %KEY%
echo   Message: %MSG%
echo.

rem --- Sanity checks ---------------------------------------------------------
if not exist "%PUBDIR%" goto :no_pubdir
if not exist "%KEY%"    goto :no_key

where git >nul 2>&1
if errorlevel 1 goto :no_git

rem --- Dedicated SSH command: only this key, no prompts ----------------------
rem  IdentitiesOnly=yes  -> don't try other keys in %USERPROFILE%\.ssh
rem  BatchMode=yes       -> fail instead of prompting for a passphrase
set "GIT_SSH_COMMAND=ssh -i "%KEY%" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

cd /d "%PUBDIR%" || goto :no_cd

rem --- Init repo if needed ---------------------------------------------------
if not exist ".git" (
    echo [1/4] Initialising git repository in %PUBDIR% ...
    git init -b "%BRANCH%" || goto :git_failed
    git remote add origin "%REMOTE%" || goto :git_failed
) else (
    echo [1/4] Existing .git found, reusing it.
    rem Make sure origin points where we expect (harmless if already correct).
    git remote get-url origin >nul 2>&1
    if errorlevel 1 (
        git remote add origin "%REMOTE%" || goto :git_failed
    ) else (
        git remote set-url origin "%REMOTE%" || goto :git_failed
    )
)

rem --- Make sure we're on the target branch ----------------------------------
git rev-parse --abbrev-ref HEAD 2>nul | findstr /I /C:"%BRANCH%" >nul
if errorlevel 1 (
    echo [2/4] Switching to branch %BRANCH% ...
    git checkout -B "%BRANCH%" || goto :git_failed
) else (
    echo [2/4] Already on branch %BRANCH%.
)

rem --- Stage, commit, push ---------------------------------------------------
echo [3/4] Staging and committing ...
git add -A || goto :git_failed

rem Nothing to commit is not an error: still push in case remote is behind.
git diff --cached --quiet
if errorlevel 1 (
    git -c user.name="deploy" -c user.email="deploy@local" commit -m "%MSG%" || goto :git_failed
) else (
    echo        No changes to commit.
)

echo [4/4] Pushing to %REMOTE% ...
git push -u origin "%BRANCH%" || goto :push_failed

echo.
echo [OK] Published to %REMOTE% (%BRANCH%).
goto :done

rem ---------------------------------------------------------------------------
:no_cwd
echo [ERROR] Cannot enter the script directory: %~dp0
set "RC=1" & goto :done_plain

:no_pubdir
echo [ERROR] Public folder not found: %PUBDIR%
echo         Run the Hugo build script first.
set "RC=1" & goto :done

:no_key
echo [ERROR] SSH private key not found: %KEY%
echo         Expected: D:\file\key\gitee\gitee
set "RC=1" & goto :done

:no_git
echo [ERROR] git was not found in PATH.
set "RC=1" & goto :done

:no_cd
echo [ERROR] Cannot cd into %PUBDIR%
set "RC=1" & goto :done

:git_failed
echo [FAILED] A git command failed. See output above.
set "RC=1" & goto :done

:push_failed
echo [FAILED] Push rejected. Common causes:
echo          - The Gitee repo is not empty (README / license). Run:
echo              git pull --rebase origin %BRANCH%
echo            once, then retry.
echo          - The public key gitee.pub is not added to Gitee ^(Settings - SSH^).
echo          - Network / firewall blocks port 22. Try:
echo              set GIT_SSH_COMMAND=ssh -i "%KEY%" -p 443 ...
echo            with ssh.gitee.com as host if needed.
set "RC=1" & goto :done

:done
echo.
popd
pause
endlocal & exit /b %RC%

:done_plain
echo.
endlocal & exit /b %RC%