# Disable UAC
Write-Host "Press any key to open UAC settings, then disable UAC by changing the slider to 'Never notify'" -ForegroundColor Cyan
$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') | Out-Null
useraccountcontrolsettings
Start-Sleep -Milliseconds 2000
Write-Host "Confirm UAC is disabled, then press any key to continue" -ForegroundColor Yellow
$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') | Out-Null

# Set execution policy
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

# Widgets off (HKLM) - elevate only if needed
$RemoveWidgetCmd = 'reg.exe add "HKLM\Software\Policies\Microsoft\Dsh" /v "AllowNewsAndInterests" /t REG_DWORD /d 0 /f'

$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    & reg.exe add "HKLM\Software\Policies\Microsoft\Dsh" /v "AllowNewsAndInterests" /t REG_DWORD /d 0 /f | Out-Null
} else {
    try {
        Start-Process -FilePath "powershell.exe" -Verb RunAs -Wait -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy','Bypass',
            '-Command', "$RemoveWidgetCmd | Out-Null"
        )
    } catch {
        Write-Warning "Elevation was cancelled or failed. Widgets policy was not applied."
    }
}

# Restore classic context menu
reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve

# Remove all pinned apps from taskbar
$taskbarPins = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
if (Test-Path $taskbarPins) {
    Remove-Item -Path (Join-Path $taskbarPins "*") -Force -ErrorAction SilentlyContinue
}

# Also try deleting Taskband state (may not exist on newer builds)
reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" /f 2>$null | Out-Null

# Search = Hide (plus cache)
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode"      /t REG_DWORD /d 0 /f | Out-Null
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarModeCache" /t REG_DWORD /d 1 /f | Out-Null

# Task View off
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t REG_DWORD /d 0 /f | Out-Null

# Start: More pins
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_Layout" /t REG_DWORD /d 1 /f | Out-Null

# Start: disable “recently added”
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Start" /v "ShowRecentList" /t REG_DWORD /d 0 /f | Out-Null

# Start/Explorer/Jump lists: disable recents
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_TrackDocs" /t REG_DWORD /d 0 /f | Out-Null

# Start: disable websites from browsing history (policy)
reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "HideRecommendedPersonalizedSites" /t REG_DWORD /d 1 /f | Out-Null

# Start: disable “tips/shortcuts/new apps”
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_IrisRecommendations" /t REG_DWORD /d 0 /f | Out-Null

# Start: disable account notifications
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_AccountNotifications" /t REG_DWORD /d 0 /f | Out-Null

# Explorer: compact view + file extensions
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "UseCompactMode" /t REG_DWORD /d 1 /f | Out-Null
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt"    /t REG_DWORD /d 0 /f | Out-Null

# File Explorer: open to "This PC" (LaunchTo=1)
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "LaunchTo" /t REG_DWORD /d 1 /f | Out-Null

# Theme: Windows (dark) – system + apps
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme"     /t REG_DWORD /d 0 /f | Out-Null
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "SystemUsesLightTheme" /t REG_DWORD /d 0 /f | Out-Null

# Desktop: set dark Bloom wallpaper
if (-not (Test-Path "C:\Windows\Web\4K\Wallpaper\Windows\img19_1920x1200.jpg")) {
    throw "Wallpaper file not found: C:\Windows\Web\4K\Wallpaper\Windows\img19_1920x1200.jpg"
}

