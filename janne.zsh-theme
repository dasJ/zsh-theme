# vim: filetype=sh

autoload -Uz 'helper'

# Render a statusline for git
prompt_janne_gitstatus() {
	[ ! -z "${PROMPT_JANNE_GIT}" ] || return
	local branch
	# Check if this is a repo
	git rev-parse --git-dir &>/dev/null || return
	# Get branch
	branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
	# No branch created yet?
	test $? -eq 0 || branch="[no branch]"
	# Detached head?
	if [ "${branch}" = "HEAD" ]; then
		branch="`git rev-parse --short HEAD`"
	fi
	# Output
	echo -n "%{$fg[yellow]%}$branch%{$terminfo[sgr0]%} "
}

# Show waiting dots while completing
prompt_janne_completeWithDots() {
	echo -n "$fg_bold[red]...$fg_bold[reset]"
	zle expand-or-complete
	zle redisplay
}

# Gets executed before showing the prompt
prompt_janne_precmd() {
	unset REPORTTIME
	local TERMWIDTH

	(( TERMWIDTH = ${COLUMNS} - 1 ))

	# Truncate the path if it's too long.
	PROMPT_JANNE_FILLBAR=""
	PROMPT_JANNE_PWDLEN=""

	local promptsize=${#${(%):---(%n@%m:%l)---()--}}
	local pwdsize=${#${(%):-%~}}

	# Calculate bar width
	if [[ "$promptsize + $pwdsize" -gt $TERMWIDTH ]]; then
		((PROMPT_JANNE_PWDLEN=$TERMWIDTH - $promptsize))
	else
		PROMPT_JANNE_FILLBAR="\${(l.(($TERMWIDTH - ($promptsize + $pwdsize)))..${PROMPT_JANNE_HBAR}.)}"
	fi
	PROMPT_JANNE_GITPROMPT="$(prompt_janne_gitstatus)"
}

prompt_janne_preexec() {
	REPORTTIME=0
}

# Gets executed when switching vi modes
function zle-line-init zle-keymap-select {
	test $KEYMAP = vicmd && PROMPT_JANNE_COLOR="%{$fg[cyan]%}" \
		|| PROMPT_JANNE_COLOR="%{$fg[yellow]%}"
	zle reset-prompt
}

# Apply the prompt
prompt_janne_setprompt() {
	# Load required functons
	autoload -U add-zsh-hook

	# Add hook
	add-zsh-hook precmd prompt_janne_precmd
	add-zsh-hook preexec prompt_janne_preexec

	# Completion waiting dots
	zle -N prompt_janne_completeWithDots
	bindkey "^I" prompt_janne_completeWithDots

	# vi mode highlight
	zle -N zle-line-init
	zle -N zle-keymap-select

	# See if we can use extended characters to look nicer.
	if [ "$(locale charmap)" = 'UTF-8' ]; then
		PROMPT_JANNE_SET_CHARSET=''
		PROMPT_JANNE_HBAR='─'
		PROMPT_JANNE_ULCORNER='┌'
		PROMPT_JANNE_URCORNER='┐'
	else
		typeset -A altchar
		set -A altchar ${(s..)terminfo[acsc]}
		# Some stuff to help us draw nice lines
		PROMPT_JANNE_SET_CHARSET="$terminfo[enacs]"
		PROMPT_JANNE_SHIFT_IN="%{$terminfo[smacs]%}"
		PROMPT_JANNE_SHIFT_OUT="%{$terminfo[rmacs]%}"
		PROMPT_JANNE_HBAR='$PROMPT_JANNE_SHIFT_IN${altchar[q]:--}$PROMPT_JANNE_SHIFT_OUT'
		PROMPT_JANNE_ULCORNER='$PROMPT_JANNE_SHIFT_IN${altchar[l]:--}$PROMPT_JANNE_SHIFT_OUT'
		PROMPT_JANNE_URCORNER='$PROMPT_JANNE_SHIFT_IN${altchar[k]:--}$PROMPT_JANNE_SHIFT_OUT'
	fi

	PROMPT_JANNE_COLOR="%{$fg[yellow]%}"

	# Change $/# color for SSH
	if [ \( -n "${SSH_CLIENT}" -o -n "${SSH_TTY}" \) -a ! -f "${HOME}/.dotfiles/local/thisislocal" ]; then
		PROMPT_JANNE_SSH_COLOR="%{$fg[magenta]%}"
	else
		PROMPT_JANNE_SSH_COLOR="%{$fg[yellow]%}"
	fi

	if hash git 2>/dev/null; then
		PROMPT_JANNE_GIT=0
	fi

	# Define prompts
	return_code="%(?..%{$fg[red]%}%? %{$reset_color%})"
	PS1='%{$PROMPT_JANNE_SET_CHARSET$terminfo[bold]%}\
$PROMPT_JANNE_COLOR$PROMPT_JANNE_ULCORNER$PROMPT_JANNE_HBAR%{$fg[grey]%}(\
%{$fg[green]%}%$PROMPT_JANNE_PWDLEN<...<%~%<<\
%{$fg[grey]%})$PROMPT_JANNE_COLOR$PROMPT_JANNE_HBAR\
$PROMPT_JANNE_HBAR${(e)PROMPT_JANNE_FILLBAR}$PROMPT_JANNE_HBAR%{$fg[grey]%}(\
%{$fg[white]%}%n%{$fg[grey]%}@%{$fg[green]%}%m:%l\
%{$fg[grey]%})$PROMPT_JANNE_COLOR$PROMPT_JANNE_HBAR$PROMPT_JANNE_URCORNER\

$PROMPT_JANNE_GITPROMPT\
$return_code$PROMPT_JANNE_SSH_COLOR%(!.#.$)%{$terminfo[sgr0]%} '

	# ZLE lines (after line 1)
	PS2='$PROMPT_JANNE_COLOR$PROMPT_JANNE_HBAR\
$PROMPT_JANNE_HBAR%{$fg[grey]%}(\
$fg[green]%_%{$fg[grey]%})$PROMPT_JANNE_COLOR\
$PROMPT_JANNE_HBAR$PROMPT_JANNE_HBAR%{$terminfo[sgr0]%} '

	# Execution traces
	PS4="%{$fg[green]%}+%{$terminfo[sgr0]%} "

	# Correction
	SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '

	# time output
	TIMEFMT="%J $fg[cyan]%U $terminfo[sgr0]user $fg[cyan]%S $terminfo[sgr0]system \
$fg[cyan]%P $terminfo[sgr0]cpu $fg[cyan]%*E $terminfo[sgr0]total"

	# Fix for midnight commander
	if [ ! -z "${MC_SID}" ]; then
		PROMPT='zsh: '
	fi
}

prompt_janne_setprompt
