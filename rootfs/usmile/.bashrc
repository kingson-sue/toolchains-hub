# Toolchains Hub interactive shell

case $- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=2000
HISTFILESIZE=4000
shopt -s checkwinsize

PS1='\[\e[1;32m\]\u@toolchains-hub\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias grep='grep --color=auto'

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# ---------------------------------------------------------------------------
# ESP-IDF 6.0.2（路径相对容器 HOME=/usmile，与宿主机用户名无关）
# ---------------------------------------------------------------------------

alias esp_idf='unset PYTHONPATH && unset VIRTUAL_ENV && \
  export IDF_TOOLS_PATH=~/.espressif && \
  export IDF_PATH=~/sdk/esp/esp-idf-v6.0.2 && \
  export ESP_IDF_VERSION=6.0.2 && \
  export IDF_PYTHON_ENV_PATH=~/.espressif/python_env/idf6.0.2_py3.10_env && \
  . ~/sdk/esp/esp-idf-v6.0.2/export.sh'

alias esp_idf_v602='esp_idf'

idf_status() {
    echo "IDF_PATH=${IDF_PATH:-<unset>}"
    echo "ESP_IDF_VERSION=${ESP_IDF_VERSION:-<unset>}"
    echo "IDF_TOOLS_PATH=${IDF_TOOLS_PATH:-<unset>}"
    echo "IDF_PYTHON_ENV_PATH=${IDF_PYTHON_ENV_PATH:-<unset>}"
    echo "VIRTUAL_ENV=${VIRTUAL_ENV:-<unset>}"
    if command -v idf.py >/dev/null 2>&1; then
        idf.py --version
    else
        echo "idf.py not on PATH (run esp_idf)"
    fi
}

echo "Tip: esp_idf"