New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -PropertyType String -Value "10" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper   -PropertyType String -Value "0"  -Force | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Params {
    [DllImport("User32.dll", CharSet = CharSet.Unicode)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

# SPI_SETDESKWALLPAPER = 0x0014, flags = 0x01 (update ini) + 0x02 (broadcast change) = 0x03
[Params]::SystemParametersInfo(0x0014, 0, "C:\Windows\Web\4K\Wallpaper\Windows\img19_1920x1200.jpg", 0x03) | Out-Null

# Apply changes: restart Explorer
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800
Start-Process explorer.exe

# Remove bloatware
Get-AppxPackage -Name "Clipchamp.Clipchamp" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.BingNews" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.BingWeather" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.GamingApp" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.GetHelp" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.MicrosoftOfficeHub" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.MicrosoftSolitaireCollection" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.MicrosoftStickyNotes" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.OutlookForWindows" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.PowerAutomateDesktop" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.Todos" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.Windows.DevHome" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.WindowsAlarms" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.WindowsCamera" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.WindowsFeedbackHub" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.WindowsSoundRecorder" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.YourPhone" | Remove-AppxPackage
Get-AppxPackage -Name "Microsoft.ZuneMusic" | Remove-AppxPackage
Get-AppxPackage -Name "MicrosoftCorporationII.QuickAssist" | Remove-AppxPackage
winget remove Microsoft.Teams

# Update winget sources
winget source update

# Update existing apps
winget upgrade --all --accept-source-agreements --accept-package-agreements

# Install new apps
winget install Microsoft.VCRedist.2005.x64 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2005.x86 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2008.x64 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2008.x86 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2010.x64 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2010.x86 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2012.x64 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2012.x86 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2013.x64 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2013.x86 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2015+.x64 --accept-source-agreements --accept-package-agreements
winget install Microsoft.VCRedist.2015+.x86 --accept-source-agreements --accept-package-agreements
winget install 7zip.7zip --accept-source-agreements --accept-package-agreements
winget install Gyan.FFmpeg --accept-source-agreements --accept-package-agreements
winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements
winget install 9N1F85V9T8BN --accept-source-agreements --accept-package-agreements
winget install Microsoft.Office --accept-source-agreements --accept-package-agreements
winget install Starship.Starship --accept-source-agreements --accept-package-agreements
winget install ajeetdsouza.zoxide --accept-source-agreements --accept-package-agreements
winget install DEVCOM.JetBrainsMonoNerdFont --accept-source-agreements --accept-package-agreements
winget install CrystalDewWorld.CrystalDiskInfo --accept-source-agreements --accept-package-agreements
winget install CrystalDewWorld.CrystalDiskMark --accept-source-agreements --accept-package-agreements
winget install ImputNet.Helium --accept-source-agreements --accept-package-agreements
winget install Zen-Team.Zen-Browser --accept-source-agreements --accept-package-agreements
winget install Google.Chrome --accept-source-agreements --accept-package-agreements
winget install RaspberryPiFoundation.RaspberryPiImager --accept-source-agreements --accept-package-agreements
winget install Audacity.Audacity --accept-source-agreements --accept-package-agreements
winget install TGRMNSoftware.BulkRenameUtility --accept-source-agreements --accept-package-agreements
winget install REALiX.HWiNFO --accept-source-agreements --accept-package-agreements
winget install LocalSend.LocalSend --accept-source-agreements --accept-package-agreements
winget install Discord.Discord --accept-source-agreements --accept-package-agreements
winget install Bambulab.Bambustudio --accept-source-agreements --accept-package-agreements
winget install OBSProject.OBSStudio --accept-source-agreements --accept-package-agreements
winget install MPC-BE.MPC-BE --accept-source-agreements --accept-package-agreements
winget install ente-io.auth-desktop --accept-source-agreements --accept-package-agreements
winget install Proton.ProtonVPN --accept-source-agreements --accept-package-agreements
winget install Valve.Steam --accept-source-agreements --accept-package-agreements
winget install Microsoft.VisualStudioCode --accept-source-agreements --accept-package-agreements
winget install MOTU.MSeries --accept-source-agreements --accept-package-agreements
winget install Tailscale.Tailscale --accept-source-agreements --accept-package-agreements
winget install Microsoft.PowerToys --accept-source-agreements --accept-package-agreements
winget install Adobe.CreativeCloud --accept-source-agreements --accept-package-agreements
winget remove Microsoft.OneDrive
winget remove Microsoft.CommandPalette

# Install NVIDIA App (fallback since winget package may be unavailable)
try {
    $nvidiaLandingUrl = "https://www.nvidia.com/en-us/software/nvidia-app/"
    $nvidiaInstallerPath = Join-Path $env:TEMP "NVIDIA_app_setup.exe"
    $nvidiaPage = Invoke-WebRequest -Uri $nvidiaLandingUrl -UseBasicParsing
    $nvidiaAppUrl = ($nvidiaPage.Content | Select-String -Pattern 'https://[^"''\s]+NVIDIA_app[^"''\s]+\.exe' -AllMatches).Matches.Value |
        Select-Object -First 1

    if (-not $nvidiaAppUrl) {
        Write-Warning "Could not detect a direct NVIDIA App installer URL automatically. Open $nvidiaLandingUrl and install manually."
    } else {
        Write-Host "Downloading NVIDIA App installer..." -ForegroundColor Cyan
        $downloadMethod = $null
        $downloadTimer = [System.Diagnostics.Stopwatch]::StartNew()

        if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
            $downloadMethod = "curl.exe"
            & curl.exe -L --fail --retry 3 --retry-delay 2 --output $nvidiaInstallerPath $nvidiaAppUrl
            if ($LASTEXITCODE -ne 0) {
                throw "curl.exe download failed with exit code $LASTEXITCODE"
            }
        } elseif (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            $downloadMethod = "BITS"
            Start-BitsTransfer -Source $nvidiaAppUrl -Destination $nvidiaInstallerPath -ErrorAction Stop
        } else {
            $downloadMethod = "Invoke-WebRequest"
            $oldProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try {
                Invoke-WebRequest -Uri $nvidiaAppUrl -OutFile $nvidiaInstallerPath -UseBasicParsing
            } finally {
                $ProgressPreference = $oldProgressPreference
            }
        }

        $downloadTimer.Stop()
        if (Test-Path $nvidiaInstallerPath) {
            $downloadedSizeMB = [Math]::Round(((Get-Item $nvidiaInstallerPath).Length / 1MB), 2)
            $downloadSeconds = [Math]::Max($downloadTimer.Elapsed.TotalSeconds, 0.01)
            $downloadSpeedMBs = [Math]::Round(($downloadedSizeMB / $downloadSeconds), 2)
            Write-Host "NVIDIA installer download complete via $downloadMethod ($downloadedSizeMB MB @ $downloadSpeedMBs MB/s)." -ForegroundColor Green
        }

        Write-Host "Installing NVIDIA App..." -ForegroundColor Cyan
        Start-Process -FilePath $nvidiaInstallerPath -ArgumentList '/S' -Wait
    }
} catch {
    Write-Warning "NVIDIA App installation failed: $($_.Exception.Message)"
} finally {
    if (Test-Path $nvidiaInstallerPath) {
        Remove-Item -Path $nvidiaInstallerPath -Force -ErrorAction SilentlyContinue
    }
}

# Install FL Studio (direct redirect to latest installer)
try {
    $flStudioInstallerUrl = "https://support.image-line.com/redirect/flstudio_win_installer"
    $flStudioInstallerPath = Join-Path $env:TEMP "FL_Studio_Installer.exe"

    Write-Host "Downloading FL Studio installer..." -ForegroundColor Cyan
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L --fail --retry 3 --retry-delay 2 --output $flStudioInstallerPath $flStudioInstallerUrl
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe download failed with exit code $LASTEXITCODE"
        }
    } elseif (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        Start-BitsTransfer -Source $flStudioInstallerUrl -Destination $flStudioInstallerPath -ErrorAction Stop
    } else {
        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $flStudioInstallerUrl -OutFile $flStudioInstallerPath -UseBasicParsing
        } finally {
            $ProgressPreference = $oldProgressPreference
        }
    }

    Write-Host "Installing FL Studio..." -ForegroundColor Cyan
    $flStudioProcess = Start-Process -FilePath $flStudioInstallerPath -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-' -Wait -PassThru
    if ($flStudioProcess.ExitCode -ne 0) {
        Write-Warning "Silent FL Studio install was not accepted (exit code: $($flStudioProcess.ExitCode)). Launching interactive installer..."
        Start-Process -FilePath $flStudioInstallerPath -Wait
    }
} catch {
    Write-Warning "FL Studio installation failed: $($_.Exception.Message)"
} finally {
    if (Test-Path $flStudioInstallerPath) {
        Remove-Item -Path $flStudioInstallerPath -Force -ErrorAction SilentlyContinue
    }
}

