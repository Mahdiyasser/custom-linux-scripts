#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║                        gitman.sh                            ║
# ║           Multi-repo Git Manager  •  by Mahdi Yasser        ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Config ────────────────────────────────────────────────────
LOG_FILE="$(pwd)/git.log"
SCAN_DIR="$(pwd)"

# ── Colours ───────────────────────────────────────────────────
R='\033[0;31m'   # red
G='\033[0;32m'   # green
Y='\033[0;33m'   # yellow
B='\033[0;34m'   # blue
C='\033[0;36m'   # cyan
W='\033[1;37m'   # bold white
D='\033[2m'      # dim
N='\033[0m'      # reset
BOLD='\033[1m'

# ── Helpers ───────────────────────────────────────────────────
divider()  { echo -e "${D}────────────────────────────────────────────────${N}"; }
header()   { echo -e "\n${BOLD}${C}  $1${N}"; divider; }
ok()       { echo -e "  ${G}✔${N}  $1"; }
fail()     { echo -e "  ${R}✘${N}  $1"; }
info()     { echo -e "  ${Y}→${N}  $1"; }
dim()      { echo -e "  ${D}$1${N}"; }

log_entry() {
  local action="$1"; shift
  {
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  [$(date '+%Y-%m-%d %H:%M:%S')]  ACTION: $action"
    echo "════════════════════════════════════════════════════════"
    for repo in "$@"; do
      echo "  • $repo"
    done
  } >> "$LOG_FILE"
}

log_result() {
  echo "  RESULT: $1" >> "$LOG_FILE"
}

