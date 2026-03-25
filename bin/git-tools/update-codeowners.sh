#!/bin/bash

# update-codeowners.sh - Update CODEOWNERS file(s) in a repo:
#   Remove: tom-mackall_ukg, jose-cartaya_ukg, jorge-suarez_ukg, metehan-diziog_ukg, vladimir-sutskever_ukg
#   Add:    brandon-foote_ukg (to any line where a removed person appeared)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gitRepoUtils/lib/common.sh"

FEATURE_BRANCH="feature/codeowner-update"
REMOVE_USERS=("tom-mackall_ukg" "jose-cartaya_ukg" "jorge-suarez_ukg" "metehan-diziog_ukg" "vladimir-sutskever_ukg")
ADD_USER="brandon-foote_ukg"

usage() {
    echo "Usage: $(basename "$0") <repo-dir>"
    echo ""
    echo "  <repo-dir>  Path to a git repository (or just the repo name if under ~/projects/)"
    exit 1
}

# ---------------------------------------------------------------------------
# Edit a single CODEOWNERS file in-place using Python for reliable line logic
# ---------------------------------------------------------------------------
edit_codeowners() {
    local file="$1"

    python3 - "$file" "$ADD_USER" "${REMOVE_USERS[@]}" <<'PYEOF'
import sys
import re

filepath   = sys.argv[1]
add_user   = sys.argv[2]
remove_set = set(sys.argv[3:])

with open(filepath) as f:
    lines = f.readlines()

out = []
changed = False

for line in lines:
    # Preserve blank lines and comments unchanged
    stripped = line.rstrip('\n')
    if not stripped or stripped.lstrip().startswith('#'):
        out.append(line)
        continue

    # Split into pattern + owners (owners are whitespace-separated tokens)
    parts  = stripped.split()
    pattern = parts[0]
    owners  = parts[1:]

    # Track which owners are being removed
    kept      = [o for o in owners if o.lstrip('@') not in remove_set]
    removed   = [o for o in owners if o.lstrip('@') in remove_set]

    if removed:
        changed = True
        # Add the new user to this line if not already present
        add_handle = f"@{add_user}"
        if add_handle not in kept and add_user not in kept:
            kept.append(add_handle)

    new_line = (pattern + (' ' + ' '.join(kept) if kept else '') + '\n')
    out.append(new_line)

if changed:
    with open(filepath, 'w') as f:
        f.writelines(out)
    print(f"  Updated: {filepath}", flush=True)
else:
    # Still check if add_user is absent from the whole file and insert on *
    content = ''.join(lines)
    add_handle = f"@{add_user}"
    if add_handle not in content and add_user not in content:
        # Append to wildcard line if present, otherwise note it
        new_out = []
        appended = False
        for line in lines:
            stripped = line.rstrip('\n')
            if not stripped or stripped.lstrip().startswith('#'):
                new_out.append(line)
                continue
            parts = stripped.split()
            if parts[0] == '*' and not appended:
                new_out.append(stripped + ' ' + add_handle + '\n')
                appended = True
                changed = True
            else:
                new_out.append(line)
        if appended:
            with open(filepath, 'w') as f:
                f.writelines(new_out)
            print(f"  Added {add_handle} to wildcard rule in: {filepath}", flush=True)
        else:
            print(f"  No removed users found and no wildcard rule; {add_handle} NOT added to {filepath}", flush=True)
    else:
        print(f"  No changes needed: {filepath}", flush=True)
PYEOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
[[ $# -lt 1 ]] && usage

REPO_DIR=$(resolve_project_path "$1")
validate_git_repo "$REPO_DIR"

cd "$REPO_DIR" || { print_error "Cannot cd to $REPO_DIR"; exit 1; }

print_header "CODEOWNERS Update: $(basename "$REPO_DIR")"

# -- 1. Warn about dirty workspace and stash if needed ----------------------
if ! git diff --quiet || ! git diff --cached --quiet; then
    print_warning "WARNING: Dirty workspace detected. Stashing changes before proceeding."
    print_warning "         Your stash will NOT be automatically restored — run 'git stash pop' when ready."
    STASH_MSG="update-codeowners auto-stash $(date '+%Y-%m-%d %H:%M:%S')"
    git stash push -m "$STASH_MSG" --include-untracked >/dev/null
    print_info "Stashed as: $STASH_MSG"
fi

# -- 2. Detect and sync default branch --------------------------------------
print_info "Detecting default branch..."
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep "HEAD branch" | awk '{print $NF}')
if [[ -z "$DEFAULT_BRANCH" ]]; then
    print_error "Could not determine default branch from origin."
    exit 1
fi
print_info "Default branch: $DEFAULT_BRANCH"

git checkout "$DEFAULT_BRANCH" --quiet || { print_error "Failed to checkout $DEFAULT_BRANCH"; exit 1; }
print_info "Pulling latest from origin/$DEFAULT_BRANCH..."
git pull origin "$DEFAULT_BRANCH" --quiet || { print_error "git pull failed"; exit 1; }

# -- 3. Delete existing feature branch (local + remote) then recreate -------
if git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"; then
    print_info "Deleting local branch '$FEATURE_BRANCH'..."
    git branch -D "$FEATURE_BRANCH" --quiet
fi
if git ls-remote --exit-code --heads origin "$FEATURE_BRANCH" >/dev/null 2>&1; then
    print_info "Deleting remote branch 'origin/$FEATURE_BRANCH'..."
    git push origin --delete "$FEATURE_BRANCH" --quiet
fi
git checkout -b "$FEATURE_BRANCH" --quiet
print_success "On branch: $FEATURE_BRANCH"

# -- 4. Find and edit CODEOWNERS files --------------------------------------
print_info "Searching for CODEOWNERS files..."
CODEOWNERS_FILES=()
while IFS= read -r line; do
    CODEOWNERS_FILES+=("$line")
done < <(find . -name "CODEOWNERS" -not -path "./.git/*" | sort)

if [[ ${#CODEOWNERS_FILES[@]} -eq 0 ]]; then
    print_warning "No CODEOWNERS files found. Nothing to do."
    git checkout "$DEFAULT_BRANCH" --quiet
    exit 0
fi

print_info "Found ${#CODEOWNERS_FILES[@]} CODEOWNERS file(s):"
for f in "${CODEOWNERS_FILES[@]}"; do
    echo "  $f"
done

for f in "${CODEOWNERS_FILES[@]}"; do
    edit_codeowners "$f"
done

# -- 5. Commit if there are changes -----------------------------------------
if git diff --quiet; then
    print_warning "No effective changes made to CODEOWNERS file(s). Nothing to commit."
    exit 0
fi

print_info "Committing changes..."
git add "${CODEOWNERS_FILES[@]}"
git commit -m "$(cat <<'EOF'
chore: update CODEOWNERS

Remove tom-mackall_ukg, jose-cartaya_ukg, jorge-suarez_ukg, metehan-diziog_ukg, vladimir-sutskever_ukg.
Add brandon-foote_ukg to any rules that previously listed a removed owner.
EOF
)"

# -- 6. Push to origin -------------------------------------------------------
print_info "Pushing $FEATURE_BRANCH to origin..."
git push origin "$FEATURE_BRANCH" --force-with-lease

# -- 7. Create PR via service account ----------------------------------------
GITSVCRC="$HOME/.gitsvcrc"
if [[ ! -f "$GITSVCRC" ]]; then
    print_warning "~/.gitsvcrc not found — skipping PR creation."
    print_info "Create a PR manually: gh pr create --base $DEFAULT_BRANCH"
    exit 0
fi

# Source only to pick up GH_TOKEN (suppress other side-effects quietly)
GH_TOKEN=$(grep -E '^export GH_TOKEN=' "$GITSVCRC" | tail -1 | sed 's/export GH_TOKEN=//')
if [[ -z "$GH_TOKEN" ]]; then
    print_warning "GH_TOKEN not found in ~/.gitsvcrc — skipping PR creation."
    exit 0
fi

REPO=$(basename "$REPO_DIR")
PR_TITLE="chore: update CODEOWNERS"
PR_BODY="Remove tom-mackall_ukg, jose-cartaya_ukg, jorge-suarez_ukg, metehan-diziog_ukg, vladimir-sutskever_ukg.\nAdd brandon-foote_ukg to any rules that previously listed a removed owner."
PR_URL="https://api.github.com/repos/UKGEPIC/$REPO/pulls"

print_info "Creating PR: $FEATURE_BRANCH -> $DEFAULT_BRANCH"
RESPONSE=$(curl -s -H "Authorization: Bearer $GH_TOKEN" \
    -X POST \
    -d "{\"title\":\"$PR_TITLE\",\"body\":\"$PR_BODY\",\"head\":\"$FEATURE_BRANCH\",\"base\":\"$DEFAULT_BRANCH\"}" \
    "$PR_URL")

PR_HTML_URL=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('html_url',''))" 2>/dev/null)

if [[ -n "$PR_HTML_URL" ]]; then
    print_success "PR created: $PR_HTML_URL"
else
    print_error "PR creation may have failed. API response:"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
fi
