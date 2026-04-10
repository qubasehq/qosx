# QOSX bashrc

[ -z "$PS1" ] && return

# Prompt
PS1='\[\e[1;34m\][\u@qosx \W]\$\[\e[0m\] '

# History
HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ip='ip -c'

# QShell alias (use qsh as interactive shell wrapper)
alias qsh='/usr/local/bin/qsh'

# Source profile.d
for f in /etc/profile.d/*.sh; do
  [ -r "$f" ] && . "$f"
done
