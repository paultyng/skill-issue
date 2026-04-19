#!/bin/bash
# Inspired by https://github.com/daniel3303/ClaudeCodeStatusLine
# No API calls — all data from stdin JSON + local git/gh commands.

set -f  # disable globbing

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ANSI colors
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;160;0m'
cyan='\033[38;2;46;149;153m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
purple='\033[38;2;180;130;255m'
dim='\033[2m'
reset='\033[0m'

# Format token counts: 1234567 → "1.2m", 50000 → "50k"
format_tokens() {
    local num="$1"
    if [ "$num" -ge 1000000 ] 2>/dev/null; then
        local whole=$(( num / 1000000 ))
        local frac=$(( (num % 1000000) / 100000 ))
        if [ "$frac" -eq 0 ]; then
            printf "%dm" "$whole"
        else
            printf "%d.%dm" "$whole" "$frac"
        fi
    elif [ "$num" -ge 1000 ] 2>/dev/null; then
        printf "%dk" "$(( num / 1000 ))"
    else
        printf "%d" "$num"
    fi
}

# Color based on usage percentage
usage_color() {
    local pct="$1"
    if [ "$pct" -ge 90 ] 2>/dev/null; then printf '%s' "$red"
    elif [ "$pct" -ge 70 ] 2>/dev/null; then printf '%s' "$orange"
    elif [ "$pct" -ge 50 ] 2>/dev/null; then printf '%s' "$yellow"
    else printf '%s' "$green"
    fi
}

# Detect default branch name (no network calls)
detect_default_branch() {
    local cwd="$1"
    local ref
    ref=$(git -C "$cwd" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)
    if [ -n "$ref" ]; then
        echo "${ref##refs/remotes/origin/}"
        return
    fi
    if git -C "$cwd" rev-parse --verify refs/heads/main >/dev/null 2>&1; then
        echo "main"
    elif git -C "$cwd" rev-parse --verify refs/heads/master >/dev/null 2>&1; then
        echo "master"
    fi
}

# Format epoch timestamp to local HH:MM
format_epoch_time() {
    local epoch="$1"
    [ -z "$epoch" ] || [ "$epoch" = "null" ] || [ "$epoch" = "0" ] && return
    # GNU date, then BSD date
    date -d "@$epoch" +"%H:%M" 2>/dev/null || date -j -r "$epoch" +"%H:%M" 2>/dev/null
}

# Format epoch timestamp to local "Mon D, HH:MM"
format_epoch_datetime() {
    local epoch="$1"
    [ -z "$epoch" ] || [ "$epoch" = "null" ] || [ "$epoch" = "0" ] && return
    date -d "@$epoch" +"%b %-d, %H:%M" 2>/dev/null || date -j -r "$epoch" +"%b %-d, %H:%M" 2>/dev/null
}

# ===== Extract data from stdin JSON =====
git_worktree=$(echo "$input" | jq -r '.workspace.git_worktree // empty')

model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
model_name=$(echo "$model_name" | sed 's/ *([0-9.]*[kKmM]* context)//')

size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
[ "$size" -eq 0 ] 2>/dev/null && size=200000

input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
current=$(( input_tokens + cache_create + cache_read ))

used_tokens=$(format_tokens "$current")
total_tokens=$(format_tokens "$size")
pct_used=$(( size > 0 ? current * 100 / size : 0 ))

# Effort level: prefer stdin JSON, then env var, then settings.json
effort_level=""
effort_val=$(echo "$input" | jq -r '.effort // empty' 2>/dev/null)
[ -n "$effort_val" ] && effort_level="$effort_val"
if [ -z "$effort_level" ] && [ -n "$CLAUDE_CODE_EFFORT_LEVEL" ]; then
    effort_level="$CLAUDE_CODE_EFFORT_LEVEL"
fi
if [ -z "$effort_level" ]; then
    settings_path="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
    if [ -f "$settings_path" ]; then
        effort_val=$(jq -r '.effortLevel // empty' "$settings_path" 2>/dev/null)
        [ -n "$effort_val" ] && effort_level="$effort_val"
    fi
fi
[ -z "$effort_level" ] && effort_level="medium"

# ===== Build output =====
sep=" ${dim}|${reset} "
out="${blue}${model_name}${reset}"

# Git info: repo@branch + PR + Jira
cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

    default_branch=$(detect_default_branch "$cwd")

    out+="${sep}${cyan}${repo}${reset}"
    if [ -n "$branch" ]; then
        if [ "$branch" = "$default_branch" ]; then
            out+="${dim}@${branch}${reset}"
        else
            out+="${dim}@${reset}${orange}${branch}${reset}"
        fi

        # Jira ticket from branch name (e.g. PROJ-123)
        jira=$(echo "$branch" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -1)
        [ -n "$jira" ] && out+=" ${white}${jira}${reset}"

        # Worktree indicator
        [ -n "$git_worktree" ] && out+=" ${dim}wt${reset}"

        # Git diff stat vs default branch
        if [ -n "$default_branch" ] && [ "$branch" != "$default_branch" ]; then
            diff_stat=$(git -C "$cwd" diff --shortstat "${default_branch}...HEAD" 2>/dev/null)
            if [ -n "$diff_stat" ]; then
                insertions=$(echo "$diff_stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
                deletions=$(echo "$diff_stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
                diff_part=""
                [ -n "$insertions" ] && diff_part="${green}+${insertions}${reset}"
                if [ -n "$deletions" ]; then
                    [ -n "$diff_part" ] && diff_part+=" "
                    diff_part+="${red}-${deletions}${reset}"
                fi
                [ -n "$diff_part" ] && out+=" ${dim}|${reset} ${diff_part}"
            fi
        fi
    fi
fi

# Tokens
tok_color=$(usage_color "$pct_used")
out+="${sep}${tok_color}${used_tokens}/${total_tokens} (${pct_used}%)${reset}"

# Effort
out+="${sep}effort: "
case "$effort_level" in
    low)    out+="${dim}${effort_level}${reset}" ;;
    medium) out+="${orange}med${reset}" ;;
    high)   out+="${green}${effort_level}${reset}" ;;
    xhigh)  out+="${purple}${effort_level}${reset}" ;;
    max)    out+="${red}${effort_level}${reset}" ;;
    *)      out+="${green}${effort_level}${reset}" ;;
esac

# Rate limits (from stdin JSON only — no API calls)
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$five_pct" ]; then
    five_int=$(printf "%.0f" "$five_pct")
    five_color=$(usage_color "$five_int")
    out+="${sep}${white}5h${reset} ${five_color}${five_int}%${reset}"
    five_time=$(format_epoch_time "$five_reset")
    [ -n "$five_time" ] && out+=" ${dim}@${five_time}${reset}"
fi

if [ -n "$seven_pct" ]; then
    seven_int=$(printf "%.0f" "$seven_pct")
    seven_color=$(usage_color "$seven_int")
    out+="${sep}${white}7d${reset} ${seven_color}${seven_int}%${reset}"
    seven_time=$(format_epoch_datetime "$seven_reset")
    [ -n "$seven_time" ] && out+=" ${dim}@${seven_time}${reset}"
fi

printf "%b" "$out"
exit 0