# ── Scan repos ────────────────────────────────────────────────
get_repos() {
  local repos=()
  for dir in "$SCAN_DIR"/*/; do
    [[ -d "$dir/.git" ]] && repos+=("$(basename "$dir")")
  done
  echo "${repos[@]:-}"
}

# ── Fetch all in parallel ────────────────────────────────────
fetch_all() {
  local repos=("$@")
  echo -e "\n  ${D}Fetching remotes…${N}"
  local pids=()
  for repo in "${repos[@]}"; do
    git -C "$SCAN_DIR/$repo" fetch --quiet 2>/dev/null &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || true
  done
}

# ── Check if repo needs pull ──────────────────────────────────
needs_pull() {
  local repo="$1"
  local behind
  behind=$(git -C "$SCAN_DIR/$repo" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
  [[ "$behind" -gt 0 ]]
}

# ── Check if repo needs push ──────────────────────────────────
needs_push() {
  local repo="$1"
  local ahead
  ahead=$(git -C "$SCAN_DIR/$repo" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
  [[ "$ahead" -gt 0 ]]
}

# ── Pull a single repo ────────────────────────────────────────
do_pull() {
  local repo="$1"
  local result
  result=$(git -C "$SCAN_DIR/$repo" pull 2>&1)
  local rc=$?
  local first_line
  first_line=$(echo "$result" | head -1)
  if [[ $rc -eq 0 ]]; then
    ok "${W}$repo${N}  ${D}$first_line${N}"
    echo "    $repo → OK: $first_line" >> "$LOG_FILE"
  else
    fail "${W}$repo${N}  ${R}$first_line${N}"
    echo "    $repo → FAIL: $first_line" >> "$LOG_FILE"
  fi
}

# ── Push a single repo ────────────────────────────────────────
do_push() {
  local repo="$1"
  local result
  result=$(git -C "$SCAN_DIR/$repo" push 2>&1)
  local rc=$?
  local summary
  summary=$(echo "$result" | grep -v '^$' | tail -1)
  if [[ $rc -eq 0 ]]; then
    ok "${W}$repo${N}  ${D}$summary${N}"
    echo "    $repo → OK: $summary" >> "$LOG_FILE"
  else
    summary=$(echo "$result" | head -1)
    fail "${W}$repo${N}  ${R}$summary${N}"
    echo "    $repo → FAIL: $summary" >> "$LOG_FILE"
  fi
}

# ── Multi-select picker ───────────────────────────────────────
# Usage: pick_repos "verb" repo1 repo2 …
# Sets global PICKED array
PICKED=()
pick_repos() {
  local verb="$1"; shift
  local repos=("$@")

  echo ""
  local i=1
  for repo in "${repos[@]}"; do
    printf "  ${C}%2d${N}  %s\n" "$i" "$repo"
    ((i++))
  done
  echo ""
  echo -e "  ${D}Enter numbers separated by _ (e.g. 1_3_5)   or  ${W}all${D} for everything${N}"
  printf "  ${Y}›${N} ${W}$verb${N}: "
  read -r selection

  PICKED=()
  if [[ "$selection" == "all" ]]; then
    PICKED=("${repos[@]}")
    return
  fi

  IFS='_' read -ra parts <<< "$selection"
  for n in "${parts[@]}"; do
    n=$(echo "$n" | tr -d '[:space:]')
    if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#repos[@]} )); then
      PICKED+=("${repos[$((n-1))]}")
    else
      echo -e "  ${R}Skipping invalid entry: '$n'${N}"
    fi
  done
}

# ══════════════════════════════════════════════════════════════
#  OPTION 1 — Pull all
# ══════════════════════════════════════════════════════════════
cmd_pull_all() {
  read -ra REPOS <<< "$(get_repos)"
  [[ ${#REPOS[@]} -eq 0 ]] && { info "No git repos found."; return; }

  header "Pull All  (${#REPOS[@]} repos)"
  fetch_all "${REPOS[@]}"
  divider
  log_entry "PULL ALL" "${REPOS[@]}"
  for repo in "${REPOS[@]}"; do
    do_pull "$repo"
  done
  log_result "Done"
}

# ══════════════════════════════════════════════════════════════
#  OPTION 2 — Push all
# ══════════════════════════════════════════════════════════════
cmd_push_all() {
  read -ra REPOS <<< "$(get_repos)"
  [[ ${#REPOS[@]} -eq 0 ]] && { info "No git repos found."; return; }

  header "Push All  (${#REPOS[@]} repos)"
  log_entry "PUSH ALL" "${REPOS[@]}"
  for repo in "${REPOS[@]}"; do
    do_push "$repo"
  done
  log_result "Done"
}

# ══════════════════════════════════════════════════════════════
#  OPTION 3 — See what needs to be pulled
# ══════════════════════════════════════════════════════════════
cmd_check_pull() {
  read -ra REPOS <<< "$(get_repos)"
  [[ ${#REPOS[@]} -eq 0 ]] && { info "No git repos found."; return; }

  header "Needs Pull"
  fetch_all "${REPOS[@]}"
  divider

  local found=0
  for repo in "${REPOS[@]}"; do
    local behind
    behind=$(git -C "$SCAN_DIR/$repo" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
    if [[ "$behind" -gt 0 ]]; then
      echo -e "  ${Y}↓${N}  ${W}$repo${N}  ${D}($behind commit(s) behind)${N}"
      ((found++))
    fi
  done

  [[ $found -eq 0 ]] && ok "All repos are up to date."
  log_entry "CHECK PULL — $found repo(s) behind"
}

# ══════════════════════════════════════════════════════════════
#  OPTION 4 — See what needs to be pushed
# ══════════════════════════════════════════════════════════════
cmd_check_push() {
  read -ra REPOS <<< "$(get_repos)"
  [[ ${#REPOS[@]} -eq 0 ]] && { info "No git repos found."; return; }

  header "Needs Push"
  fetch_all "${REPOS[@]}"
  divider

  local found=0
  for repo in "${REPOS[@]}"; do
    local ahead
    ahead=$(git -C "$SCAN_DIR/$repo" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    if [[ "$ahead" -gt 0 ]]; then
      echo -e "  ${G}↑${N}  ${W}$repo${N}  ${D}($ahead commit(s) ahead)${N}"
      ((found++))
    fi
  done

  [[ $found -eq 0 ]] && ok "Nothing to push."
  log_entry "CHECK PUSH — $found repo(s) ahead"
}

# ══════════════════════════════════════════════════════════════
#  OPTION 5 — Pull specific
# ══════════════════════════════════════════════════════════════
cmd_pull_specific() {
  read -ra REPOS <<< "$(get_repos)"
  [[ ${#REPOS[@]} -eq 0 ]] && { info "No git repos found."; return; }

  header "Pull — Choose Repos"
  pick_repos "pull" "${REPOS[@]}"

  [[ ${#PICKED[@]} -eq 0 ]] && { info "Nothing selected."; return; }

  divider
  log_entry "PULL SPECIFIC" "${PICKED[@]}"
  for repo in "${PICKED[@]}"; do
    do_pull "$repo"
  done
  log_result "Done"
}

# ══════════════════════════════════════════════════════════════
#  OPTION 6 — Push specific
# ══════════════════════════════════════════════════════════════
cmd_push_specific() {
  read -ra REPOS <<< "$(get_repos)"
  [[ ${#REPOS[@]} -eq 0 ]] && { info "No git repos found."; return; }

  header "Push — Choose Repos"
  pick_repos "push" "${REPOS[@]}"

  [[ ${#PICKED[@]} -eq 0 ]] && { info "Nothing selected."; return; }

  divider
  log_entry "PUSH SPECIFIC" "${PICKED[@]}"
  for repo in "${PICKED[@]}"; do
    do_push "$repo"
  done
  log_result "Done"
}

# ══════════════════════════════════════════════════════════════
#  OPTION 7 — Help
# ══════════════════════════════════════════════════════════════
cmd_help() {
  echo ""
  echo -e "${BOLD}${W}  gitman.sh${N}  ${D}— Multi-repo Git Manager${N}"
  echo ""
  divider
  echo -e "  ${C}1${N}  Pull All          Pull every repo in this directory"
  echo -e "  ${C}2${N}  Push All          Push every repo in this directory"
  echo -e "  ${C}3${N}  Check Pull        See which repos are behind the remote"
  echo -e "  ${C}4${N}  Check Push        See which repos are ahead of the remote"
  echo -e "  ${C}5${N}  Pull Specific     Choose repos to pull (multi-select)"
  echo -e "  ${C}6${N}  Push Specific     Choose repos to push (multi-select)"
  echo -e "  ${C}7${N}  Help              Show this message"
  echo -e "  ${C}q${N}  Quit"
  divider
  echo -e "  ${D}Multi-select:  type numbers separated by _  e.g.  ${W}1_3_5${D}${N}"
  echo -e "  ${D}Log file:      ${W}git.log${D} in the current directory${N}"
  echo ""
}

# ══════════════════════════════════════════════════════════════
#  MAIN MENU
# ══════════════════════════════════════════════════════════════
main_menu() {
  clear
  echo ""
  echo -e "${BOLD}${W}  ╔══════════════════════════════╗${N}"
  echo -e "${BOLD}${W}  ║        gitman.sh             ║${N}"
  echo -e "${BOLD}${W}  ╚══════════════════════════════╝${N}"
  echo ""

  # Show repo count
  read -ra REPOS <<< "$(get_repos)"
  local count=${#REPOS[@]}
  dim "Scanning: $SCAN_DIR"
  dim "Found $count git repo(s)"
  echo ""

  divider
  echo -e "  ${C}1${N}  Pull All"
  echo -e "  ${C}2${N}  Push All"
  echo -e "  ${C}3${N}  Check — what needs to be pulled"
  echo -e "  ${C}4${N}  Check — what needs to be pushed"
  echo -e "  ${C}5${N}  Pull Specific"
  echo -e "  ${C}6${N}  Push Specific"
  echo -e "  ${C}7${N}  Help"
  echo -e "  ${C}q${N}  Quit"
  divider
  echo ""
  printf "  ${Y}›${N} Choose: "
  read -r choice

  case "$choice" in
    1) cmd_pull_all ;;
    2) cmd_push_all ;;
    3) cmd_check_pull ;;
    4) cmd_check_push ;;
    5) cmd_pull_specific ;;
    6) cmd_push_specific ;;
    7) cmd_help ;;
    q|Q) echo -e "\n  ${D}Bye.${N}\n"; exit 0 ;;
    *) echo -e "\n  ${R}Invalid option.${N}" ;;
  esac

  echo ""
  printf "  ${D}Press Enter to return to menu…${N}"
  read -r
  main_menu
}

main_menu
