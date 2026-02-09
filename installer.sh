#!/bin/bash
#
### CodeLikeBastiMove - Ultimate Termux SDK & Environment Installer
# Basierend auf dem AndroidIDE Installer, erweitert für Native Dev & AI
#

# Vars
install_dir="${HOME}"
manifest_url="https://raw.githubusercontent.com/AndroidIDEOfficial/androidide-tools/main/manifest.json"
manifest="${PWD}/manifest.json"
# Offizielles Google NDK für Aarch64 (r26b ist stabil)
ndk_url="https://dl.google.com/android/repository/android-ndk-r26b-linux-aarch64.zip"
ndk_ver_name="android-ndk-r26b"

# DO NOT CHANGE THESE!
CURRENT_SHELL="${SHELL##*/}"
CURRENT_DIR="${PWD}"
arch="$(dpkg --print-architecture)"

# Color Codes
red="\e[0;31m"          # Red
green="\e[0;32m"        # Green
yellow="\e[0;33m"       # Yellow
cyan="\e[0;36m"         # Cyan
white="\e[0;37m"        # White
nocol="\033[0m"         # Default

# Functions
banner() {
  echo -e "
${cyan}------------------------------------------------
CodeLikeBastiMove Dev Environment Setup
${white}Android SDK + NDK + AI (Gemini) + Native Tools
${cyan}------------------------------------------------${nocol}
"
}

download_and_extract() {
  name="${1}"
  url="${2}"
  dir="${3}"
  dest="${4}"

  # Verzeichnis erstellen falls nicht vorhanden
  mkdir -p "${dir}"

  cd ${dir}
  do_download=true
  if [[ -f ${dest} ]]; then
    name=$(basename ${dest})
    echo -e "${yellow}File ${name} already exists.${nocol}"
    echo "Skip download? ([y]es/[N]o): "
    read skip
    if [[ "${skip}" =~ ^[Yy]$ ]]; then
      do_download=false
    fi
  fi

  if [[ "${do_download}" = "true" ]]; then
    echo -e "${green}Downloading ${name}...${nocol}"
    curl -L -o ${dest} ${url}
    echo -e "${green}${name} downloaded.${nocol}"
  fi

  if [[ ! -f ${dest} ]]; then
    echo -e "${red}File ${name} missing! Aborting...${nocol}"
    exit 1
  fi

  echo -e "${green}Extracting ${name}...${nocol}"
  if [[ "${dest}" == *.zip ]]; then
      unzip -q ${dest}
  else
      tar xJf ${dest}
  fi
  echo -e "${green}Extraction complete.${nocol}"
  
  # Cleanup zip/tar
  rm -vf ${dest}
  cd ${CURRENT_DIR}
}

