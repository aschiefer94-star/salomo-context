# Salomo VPS Setup Script
# Run as Administrator in PowerShell
# Sets up Python, Git, Salomo repo, dependencies, and Task Scheduler

$ErrorActionPreference = "Stop"
$INSTALL_DIR = "C:\Salomo"
$FRED_API_KEY = Read-Host "Enter your FRED API Key"
$GH_TOKEN = Read-Host "Enter your GitHub Personal Access Token (for cloning private repo)"
$REPO_URL = "https://x-access-token:$GH_TOKEN@github.com/aschiefer94-star/salomo.git"

Write-Host "`n=== Salomo VPS Setup ===" -ForegroundColor Cyan

# --- Git ---
Write-Host "`n[1/5] Installing Git..." -ForegroundColor Yellow
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# --- Python 3.12 ---
Write-Host "`n[2/5] Installing Python 3.12..." -ForegroundColor Yellow
winget install --id Python.Python.3.12 -e --source winget --accept-package-agreements --accept-source-agreements
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# --- Clone repo ---
Write-Host "`n[3/5] Cloning Salomo repo to $INSTALL_DIR..." -ForegroundColor Yellow
if (Test-Path $INSTALL_DIR) {
    Write-Host "Directory exists — pulling latest..." -ForegroundColor Gray
    Set-Location $INSTALL_DIR
    git pull
} else {
    git clone $REPO_URL $INSTALL_DIR
    Set-Location $INSTALL_DIR
}

# --- .env ---
Write-Host "`n[4/5] Creating .env..." -ForegroundColor Yellow
@"
FRED_API_KEY=$FRED_API_KEY
MPLBACKEND=Agg
"@ | Set-Content "$INSTALL_DIR\.env"

# --- Virtual environment + dependencies ---
Write-Host "`n[5/5] Setting up Python venv and installing dependencies..." -ForegroundColor Yellow
python -m venv "$INSTALL_DIR\.venv"
& "$INSTALL_DIR\.venv\Scripts\pip.exe" install --upgrade pip
& "$INSTALL_DIR\.venv\Scripts\pip.exe" install -r "$INSTALL_DIR\requirements.txt"

# --- Task Scheduler: Mo-Fr 06:30 UTC ---
Write-Host "`nSetting up Task Scheduler (Mo-Fr 06:30 UTC)..." -ForegroundColor Yellow

$taskName = "SalomoDailyContext"
$pythonExe = "$INSTALL_DIR\.venv\Scripts\python.exe"
$scriptPath = "$INSTALL_DIR\main.py"

$action = New-ScheduledTaskAction -Execute $pythonExe -Argument $scriptPath -WorkingDirectory $INSTALL_DIR
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "06:30AM"
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal

Write-Host "`n=== Setup complete! ===" -ForegroundColor Green
Write-Host "Repo:        $INSTALL_DIR"
Write-Host "Python:      $pythonExe"
Write-Host "Task:        $taskName (Mo-Fr 06:30 UTC)"
Write-Host "`nTest run: Press any key to run the pipeline now..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Set-Location $INSTALL_DIR
& $pythonExe $scriptPath
