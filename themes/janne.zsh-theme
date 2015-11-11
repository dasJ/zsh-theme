# vim: filetype=sh

pmodload 'helper'
pmodload 'git'

# Thanks to Karen for this!
function milis_to_human() {
	if [ $1 -gt 30000 ]; then # 30 seconds
		local elapsed=`expr $1 / 1000`
		TIMER_ELAPSED="${elapsed}s"
		return
	fi
	if [ $1 -gt 120000 ]; then # 2 minutes
		local elapsed=`expr $1 / 60000`
		TIMER_ELAPSED="${elapsed}min"
		return
	fi
	if [ $1 -gt 7200000 ]; then # 2 hours
		local elapsed=`expr $1 / 3600000`
		TIMER_ELAPSED="${elapsed}h"
		return
	fi
	if [ $1 -gt 7200000 ]; then # 2 days
		local elapsed=`expr $1 / 3600000`
		TIMER_ELAPSED="${elapsed}days"
		return
	fi
	if [ $1 -gt 1209600000 ]; then # 2 weeks
		local elapsed=`expr $1 / 604800000`
		TIMER_ELASPED="${elapsed}weeks"
		return
	fi
	if [ $1 -gt 5259487660 ]; then # 2 months
		local elapsed=`expr $1 / 2629743830`
		TIMER_ELAPSED="${elapsed}months"
		return
	fi
	TIMER_ELAPSED="${1}ms"
}

