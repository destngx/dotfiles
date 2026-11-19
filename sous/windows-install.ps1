# Runs on the Windows machine, copied there and started by bin/sous-windows-push after it copies
# sous.exe.new and config.toml.new. It stops the engine, puts the new files in place, registers the
# logon task that runs the engine (W-service option A in the monorepo's docs/sous/windows-port.md),
# starts it, and publishes the tailnet port once the port refuses a caller who is not the owner.
# It prints key=value lines for the push script to check.

$ErrorActionPreference = "Stop"
$bin = "$env:USERPROFILE\.local\bin"
$cfg = "$env:USERPROFILE\.config\sous"
$state = "$env:USERPROFILE\.local\state\sous"
$taskName = "sous"
# USERDOMAIN is WORKGROUP in an ssh session, which names no account; the token's name is MACHINE\user.
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name

# Stop the engine and the headless claude sessions it started, so the binary can be replaced.
if ((Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).State -eq "Running") {
  Stop-ScheduledTask -TaskName $taskName
}
Get-CimInstance Win32_Process -Filter "Name='sous.exe'" | ForEach-Object {
  Get-CimInstance Win32_Process -Filter "ParentProcessId=$($_.ProcessId)" |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

Move-Item "$bin\sous.exe.new" "$bin\sous.exe" -Force
Move-Item "$cfg\config.toml.new" "$cfg\config.toml" -Force
icacls "$cfg\config.toml" /inheritance:r /grant:r "${env:USERNAME}:F" "SYSTEM:F" "Administrators:F" | Out-Null

# Task Scheduler keeps no output, so the task runs this wrapper, which appends the engine's
# stdout and stderr to serve.log in the state folder, as launchd.log does on the Macs.
New-Item -ItemType Directory -Force $state | Out-Null
$wrapper = @'
$exe = "$env:USERPROFILE\.local\bin\sous.exe"
$log = "$env:USERPROFILE\.local\state\sous\serve.log"
cmd.exe /c "`"$exe`" serve >> `"$log`" 2>&1"
exit $LASTEXITCODE
'@
Set-Content -Path "$bin\sous-serve.ps1" -Value $wrapper -Encoding UTF8

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$bin\sous-serve.ps1`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 `
  -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew `
  -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings `
  -Principal $principal -Force | Out-Null

# The task runs only in the owner's logon session; with no one logged on it starts at the next logon.
Start-ScheduledTask -TaskName $taskName
$up = $false
foreach ($i in 1..15) {
  Start-Sleep -Seconds 2
  & "$bin\sous.exe" status *> $null
  if ($LASTEXITCODE -eq 0) { $up = $true; break }
}

$published = "no"
if ($up) {
  if ((tailscale serve status 2>$null | Out-String) -match ":9697") {
    $published = "yes"
  } else {
    $check = curl.exe -s -H "Tailscale-User-Login: sous-install-check@invalid" http://127.0.0.1:9697/api/whoami | Out-String
    if ($check -match '"error":"identity"') {
      tailscale serve --bg --https=9697 http://127.0.0.1:9697 | Out-Null
      $published = "yes"
    } else {
      $published = "refused"
    }
  }
}

"bin=" + (Get-FileHash "$bin\sous.exe").Hash.ToLower()
"config=" + (Get-FileHash "$cfg\config.toml").Hash.ToLower()
"version=" + (& "$bin\sous.exe" version)
"engine=" + $(if ($up) { "running" } else { "stopped" })
"published=$published"
