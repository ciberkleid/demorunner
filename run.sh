# Usage example:
# source run.sh demos/dockerfile.txt files/dockerfile -f
# OR
# source run.sh demos/dockerfile.txt files/dockerfile -f -a -v
# source demorunner.sh demos/dockerfile.txt 1

# Default values of arguments
demo_script=""
demo_files=""
force_cleanup_enabled=0
run_demorunner_enabled=0
verbose_enabled=0

function log() {
  if [ ${force_cleanup_enabled} -eq 1 ]; then
    echo -e "${1}"
  fi
}

# Check number of arguments
if [ "$#" -gt 5 ]; then
    echo "Illegal number of arguments"
    echo "Usage:"
    echo "source run.sh <script_file> <files_dir> [-f] [-a]"
    echo "Notes: -f forces deletion and recreation of demo temp directory"
    echo "       -a enables calling demorunner automatically"
    echo "       -v enables verbose logging"
    kill -INT $$
fi

# Process arguments
# Check for a "-f" boolean flag to enable forced cleanup and avoid being prompted
# Inspired by: https://pretzelhands.com/posts/command-line-flags
for arg in "$@"
do
    case $arg in
        -f|--force)
        force_cleanup_enabled=1
        shift # Remove from processing
        ;;
        -a|--auto)
        run_demorunner_enabled=1
        shift
        ;;
        -v|--verbose)
        verbose_enabled=1
        shift # Remove from processing
        ;;
        *)
        if [[ "${demo_script}" == "" ]]; then
          demo_script="${1}"
          if [ ! -f "${demo_script}" ]; then
            echo "File does not exist: [${demo_script}]"
            kill -INT $$
          fi
        elif [[ "${demo_files}" == "" ]]; then
          demo_files="${1}"
          if [ ! -d "${demo_files}" ]; then
            echo "Directory does not exist: [${demo_files}]"
            kill -INT $$
          fi
        fi
        shift
        ;;
    esac
done

echo -e "\n\n##### SETTING UP DEMO [${demo_script}] [${demo_files}] [$(date)] #####"

# brew install coreutils (for greadlink)
demo_script_absolute_path=$(greadlink -f "${demo_script}")
demo_script_handle=$(echo $(basename "${demo_script}") | cut -d. -f1)
if [[ "${demo_files}" != "" ]]; then
  demo_files_absolute_path=$(greadlink -f "${demo_files}")
else
  demo_files_absolute_path=""
fi

##### DEMO ENV VARS
export DEMO_HOME=`pwd`
export DEMO_SCRIPT="${demo_script_absolute_path}"
export DEMO_FILES="${demo_files_absolute_path}"
export DEMO_TEMP="${DEMO_HOME}/temp/${demo_script_handle}"
# Default delay is 10. To make it faster, increase the number
export DEMO_DELAY=${DEMO_DELAY:-15}
export SAVED_DEMO_DELAY=${DEMO_DELAY}

##### APPEARANCE SETTINGS
# https://github.com/sharkdp/bat
#brew install bat