gen_data() {
  if ! command -v curl &> /dev/null; then
    echo -e "${red}curl missing! Install with pkg install curl${nocol}"
    exit 1
  fi
  curl --silent -L -o ${manifest} ${manifest_url}
  
  # Check manifest
  if ! [[ -s ${manifest} ]]; then
     echo -e "${red}Manifest download failed!${nocol}"
     rm -f ${manifest}
     exit 1
  fi

  sdk_url=$(cat ${manifest} | jq -r .android_sdk)
  sdk_file=${sdk_url##*/}
  
  # Logic to find correct build tools version from manifest
  sdk_m_version=($(cat ${manifest} | jq .build_tools.${arch} | jq -r 'keys_unsorted[]'))
  sdk_m_version=${sdk_m_version[0]}
  sdk_version=${sdk_m_version:1}
  sdk_version="${sdk_version//_/.}"
  
  build_tools_url=($(cat ${manifest} | jq .build_tools.${arch} | jq -r .${sdk_m_version}))
  build_tools_file=${build_tools_url##*/}
  
  cmdline_tools_url=$(cat ${manifest} | jq -r .cmdline_tools)
  cmdline_tools_file=${cmdline_tools_url##*/}
  
  platform_tools_url=($(cat ${manifest} | jq .platform_tools.${arch} | jq -r .${sdk_m_version}))
  platform_tools_file=${platform_tools_url##*/}
  
  rm ${manifest}
}

install_system_tools() {
  echo -e "${green}Installing System & Native Dev Tools...${nocol}"
  pkg update -y
  # Core Tools: JDK, Git, Build-Tools, Python, Rust, Editoren
  pkg install -y \
    openjdk-17 \
    curl wget jq tar unzip zip \
    git gh \
    cmake ninja make clang binutils pkg-config \
    python rust \
    neovim ripgrep lazygit fd \
    libopenblas libjpeg-turbo libcrypt libffi openssl \
    gradle
}

install_ai_tools() {
  echo -e "${green}Installing AI Tools (Aider)...${nocol}"
  
  # Fix für Rust/Python Builds auf Termux
  export ANDROID_API_LEVEL=24
  export CARGO_BUILD_TARGET=aarch64-linux-android
  export CFLAGS="-Wno-incompatible-function-pointer-types"

  echo "Upgrading pip & build tools..."
  pip install -U pip setuptools wheel maturin

  echo "Installing aider-chat (this may take time compiling numpy)..."
  pip install aider-chat
}

install() {
  echo ""
  gen_data
  
  echo -e "${green}Starting Setup...${nocol}"
  install_system_tools

  echo -e "${red}!${nocol}${green}Downloading SDK & NDK components (~1.5 GB). Ensure enough WiFi/Storage.${nocol}"
  echo -e "Continue? ([y]es/[N]o): "
  read proceed
  if ! [[ "${proceed}" =~ ^[Yy]$ ]]; then
    echo -e "${red}Aborted!${nocol}"
    exit 1
  fi

  # 1. Android SDK Components
  # -------------------------
  download_and_extract "Android SDK Base" ${sdk_url} ${install_dir} "${install_dir}/${sdk_file}"
  download_and_extract "Build Tools (Patched)" ${build_tools_url} "${install_dir}/android-sdk" "${install_dir}/${build_tools_file}"
  download_and_extract "Cmdline Tools" ${cmdline_tools_url} "${install_dir}/android-sdk" "${install_dir}/${cmdline_tools_file}"
  download_and_extract "Platform Tools" ${platform_tools_url} "${install_dir}/android-sdk" "${install_dir}/${platform_tools_file}"

  # 2. Android NDK
  # --------------
  echo -e "${green}Setting up NDK...${nocol}"
  # Wir installieren das NDK direkt in das sdk Verzeichnis unter /ndk
  mkdir -p "${install_dir}/android-sdk/ndk"
  download_and_extract "Android NDK (r26b)" ${ndk_url} "${install_dir}/android-sdk/ndk" "${install_dir}/android-sdk/ndk/ndk-bundle.zip"
  
  # Umbenennen des entpackten Ordners für einfachere Pfade
  if [[ -d "${install_dir}/android-sdk/ndk/${ndk_ver_name}" ]]; then
      echo "Linking NDK version..."
      # Optional: Symlink 'latest' erstellen
      ln -sfn "${install_dir}/android-sdk/ndk/${ndk_ver_name}" "${install_dir}/android-sdk/ndk/latest"
  fi

  # 3. AI Setup
  # -----------
  install_ai_tools

  # 4. Exports & Config
  # -------------------
  echo -e "${green}Configuring Environment Variables...${nocol}"
  
  if [[ "${CURRENT_SHELL}" == "bash" ]]; then
    shell_profile="${HOME}/.bashrc"
  elif [[ "${CURRENT_SHELL}" == "zsh" ]]; then
    shell_profile="${HOME}/.zshrc"
  else
    shell_profile="${HOME}/.bashrc" # Fallback
  fi

  # Ask for Gemini Key
  echo -e "${yellow}Enter your Gemini API Key for the AI Agent (Leave empty to skip):${nocol}"
  read -r api_key

  # Backup .bashrc
  cp ${shell_profile} "${shell_profile}.bak" 2>/dev/null

  # Clean old CodeLikeBastiMove entries to avoid duplicates
  sed -i '/# --- CodeLikeBastiMove Config ---/,/# --- End Config ---/d' ${shell_profile}

  # Write new config
  cat <<EOT >> ${shell_profile}

# --- CodeLikeBastiMove Config ---
export JAVA_HOME=\${PREFIX}/opt/openjdk
export ANDROID_HOME=\${HOME}/android-sdk
export ANDROID_SDK_ROOT=\${HOME}/android-sdk
export NDK_HOME=\${ANDROID_HOME}/ndk/${ndk_ver_name}
export ANDROID_NDK_ROOT=\${NDK_HOME}

# Path Updates
export PATH=\${JAVA_HOME}/bin:\${PATH}
export PATH=\${ANDROID_HOME}/cmdline-tools/latest/bin:\${ANDROID_HOME}/platform-tools:\${PATH}
export PATH=\${NDK_HOME}:\${PATH}

# AI & Compiler Flags
export ANDROID_API_LEVEL=24
export GEMINI_API_KEY="${api_key}"
export AIDER_MODEL="gemini/gemini-1.5-pro-latest"
# --- End Config ---
EOT

  apt clean
}

# Main program
case ${@} in
  -h|--help)
    banner
    echo -e "${green}Usage:${nocol}"
    echo "  ./installer.sh -i   -> Full Install (SDK, NDK, AI, Tools)"
    echo "  ./installer.sh --info -> Show Versions"
    exit 0
  ;;
  --info)
    banner
    info
    exit 0
  ;;
  -i|--install)
    banner
    if [[ ! -d ${install_dir} ]]; then
      echo -e "${red}Install dir missing! Check Termux setup.${nocol}"
      exit 1
    fi
    install
    echo -e "${green}=========================================${nocol}"
    echo -e "${green}      Installation Complete!             ${nocol}"
    echo -e "${green}=========================================${nocol}"
    echo -e "Please restart Termux or run: source ${shell_profile}"
    echo -e "Start AI coding with: aider"
    exit 0
  ;;
  *)
    banner
    echo -e "Use -i to install."
    exit 1
  ;;
esac
