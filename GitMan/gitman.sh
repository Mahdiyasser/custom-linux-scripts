#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║                        gitman.sh                            ║
# ║           Multi-repo Git Manager  •  by Mahdi Yasser        ║
# ╚══════════════════════════════════════════════════════════════╝


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

# ── Parallel fetch + check ───────────────────────────────────
# Each repo gets its own background job: fetch + count written to tmpdir.
# Runs in the MAIN shell (not via $()) so output is live and jobs are real.
_CHECK_FOUND=0

run_parallel_check() {
  local mode="$1"; shift
  local repos=("$@")
  _CHECK_FOUND=0
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" RETURN

  local pids=()
  for repo in "${repos[@]}"; do
    (
      git -C "$SCAN_DIR/$repo" fetch --quiet 2>/dev/null || true
      local branch
      branch=$(git -C "$SCAN_DIR/$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
      local count=0
      if [[ "$mode" == "pull" ]]; then
        count=$(git -C "$SCAN_DIR/$repo" rev-list --count HEAD..origin/"$branch" 2>/dev/null || echo 0)
      else
        count=$(git -C "$SCAN_DIR/$repo" rev-list --count origin/"$branch"..HEAD 2>/dev/null || echo 0)
      fi
      printf '%s' "$count" > "$tmpdir/$repo"
    ) &
    pids+=($!)
  done

  echo -e "\n  ${D}Checking ${#repos[@]} repos in parallel…${N}"
  for pid in "${pids[@]}"; do wait "$pid" || true; done
  divider

  for repo in "${repos[@]}"; do
    local count=0
    [[ -f "$tmpdir/$repo" ]] && count=$(< "$tmpdir/$repo")
    if [[ "$count" -gt 0 ]]; then
      if [[ "$mode" == "pull" ]]; then
        echo -e "  ${Y}↓${N}  ${W}$repo${N}  ${D}($count commit(s) behind)${N}"
      else
        echo -e "  ${G}↑${N}  ${W}$repo${N}  ${D}($count commit(s) ahead)${N}"
      fi
      (( _CHECK_FOUND++ )) || true
    fi
  done
}

# ── Pull a single repo ────────────────────────────────────────
do_pull() {
  local repo="$1"
  echo -e "  ${D}► $repo${N}"
  if git -C "$SCAN_DIR/$repo" pull; then
    ok "${W}$repo${N}"
    echo "    $repo → OK" >> "$LOG_FILE"
  else
    fail "${W}$repo${N}"
    echo "    $repo → FAIL" >> "$LOG_FILE"
  fi
}

# ── Push a single repo ────────────────────────────────────────
do_push() {
  local repo="$1"
  echo -e "  ${D}► $repo${N}"
  git -C "$SCAN_DIR/$repo" add .
  git -C "$SCAN_DIR/$repo" commit -m "Update" || true
  if git -C "$SCAN_DIR/$repo" push; then
    ok "${W}$repo${N}"
    echo "    $repo → OK" >> "$LOG_FILE"
  else
    fail "${W}$repo${N}"
    echo "    $repo → FAIL" >> "$LOG_FILE"
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
  run_parallel_check "pull" "${REPOS[@]}"
  [[ "$_CHECK_FOUND" -eq 0 ]] && ok "All repos are up to date."
  log_entry "CHECK PULL — $_CHECK_FOUND repo(s) behind"
}

# ══════════════════════════════════════════════════════════════
#  OPTION 4 — See what needs to be pushed
# ══════════════════════════════════════════════════════════════
cmd_check_push() {
  read -ra REPOS <<< "$(get_repos)"
  [[ ${#REPOS[@]} -eq 0 ]] && { info "No git repos found."; return; }

  header "Needs Push"
  run_parallel_check "push" "${REPOS[@]}"
  [[ "$_CHECK_FOUND" -eq 0 ]] && ok "Nothing to push."
  log_entry "CHECK PUSH — $_CHECK_FOUND repo(s) ahead"
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