function precmd {
	local TERMWIDTH

	if $TIMER_EXECUTED; then
		TIMER_EXECUTED=false
		milis_to_human $(($(($(date +%s%N)/1000000))-TIMER_START))
	fi

	(( TERMWIDTH = ${COLUMNS} - 1 ))

	if (( $+functions[git-info] )); then
		git-info
	fi

	# Truncate the path if it's too long.

	PR_FILLBAR=""
	PR_PWDLEN=""

	local promptsize=${#${(%):---(%n@%m:%l)---()--}}
	local pwdsize=${#${(%):-%~}}

	# Calculate bar width
	if [[ "$promptsize + $pwdsize" -gt $TERMWIDTH ]]; then
		((PR_PWDLEN=$TERMWIDTH - $promptsize))
	else
		PR_FILLBAR="\${(l.(($TERMWIDTH - ($promptsize + $pwdsize)))..${PR_HBAR}.)}"
	fi
}

function preexec {
	if [[ "$TERM" == "screen" ]]; then
		local CMD=${1[(wr)^(*=*|sudo|-*)]}
		echo -n "\ek$CMD\e\\"
	fi

	TIMER_START=$(($(date +%s%N)/1000000))
	TIMER_EXECUTED=true
}

function setprompt {
	setopt LOCAL_OPTIONS
	setopt prompt_subst
	prompt_opts=(cr percent subst)

	# Load required functons
	autoload -U add-zsh-hook
	autoload colors zsh/terminfo

	# Add hooks
	add-zsh-hook precmd prompt_janne_precmd
	add-zsh-hook preexec prompt_janne_preexec

	# See if we can use colors.
	if [[ "$terminfo[colors]" -ge 8 ]]; then
		colors
	fi
	for color in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE GREY; do
		eval PR_$color='%{$terminfo[bold]$fg[${(L)color}]%}'
		eval PR_LIGHT_$color='%{$fg[${(L)color}]%}'
		(( count = $count + 1 ))
	done
	PR_NO_COLOUR="%{$terminfo[sgr0]%}"

	# Completion waiting dots
	zstyle ':prezto:module:editor:info:completing' format '%B%F{red}...%f%b'

	# Modify Git prompt
	zstyle ':prezto:module:git:info:branch' format '${PR_WHITE}on %b'
	zstyle ':prezto:module:git:info:commit' format '${PR_GREY}at %.5c'
	zstyle ':prezto:module:git:info:keys' format \
		'prompt' ' $(coalesce "%b" "%c")'

	# See if we can use extended characters to look nicer.
	if [[ $(locale charmap) == "UTF-8" ]]; then
		PR_SET_CHARSET=""
		PR_SHIFT_IN=""
		PR_SHIFT_OUT=""
		PR_HBAR="─"
		PR_ULCORNER="┌"
		PR_LLCORNER="└"
		PR_LRCORNER="┘"
		PR_URCORNER="┐"
	else
		typeset -A altchar
		set -A altchar ${(s..)terminfo[acsc]}
		# Some stuff to help us draw nice lines
		PR_SET_CHARSET="%{$terminfo[enacs]%}"
		PR_SHIFT_IN="%{$terminfo[smacs]%}"
		PR_SHIFT_OUT="%{$terminfo[rmacs]%}"
		PR_HBAR='$PR_SHIFT_IN${altchar[q]:--}$PR_SHIFT_OUT'
		PR_ULCORNER='$PR_SHIFT_IN${altchar[l]:--}$PR_SHIFT_OUT'
		PR_LLCORNER='$PR_SHIFT_IN${altchar[m]:--}$PR_SHIFT_OUT'
		PR_LRCORNER='$PR_SHIFT_IN${altchar[j]:--}$PR_SHIFT_OUT'
		PR_URCORNER='$PR_SHIFT_IN${altchar[k]:--}$PR_SHIFT_OUT'
	 fi

	# Decide if we need to set titlebar text.
	case $TERM in
		xterm*)
			PR_TITLEBAR=$'%{\e]0;%n@%m:%~ | ${COLUMNS}x${LINES} | %y\a%}'
			;;
		screen)
			PR_TITLEBAR=$'%{\e_screen \005 (\005t) | %n@%m:%~ | ${COLUMNS}x${LINES} | %y\e\\%}'
			;;
		*)
			PR_TITLEBAR=''
			;;
	esac

	# Decide whether to set a screen title
	if [[ "$TERM" == "screen" ]]; then
		PR_STITLE=$'%{\ekzsh\e\\%}'
	else
		PR_STITLE=''
	fi

	# Make it red for root
	if [[ $EUID -ne 0 ]]; then
		PROMPT_COLOR=$PR_YELLOW
		PROMPT_SECOND_COLOR=$PR_GREY
	else
		PROMPT_COLOR=$PR_RED
		PROMPT_SECOND_COLOR=$PR_RED
	fi

	# Change $/# color for root
	if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
		PR_SSH_COLOR=$PR_RED
	else
		PR_SSH_COLOR=$PR_YELLOW
	fi

	# Define prompts
	PROMPT='$PR_SET_CHARSET$PR_STITLE${(e)PR_TITLEBAR}\
$PROMPT_COLOR$PR_ULCORNER$PR_HBAR$PR_GREY(\
$PR_GREEN%$PR_PWDLEN<...<%~%<<\
$PR_GREY)$PROMPT_COLOR$PR_HBAR\
$PR_HBAR${(e)PR_FILLBAR}$PR_HBAR$PR_GREY(\
$PR_WHITE%(!.%SROOT%s.%n)$PR_GREY@$PR_GREEN%m:%l\
$PR_GREY)$PROMPT_COLOR$PR_HBAR$PR_URCORNER\

${git_info:+${(e)git_info[prompt]}}\
$PR_SSH_COLOR%(!.#.$)$PR_NO_COLOUR '

	# display exitcode on the right when >0
	return_code="%(?..%{$fg[red]%}%? ↵ %{$reset_color%})"
	RPROMPT=' $return_code$PROMPT_COLOR$PROMPT_SECOND_COLOR\
($PR_YELLOW$TIMER_ELAPSED$PROMPT_SECOND_COLOR)$PROMPT_COLOR$PR_HBAR$PR_LRCORNER$PR_NO_COLOUR'

	PS2='$PROMPT_COLOR$PR_HBAR\
$PROMPT_SECOND_COLOR$PR_HBAR(\
$PR_LIGHT_GREEN%_$PROMPT_SECOND_COLOR)$PR_HBAR\
$PROMPT_COLOR$PR_HBAR$PR_NO_COLOUR '

	SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '

	# Fix for midnight commander
	if ps $PPID | grep mc; then
		unset RPROMPT
		PROMPT='mc: '
	fi

	milis_to_human 0
	TIMER_EXECUTED=false
}

function prompt_janne_preview {
	local +h PROMPT='%# '
	local +h RPROMPT=''
	prompt_preview_theme 'janne' "$@"
}

setprompt
