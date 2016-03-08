#!/bin/bash
path_Set(){
  local scriptFilePath
  eval scriptFilePath\=\"$1\"
  local scriptDir
  scriptDir="$( dirname "$scriptFilePath")"
  export PATH="$scriptDir:$PATH"
}
path_Set "${BASH_SOURCE[0]}"
source "MessageInclude.sh";
source "ArgumentsGetInclude.sh";
source "ArrayMapTestInclude.sh";
source "VirtCmmdInterface.sh";
source 'ucp.sh'
source "ArgumentsMainInclude.sh";

