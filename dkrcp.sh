#!/bin/bash
path_Set(){
  local -r scriptFilePath="$(readlink -f "$1")"
  local -r scriptDir="$( dirname "$scriptFilePath")"
  # include dependent utilities/libraries in path
  if [ -d "$scriptDir/module" ]; then
    local modDir
    for modDir in $( ls -d "$scriptDir/module"/* ); do
      PATH="$modDir:$PATH"
     done
  fi
  export PATH="$scriptDir:$PATH"
}
path_Set "${BASH_SOURCE[0]}"
source "MessageInclude.sh";
source "ArgumentsGetInclude.sh";
source "ArrayMapTestInclude.sh";
source "VirtCmmdInterface.sh";
source "CommonInclude.sh";
source "UcpInclude.sh"
source "ArgumentsMainInclude.sh";

