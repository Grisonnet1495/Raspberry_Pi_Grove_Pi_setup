#! /bin/bash
# =============================================================================
# install_grovepi.sh
#
# Base: Original GrovePi install script by Dexter Industries
#       (install_grovepi.sh, "Raspbian for Robots").
#
# Change: The original script depends on Python 2 / pip and the "RFR_Tools"
# bash installer, both incompatible with Debian Trixie. This version uses
# only Python3/pip3 and replaces RFR_Tools with its successor, "mr-rfr-tools"
# (pip). See each function's comments for the details of what changed.
#
# AI assistance: This script was adapted with the help of AI, starting from
# the original script, based on iterative testing performed by the user on
# their own hardware.
#
# WARNING: This script is provided "as is", without warranty of any kind.
# The author assumes no responsibility for the consequences of running it
# (including breaking system packages). Use at your own risk -- read the
# script before running it.
#
# Last tested: October 2, 2026
# OS tested: Debian Trixie (13), arm64 architecture
# Hardware: Raspberry Pi 4B (8GB RAM)
# Source repo: https://github.com/DexterInd/GrovePi
# =============================================================================

################################################
######## Parsing Command Line Arguments ########
################################################

# definitions needed for standalone call
PIHOME=/home/pi
DEXTER=Dexter
DEXTER_PATH=$PIHOME/$DEXTER
RASPBIAN=$PIHOME/di_update/Raspbian_For_Robots
GROVEPI_DIR=$DEXTER_PATH/GrovePi
DEXTERSCRIPT=$DEXTER_PATH/lib/Dexter/script_tools


# called way down bellow
check_if_run_with_pi() {
  ## if not running with the pi user then exit
  if [ $(id -ur) -ne $(id -ur pi) ]; then
    echo "GrovePi installer script must be run with \"pi\" user. Exiting."
    exit 6
  fi
}

