# wb_health_check.ps1 (v2 - 2026-09-07)
# Adds system-level monitoring on top of WB-only check
# Monitors:
#   - WorkBuddy: process count, total mem
#   - System: CPU load, uptime, total procs, Not Responding, total handles
#   - Memory: free GB, used %
#   - C: drive free
#   - GPU: optional via nvidia-smi
# Output: JSON to stdout; -Log also writes status JSON + history log

param([switch]$Log)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$warnings = New-Object System.Collections.Generic.List[string]
$status = "GREEN"

# === A. WorkBuddy processes ===
$wbProcs = @(Get-Process -Name WorkBuddy -ErrorAction SilentlyContinue)
$procCount = $wbProcs.Count
$wbMemGB = 0
$pidsDetail = ""
if ($procCount -gt 0) {
    $wbMemBytes = ($wbProcs | Measure-Object -Property WorkingSet64 -Sum).Sum
    $wbMemGB = [math]::Round($wbMemBytes / 1GB, 2)
    $pidsDetail = ($wbProcs | ForEach-Object { "$($_.PID):$([math]::Round($_.WorkingSet64/1MB,0))MB" }) -join " | "

    if ($wbMemGB -gt 8) { $status = "RED"; $warnings.Add("WB total mem $wbMemGB GB > 8GB (CRASH RISK)") }
    elseif ($wbMemGB -gt 5) { if ($status -eq "GREEN") { $status = "YELLOW" }; $warnings.Add("WB total mem $wbMemGB GB > 5GB (caution)") }
    if ($procCount -gt 20) { $status = "RED"; $warnings.Add("WB process count $procCount > 20 (abnormal)") }
    elseif ($procCount -gt 15 -and $status -eq "GREEN") { $status = "YELLOW"; $warnings.Add("WB process count $procCount > 15 (high)") }
} else {
    $status = "RED"
    $warnings.Add("WB process not running")
}

# === B. System resources (memory + uptime) ===
$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
$totalMemGB = 0; $freeMemGB = 0; $usedPct = 0; $uptimeHours = 0
if ($os) {
    $totalMemGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedPct = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 1)

    if ($freeMemGB -lt 1.5) { $status = "RED"; $warnings.Add("System free mem $freeMemGB GB < 1.5GB (CRASH IMMINENT)") }
    elseif ($freeMemGB -lt 3 -and $status -eq "GREEN") { $status = "YELLOW"; $warnings.Add("System free mem $freeMemGB GB < 3GB (tight)") }

    # Uptime - this is the key "restart" signal
    try {
        $uptimeHours = [math]::Round((New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)).TotalHours, 1)
    } catch { $uptimeHours = -1 }
    if ($uptimeHours -gt 168) { $status = "RED"; $warnings.Add("System uptime $uptimeHours h > 168h (7d) - RESTART RECOMMENDED") }
    elseif ($uptimeHours -gt 72 -and $status -eq "GREEN") { $status = "YELLOW"; $warnings.Add("System uptime $uptimeHours h > 72h (3d) - consider restart") }
}

# === C. CPU load ===
$cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
$cpuLoad = -1
if ($cpu) {
    $cpuLoad = [math]::Round(($cpu | Measure-Object -Property LoadPercentage -Average).Average, 1)
    if ($cpuLoad -gt 80) { $status = "RED"; $warnings.Add("CPU load $cpuLoad% > 80% (overloaded)") }
    elseif ($cpuLoad -gt 60 -and $status -eq "GREEN") { $status = "YELLOW"; $warnings.Add("CPU load $cpuLoad% > 60% (high)") }
}