if [[ $(which bat) != "" ]]; then
  log -e "\nSetting up bat utility"
  mkdir -p "$(bat --config-dir)/themes"
  cp config/bat/themes/*.tmTheme "$(bat --config-dir)/themes"
  bat cache --build
  export BAT_STYLE=grid
  #export BAT_STYLE=plain
  #export BAT_STYLE=numbers
  export BAT_PAGER=""
  #export BAT_PAGER="never"
fi

if [ -z ${COLORFGBG} ]; then
  # Background is white
  export BAT_THEME=ansi-light-MODIFIED
  #export BAT_THEME=GitHub
  export DEMO_COLOR=blue
else
  # Background is black
  if [[ ${DEMO_COLOR} != white ]]; then
    export DEMO_COLOR=yellow
  fi
fi

##### TEMP DIR

log -e "\nSetting up temp dir [${DEMO_TEMP}]"
if [ "$(ls -A ${DEMO_TEMP})" ]; then
  log "Temp dir contents"
  tree "${DEMO_TEMP}"
fi
if [ ${force_cleanup_enabled} -eq 1 ]; then
  echo "Forced deletion is enabled. Recreating temp directory."
  rm -rf "${DEMO_TEMP}"
  log "Temp dir conents"
  tree "${DEMO_TEMP}"
else
  echo "Forced deletion is not enabled. Using existing temp directory."
fi
mkdir -p "${DEMO_TEMP}"

##### ALIASES

# https://github.com/dandavison/delta
#brew install git-delta

# Stop running containers & prune images, containers, volumes, and networks (stopped, unused, and dangling)
alias dclean="docker ps -a -q | xargs -n1 docker stop; docker system prune -af"
# Remove all containers; prune dangling images; prune images, containers, volumes, and networks with specified label
alias dclean2="docker ps -a -q | xargs -n1 docker rm -f; docker image prune -f; docker system prune -af --filter label=maintainer=me@example.com"

# Change Terminal prompt to show only a $
export PS1="\[\033[0m\]\$ "

# BEGIN SECTION: Fancy cat and diff aliases
#brew install colordiff

# catt - like cat, but skip commented lines and empty lines
cattf() { grep -v -A1 '^[[:blank:]]*$' "${@}" | grep -v '^--$' | grep -vE '^\s*#'; }
alias catt=cattf

# cattd - like dif, but side-by-side and colored, and skip commented lines and empty lines
cattdf() { cattf ${1} > .___cattdf_temp_file_1; cattf ${2} > .___cattdf_temp_file_2; colordiff -yW"`tput cols`" .___cattdf_temp_file_1 .___cattdf_temp_file_2; rm .___cattdf_temp_file_1; rm .___cattdf_temp_file_2; }
alias cattd=cattdf

# catd - like dif, but side-by-side and colored
catdf() { colordiff -yW"`tput cols`" ${1} ${2}; }
alias catd=catdf
# END SECTION: Fancy cat and diff aliases

# Generate args to highlight changed lines for bat
BAT_LANG=""
batdf() { hArgs=$(diff --unchanged-line-format="" --old-line-format="" --new-line-format="%dn " ${1} ${2} | xargs -n1 -I {} printf -- '-H %s:%s ' {} {}); bat ${BAT_LANG} ${2} $hArgs; }
alias batd=batdf
setBatLangf() { if [[ "${1}" == "" ]]; then export BAT_LANG=""; else export BAT_LANG="-l ${1}"; fi; alias bat="bat ${BAT_LANG}"; }
alias setBatLang=setBatLangf
setBatLang ""
# Usage example:
# setBatLang Dockerfile
# bat Dockerfile
# batd Dockerfile Dockerfile2
# setBatLang exclude
# bat .dockerignore
# batd .dockerignore .dockerignore2
# To use default language detection, set to empty string:
# setBatLang

#####  PRINT ENV VARS

log -e "\nDemo config:"
log "DEMO_HOME=${DEMO_HOME}"
log "DEMO_TEMP=${DEMO_TEMP}"
log "DEMO_SCRIPT=${DEMO_SCRIPT}"
log "DEMO_FILES=${DEMO_FILES}"
log "DEMO_DELAY=${DEMO_DELAY}"
log "SAVED_DEMO_DELAY=${SAVED_DEMO_DELAY}"
log "DEMO_COLOR=${DEMO_COLOR}"
if [[ $(which bat) != "" ]]; then
  log "BAT_STYLE=${BAT_STYLE}"
  log "BAT_PAGER=${BAT_PAGER}"
  log "BAT_THEME=${BAT_THEME}"
  log "BAT_LANG=${BAT_LANG}   # to change, use: setBatLang <language>"
fi
log -e "\nFinished setting up environment"

#####  PROVIDE COMMAND FOR STARTING DEMO SCRIPT
#command="cd \${DEMO_TEMP}; source \${DEMO_HOME}/demorunner.sh \${DEMO_SCRIPT} 1; cd \${DEMO_HOME}"
#printf "${command}" | pbcopy
#echo
#echo "To start the demo, execute the following command (it's in your clipboard!):"
#echo "cd \${DEMO_TEMP}; source \${DEMO_HOME}/demorunner.sh \${DEMO_SCRIPT} 1; cd \${DEMO_HOME}"
#echo
#echo "Expanded form:"
#echo "cd ${DEMO_TEMP}; source ${DEMO_HOME}/demorunner.sh ${DEMO_SCRIPT} 1; cd ${DEMO_HOME}"
#echo

##### RUN AUTOMATICALLY
#if [ ${run_demorunner_enabled} -eq 1 ]; then
#  echo -e "\nExecuting ${DEMO_HOME}/demorunner.sh...\n"
#  cd "${DEMO_TEMP}"
#  source ${DEMO_HOME}/demorunner.sh "${DEMO_SCRIPT}" 1
#  cd "${DEMO_HOME}"
#fi

#####  PROVIDE COMMAND FOR STARTING DEMO SCRIPT
echo "###################################################################"
echo "#################### Your environment is ready ####################"
echo "###################################################################"
alias cdd="cd ${DEMO_HOME}"
alias cdt="cd ${DEMO_TEMP}"
command="cd \${DEMO_TEMP}; source demorunner.sh \${DEMO_SCRIPT} 1; cd \${DEMO_HOME}"
printf "${command}" | pbcopy
echo
echo "The following env vars have been set:"
echo "DEMO_HOME=${DEMO_HOME}"
echo "DEMO_SCRIPT=${DEMO_SCRIPT}"
echo "DEMO_TEMP=${DEMO_TEMP}           -----> Directory created"
echo "DEMO_FILES=${DEMO_FILES}         -----> Directory created"
echo "alias cdd=\${DEMO_HOME}"
echo "alias cdt=\${DEMO_TEMP}"
echo
echo "To start the demo, execute the following command (it's in your clipboard!):"
echo
echo "cd \${DEMO_TEMP}; source \${DEMO_HOME}/demorunner.sh \${DEMO_SCRIPT} 1; cd \${DEMO_HOME}"
#echo "cd ${DEMO_TEMP}; source ${DEMO_HOME}/demorunner.sh ${DEMO_SCRIPT} 1; cd ${DEMO_HOME}"
#echo
#echo "Expanded form:"
#echo "cd ${DEMO_TEMP}; source ${DEMO_HOME}/demorunner.sh ${DEMO_SCRIPT} 1; cd ${DEMO_HOME}"
echo
