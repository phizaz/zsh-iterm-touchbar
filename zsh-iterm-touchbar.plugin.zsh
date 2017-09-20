# GIT
GIT_UNCOMMITTED="${GIT_UNCOMMITTED:-+}"
GIT_UNSTAGED="${GIT_UNSTAGED:-!}"
GIT_UNTRACKED="${GIT_UNTRACKED:-?}"
GIT_STASHED="${GIT_STASHED:-$}"
GIT_UNPULLED="${GIT_UNPULLED:-⇣}"
GIT_UNPUSHED="${GIT_UNPUSHED:-⇡}"

# Output name of current branch.
git_current_branch() {
  local ref
  ref=$(command git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # no git repo.
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return
  fi
  echo ${ref#refs/heads/}
}

# Uncommitted changes.
# Check for uncommitted changes in the index.
git_uncomitted() {
  if ! $(git diff --quiet --ignore-submodules --cached); then
    echo -n "${GIT_UNCOMMITTED}"
  fi
}

# Unstaged changes.
# Check for unstaged changes.
git_unstaged() {
  if ! $(git diff-files --quiet --ignore-submodules --); then
    echo -n "${GIT_UNSTAGED}"
  fi
}

# Untracked files.
# Check for untracked files.
git_untracked() {
  if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo -n "${GIT_UNTRACKED}"
  fi
}

# Stashed changes.
# Check for stashed changes.
git_stashed() {
  if $(git rev-parse --verify refs/stash &>/dev/null); then
    echo -n "${GIT_STASHED}"
  fi
}

# Unpushed and unpulled commits.
# Get unpushed and unpulled commits from remote and draw arrows.
git_unpushed_unpulled() {
  # check if there is an upstream configured for this branch
  command git rev-parse --abbrev-ref @'{u}' &>/dev/null || return

  local count
  count="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"
  # exit if the command failed
  (( !$? )) || return

  # counters are tab-separated, split on tab and store as array
  count=(${(ps:\t:)count})
  local arrows left=${count[1]} right=${count[2]}

  (( ${right:-0} > 0 )) && arrows+="${GIT_UNPULLED}"
  (( ${left:-0} > 0 )) && arrows+="${GIT_UNPUSHED}"

  [ -n $arrows ] && echo -n "${arrows}"
}

pecho() {
  if [ -n "$TMUX" ]
  then
    echo -ne "\ePtmux;\e$*\e\\"
  else
    echo -ne $*
  fi
}

# F1-12: https://github.com/vmalloc/zsh-config/blob/master/extras/function_keys.zsh
fnKeys=('^[OP' '^[OQ' '^[OR' '^[OS' '^[[15~' '^[[17~' '^[[18~' '^[[19~' '^[[20~' '^[[21~' '^[[23~' '^[[24~')
touchBarState=''
npmScripts=()
yarnScripts=()
lastPackageJsonPath=''

function _clearTouchbar() {
  pecho "\033]1337;PopKeyLabels\a"
}

function _unbindTouchbar() {
  for fnKey in "$fnKeys[@]"; do
    bindkey -s "$fnKey" ''
  done
}

function _displayDefault() {
  _clearTouchbar
  _unbindTouchbar

  touchBarState=''

  # CURRENT_DIR
  # -----------
  pecho "\033]1337;SetKeyLabel=F1=👉 $(echo $(pwd) | awk -F/ '{print $(NF-1)"/"$(NF)}')\a"
  bindkey -s '^[OP' 'pwd \n'

  # GIT
  # ---
  # Check if the current directory is in a Git repository.
  command git rev-parse --is-inside-work-tree &>/dev/null || return

  # Check if the current directory is in .git before running git checks.
  if [[ "$(git rev-parse --is-inside-git-dir 2> /dev/null)" == 'false' ]]; then

    # Ensure the index is up to date.
    git update-index --really-refresh -q &>/dev/null

    # String of indicators
    local indicators=''

    indicators+="$(git_uncomitted)"
    indicators+="$(git_unstaged)"
    indicators+="$(git_untracked)"
    indicators+="$(git_stashed)"
    indicators+="$(git_unpushed_unpulled)"

    [ -n "${indicators}" ] && touchbarIndicators="🔥[${indicators}]" || touchbarIndicators="🙌";

    pecho "\033]1337;SetKeyLabel=F2=🎋 $(git_current_branch)\a"
    pecho "\033]1337;SetKeyLabel=F3=$touchbarIndicators\a"
    pecho "\033]1337;SetKeyLabel=F4=✉️ push\a";

    # bind git actions
    bindkey -s '^[OQ' 'git branch -a \n'
    bindkey -s '^[OR' 'git status \n'
    bindkey -s '^[OS' "git push origin $(git_current_branch) \n"
  fi

  pecho "\033]1337;SetKeyLabel=F5=🤖 react-devtools\a"
  bindkey -s "${fnKeys[5]}" 'react-devtools \n'

  # PACKAGE.JSON
  # ------------
  if [[ -f package.json ]]; then
    pecho "\033]1337;SetKeyLabel=F6=⚡️ npm-run\a"
    bindkey "${fnKeys[6]}" _displayNpmScripts
  fi

  # Yarn
  if [[ -f yarn.lock ]]; then
    pecho "\033]1337;SetKeyLabel=F7=⚙️ yarn install\a"
    bindkey -s "${fnKeys[7]}" 'yarn install \n'
    pecho "\033]1337;SetKeyLabel=F8=🏗 yarn add\a"
    bindkey -s "${fnKeys[8]}" 'yarn add '
  fi

  if [[ -f Gemfile ]]; then
    pecho "\033]1337;SetKeyLabel=F9=💎 start rails server\a"
    bindkey -s "${fnKeys[9]}" 'bundle exec rails s \n'
    pecho "\033]1337;SetKeyLabel=F10=📃 run specs\a"
    bindkey -s "${fnKeys[10]}" 'bundle exec rspec spec \n'
    pecho "\033]1337;SetKeyLabel=F11=👾 webpacker dev server\a"
    bindkey -s "${fnKeys[11]}" 'bin/webpack-dev-server \n'
  fi



}

function _displayNpmScripts() {
  # find available npm scripts only if new directory
  if [[ $lastPackageJsonPath != $(echo "$(pwd)/package.json") ]]; then
    lastPackageJsonPath=$(echo "$(pwd)/package.json")
    npmScripts=($(node -e "console.log(Object.keys($(npm run --json)).filter(name => !name.includes(':')).sort((a, b) => a.localeCompare(b)).filter((name, idx) => idx < 12).join(' '))"))
  fi

  _clearTouchbar
  _unbindTouchbar

  touchBarState='npm'

  fnKeysIndex=1
  for npmScript in "$npmScripts[@]"; do
    fnKeysIndex=$((fnKeysIndex + 1))
    bindkey -s $fnKeys[$fnKeysIndex] "npm run $npmScript \n"
    pecho "\033]1337;SetKeyLabel=F$fnKeysIndex=$npmScript\a"
  done

  pecho "\033]1337;SetKeyLabel=F1=👈 back\a"
  bindkey "${fnKeys[1]}" _displayDefault
}

zle -N _displayDefault
zle -N _displayNpmScripts

precmd_iterm_touchbar() {
  if [[ $touchBarState == 'npm' ]]; then
    _displayNpmScripts
  else
    _displayDefault
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd precmd_iterm_touchbar