# Install iLok License Manager
try {
    $iLokZipUrl = "https://installers.ilok.com/iloklicensemanager/LicenseSupportInstallerWin64.zip"
    $iLokZipPath = Join-Path $env:TEMP "LicenseSupportInstallerWin64.zip"
    $iLokExtractDir = Join-Path $env:TEMP "iLokLicenseManager"

    Write-Host "Downloading iLok License Manager installer..." -ForegroundColor Cyan
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L --fail --retry 3 --retry-delay 2 --output $iLokZipPath $iLokZipUrl
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe download failed with exit code $LASTEXITCODE"
        }
    } elseif (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        Start-BitsTransfer -Source $iLokZipUrl -Destination $iLokZipPath -ErrorAction Stop
    } else {
        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $iLokZipUrl -OutFile $iLokZipPath -UseBasicParsing
        } finally {
            $ProgressPreference = $oldProgressPreference
        }
    }

    if (Test-Path $iLokExtractDir) {
        Remove-Item -Path $iLokExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $iLokExtractDir -Force | Out-Null
    Expand-Archive -Path $iLokZipPath -DestinationPath $iLokExtractDir -Force

    $iLokExeInstaller = Get-ChildItem -Path $iLokExtractDir -Filter *.exe -Recurse | Select-Object -First 1
    $iLokMsiInstaller = Get-ChildItem -Path $iLokExtractDir -Filter *.msi -Recurse | Select-Object -First 1

    Write-Host "Installing iLok License Manager..." -ForegroundColor Cyan
    if ($iLokExeInstaller) {
        Start-Process -FilePath $iLokExeInstaller.FullName -Wait
    } elseif ($iLokMsiInstaller) {
        Start-Process -FilePath "msiexec.exe" -ArgumentList '/i',"$($iLokMsiInstaller.FullName)",'/qn','/norestart' -Wait
    } else {
        throw "Could not find an .exe or .msi installer in extracted iLok package."
    }
} catch {
    Write-Warning "iLok License Manager installation failed: $($_.Exception.Message)"
} finally {
    if (Test-Path $iLokZipPath) {
        Remove-Item -Path $iLokZipPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $iLokExtractDir) {
        Remove-Item -Path $iLokExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Install Neural DSP - Archetype Gojira X
try {
    $neuralDspConfirmationUrl = "https://neuraldsp.com/download-confirmation/archetype-gojira?platform=pc"
    $neuralDspInstallerPath = Join-Path $env:TEMP "Archetype_Gojira_X_Setup.exe"
    $neuralDspInstallerUrl = $null

    Write-Host "Resolving Neural DSP installer URL..." -ForegroundColor Cyan
    $neuralDspResponse = Invoke-WebRequest -Uri $neuralDspConfirmationUrl -UseBasicParsing -MaximumRedirection 10
    $neuralDspFinalUri = $neuralDspResponse.BaseResponse.ResponseUri.AbsoluteUri
    if ($neuralDspFinalUri -match '\.exe(\?|$)') {
        $neuralDspInstallerUrl = $neuralDspFinalUri
    } else {
        $neuralDspInstallerUrl = ($neuralDspResponse.Content | Select-String -Pattern 'https://downloads\.neuraldsp\.com[^"''\s]+\.exe' -AllMatches).Matches.Value |
            Select-Object -First 1
    }

    if (-not $neuralDspInstallerUrl) {
        throw "Could not resolve a direct Neural DSP .exe installer URL from $neuralDspConfirmationUrl"
    }

    Write-Host "Downloading Neural DSP Archetype Gojira X installer..." -ForegroundColor Cyan
    if (Test-Path $neuralDspInstallerPath) {
        Remove-Item -Path $neuralDspInstallerPath -Force -ErrorAction SilentlyContinue
    }

    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L --silent --show-error --fail --retry 3 --retry-delay 2 --output $neuralDspInstallerPath $neuralDspInstallerUrl
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe download failed with exit code $LASTEXITCODE"
        }
    } elseif (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        Start-BitsTransfer -Source $neuralDspInstallerUrl -Destination $neuralDspInstallerPath -ErrorAction Stop
    } else {
        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $neuralDspInstallerUrl -OutFile $neuralDspInstallerPath -UseBasicParsing
        } finally {
            $ProgressPreference = $oldProgressPreference
        }
    }

    if (-not ((Test-Path $neuralDspInstallerPath) -and ((Get-Item $neuralDspInstallerPath).Length -gt 0))) {
        throw "Neural DSP installer download failed or returned an empty file."
    }

    $neuralDspHeader = Get-Content -Path $neuralDspInstallerPath -Encoding Byte -TotalCount 2
    if (($neuralDspHeader.Count -lt 2) -or ($neuralDspHeader[0] -ne 0x4D) -or ($neuralDspHeader[1] -ne 0x5A)) {
        throw "Downloaded Neural DSP file is not a valid Windows executable (likely HTML instead of installer)."
    }

    Write-Host "Installing Neural DSP Archetype Gojira X..." -ForegroundColor Cyan
    Start-Process -FilePath $neuralDspInstallerPath -Wait
} catch {
    Write-Warning "Neural DSP Archetype Gojira X installation failed: $($_.Exception.Message)"
} finally {
    if (Test-Path $neuralDspInstallerPath) {
        Remove-Item -Path $neuralDspInstallerPath -Force -ErrorAction SilentlyContinue
    }
}

