# QOSX user profile
# Auto-launch Sway compositor on tty1

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=sway
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland
export WLR_RENDERER=gles2
export WLR_NO_HARDWARE_CURSORS=1

# Source bashrc
[ -f ~/.bashrc ] && . ~/.bashrc

# Source bashrc
[ -f ~/.bashrc ] && . ~/.bashrc
