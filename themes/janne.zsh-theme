# vim: filetype=sh

autoload -Uz 'helper'

prompt_janne_gitstatus() {
	local gitstatus branch
	# Check if dirty
	gitstatus=`git status --porcelain --ignore-submodules 2>/dev/null`
	test $? -eq 0 || return 0 # Not in a git repo
	branch="`git rev-parse --abbrev-ref HEAD 2>/dev/null`"
	test $? -eq 0 || branch="[none]" # No branch created yet
	if [ "$branch" = "HEAD" ]; then
		# Detached head
		branch="`git rev-parse --short HEAD`"
	fi
	echo -n "%{$fg[yellow]%}$branch%{$terminfo[sgr0]%}"
	test -n "$gitstatus" && echo -n "%{$fg[cyan]%}\u2718 %{$terminfo[sgr0]%}" # Dirty stuff
}

prompt_janne_completeWithDots() {
	echo -n "$fg[red]...$terminfo[sgr0]"
	zle expand-or-complete
	zle redisplay
}

prompt_janne_precmd() {
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
	test $PROMPT_JANNE_GIT -eq 0 && PROMPT_JANNE_GITPROMPT="`prompt_janne_gitstatus`"
}

prompt_janne_preexec() {
	if [[ "$TERM" == screen* ]]; then
		local CMD=${1[(wr)^(*=*|sudo|-*)]}
		echo -n "\ek$CMD\e\\"
	fi
}

prompt_janne_setprompt() {
	setopt LOCAL_OPTIONS
	setopt prompt_subst
	prompt_opts=(cr percent subst)

	# Load required functons
	autoload -U add-zsh-hook
	autoload colors zsh/terminfo

	# Add hooks
	add-zsh-hook precmd prompt_janne_precmd
	add-zsh-hook preexec prompt_janne_preexec

	# Completion waiting dots
	zle -N prompt_janne_completeWithDots
	bindkey "^I" prompt_janne_completeWithDots

	# See if we can use extended characters to look nicer.
	if [[ $(locale charmap) == "UTF-8" ]]; then
		PROMPT_JANNE_SET_CHARSET=""
		PROMPT_JANNE_HBAR="─"
		PROMPT_JANNE_ULCORNER="┌"
		PROMPT_JANNE_URCORNER="┐"
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

	# Decide if we need to set titlebar text.
	case $TERM in
		xterm*)
			PROMPT_JANNE_TITLEBAR=$'\e]0;%n@%m:%~ | %y\a'
			;;
		screen*)
			PROMPT_JANNE_TITLEBAR=$'\e_screen \005 (\005t) | %n@%m:%~ | %y\e\\'
			;;
		*)
			PROMPT_JANNE_TITLEBAR=''
			;;
	esac

	# Decide whether to set a screen title
	if [[ "$TERM" == screen* ]]; then
		PROMPT_JANNE_STITLE=$'\ekzsh\e\\'
	else
		PROMPT_JANNE_STITLE=''
	fi

	# Make it red for root
	if [[ $EUID -ne 0 ]]; then
		PROMPT_COLOR="%{$fg[yellow]%}"
	else
		PROMPT_COLOR="%{$fg[red]%}"
	fi

	# Change $/# color for SSH
	if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
		PROMPT_JANNE_SSH_COLOR="%{$fg[magenta]%}"
	else
		PROMPT_JANNE_SSH_COLOR="%{$fg[yellow]%}"
	fi

	if hash git 2>/dev/null; then
		PROMPT_JANNE_GIT=0
	else
		PROMPT_JANNE_GIT=1
	fi

	# Define prompts
	return_code="%(?..%{$fg[red]%}%? %{$reset_color%})"
	PS1='%{$PROMPT_JANNE_SET_CHARSET$PROMPT_JANNE_STITLE${(e)PROMPT_JANNE_TITLEBAR}$terminfo[bold]%}\
$PROMPT_COLOR$PROMPT_JANNE_ULCORNER$PROMPT_JANNE_HBAR%{$fg[grey]%}(\
%{$fg[green]%}%$PROMPT_JANNE_PWDLEN<...<%~%<<\
%{$fg[grey]%})$PROMPT_COLOR$PROMPT_JANNE_HBAR\
$PROMPT_JANNE_HBAR${(e)PROMPT_JANNE_FILLBAR}$PROMPT_JANNE_HBAR%{$fg[grey]%}(\
%{$fg[white]%}%n%{$fg[grey]%}@%{$fg[green]%}%m:%l\
%{$fg[grey]%})$PROMPT_COLOR$PROMPT_JANNE_HBAR$PROMPT_JANNE_URCORNER\

$PROMPT_JANNE_GITPROMPT\
$return_code$PROMPT_JANNE_SSH_COLOR%(!.#.$)%{$terminfo[sgr0]%} '

	PS2='$PROMPT_COLOR$PROMPT_JANNE_HBAR\
$PROMPT_JANNE_HBAR%{$fg[grey]%}(\
$fg[green]%_%{$fg[grey]%})$PROMPT_COLOR\
$PROMPT_JANNE_HBAR$PROMPT_JANNE_HBAR%{$terminfo[sgr0]%} '

	PS4="%{$fg[green]%}+%{$terminfo[sgr0]%} "

	SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '

	TIMEFMT="%J $fg[cyan]%U $terminfo[sgr0]user $fg[cyan]%S $terminfo[sgr0]system \
$fg[cyan]%P $terminfo[sgr0]cpu $fg[cyan]%*E $terminfo[sgr0]total"

	# Fix for midnight commander
	if ps $PPID | grep mc; then
		unset RPROMPT
		PROMPT='mc: '
	fi
}

prompt_janne_setprompt
