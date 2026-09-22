function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive # Commands to run in interactive sessions can go here

    # No greeting
    set fish_greeting

    # Use starship
    starship init fish | source
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    alias pamcan pacman
    alias ls 'eza --icons'
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias q 'qs -c ii'
    
end

# Created by `pipx` on 2026-07-27 12:14:19
set PATH $PATH /home/zoecyber/.local/bin


# Added by Antigravity CLI installer
set -gx PATH "/home/zoecyber/.local/bin" $PATH

# Modern CLI Replacements
if type -q starship
    starship init fish | source
end

if type -q zoxide
    zoxide init fish --cmd cd | source
end

if type -q eza
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first'
end

if type -q bat
    alias cat='bat --style=plain --theme="TwoDark"'
end