# called way down below
parse_cmdline_arguments() {

  # whether to install the dependencies or not (avrdude, apt-get, wiringpi, and so on)
  installdependencies=true
  updaterepo=true
  install_rfrtools=true
  install_pkg_rfrtools=true
  install_rfrtools_gui=true

  # the following 3 options are mutually exclusive
  systemwide=true
  userlocal=false
  envlocal=false

  # the following option tells which branch has to be used
  selectedbranch="master"

  # iterate through bash arguments
  for i; do
    case "$i" in
      --no-dependencies)
        installdependencies=false
        ;;
      --no-update-aptget)
        updaterepo=false
        ;;
      --bypass-rfrtools)
        install_rfrtools=false
        ;;
      --bypass-python-rfrtools)
        install_pkg_rfrtools=false
        ;;
      --bypass-gui-installation)
        # no-op: mr-rfr-tools has no GUI component, unlike the old installer
        install_rfrtools_gui=false
        ;;
      --user-local)
        userlocal=true
        systemwide=false
        ;;
      --env-local)
        envlocal=true
        systemwide=false
        ;;
      --system-wide)
        ;;
      develop|feature/*|hotfix/*|fix/*|DexterOS*|v*)
        selectedbranch="$i"
        ;;
    esac
  done

  # show some feedback on the console
  if [ -f $DEXTERSCRIPT/functions_library.sh ]; then
    source $DEXTERSCRIPT/functions_library.sh
    # show some feedback for the GrovePi
    if [[ quiet_mode -eq 0 ]]; then
      echo "  _____            _                                ";
      echo " |  __ \          | |                               ";
      echo " | |  | | _____  _| |_ ___ _ __                     ";
      echo " | |  | |/ _ \ \/ / __/ _ \ '__|                    ";
      echo " | |__| |  __/>  <| ||  __/ |                       ";
      echo " |_____/ \___/_/\_\\\__\___|_|          _            ";
      echo " |_   _|         | |         | |      (_)           ";
      echo "   | |  _ __   __| |_   _ ___| |_ _ __ _  ___  ___  ";
      echo "   | | | '_ \ / _\ | | | / __| __| '__| |/ _ \/ __| ";
      echo "  _| |_| | | | (_| | |_| \__ \ |_| |  | |  __/\__ \ ";
      echo " |_____|_| |_|\__,_|\__,_|___/\__|_|  |_|\___||___/ ";
      echo "                                                    ";
      echo "                                                    ";
      echo "  _____                    _____ _ "
      echo " / ____|                  |  __ (_)  "
      echo "| |  __ _ __ _____   _____| |__) |   "
      echo "| | |_ | '__/ _ \ \ / / _ \  ___/ |  "
      echo "| |__| | | | (_) \ V /  __/ |   | |  "
      echo " \_____|_|  \___/ \_/ \___|_|   |_|  "
      echo " "
    fi

    feedback "Welcome to GrovePi Installer."
  else
    echo "Welcome to GrovePi Installer."
  fi

  echo "Updating GrovePi for $selectedbranch branch with the following options:"
  ([[ $installdependencies = "true" ]] && echo "  --no-dependencies=false") || echo "  --no-dependencies=true"
  ([[ $updaterepo = "true" ]] && echo "  --no-update-aptget=false") || echo "  --no-update-aptget=true"
  ([[ $install_rfrtools = "true" ]] && echo "  --bypass-rfrtools=false") || echo "  --bypass-rfrtools=true"
  ([[ $install_pkg_rfrtools = "true" ]] && echo "  --bypass-python-rfrtools=false") || echo "  --bypass-python-rfrtools=true"
  echo "  --user-local=$userlocal"
  echo "  --env-local=$envlocal"
  echo "  --system-wide=$systemwide"

  echo "Using \"$selectedbranch\" branch"
  echo "script_tools will be installed, then mr-rfr-tools (Python3) if not bypassed."
}

################################################
######## Cloning GrovePi & mr-rfr-tools ########
################################################

# called in <<install_rfrtools_repo>>
check_dependencies() {
  command -v git >/dev/null 2>&1 || { echo "This script requires \"git\" but it's not installed. Error occurred with the tools installation." >&2; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "Executable \"python3\" couldn't be found. Error occurred with the tools installation." >&2; exit 2; }
  command -v pip3 >/dev/null 2>&1 || { echo "Executable \"pip3\" couldn't be found. Error occurred with the tools installation." >&2; exit 3; }

  if [[ ! -f $DEXTERSCRIPT/functions_library.sh ]]; then
    echo "script_tools didn't get installed. Exiting."
    exit 8
  fi
}

# called way down below
# Changed: installs script_tools (functions_library.sh) then mr-rfr-tools
# via pip, instead of the old RFR_Tools bash installer (which depends on
# python2 / the "python" executable, both absent on Trixie).
install_rfrtools_repo() {

  if [[ $install_rfrtools = "true" ]]; then

    echo "Installing script_tools. This might take a while.."
    curl --silent -kL https://raw.githubusercontent.com/DexterInd/script_tools/master/install_script_tools.sh | bash

    if [[ ! -f $DEXTERSCRIPT/functions_library.sh ]]; then
      echo "script_tools didn't get installed. Exiting."
      exit 8
    fi
    source $DEXTERSCRIPT/functions_library.sh
    feedback "Done installing script_tools"

    if [[ $install_pkg_rfrtools = "true" ]]; then
      feedback "Installing mr-rfr-tools. This might take a while.."
      # --break-system-packages required on Trixie (PEP 668, "externally managed" Python)
      sudo pip3 install --upgrade mr_rfr-tools --break-system-packages
      ret_val=$?
      if [[ $ret_val -ne 0 ]]; then
        echo "mr-rfr-tools failed installing with exit code $ret_val. Exiting."
        exit 7
      fi
      feedback "Done installing mr-rfr-tools"
    fi
  fi

  # check if all deb packages have been installed
  check_dependencies
}

# called by <<clone_grovepi>>
# Added: fixes a couple of deprecated-metadata warnings in the cloned
# GrovePi repo (setup.cfg / setup.py). No-op if already fixed (grep -q
# guards) -- and clone_grovepi() always starts from a fresh clone anyway,
# so nothing stacks across runs.
patch_grovepi_source() {
  local setup_cfg="$GROVEPI_DIR/Software/Python/setup.cfg"
  local setup_py="$GROVEPI_DIR/Software/Python/setup.py"

  # dash-separated "description-file" is deprecated in favour of "description_file"
  if [[ -f "$setup_cfg" ]] && grep -q "^description-file" "$setup_cfg"; then
    sed -i 's/^description-file/description_file/' "$setup_cfg"
  fi

  # deprecated license classifier + "test_suite" option no longer recognised
  # by recent setuptools: purely cosmetic, no functional impact
  if [[ -f "$setup_py" ]] && grep -q "License :: OSI Approved" "$setup_py"; then
    sed -i "/License :: OSI Approved/d" "$setup_py"
  fi
  if [[ -f "$setup_py" ]] && grep -q "test_suite" "$setup_py"; then
    sed -i "/test_suite/d" "$setup_py"
  fi
}

# called way down bellow
clone_grovepi() {
  # $DEXTER_PATH is still only available for the pi user
  # shortly after this, we'll make it work for any user
  sudo mkdir -p $DEXTER_PATH
  sudo chown pi:pi -R $DEXTER_PATH
  cd $DEXTER_PATH
  # it's simpler and more reliable (for now) to just delete the repo and clone a new one
  # otherwise, we'd have to deal with all the intricacies of git
  sudo rm -rf $GROVEPI_DIR
  git clone --quiet --depth=1 -b $selectedbranch https://github.com/DexterInd/GrovePi.git
  patch_grovepi_source
  cd $GROVEPI_DIR
}

################################################
######## Install Python Packages & Deps ########
################################################

# called by <<install_python_pkgs_and_dependencies>>
# Changed: "pip3 install ." replaces "setup.py install" (deprecated), to go
# through pip's own isolated build backend instead of the legacy
# easy_install/bdist_egg path, which is broken with recent setuptools on
# Trixie.
install_python_packages() {
  [[ $systemwide = "true" ]] && sudo pip3 install . --break-system-packages
  [[ $userlocal = "true" ]] && pip3 install . --user --break-system-packages
  [[ $envlocal = "true" ]] && pip3 install .
}

# called by <<install_python_pkgs_and_dependencies>>
# Changed: "libncurses5" -> "libncurses6" (missing on Trixie). Added
# "libffi-dev" (needed to build smbus-cffi) and "avrdude" (current Debian
# version). "python3-rpi.gpio" removed: it conflicts with
# "python3-rpi-lgpio" (already present, and needed on a Pi 5); RPi.GPIO is
# installed via pip further down if required.
install_deb_dependencies() {
  feedback "Installing dependencies for the GrovePi"

  # in order for nodejs to be installed, the repo for it
  # needs to be in; this is all done in script_tools while doing an apt-get update
  sudo apt-get install --no-install-recommends -y nodejs \
    git libi2c-dev i2c-tools avrdude \
    python3-setuptools python3-pip python3-smbus python3-dev python3-serial python3-numpy python3-scipy \
    libncurses6 libffi-dev

  feedback "Dependencies for the GrovePi installed"
}

# called way down bellow
install_python_pkgs_and_dependencies() {
  # installing dependencies if required
  if [[ $installdependencies = "true" ]]; then
    feedback "Installing GrovePi dependencies. This might take a while.."
    install_deb_dependencies
    pushd $GROVEPI_DIR/Script > /dev/null
    sudo bash ./install.sh
    popd > /dev/null

    # Added: GrovePi's Script/install.sh forces its own bundled avrdude
    # (armhf, very old) if it doesn't detect "5.10" in the installed
    # version, which breaks dpkg on Trixie/arm64. Repaired here.
    feedback "Repairing avrdude (GrovePi's installer tried to replace it with an incompatible legacy package)"
    sudo dpkg --remove --force-depends --force-architecture avrdude:armhf >/dev/null 2>&1 || true
    sudo apt-get install --reinstall -y avrdude
    sudo apt-get -f install -y
  fi

  # Removed: the old setup.py/egg install path needed to manually clear out
  # the previous "grovepi" egg first. "pip3 install ." (below) replaces an
  # existing install cleanly on its own, so this step is no longer needed.

  # Added: pre-installing smbus-cffi via pip avoids a failure in GrovePi's
  # setup.py (easy_install broken with recent setuptools)
  feedback "Pre-installing smbus-cffi via pip3 (avoids a broken easy_install path in GrovePi's setup.py)"
  sudo pip3 install --upgrade smbus-cffi --break-system-packages

  # installing the package itself
  pushd $GROVEPI_DIR/Software/Python > /dev/null
  install_python_packages
  popd > /dev/null
}

################################################
######## Aggregating all function calls ########
################################################

# Added: explicit confirmation before any system change.
echo "This script will install/modify system packages and clone repositories (see the file header for details)."
read -r -p "Continue? [y/N] " user_confirm
case "$user_confirm" in
  [yY]|[yY][eE][sS]) ;;
  *) echo "Installation cancelled."; exit 0 ;;
esac

check_if_run_with_pi

parse_cmdline_arguments "$@"
install_rfrtools_repo

clone_grovepi
install_python_pkgs_and_dependencies

exit 0
