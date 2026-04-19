# Inspired by https://github.com/daniel3303/ClaudeCodeStatusLine
# No API calls — all data from stdin JSON + local git/gh commands.

$input = @($Input) -join "`n"

if (-not $input) {
    Write-Host -NoNewline "Claude"
    exit 0
}

# ANSI escape (PS5 compatible)
$esc = [char]0x1b

$blue   = "${esc}[38;2;0;153;255m"
$orange = "${esc}[38;2;255;176;85m"
$green  = "${esc}[38;2;0;160;0m"
$cyan   = "${esc}[38;2;46;149;153m"
$red    = "${esc}[38;2;255;85;85m"
$yellow = "${esc}[38;2;230;200;0m"
$white  = "${esc}[38;2;220;220;220m"
$purple = "${esc}[38;2;180;130;255m"
$dim    = "${esc}[2m"
$reset  = "${esc}[0m"

function Format-Tokens([long]$num) {
    if ($num -ge 1000000) {
        $whole = [math]::Floor($num / 1000000)
        $frac = [math]::Floor(($num % 1000000) / 100000)
        if ($frac -eq 0) { return "${whole}m" }
        return "${whole}.${frac}m"
    }
    elseif ($num -ge 1000) { return "$([math]::Floor($num / 1000))k" }
    else { return "$num" }
}

function Get-UsageColor([int]$pct) {
    if ($pct -ge 90) { return $red }
    elseif ($pct -ge 70) { return $orange }
    elseif ($pct -ge 50) { return $yellow }
    else { return $green }
}

function Get-DefaultBranch([string]$cwd) {
    $ref = git -C $cwd symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $ref) {
        return ($ref -replace 'refs/remotes/origin/', '')
    }
    $null = git -C $cwd rev-parse --verify refs/heads/main 2>$null
    if ($LASTEXITCODE -eq 0) { return "main" }
    $null = git -C $cwd rev-parse --verify refs/heads/master 2>$null
    if ($LASTEXITCODE -eq 0) { return "master" }
    return $null
}

function Format-EpochTime([object]$epoch, [string]$style) {
    if ($null -eq $epoch -or "$epoch" -eq "null" -or "$epoch" -eq "0" -or "$epoch" -eq "") { return $null }
    try {
        $dt = [DateTimeOffset]::FromUnixTimeSeconds([long]$epoch).LocalDateTime
        switch ($style) {
            "time"     { return $dt.ToString("HH:mm") }
            "datetime" { return $dt.ToString("MMM d, HH:mm") }
            default    { return $dt.ToString("HH:mm") }
        }
    } catch { return $null }
}

# ===== Parse stdin JSON =====
$data = $input | ConvertFrom-Json

$gitWorktree = $data.workspace.git_worktree

$modelName = if ($data.model.display_name) { $data.model.display_name } else { "Claude" }
$modelName = ($modelName -replace '\s*\(\d+\.?\d*[kKmM]*\s+context\)', '').Trim()

$size = if ($data.context_window.context_window_size) { [long]$data.context_window.context_window_size } else { 200000 }
if ($size -eq 0) { $size = 200000 }

$inputTokens = if ($data.context_window.current_usage.input_tokens) { [long]$data.context_window.current_usage.input_tokens } else { 0 }
$cacheCreate = if ($data.context_window.current_usage.cache_creation_input_tokens) { [long]$data.context_window.current_usage.cache_creation_input_tokens } else { 0 }
$cacheRead   = if ($data.context_window.current_usage.cache_read_input_tokens) { [long]$data.context_window.current_usage.cache_read_input_tokens } else { 0 }
$current = $inputTokens + $cacheCreate + $cacheRead

$usedTokens  = Format-Tokens $current
$totalTokens = Format-Tokens $size
$pctUsed = if ($size -gt 0) { [math]::Floor($current * 100 / $size) } else { 0 }