# Pull Windows Terminal config
New-Item -ItemType Directory -Path "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState" -Force | Out-Null; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/chriscorbell/dotfiles-windows/main/settings.json" -OutFile "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# Set default terminal application to Windows Terminal
$consoleStartupKey = "HKCU:\Console\%%Startup"
$windowsTerminalDelegationGuid = "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
New-Item -Path $consoleStartupKey -Force | Out-Null
New-ItemProperty -Path $consoleStartupKey -Name "DelegationConsole" -PropertyType String -Value $windowsTerminalDelegationGuid -Force | Out-Null
New-ItemProperty -Path $consoleStartupKey -Name "DelegationTerminal" -PropertyType String -Value $windowsTerminalDelegationGuid -Force | Out-Null

# Install WSL2
wsl --install --no-distribution

# Install Bun
powershell -c "irm bun.sh/install.ps1|iex"

# Install uv
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Pull Starship config
New-Item -ItemType Directory -Path "$HOME\.config" -Force | Out-Null; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/chriscorbell/dotfiles/main/.config/starship.toml" -OutFile "$HOME\.config\starship.toml"

# Pull PowerShell profile
New-Item -ItemType Directory -Path "$HOME\Documents\PowerShell" -Force | Out-Null; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/chriscorbell/dotfiles-windows/main/Microsoft.PowerShell_profile.ps1" -OutFile "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
New-Item -ItemType Directory -Path "$HOME\Documents\WindowsPowerShell" -Force | Out-Null; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/chriscorbell/dotfiles-windows/main/Microsoft.PowerShell_profile.ps1" -OutFile "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

# Refresh path and source profile
$env:Path = [System.Environment]::ExpandEnvironmentVariables(([System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")))
. $PROFILE

# Install Python
uv python install