# === D. Process inventory (zombie detection) ===
$allProcs = @(Get-Process -ErrorAction SilentlyContinue)
$totalProcs = $allProcs.Count
$notResponding = ($allProcs | Where-Object { $_.Responding -eq $false }).Count
if ($totalProcs -gt 350) { $status = "RED"; $warnings.Add("Total process count $totalProcs > 350 (zombie risk)") }
elseif ($totalProcs -gt 250 -and $status -eq "GREEN") { $status = "YELLOW"; $warnings.Add("Total process count $totalProcs > 250 (high)") }
if ($notResponding -gt 3) { $status = "RED"; $warnings.Add("Not Responding processes $notResponding > 3 (zombies)") }
elseif ($notResponding -gt 0 -and $status -eq "GREEN") { $status = "YELLOW"; $warnings.Add("Not Responding processes $notResponding > 0") }

# === E. Total handles (system burden) ===
$totalHandles = 0
if ($allProcs.Count -gt 0) {
    $totalHandles = ($allProcs | Measure-Object -Property HandleCount -Sum).Sum
}
if ($totalHandles -gt 100000) { $status = "RED"; $warnings.Add("Total handles $totalHandles > 100K (system overloaded)") }
elseif ($totalHandles -gt 60000 -and $status -eq "GREEN") { $status = "YELLOW"; $warnings.Add("Total handles $totalHandles > 60K (heavy)") }

# === F. C: drive ===
$cDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
$cFreeGB = 0
if ($cDrive) {
    $cFreeGB = [math]::Round($cDrive.Free / 1GB, 1)
    if ($cFreeGB -lt 8) { $status = "RED"; $warnings.Add("C: drive free $cFreeGB GB < 8GB (CRITICAL)") }
    elseif ($cFreeGB -lt 20 -and $status -eq "GREEN") { $status = "YELLOW"; $warnings.Add("C: drive free $cFreeGB GB < 20GB (tight)") }
}

# === G. GPU (optional) ===
$gpuInfo = "n/a"
try {
    $nvsmiOut = & nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>$null
    if ($nvsmiOut) {
        $parts = $nvsmiOut -split ','
        if ($parts.Count -ge 2) {
            $gpuUsedGB = [math]::Round([int]$parts[0].Trim() / 1024, 2)
            $gpuTotalGB = [math]::Round([int]$parts[1].Trim() / 1024, 2)
            $gpuInfo = "$gpuUsedGB / $gpuTotalGB GB"
        }
    }
} catch {}

# === Advice ===
$advice = switch ($status) {
    "GREEN"  { "All normal, keep working" }
    "YELLOW" { "Caution: close unused apps/tabs; consider restart if system uptime > 3 days" }
    "RED"    { "URGENT: save conversation, restart WorkBuddy; consider system reboot to clear garbage" }
    default  { "Unknown" }
}

# === JSON output ===
$result = @{
    timestamp = $timestamp
    status = $status
    warnings = $warnings
    advice = $advice
    workbuddy = @{
        process_count = $procCount
        total_mem_gb = $wbMemGB
        pids_detail = $pidsDetail
    }
    system = @{
        cpu_load_pct = $cpuLoad
        uptime_hours = $uptimeHours
        total_procs = $totalProcs
        not_responding = $notResponding
        total_handles = $totalHandles
    }
    memory = @{
        total_gb = $totalMemGB
        free_gb = $freeMemGB
        used_pct = $usedPct
    }
    c_drive_free_gb = $cFreeGB
    gpu = $gpuInfo
}
$json = $result | ConvertTo-Json -Depth 4
Write-Output $json

# === Log to file (with -Log) ===
if ($Log) {
    $statusFile = "C:\Users\Administrator\workbuddy_health_status.json"
    $historyFile = "C:\Users\Administrator\workbuddy_health_history.log"
    Set-Content -Path $statusFile -Value $json -Encoding UTF8
    $logLine = "[$timestamp] [$status] WB:$wbMemGB GB (${procCount}p) Sys:CPU=$cpuLoad% Uptime=${uptimeHours}h Procs=$totalProcs(NR=$notResponding) Hdl=$totalHandles FreeMem=$freeMemGB C=$cFreeGB | GPU:$gpuInfo | " + (($warnings -join "; ") + " | " + $advice)
    Add-Content -Path $historyFile -Value $logLine -Encoding UTF8
}