# Effort level: prefer stdin JSON, then env var, then settings.json
$effortLevel = $null
if ($data.effort) { $effortLevel = $data.effort }
if (-not $effortLevel -and $env:CLAUDE_CODE_EFFORT_LEVEL) {
    $effortLevel = $env:CLAUDE_CODE_EFFORT_LEVEL
}
if (-not $effortLevel) {
    $claudeConfigDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
    $settingsPath = Join-Path $claudeConfigDir "settings.json"
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            if ($settings.effortLevel) { $effortLevel = $settings.effortLevel }
        } catch {}
    }
}
if (-not $effortLevel) { $effortLevel = "medium" }

# ===== Build output =====
$sep = " ${dim}|${reset} "
$out = "${blue}${modelName}${reset}"

# Git info: repo@branch + PR + Jira
$cwd = $data.cwd
if ($cwd) {
    try {
        $null = git -C $cwd rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0) {
            $repoRoot = git -C $cwd rev-parse --show-toplevel 2>$null
            $repo = Split-Path $repoRoot -Leaf
            $branch = git -C $cwd rev-parse --abbrev-ref HEAD 2>$null

            $out += "${sep}${cyan}${repo}${reset}"
            if ($branch) {
                $out += "${dim}@${reset}${green}${branch}${reset}"

                # Jira ticket from branch name
                if ($branch -match '([A-Z][A-Z0-9]+-\d+)') {
                    $out += " ${white}$($Matches[1])${reset}"
                }

                # Worktree indicator
                if ($gitWorktree) {
                    $out += " ${dim}wt${reset}"
                }

                # Git diff stat vs default branch
                $defaultBranch = Get-DefaultBranch $cwd
                if ($defaultBranch -and $branch -ne $defaultBranch) {
                    $diffStat = git -C $cwd diff --shortstat "${defaultBranch}...HEAD" 2>$null
                    if ($LASTEXITCODE -eq 0 -and $diffStat) {
                        $ins = if ($diffStat -match '(\d+) insertion') { $Matches[1] } else { $null }
                        $del = if ($diffStat -match '(\d+) deletion') { $Matches[1] } else { $null }
                        $diffPart = ""
                        if ($ins) { $diffPart += "${green}+${ins}${reset}" }
                        if ($del) {
                            if ($diffPart) { $diffPart += " " }
                            $diffPart += "${red}-${del}${reset}"
                        }
                        if ($diffPart) { $out += " $diffPart" }
                    }
                }
            }
        }
    } catch {}
}

# Tokens
$tokColor = Get-UsageColor $pctUsed
$out += "${sep}${tokColor}${usedTokens}/${totalTokens} (${pctUsed}%)${reset}"

# Effort
$out += "${sep}effort: "
switch ($effortLevel) {
    "low"    { $out += "${dim}${effortLevel}${reset}" }
    "medium" { $out += "${orange}med${reset}" }
    "high"   { $out += "${green}${effortLevel}${reset}" }
    "xhigh"  { $out += "${purple}${effortLevel}${reset}" }
    "max"    { $out += "${red}${effortLevel}${reset}" }
    default  { $out += "${green}${effortLevel}${reset}" }
}

# Rate limits (from stdin JSON only — no API calls)
$fivePct = $data.rate_limits.five_hour.used_percentage
$fiveReset = $data.rate_limits.five_hour.resets_at
$sevenPct = $data.rate_limits.seven_day.used_percentage
$sevenReset = $data.rate_limits.seven_day.resets_at

if ($null -ne $fivePct) {
    $fiveInt = [math]::Floor([double]$fivePct)
    $fiveColor = Get-UsageColor $fiveInt
    $out += "${sep}${white}5h${reset} ${fiveColor}${fiveInt}%${reset}"
    $fiveTime = Format-EpochTime $fiveReset "time"
    if ($fiveTime) { $out += " ${dim}@${fiveTime}${reset}" }
}

if ($null -ne $sevenPct) {
    $sevenInt = [math]::Floor([double]$sevenPct)
    $sevenColor = Get-UsageColor $sevenInt
    $out += "${sep}${white}7d${reset} ${sevenColor}${sevenInt}%${reset}"
    $sevenTime = Format-EpochTime $sevenReset "datetime"
    if ($sevenTime) { $out += " ${dim}@${sevenTime}${reset}" }
}

Write-Host -NoNewline "$out"
exit 0
