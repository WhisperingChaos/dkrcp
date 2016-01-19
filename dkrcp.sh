#!/bin/bash
path_Set(){
  local scriptFilePath
  eval scriptFilePath\=\"$1\"
  local scriptDir
  scriptDir="$( dirname "$scriptFilePath")"
  export PATH="$scriptDir:$PATH"
}
path_Set "${BASH_SOURCE[0]}"
source 'ucp.sh'

