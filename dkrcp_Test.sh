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
source "TestFramework.sh";
source "ObjectReflectFramework.sh"
source "CommonInclude.sh"

###############################################################################
##
##  Purpose:
##    See TestFramework.sh -> TestConfigSetDefault
##
#################################################################################
TestConfigSetDefault(){
  # establishes name space that prefixes each test function, image name, 
  # container name, file name,..., essentially any named, generated artifact.
  TEST_NAME_SPACE='dkrcp_test_'
  # create a temporary test file/directory prefix used to contain test artifacts
  # produced by this testing procedure.
  local tempDir="$(dirname "$(mktemp -u)")"
  if [ -z "$tempDir" ]; then 
    ScriptUnwind "$LINENO" "Unable to determine temp dir from: 'mktemp -u'."
  fi
  TEST_FILE_PREFIX="$TEST_NAME_SPACE"
  TEST_FILE_ROOT="$tempDir/${TEST_NAME_SPACE}tmp/"
}
###############################################################################
##
##  Purpose:
##    see TestFramework.sh -> TestHelpCmmdUsageDisplay
##
###############################################################################
TestHelpCmmdUsageDisplay(){
  echo "Execute tests to verify operation of 'dkrcp.sh' command."
  echo
  echo "Usage: dkrcp_test.sh [OPTIONS] TEST_NUM"
}
###############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdVersionDisplay
##
###############################################################################
VirtCmmdVersionDisplay(){
  echo 'Version : 0.5'
  echo 'Requires: bash 4.0+, Docker Client 1.8+'
}
###############################################################################
##
##  Purpose:
##    see TestFramework.sh -> TestEnvironentDependenciesAssert
##
###############################################################################
TestEnvironentDependenciesAssert(){
  local depndSuccess='true'
  ! TestDependenciesScanSuccess 'dkrcp_dependency_define_Docker_Client' '1.8.0' && depndSuccess='false'
  ! TestDependenciesScanSuccess 'dkrcp_dependency_define_Diff'          '3.0'   && depndSuccess='false'
  ! TestDependenciesScanSuccess 'Testdependency_define_Bash'            '4.'   && depndSuccess='false'
  ! TestDependenciesScanSuccess 'dkrcp_dependency_dkrcp'                '0.5'   && depndSuccess='false'
  ! TestLocalRepositoryIsEmpty && depndSuccess='false'
  ! $depndSuccess && ScriptUnwind "$LINENO" "Detected problematic dependencies.  Repair or try '--no-depend'."
  true
}
###############################################################################
##
##  Purpose:
##    Verifies Docker client version for dkrcp.
##
##  see interface definition: TestFramework.sh -> Testdependency_define_Docker_Client
##
###############################################################################
dkrcp_dependency_define_Docker_Client(){
  Testdependency_define_Docker_Client
  dependency_version_Violation_Gen(){
    ScriptError "Requires Docker Client version:'$1+' for 'docker cp' functionality.  Client version detected:'$2'."
  }
}
###############################################################################
##
##  Purpose:
##    dkrcp relies on 'diff' to verify cp operation.
##
##  see interface definition: TestFramework.sh -> TestDependenciesScanSuccess
##
###############################################################################
dkrcp_dependency_define_Diff(){
  dependency_Exist(){
    diff --help >/dev/null 2>/dev/null
  }
  dependency_version_Get(){
    if diff --help | grep '[-]q'>/dev/null 2>/dev/null; then
      echo '3.0'
    else
      echo '0.0'
    fi
  }
  dependency_version_Violation_Gen(){
    ScriptError "Requires 'diff' with -q option: report on files only if different."
  }
}

###############################################################################
##
##  Purpose:
##    dkrcp_Test.sh relies on 'dkrcp.sh' so it can test dkrcp.sh.
##
##  see interface definition: TestFramework.sh -> TestDependenciesScanSuccess
##
###############################################################################
dkrcp_dependency_dkrcp(){
  dependency_Exist(){
    dkrcp.sh --help >/dev/null 2>/dev/null
  }
  dependency_version_Get(){
    local versionLabel
    if versionLabel="$(dkrcp.sh --ver | grep  '^Version : ')"; then
      echo "${versionLabel:10}"
    else
      echo '0.0'
    fi
  }
  dependency_version_Violation_Gen(){
    ScriptError "Requires 'dkrcp' of version: '$1', detected: '$2'."
  }
}
###############################################################################
##
##  Section:
##    Helper utility functions.
##
###############################################################################

###############################################################################
##
##  Purpose:
##    Create a file whose contents reflects absolute file name.
##
##  Input:
##    $1 - Absolute file name to create.
##
###############################################################################
file_content_reflect_name(){
  if ! mkdir -p "$( dirname "$1")"; then
    ScriptError "Unable to create directory path for file: '$1'"
  elif ! echo "$1">"$1"; then
    ScriptError "Failed to create file content:'$1'."
  fi
}
###############################################################################
##
##  Purpose:
##    Create a directory of a given path.  Create all necessary parent 
##    directories when necessary.
##
##  Input:
##    $1 - Absolute directory path to create.
##
###############################################################################
file_content_dir_create(){
  if ! mkdir -p "$1" >/dev/null; then
    ScriptError "Unable to create directory: '$1'"
  fi
}
#TODO:
#   Encode additional tests:
#     9.  Copy with -L argument supported by 1.10.
resource_File_Path_Name_Prefix(){
   local filePath_lcl="$1"
   if [ "${filePath_lcl:0:1}" == '/' ]; then
     filePath_lcl="${filePath_lcl:1}"
   fi
   ref_simple_value_Set "$2" "${TEST_FILE_ROOT}${filePath_lcl}"
}

container_Clean(){
  local errorMsg
  if ! errorMsg="$( docker rm $( docker ps -a --no-trunc | grep "$1" | awk '{ print $1 }') 2>&1 )"; then
    if ! [[ $errorMsg =~ 'docker: "rm" requires a minimum of 1 argument' ]]; then
      ScriptUnwind "$LINENO" "docker rm unexpectedly failed with message: '$errorMsg'."
    fi
  fi
}
###########################################################################
##
##  Purpose:
##    Given a set of Dockerfile metadata commands, ensure these commands
##    affected the image's metadata values.
##
##  Input:
##    $1 - An existing image name or UUID.
##    $2 - Variable name to map relating a Dockerfile metadata command 
##         to a value filter that can be expressed as a grep extended
##         regular expression.  A successful filter causes grep to generate
##         some output without failing.
##    $3 - Variable name to a map defining the relationship between
##         metadata command name and its associated json reference to the
##         desired value. Command name must be all upper-case.
##
##  Output:
##    When successful: nothing
##    Otherwise: Error message to STDERR.
##
###########################################################################
image_metadata_Verify(){
  local -r imageNameUUID="$1"
  local -r metaDataMap_ref="$2"
  local -r metaDataFormat_ref="$3"
  local imageMetaData
  if ! imageMetaData="$( docker inspect --type=image -- $imageNameUUID )"; then
    ScriptError "Image metadata not found for: '$imageNameUUID'."
    return
  fi
  local -r imageMetaData
  local jsonRef
  local metaDataFilter
  local metaDataFilterResult
  eval local \-r metaDataCmdList=\"\$\{\!$metaDataMap_ref\[\@\]\}\"
  for metaDataCmd in $metaDataCmdList
  do
    metaDataCmd="${metaDataCmd^^}"
    AssociativeMapAssignIndirect "$metaDataMap_ref"    "$metaDataCmd" 'metaDataFilter'
    AssociativeMapAssignIndirect "$metaDataFormat_ref" "$metaDataCmd" 'jsonRef'
    if ! metaDataFilterResult="$( echo "$imageMetaData" | jq ".[0]$jsonRef" | grep -E "$metaDataFilter" )"; then
      ScriptError "grep for metadata command: '$metaDataCmd' failed using filter: '$metaDataFilter'."
      return
    fi
    if [ -z "$metaDataFilterResult" ]; then
      ScriptError "Filter for metadata command: '$metaDataCmd' failed to find value using filter: '$metaDataFilter'."
      return
    fi 
  done
}
##############################################################################
#TODO: Place in common docker include source
##
##  Purpose:
##    Convert an image to a container.  As a container, the image can be
##    copied to/from using docker cp command introduced in 1.8.
##
##  Inputs:
##    $1 - Existing image name or image UUID.
##    $2 - A variable to contain the resulting container UUID created from
##         the given image.
##    $3 - (optional) A variable to contain ENTRYPOINT nullify directive.  If the image
##         lacks an ENTRYPOINT or CMD, a pseudo one is created to permit the
##         docker create to successfully complete.  However, to consistently
##         maintain this property value in the newly derived image,
##         the ENTRYPOINT must be nullified.  This variable records, if 
##         necessary, the nullify directive.
##
##  Outputs:
##    $2 - Variable updated to reflect newly created container UUID.
##    $3 - (optional) Variable updated to ENTRYPOINT directive.
##
###############################################################################
image_container_Create(){
  local imageNameUUID="$1"
  local targetContainer_ref="$2"
  local entryptNullify_ref="$3"

  local entryptNullify_lcl=''
  local targetContainer_lcl=''
  while true; do
    if targetContainer_lcl="$( docker create $imageNameUUID 2>&1 )"; then
      # create successful - do not nullify CMD/ENTRYPOINT
      break
    fi
    if [[ $targetContainer_lcl =~ Error[^:]+:.No.command.specified ]] \
       && targetContainer_lcl="$( docker create --entrypoint=['','']  $imageNameUUID 2>&1 )"; then
      # create was successful after generating pseudo ENTRYPOINT. Encode directive
      # to nullify ENTRYPOINT in resulting image.
      entryptNullify_lcl='-c="'"ENTRYPOINT null"'"'
      break
    fi
    # some unexpected error
    echo "$targetContainer_lcl" >&2
    ScriptUnwind "$LINENO" "Failed while creating container from image: '$imageNameUUID'."
  done
  if [ -n "$entryptNullify_ref" ]; then
    eval $entryptNullify_ref\=\"\$entryptNullify_lcl\"
  fi
  eval $targetContainer_ref\=\"\$targetContainer_lcl\"
}
###########################################################################
##
##  Purpose:
##    Define the mapping between a docker commit image metadata command
##    and the json reference to view its value.  Image metadata command
##    must be in all uppercase.
##
##  Input:
##    $1 - Variable name to map.
##
##  Output:
##    $1 updated to reflect docker commit map.
##
###########################################################################
docker_commit_metadata_cmd_to_jsonReference_Map(){
  local -r metaDataFormat_ref="$1"
  # initialize the map to nothing
  eval $metaDataFormat_ref\=\(\)
  # set the map to correlate commit metadata requests to
  # their json references
  _reflect_field_Set "$metaDataFormat_ref"  \
    '--AUTHOR'    '.Author'                 \
    '--MESSAGE'   '.Comment'                \
    'CMD'         '.Config.Cmd'             \
    'ENTRYPOINT'  '.Config.Entrypoint'      \
    'ENV'         '.Config.Env'             \
    'EXPOSE'      '.Config.ExposedPorts'    \
    'LABEL'       '.Config.Labels'          \
    'ONBUILD'     '.Config.OnBuild'         \
    'USER'        '.Config.User'            \
    'VOLUME'      '.Config.Volumes'         \
    'WORKDIR'     '.Config.WorkingDir'
}
###########################################################################
##
##  Purpose:
##    Extract only the docker commit options from the dkrcp provided option
##    string.  Then extract the Docker metadata commands from the
##    --change options and their values creating a result map associating
##    these metadata commands with their values.
##
##  Input:
##    $1 - One or more dkrcp options provided as a string.
##    $2 - Variable name of map to return association between Dockerfile
##         metadata commands and their values.
##
##  Output:
##    $2 - Updated map.
##
###########################################################################
docker_commit_metadata_cmd_value_Map(){
  local -r optionString="$1"
  local -r metadataValueMap_ref="$2"
  eval $metadataValueMap_ref\=\(\)
  local -a dkrOptList
  eval set -- $optionString
  while (( $# > 0 )); do
   dkrOptList+=( "$1" )
   shift
  done
  local -r dkrOptList
  if (( ${#dkrOptList[@]} < 1 )); then return; fi
  local -a dkrOptArgList
  local -A dkrOptArgMap
  local -a ucpOptRepeatList=( '--change' )
  ucpOptRepeatList+=( '-c' )
  local -r ucpOptRepeatList
  if ! ArgumentsParse 'dkrOptList' 'dkrOptArgList' 'dkrOptArgMap' 'ucpOptRepeatList'; then
    ScriptUnwind "$LINENO" "Unexpected error while processing option list: '$optionString'."
  fi
  # extract only image commit options from option string
  local -r IMAGE_OPTION_FILTER='[[ $optArg =~ ^--change=[1-9][0-9]*$ ]] || [[ $optArg =~ ^-c=[1-9][0-9]*$ ]] || [ "$optArg" == "--author" ] || [ "$optArg" == "--message" ]'
  local -a dkrCommitOptList
  local -A dkrCommitOptMap
  if ! OptionsArgsFilter 'dkrOptArgList' 'dkrOptArgMap' 'dkrCommitOptList' 'dkrCommitOptMap' "$IMAGE_OPTION_FILTER" 'true'; then
    ScriptUnwind "$LINENO" "Problem filtering options for docker commit."
  fi
  local -r dkrCommitOptList
  if (( ${#dkrCommitOptList[@]} < 1 )); then return; fi
  local -r dkrCommitOptMap
  # Dockerfile metadata commands follow form of <keyword><whitespace><value>
  local -r regExDkrFileCmd='(^[^ ]+)[ ]+(.*)$'
  local keyName
  local innerKeyValue
  for keyName in ${dkrCommitOptList[@]}
  do
    innerKeyValue="${dkrCommitOptMap["$keyName"]}"
    if [ "$keyName" == '--author' ] || [ "$keyName" == '--message' ]; then
      _reflect_field_Set "$metadataValueMap_ref" "${keyName^^}" "$innerKeyValue"
      continue
    fi
    if ! [[ $innerKeyValue =~ $regExDkrFileCmd ]]; then
      ScriptUnwind "$LINENO" "Parsing of Dockerfile command failed: '$innerKeyValue'."
    fi
    if [ "${BASH_REMATCH[1]^^}" == "LABEL" ]; then
      # Special case for LABEL due to its json representation
      _reflect_field_Set "$metadataValueMap_ref" "${BASH_REMATCH[1]^^}" "${BASH_REMATCH[2]/=/.+}"
      continue
    fi
    #TODO: only one value for each distinct Dockerfile command survives (rightmost option).
    # not currently necessary for testing to support multiple values.
    _reflect_field_Set "$metadataValueMap_ref" "${BASH_REMATCH[1]^^}" "${BASH_REMATCH[2]}"
  done
}
###########################################################################
#TODO: remove
##
##  Purpose:
##    Extract the 64 byte UUID for an image/container.  Unfortunately, in 1.10
##    Docker implemented a breaking change to its .Id format, that given
##    what I know, didn't need to happen. This issue is addressed 
##    by this function call (layer) to allow existing code, built before
##    the breaking change was implemented, to retain its notion of
##    a UUID.
##
##  Input:
##    $1 - name or UUID to search for.
##    $2 - type:
##          'image'     - image namespace
##          'container' - container namespace
##    $3 - (optional)
##
###########################################################################
#image_container_UUID_Get(){
  #  local -r nameUUID="$1"
  #  if [ -z "$2" ] then
  #  local -r typeInspect='image'
  #  else
    #    local -r typeInspect="$2"
  #  fi
  #  local -r UUID_value_ref="$3"
  #  local UUID_value_lcl
  #  if ! UUID_value_lcl="$(docker inspect --type="$typeInspect" --format='{{ .Id }}' -- "$nameUUID" )"; then
    #    return 1
  #  fi
  #  local -r UUID_value_lcl="${UUID_value_lcl#*:}
  #  if [ -n "$UUID_value_ref" ]; then
    #    ref_simple_value_Set "$UUID_value_ref" "$UUID_value_lcl"
  #  else
    #    echo "$UUID_value_lcl"
  #  fi
#}
###########################################################################
##
##  Purpose:
##    Defines an interface to examine the environment for resources that
##    maybe remnants of a failed test or simply happen to share the
##    same name.
##
###########################################################################
env_check_interface(){
  ###########################################################################
  ##
  ##  Purpose:
  ##    Defines an interface to examine the environment for resources that
  ##    maybe remnants of a failed test or simply happen to share the
  ##    same name.
  ##
  ##  Inputs:
  ##    $1 - Variable name whose value is set to 'true' on discovery of an
  ##         existing resource.
  ##
  ##  Outputs:
  ##    $1 - Set the variable value to 'true' iff an existing resource is
  ##         discovered, otherwise, just leave its value alone.
  ##    STDERR - Issue an appropriate error message upon detection of a
  ##         resource remnant.
  ##
  ###########################################################################
  env_Check(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
}
###########################################################################
##
##  Purpose:
##    Defines an interface to clean resources associated to the arguments
##    of the dkrcp.sh bash script.  For example, a source argument may
##    to dkrcp may refer to an Docker image which should be removed from
##    the local Docker repository when no longer needed.
##
###########################################################################
env_clean_interface(){
  env_Clean(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
}
###########################################################################
##
##  Purpose:
##    Define a concrete implementation supporting the auditing of the dkrcp
##    copy operation.
##
###########################################################################
audit_model_impl(){
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct an instance of a model.
  ##    A model contains the following members:
  ##       ModelFilePath  - A path representing the model's root directory.
  ##       ModelWritePath - The path within the ModelFilePath that will be
  ##                        the target of the simulated copy operation.
  ##  Inputs:
  ##    $1 - An 'empty' associative map variable.
  ##    $2 - Root file path to the model.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  _Create(){
    local -r this_ref="$1"
    local modelFilePath="$2"
    _reflect_type_Set "$this_ref" 'audit_model_impl'
    resource_File_Path_Name_Prefix "$modelFilePath" 'modelFilePath'
    local -r modelFilePath
    _reflect_field_Set "$this_ref" 'ModelFilePath' "$modelFilePath"
  }
  audit_model_exist_Check(){
    local -r this_ref="$1"
    local modelFilePath
    _reflect_field_Get "$this_ref" 'ModelFilePath' 'modelFilePath'
    if [ -e "$modelFilePath" ]; then
      ScriptDetectNotify "model file path:'$modelFilePath'"
    fi
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Provide root path to model.  Directories/files subordinate to this
  ##    root   
  ##
  ##  Inputs:
  ##    $1 - This pointer to model object.
  ##    $2 - Name of variable to return the value of the module's path.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  audit_model_root_path_Get(){
    local -r this_ref="$1"
    _reflect_field_Get "$this_ref" 'ModelFilePath' "$2"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Configure the ModelWritePath to reflect the existing directory path
  ##    of dkrcp's target argument.  The ModelWritePath represents the
  ##    target directory path to which the source objects write.
  ##
  ##  Inputs:
  ##    $1 - An associative map variable constructed via a _Create function
  ##         that supports this interface.
  ##    $2 - An indicator specifying the type of file system object
  ##         of $2:
  ##         'f' - A file path that refers to a file object.
  ##         'd' - A file path that refers to a directory object.
  ##    $3 - dkrcp target argument's file path.
  ##    $4 - When $2 refers to a directory, a boolean value indicating
  ##         its existence:
  ##         'true'  - directory exists.
  ##         'false' - Otherwise.
  ##
  ##  When successful:
  ##    $1 - The model's directory location reflects  A constructed this pointer.
  ##
  ###########################################################################
  audit_model_path_write_Configure(){
    local -r this_ref="$1"
    local -r targetFileType="$2"
    local -r targetFilePath="$3"
    local -r targetDirExist="$4"
    local modelRootPath
    audit_model_root_path_Get "$this_ref" 'modelRootPath'
    local -r modelRootPath
    local dirToReplicate="$targetFilePath"
    if [ "$targetFileType" == 'f' ]; then
      dirToReplicate="$( dirname "$targetFilePath")"
    elif [ "$targetFileType" == 'd' ]; then
      if ! $targetDirExist; then
        dirToReplicate="$( dirname "$targetFilePath")"
      fi
    else
      ScriptUnwind "$LINENO" "Unknown target type: '$targetFileType'.  Must be 'f' - for file or 'd' - for directory."
    fi
    if (( ${#dirToReplicate} < 3 )) && ( [ "$dirToReplicate" == '/' ] || [ "$dirToReplicate" == '.' ] || [ "$dirToReplicate" == '/.' ] ); then
      dirToReplicate=''
    fi
    local -r dirToReplicate
    local dirSep='/'
    if [ "${targetFilePath:0:1}" == '/' ]; then dirSep=''; fi 
    local -r dirSep
    if ! mkdir -p "${modelRootPath}${dirSep}${dirToReplicate}" >/dev/null; then
      ScriptUnwind "$LINENO" "Replicating target directory path:'${dirToReplicate}' within model failed: '${modelRootPath}'"
    fi
    _reflect_field_Set "$this_ref" 'ModelWritePath' "${modelRootPath}${dirSep}${targetFilePath}"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Provide a write path within a model that mimics the one specified
  ##    by the dkrcp target argument.  Before calling this method, one
  ##    must have configured the model by calling 'audit_model_path_write_Configure'.
  ##    This dependency could be replaced by turning audit_model_path_write_Configure
  ##    into a constructor for another object type that this method belongs to
  ##    but I'm a bit lazy.
  ##
  ##  Inputs:
  ##    $1 - An associative map variable constructed via a _Create function
  ##         that supports this interface.
  ##    $2 - A variable name to receive the value of the model write path.
  ##         ModelWritePath should have already been created.
  ##
  ##  When successful:
  ##    $2 - Updated to reflect the dkrcp target path within this model.
  ##
  ###########################################################################
  audit_model_path_write_Get(){
    local -r this_ref="$1"
    _reflect_field_Get "$this_ref" 'ModelWritePath' "$2"
  }
  audit_model_Destroy(){
    local -r this_ref="$1"
    local modelFilePath
    _reflect_field_Get "$this_ref" 'ModelFilePath' 'modelFilePath'
    file_path_safe_Remove "$modelFilePath"
  }
  env_check_interface
  env_Check(){
    audit_model_exist_Check "$1"
  }
  env_clean_interface
  env_Clean(){
    audit_model_Destroy "$1"
  }
}
###########################################################################
##
##  Purpose:
##    Define a mostly abstract interface so the various dkrcp argument
##    types can be manipulated via this interface without regard to 
##    their various implementation details.
##
###########################################################################
dkrcp_arg_interface(){
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct appropriate dkrcp argument.
  ##
  ##  Inputs:
  ##    $1   - An 'empty' associative map variable.
  ##    $2-N - Zero or more arguments required by the specific polymorphic
  ##           _Create method of the concrete types that implement this
  ##           interface.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  _Create(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Binds an argument to its associated resource.  If the resource
  ##    doesn't exist, it is created.
  ##
  ##  Inputs:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##
  ###########################################################################
  dkrcp_arg_resource_Bind(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Generate the argument format accepted by the dkrcp utility
  ##
  ##  Inputs:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##    $2 - A variable name that will be assigned the docker cp argument value.
  ##
  ##  Outputs:
  ##    $2 - Updated to reflect the docker cp argument value.
  ##
  ###########################################################################
  dkrcp_arg_Get(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Generate prefix command for dkrcp utility.
  ##
  ##  Inputs:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##    $2 - A variable name to accept the prequel command string supplied
  ##         by this dkrcp argument type.
  ##
  ##  Outputs:
  ##    $2 - Updated to reflect the prequel command string.
  ##
  ###########################################################################
  dkrcp_arg_prequel_cmd_Gen(){
      #  default implementation - only stream type generates a pipe.
      ref_simple_value_Set "$2" ''
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Configure the ModelWritePath to reflect the existing directory path
  ##    of dkrcp's target argument.  The ModelWritePath represents the
  ##    target directory path to which the source objects write.
  ##
  ##  Inputs:
  ##    $1 - An associative map variable constructed via a _Create function
  ##         that supports this interface.
  ##    $2 - Variable name to return an indicator specifying the type of
  ##         file system object represented by this argument.:
  ##         'f' - A file path that refers to a file object.
  ##         'd' - A file path that refers to a directory object.
  ##    $3 - Variable name to return a target argument's file path.
  ##    $4 - When $3 refers to a directory, a variable name to return a
  ##         boolean value indicating its existence in the target:
  ##         'true'  - directory exists.
  ##         'false' - Otherwise.
  ##
  ##  When successful:
  ##    $2-$4 - Updated with values as described above.
  ##
  ###########################################################################
  dkrcp_arg_model_settings_Get(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Have argument write to given model's file path as a means of 
  ##    creating an independent perspective of dkrcp's copy operation.
  ##
  ##  Inputs:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##    $2 - A model's path.
  ##    $3 - Mandatory when argument assumes role of a TARGET.  There are cases
  ##         when the TARGET assumes the filename/directory name of the SOURCE.
  ##         Specifically when copying to the default root ('/') directory.
  ##
  ##  Outputs:
  ##    $2 - Updated to reflect the write operation to the model.
  ##
  ###########################################################################
  dkrcp_arg_model_Write(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Inspect the output generated by the dkrcp command to ensure it
  ##    conforms to expected behavior.
  ##
  ##  Inputs:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##    STDIN - STDOUT of dkrcp command.
  ##
  ##  Outputs:
  ##    When actual conforms to expected nothing.
  ##
  ###########################################################################
  dkrcp_arg_output_Inspect(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ###############################################################################
  ##
  ##  Purpose:
  ##    Analyze the environment after executing the dkrcp pipeline.  At this
  ##    juncture, dkrcp has terminated and can no longer affect the environment.
  ##
  ##  Inputs:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##    $2 - Options specified for the dkrcp command.
  ##    Environment, such as local Docker repository.
  ##
  ##  Outputs:
  ##    When successful: Nothing if expected environment matches actual one.
  ##    Otherwise:       A message to STDERR & testing termination.
  ##
  ###############################################################################
  dkrcp_arg_environ_Inspect(){
    true
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Release any allocated named resources represented by the argument.
  ##
  ##  Inputs:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##
  ###########################################################################
  dkrcp_arg_Destroy(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
}
hostfilepathname_dependent_impl(){
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct a host file argument that refers to
  ##    a host file resource.
  ##
  ##  Inputs:
  ##    $1 - An 'empty' associative map variable.
  ##    $2 - The type of host file path:
  ##         'f' - file path resolves to a file.
  ##         'd' - file path resolves to a directory.
  ##    $3 - dkrcp host file path.
  ##    $4 - A function name that generates $3's content.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  _Create(){
    hostfilepathname_Create 'hostfilepathname_dependent_impl' "$@"
  }
  hostfilepathname_Create(){
    local -r thisTypeName="$1"
    local -r this_ref="$2"
    local -r argFileType="$3"
    local -r argFilePath="$4"
    local -r funcNameContentGen="$5"
    _reflect_type_Set "$this_ref" "$thisTypeName"
    local resourceFilePath
    resource_File_Path_Name_Prefix "$argFilePath" 'resourceFilePath'
    _reflect_field_Set "$this_ref"                \
      'ArgFileType'        "$argFileType"         \
      'ArgFilePath'        "$argFilePath"         \
      'ResourceFilePath'   "$resourceFilePath"    \
      'FuncNameContentGen' "$funcNameContentGen"
  }
  hostfilepathname_dependent_Bind(){
    local -r this_ref="$1"
    local resourceFilePath
    local funcNameContentGen
    _reflect_field_Get "$this_ref"               \
      'ResourceFilePath'   'resourceFilePath'    \
      'FuncNameContentGen' 'funcNameContentGen'
    local -r resourceFilePath
    local -r funcNameContentGen
    $funcNameContentGen "$resourceFilePath"
  }
  hostfilepathname_dependent_Delete(){
    local -r this_ref="$1"
    local resourceFilePath
    _reflect_field_Get "$this_ref" 'ResourceFilePath' 'resourceFilePath'
    local -r resourceFilePath
    file_path_safe_Remove "$resourceFilePath" >/dev/null
  }
  hostfilepathname_dependent_Check(){
    local -r this_ref="$1"
    local resourceFilePath
    _reflect_field_Get "$this_ref" 'ResourceFilePath' 'resourceFilePath'
    local -r resourceFilePath
    if [ -e "$resourceFilePath" ]; then
      ScriptDetectNotify "host file: '$resourceFilePath', involved in testing."
    fi
  }
  env_clean_interface
  env_Clean(){
    hostfilepathname_dependent_Delete "$1"
  }
  env_check_interface
  env_Check(){
    hostfilepathname_dependent_Check "$1"
  }
}
###########################################################################
##
##  Purpose:
##    Implement interface for dkrcp arguments bound to host file path.
##  
###########################################################################
dkrcp_arg_hostfilepath_hostfilepathExist_impl(){
  dkrcp_arg_interface
  hostfilepathname_dependent_impl
  _Create(){
    _dkrcp_arg_hostfilepath_hostfilepathExist_impl_Create "$@"
  }
  _dkrcp_arg_hostfilepath_hostfilepathExist_impl_Create(){
    local -r this_ref="$1"
    local argFilePath="$3"
    local argfileSelector=''
    #  remove selectors - extend code when docker implements go gob patterns
    if [ "${argFilePath:(( -2 ))}" == '/.' ]; then
      argFilePath="${argFilePath:0:-2}"
      argfileSelector='/.'
    fi
    hostfilepathname_Create 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' "$1" "$2" "$argFilePath" "${@:4}"
    _reflect_field_Set "$this_ref" 'ArgFileSelector' "$argFileSelector"
  }
  dkrcp_arg_Get(){
    local -r this_ref="$1"
    _reflect_field_Get "$this_ref" 'ResourceFilePath' "$2"
  }
  dkrcp_arg_resource_Bind(){
    hostfilepathname_dependent_Bind "$1"
  }
#TODO: see if implementation can be replaced by dkrcp_arg_model_settings_Get
  dkrcp_arg_model_settings_Get(){
    local -r this_ref="$1"
    local -r argFileType_ref="$2"
    local -r argFilePath_ref="$3"
    local -r argFilePathExist_ref="$4"
    _reflect_field_Get "$this_ref"             \
      'ArgFileType'        "$argFileType_ref"  \
      'ArgFilePath'        "$argFilePath_ref"
    ref_simple_value_Set "$argFilePathExist_ref" 'true'
  }
  dkrcp_arg_model_Write(){
    local -r this_ref="$1"
    local -r modelPath="$2"
    local resourceFilePath
    local argFileSelector
    _reflect_field_Get "$this_ref"          \
      'ResourceFilePath' 'resourceFilePath' \
      'ArgFileSelector'  'argFileSelector'
    local -r resourceFilePath
    local -r argFileSelector
    cp -a "${resourceFilePath}${argFileSelector}" "$modelPath"
  }
  dkrcp_arg_output_Inspect(){
    local dkrcpSTDOUT
    read -r dkrcpSTDOUT
    if [ -n "$dkrcpSTDOUT" ]; then
      ScriptUnwind "$LINENO"  "Expected no output but received this response: '$dkrcpSTDOUT'."
    fi
  }
  dkrcp_arg_Destroy(){
    local -r this_ref="$1"
    hostfilepathname_dependent_Delete "$this_ref"
  }
}
dkrcp_arg_hostfilepath_hostfilepathNotExist_impl(){
  dkrcp_arg_hostfilepath_hostfilepathExist_impl
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct a host file argument that refers to
  ##    a non-existent host file resource, however, parent directories
  ##    do exit.
  ##
  ##  Inputs:
  ##    $1 - An 'empty' associative map variable.
  ##    $2 - The type of host file path:
  ##         'f' - file path resolves to a file.
  ##         'd' - file path resolves to a directory.
  ##    $3 - dkrcp host file path.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  _Create(){
    local -r this_ref="$1"
    local -r argFilePath="$3"
    _dkrcp_arg_hostfilepath_hostfilepathExist_impl_Create "$@"
    _reflect_type_Set "$this_ref" 'dkrcp_arg_hostfilepath_hostfilepathNotExist_impl'
    local resourceFilePathRoot=''
    local -r argFileRoot="$( dirname "$argFilePath" )"
    if [ -n "$argFileRoot" ]; then
      resource_File_Path_Name_Prefix "$argFileRoot" 'resourceFilePathRoot'
    fi
    local -r resourceFilePathRoot
    _reflect_field_Set "$this_ref" 'ResourceFilePathRoot' "$resourceFilePathRoot"
  }
  dkrcp_arg_resource_Bind(){
    local -r this_ref="$1"
    local resourceFilePathRoot
    _reflect_field_Get "$this_ref" 'ResourceFilePathRoot' 'resourceFilePathRoot'
    local -r resourceFilePathRoot
    if [ -n "$resourceFilePathRoot" ]; then
      mkdir -p "$resourceFilePathRoot"
    fi
  }
#TODO: see if implementation can be replaced by dkrcp_arg_model_settings_Get
  dkrcp_arg_model_settings_Get(){
    local -r this_ref="$1"
    local -r argFileType_ref="$2"
    local -r argFilePath_ref="$3"
    local -r argFilePathExist_ref="$4"
    _reflect_field_Get "$this_ref"             \
      'ArgFileType'        "$argFileType_ref"  \
      'ArgFilePath'        "$argFilePath_ref"
    ref_simple_value_Set "$argFilePathExist_ref" 'false'
  }
  dkrcp_arg_output_Inspect(){
    local -r this_ref="$1"
    local dkrcpOutput
    local resourceFilePath
    _reflect_field_Get "$this_ref" 'ResourceFilePath' 'resourceFilePath'
    if read -r dkrcpOutput; then
      ScriptUnwind "Did not expect output: '$dkrcpOutput' when writing to host file: '$resourceFilePath'."
    fi
    if ! [ -e "$resourceFilePath" ]; then
      ScriptUnwind "Missing expected output from dkrcp: '$resourceFilePath'."
    fi
    }
  dkrcp_arg_Destroy(){
    local -r this_ref="$1"
    local resourceFilePath
    local resourceFilePathRoot
    _reflect_field_Get "$this_ref"                  \
      'ResourceFilePath'     'resourceFilePath'     \
      'ResourceFilePathRoot' 'resourceFilePathRoot'
    local -r resourceFilePath
    if [ -z "$resourceFilePathRoot" ]; then resourceFilePathRoot="$resourceFilePath"; fi
    local -r resourceFilePathRoot
    file_path_safe_Remove "$resourceFilePathRoot" >/dev/null
  }
  env_clean_interface
  env_Clean(){
    dkrcp_arg_Destroy "$1"
  }
  env_check_interface
  env_Check(){
    local -r this_ref="$1"
    local resourceFilePath
    local resourceFilePathRoot
    _reflect_field_Get "$this_ref"                  \
      'ResourceFilePath'     'resourceFilePath'     \
      'ResourceFilePathRoot' 'resourceFilePathRoot'
    local -r resourceFilePath
    if [ -z "$resourceFilePathRoot" ]; then resourceFilePathRoot="$resourceFilePath"; fi
    local -r resourceFilePathRoot
    if [ -e "$resourceFilePathRoot" ]; then
      ScriptDetectNotify "host file: '$resourceFilePath', involved in testing."
    fi
  }
}
###############################################################################
dkrcp_arg_common_model_settings_Get(){
  local -r this_ref="$1"
  local -r argFileType_ref="$2"
  local -r argFilePath_ref="$3"
  local -r argFilePathExist_ref="$4"
  _reflect_field_Get "$this_ref"                \
    'ArgFileType'        "$argFileType_ref"     \
    'ArgFilePath'        "$argFilePath_ref"     \
    'ArgFilePathExist'   "$argFilePathExist_ref"
}
dkrcp_arg_image_or_container_Create(){
  local -r typeToCreate="$1"
  local -r this_ref="$2"
  local -r argFileType="$3"
  local -r argFilePath="$4"
  _reflect_type_Set "$this_ref" "$typeToCreate"
  local argFilePathExist='false'
  if [ "$5" == 'true' ]; then argFilePathExist='true'; fi
  local -r argFilePathExist
  local -r imageName="${TEST_NAME_SPACE}$6"
  _reflect_field_Set "$this_ref"           \
    'ArgFileType'      "$argFileType"      \
    'ArgFilePath'      "$argFilePath"      \
    'ArgFilePathExist' "$argFilePathExist" \
    'ImageName'        "$imageName"
}
###########################################################################
##
##  Purpose:
##    Implement interface for dkrcp arguments bound a non existent image.
##
##  Members:
##   'ArgFilePath' - The host source/destination file path for
##                        dkrcp command.
##   'ImageName'   - A file path to the resource representing
##                        the host file path.
###########################################################################
dkrcp_arg_image_no_exist_impl(){
  dkrcp_arg_interface
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct an dkrcp image name argument that
  ##    doesn't already exist as a resource.
  ##
  ##  Inputs:
  ##    $1 - An 'empty' associative map variable.
  ##    $2 - The type of image file path:
  ##         'f' - file path resolves to a file.
  ##         'd' - file path resolves to a directory.
  ##    $3 - dkrcp image file path.
  ##    $4 - file path exists
  ##    $5 - Image name.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  _Create(){
    dkrcp_arg_image_or_container_Create 'dkrcp_arg_image_no_exist_impl' "${@}"
  }
  dkrcp_arg_Get(){
    local -r this_ref="$1"
    local -r imageFilePath_ref="$2"
    local imageName
    local imageFilePathValue
    _reflect_field_Get "$this_ref"   \
      'ImageName'       'imageName'  \
      'ArgFilePath'     'imageFilePathValue'
    ref_simple_value_Set "$imageFilePath_ref" "${imageName}::${imageFilePathValue}"
  }
  dkrcp_arg_resource_Bind(){
    true
  }
  dkrcp_arg_model_settings_Get(){
    dkrcp_arg_common_model_settings_Get "${@}"
  }
  dkrcp_arg_model_Write(){
    local -r this_ref="$1"
    local -r modelPath="$2"
    local containerFilePath="$3"
    local imageName
    local imageFilePath
    _reflect_field_Get "$this_ref"      \
      'ImageName'        'imageName'    \
      'ArgFilePath'      'imageFilePath'
    local -r imageName
    local -r imageFilePath
    if [ -z "$containerFilePath" ]; then
      # acting as a SOURCE argument :: use its specified file path.
      containerFilePath="$imageFilePath"
    fi
    local -r containerFilePath
    local containerID
    image_container_Create "$imageName" 'containerID'
    local -r containerID
    if ! docker cp "$containerID:$containerFilePath" "$modelPath" >/dev/null; then
      ScriptUnwind "$LINENO" "Failure when attempting to copy: '$containerFilePath' from container: '$containerID' derived from image: '$imageName' to model path: '$modelPath'."
    fi
    if ! docker rm $containerID >/dev/null; then
      ScriptUnwind "$LINENO" "Failure while deleting container: '$containerID' derived from image: '$imageName' after constructing model."
    fi
  }
  dkrcp_arg_output_Inspect(){
    local -r this_ref="$1"
    local dkrcpSTDOUT
    read -r dkrcpSTDOUT
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
    local -r imageName
    single_quote_Encapsulate "$dkrcpSTDOUT" 'dkrcpSTDOUT'
    PipeFailCheck 'docker inspect --type=image --format='"'{{ .Id }}'"' -- '"$imageName"' | grep '"$dkrcpSTDOUT"' >/dev/null' "$LINENO" "Expected imageUUID: '$dkrcpSTDOUT' to correspond to image name: '$imageName'."
  }
  dkrcp_arg_environ_Inspect(){
    local -r this_ref="$1"
    local dkrcptOpts="$2"
    if [ -z "$dkrcptOpts" ]; then return; fi
    local -A metadataCommitValueMap
    docker_commit_metadata_cmd_value_Map "$dkrcptOpts" 'metadataCommitValueMap'
    local -r metadataCommitValueMap
    if (( ${#metadataCommitValueMap[@]} < 1 )); then return; fi
    local -A metadataCommitJsonRefMap
    docker_commit_metadata_cmd_to_jsonReference_Map 'metadataCommitJsonRefMap'
    local -r metadataCommitValueMap
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
    local -r imageName
    image_metadata_Verify "$imageName" 'metadataCommitValueMap' 'metadataCommitJsonRefMap'
  }
  dkrcp_arg_Destroy(){
    local -r this_ref="$1"
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
    local -r imageName
    container_Clean "$imageName"
    local dockerMsg
    if ! dockerMsg="$(docker rmi -- $imageName 2>&1)"; then
      if ! [[ $dockerMsg =~ ^Error.+:.could.not.find.image: ]] && ! [[ $dockerMsg =~ ^.*Error.+:.No.such.image.*$ ]]; then
        single_quote_Encapsulate "$dockerMsg" 'dockerMsg' 
        ScriptUnwind "$LINENO" "Unexpected error: '$dockerMsg', when removing image name: '$imageName'."
      fi
    fi
  }
  env_clean_interface
  env_Clean(){
    dkrcp_arg_Destroy "$1"
  }
  env_check_interface
  env_Check(){
    local -r this_ref="$1"
    container_detect_Report(){
      local containerID
      local successInd='true'
      while read -r containerID; do
        ScriptDetectNotify "container: '$containerID', associated to image: '$imageName'"
        successInd='false'
      done
      $successInd
    }
    while true; do
      local imageName
      _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
      local -r imageName
      docker ps -a | grep "$imageName" | awk '{ print $1;}' | container_detect_Report
      if [ "${PIPESTATUS[1]}" -eq '0' ]; then
        break
      fi
      local dockerMsg
      if dockerMsg="$(docker inspect --type=image -- $imageName 2>&1)"; then
        ScriptDetectNotify "image: '$imageName'."
        break
      fi
      if ! [[ $dockerMsg =~ ^.*Error:.No.such.image.*$ ]]; then
        single_quote_Encapsulate "$dockerMsg" 'dockerMsg' 
        ScriptUnwind "$LINENO" "Unexpected error: '$dockerMsg', when testing for image name: '$imageName'."
      fi
      return
    done
  }
}
dkrcp_arg_output_bad_Inspect(){
  local -r this_ref="$1"
  local dkrcpSTDOUT
  read -r dkrcpSTDOUT
  local regExpError
  _reflect_field_Get "$this_ref" 'RegExpError' 'regExpError' 
  local -r regExpError
  if ! [[ $dkrcpSTDOUT =~ $regExpError ]]; then
    ScriptUnwind "$LINENO" "Expected error message to match: '$regExpError', but dkrcp produced: '$dkrcpSTDOUT'."
  fi
}

dkrcp_arg_image_no_exist_target_bad_impl(){
  dkrcp_arg_image_no_exist_impl
  _Create(){
    dkrcp_arg_image_or_container_Create 'dkrcp_arg_image_no_exist_target_bad_impl' "${@}"
    local -r this_ref="$1"
    local -r regExpError="$6"
    _reflect_field_Set "$this_ref" 'RegExpError' "$regExpError"
  }
  dkrcp_arg_output_Inspect(){
    dkrcp_arg_output_bad_Inspect "$1"
  }
  dkrcp_arg_environ_Inspect(){
    local -r this_ref="$1"
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
    local -r imageName
    if docker inspect --type=image -- $imageName >/dev/null 2>/dev/null; then 
      ScriptUnwind "$LINENO" "Image: '$imageName' should not exist but it does."
    fi
  }
}
dkrcp_arg_image_no_exist_docker_bug_impl(){
  dkrcp_arg_image_no_exist_impl
    #  Implementation below only temporary due to docker cp bug.  Once addressed,
    #  should be able to delete this interface implementation and
    #  revert to 'dkrcp_arg_image_no_exist_impl'"
  _Create(){
    dkrcp_arg_image_or_container_Create 'dkrcp_arg_image_no_exist_docker_bug_impl' "${@}"
  }
  dkrcp_arg_output_Inspect(){
    local -r this_ref="$1"
    local dkrcpSTDOUT
    read -r dkrcpSTDOUT
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
    local -r imageName
    if docker images --no-trunc -- $imageName | grep "$dkrcpSTDOUT" >/dev/null; then
      ScriptUnwind "$LINENO" "Docker fixed cp bug replace 'dkrcp_arg_image_no_exist_docker_bug_impl' with 'dkrcp_arg_image_no_exist_impl'"
    fi
    if ! [[ $dkrcpSTDOUT =~ .*no.such.directory ]]; then
      single_quote_Encapsulate "$dkrcpSTDOUT" 'dkrcpSTDOUT'
      ScriptUnwind "$LINENO" "Expected existing docker cp bug to generate: 'no such directory' message but it produced: '$dkrcpSTDOUT'."
    fi
  }
}
dkrcp_arg_image_exist_impl(){
  dkrcp_arg_image_no_exist_impl
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct an dkrcp image name argument that
  ##    is derived from an image created by the test itself.
  ##
  ##  Inputs:
  ##    $1 - An 'empty' associative map variable.
  ##    $2 - The type of image file path:
  ##         'f' - file path resolves to a file.
  ##         'd' - file path resolves to a directory.
  ##    $3 - dkrcp image file path.
  ##    $4 - file path exists
  ##    $5 - Image name.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  _Create(){
    dkrcp_arg_image_or_container_Create 'dkrcp_arg_image_exist_impl' "${@}"
  }
  dkrcp_arg_Destroy(){
    # derived from a non-existent image
    true
  }
  env_clean_interface
  env_Clean(){
    # derived from a non-existent image
    true
  }
  env_check_interface
  env_Check(){
    # derived from a non-existent image
    true
  }
}
dkrcp_arg_image_UUID_exist_impl(){
  dkrcp_arg_image_no_exist_impl
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct an dkrcp image UUID argument that
  ##    is derived from an image created by the test itself.
  ##
  ##  Inputs:
  ##    $1 - An 'empty' associative map variable.
  ##    $2 - The type of image file path:
  ##         'f' - file path resolves to a file.
  ##         'd' - file path resolves to a directory.
  ##    $3 - dkrcp image file path.
  ##    $4 - file path exists
  ##    $5 - Base image name.
  ##    $6 - UUID length.  Optional iff source argument, otherwise
  ##         must be '' or a number. 
  ##    $7 - Derived image name.  Optional iff source argument,
  ##         otherwise required.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  _Create(){
    local -r this_ref="$1"
    local UUIDsize="$6"
    local imageName="$7"
    if [ -z "$UUIDsize"  ]; then UUIDsize='64'; fi
    if [ -n "$imageName" ]; then imageName="${TEST_NAME_SPACE}$imageName"; fi
    local -r UUIDsize
    dkrcp_arg_image_or_container_Create 'dkrcp_arg_image_UUID_exist_impl' "${@}"
    local baseImageName
    _reflect_field_Get "$this_ref" 'ImageName' 'baseImageName'
    local -r baseImageName
    if [ -z "$imageName" ]; then
      # acting as a source argument.  In this instance basename=derived image name
      # aligns image semantics so majority of dkrcp_arg_image_no_exist_impl
      # methods can be reused.
      imageName="$baseImageName";
    fi
    _reflect_field_Set "$this_ref"       \
       'UUIDsize'      "$UUIDsize"       \
       'ImageName'     "$imageName"      \
       'BaseImageName' "$baseImageName"
  }
  dkrcp_arg_Get(){
    local -r this_ref="$1"
    local -r imageFilePath_ref="$2"
    local baseImageName
    local imageFilePathValue
    local UUIDsize
    _reflect_field_Get "$this_ref"   \
      'BaseImageName'   'baseImageName'  \
      'UUIDsize'        'UUIDsize'   \
      'ArgFilePath'     'imageFilePathValue'
    local -r baseImageName
    local -r imageFilePathValue
    local -r UUIDsize
    local imageUUID
    if ! imageUUID="$(docker inspect --type=image --format='{{ .Id }}' -- "$baseImageName")"; then
      ScriptUnwind "$LINENO" "Failed to obtain UUID for image: '$baseImageName'."
    fi
    local -r SHA_PREFIX='sha256:'
    local -r imageUUID
    local -i shaPrefixLen=0
    if [ "${imageUUID:0:${#SHA_PREFIX}}" == "$SHA_PREFIX" ]; then
      shaPrefixLen="${#SHA_PREFIX}"
    fi
    ref_simple_value_Set "$imageFilePath_ref" "${imageUUID:0:$shaPrefixLen + $UUIDsize}::${imageFilePathValue}"
  }
  dkrcp_arg_output_Inspect(){
    local -r this_ref="$1"
    local dkrcpSTDOUT
    read -r dkrcpSTDOUT
    local baseImageName
    local imageName
    _reflect_field_Get "$this_ref"      \
       'BaseImageName' 'baseImageName'  \
       'ImageName'     'imageName'
    local -r baseImageName
    local -r imageName
    local -r baseImageUUID="$(docker inspect --type=image --format='{{ .Id }}' -- "$baseImageName")"
    PipeFailCheck 'docker history -q --no-trunc -- '"'$dkrcpSTDOUT'"' | grep '"'$baseImageUUID'"' >/dev/null' "$LINENO" "Expected imageUUID: '$dkrcpSTDOUT' to be derived from image name: '$baseImageName'."
    docker tag "$dkrcpSTDOUT" "$imageName"
  }
}
###########################################################################
##
##  Purpose:
##    Implement interface for dkrcp arguments bound a remote image.
##
###########################################################################
dkrcp_arg_image_remote(){
  dkrcp_arg_image_no_exist_impl
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct an dkrcp image name argument that
  ##    that references a remote image.
  ##
  ##  Inputs:
  ##    $1 - An 'empty' associative map variable.
  ##    $2 - The type of image file path:
  ##         'f' - file path resolves to a file.
  ##         'd' - file path resolves to a directory.
  ##    $3 - dkrcp image file path.
  ##    $4 - file path exists
  ##    $5 - Image name.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  _Create(){
    # temporarily disable test name space to prevent corruption of remote
    # image name.
    local -r TEST_NAME_SPACE=''
    dkrcp_arg_image_or_container_Create 'dkrcp_arg_image_remote' "${@}"
    local imageName
    _reflect_field_Get "$1"         \
    'ImageName'        'imageName'
  }
}
###########################################################################
##
##  Purpose:
##    Implement interface for dkrcp arguments bound a container.
##
###########################################################################
dkrcp_arg_container_exist_impl(){
  dkrcp_arg_interface
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct an dkrcp container argument that
  ##    doesn't already exist as a resource.
  ##
  ##  Inputs:
  ##    $1 - An 'empty' associative map variable.
  ##    $2 - The type of image file path:
  ##         'f' - file path resolves to a file.
  ##         'd' - file path resolves to a directory.
  ##    $3 - dkrcp image file path.
  ##    $4 - file path exists
  ##    $5 - Image name.
  ##
  ##  Outputs:
  ##    $1 - A constructed this pointer.
  ##
  ###########################################################################
  _Create(){
    dkrcp_arg_image_or_container_Create 'dkrcp_arg_container_exist_impl' "${@}"
  }
  dkrcp_arg_resource_Bind(){
    local -r this_ref="$1"
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
    local -r imageName
    local containerID
    image_container_Create "$imageName" 'containerID'
    local -r containerID
    _reflect_field_Set "$this_ref" 'ContainerID' "$containerID"
  }
  dkrcp_arg_Get(){
    local -r this_ref="$1"
    local -r containerFilePath_ref="$2"
    local containerID
    _reflect_field_Get "$this_ref" 'ContainerID' 'containerID'
    local -r containerID
    local containerFilePath
    _reflect_field_Get "$this_ref" 'ArgFilePath' 'containerFilePath'
    local -r containerFilePath
    ref_simple_value_Set "$containerFilePath_ref" "${containerID}:${containerFilePath}"
  }
  dkrcp_arg_model_settings_Get(){
    dkrcp_arg_common_model_settings_Get "${@}"
  }
  dkrcp_arg_model_Write(){
    local -r this_ref="$1"
    local -r modelPath="$2"
    local containerFilePath="$3"
    local containerID
    if [ -z "$containerFilePath" ]; then
      # acting as a source argument
      _reflect_field_Get "$this_ref"     \
        'ContainerID'     'containerID'  \
        'ArgFilePath'     'containerFilePath'
    else
      # acting as a target argument
      _reflect_field_Get "$this_ref"     \
        'ContainerID'     'containerID'
    fi
    local -r containerID
    local -r containerFilePath
    if ! docker cp "$containerID:$containerFilePath" "$modelPath" >/dev/null; then
      ScriptUnwind "$LINENO" "Failure when attempting to copy: '$containerFilePath' from container: '$containerID' to model path: '$modelPath'."
    fi
  }
  dkrcp_arg_output_Inspect(){
    local dkrcp_STDERR_STDOUT=''
    read -r dkrcp_STDERR_STDOUT
    if [ -n "$dkrcp_STDERR_STDOUT" ]; then
      single_quote_Encapsulate "$dkrcpSTDOUT" 'dkrcpSTDOUT'
      ScriptUnwind "$LINENO"  "Unexpected response: '$dkrcp_STDERR_STDOUT' from dkrcp.  Expected no output."
    fi
  }
  dkrcp_arg_Destroy(){
    local -r this_ref="$1"
    local containerID
    _reflect_field_Get "$this_ref" 'ContainerID' 'containerID'
    local -r containerID
    if [ -z "$containerID"]; then return; fi
    # bind was performed and the container id exists :: delete it.
    if ! docker rm -f "$containerID" >/dev/null; then
      ScriptUnwind "$LINENO" "Failure when attempting to remove container: '$containerID'."
    fi
  }
  env_clean_interface
  env_Clean(){
    dkrcp_arg_Destroy "$1"
  }
  env_check_interface
  env_Check(){
    # derived from an image constructed by the same test, therefore, when this
    # image is removed so too will this container.
    true
  }
}
dkrcp_arg_container_exist_name_impl(){
  dkrcp_arg_container_exist_impl
  _Create(){
    dkrcp_arg_image_or_container_Create 'dkrcp_arg_container_exist_name_impl' "${@}"
  }
  dkrcp_arg_Get(){
    local -r this_ref="$1"
    local -r containerFilePath_ref="$2"
    local containerID
    local containerFilePath
    _reflect_field_Get "$this_ref"  \
      'ContainerID' 'containerID'   \
      'ArgFilePath' 'containerFilePath'
    local -r containerID
    local -r containerFilePath
    local containerName="$( docker inspect --type=container --format='{{.Name}}' -- $containerID )"
    # docker container name is prefixed with a '/' when saved :: remove it.
    local -r containerName="${containerName:1}"
    ref_simple_value_Set "$containerFilePath_ref" "${containerName}:${containerFilePath}"
  }
}
###########################################################################
##
##  Purpose:
##    Base create common to all derived tar stream interfaces.
##
###########################################################################
_dkrcp_arg_stream_common_Create(){
  local -r typeName="$1"
  local -r this_ref="$2"
  local -r argFilePath="$3"
  _reflect_type_Set "$this_ref" "$typeName"
  local resourceFilePath
  resource_File_Path_Name_Prefix '' 'resourceFilePath'
  _reflect_field_Set "$this_ref"           \
    'ResourceFilePath' "$resourceFilePath" \
    'ArgFilePath'      "$argFilePath"
}
###########################################################################
##
##  Purpose:
##    Implement interface for dkrcp arguments bound to tar stream.
##
###########################################################################
dkrcp_arg_stream_impl(){
  dkrcp_arg_interface
  _Create(){
    _dkrcp_arg_stream_common_Create 'dkrcp_arg_stream_impl' "$@"
  }
  dkrcp_arg_Get(){
    ref_simple_value_Set "$2" '-'
  }
  dkrcp_arg_resource_Bind(){
    #  bind occurs to lower level resources and there's nothing
    #  at this level to bind.
    true
  }
  dkrcp_arg_model_settings_Get(){
    local -r this_ref="$1"
    local -r argFileType_ref="$2"
    local -r argFilePath_ref="$3"
    local -r argFilePathExist_ref="$4"
    ref_simple_value_Set "$argFileType_ref"      'd'
    _reflect_field_Get "$this_ref"  'ArgFilePath' "$argFilePath_ref"
    ref_simple_value_Set "$argFilePathExist_ref" 'true'
  }
  dkrcp_arg_prequel_cmd_Gen(){
    local -r this_ref="$1"
    local resourceFilePath
    local argFilePath
    _reflect_field_Get "$this_ref"          \
      'ResourceFilePath' 'resourceFilePath' \
      'ArgFilePath'      'argFilePath'
    local -r resourceFilePath
    local -r argFilePath
    ref_simple_value_Set "$2" 'tar -C '"'${resourceFilePath}'"' -cf- '"'${argFilePath}'"
  }
  dkrcp_arg_model_Write(){
    local -r this_ref="$1"
    local -r modelPath="$2"
    local tarCommand
    dkrcp_arg_prequel_cmd_Gen "$this_ref" 'tarCommand'
    PipeFailCheck "$tarCommand"' | tar -C '"'$modelPath'"' -xf-' "$LINENO" "Failure when writing stream to model path:'$ModelPath'."
  }
  dkrcp_arg_Destroy(){
    true
  }
  env_clean_interface
  env_Clean(){
    # derived from host file constructed by the same test and 
    # since it streams, it doesn't allocate resources that
    # need to be released.
    true
  }
  env_check_interface
  env_Check(){
    # derived from host file constructed by the same test, therefore,
    # this object will perform this method.
    true
  }
}
dkrcp_arg_stream_output_impl(){
  dkrcp_arg_stream_impl
  _Create(){
    _dkrcp_arg_stream_common_Create 'dkrcp_arg_stream_output_impl' "$@"
  }
  dkrcp_arg_output_Inspect(){
    local -r this_ref="$1"
    local resourceFilePath
    _reflect_field_Get "$this_ref" 'ResourceFilePath' 'resourceFilePath'
    local -r resourceFilePath
    local argFilePathType
    local argFilePath
    local argFilePathExist
    dkrcp_arg_model_settings_Get "$this_ref" 'argFilePathType' 'argFilePath' 'argFilePathExist'
    local -r argFilePath
    local -r tarStreamPath="${resourceFilePath}${argFilePath}"
    if ! mkdir -p "$tarStreamPath"; then
      ScriptUnwind "$LINENO" "Failed to create resource path for tar stream:'$tarStreamPath'."
    fi
    if ! tar -C "$tarStreamPath" -xf- ; then
      ScriptUnwind "$LINENO" "Failure when writing stream to resource path:'$tarStreamPath'."
    fi
  }
  dkrcp_arg_model_Write(){
    local -r this_ref="$1"
    local -r modelPath="$2"
    local resourceFilePath
    _reflect_field_Get "$this_ref" 'ResourceFilePath' 'resourceFilePath'
    local -r resourceFilePath
    local argFilePathType
    local argFilePath
    local argFilePathExist
    dkrcp_arg_model_settings_Get "$this_ref" 'argFilePathType' 'argFilePath' 'argFilePathExist'
    local -r argFilePath
    local -r tarStreamPath="${resourceFilePath}${argFilePath}/."
    if ! cp -a "$tarStreamPath" "$modelPath"; then
       ScriptUnwind "$LINENO" "Failure when writing saved stream:'$tarStreamPath' to model path:'$ModelPath'."
    fi
  }
}
###########################################################################
##
##  Purpose:
##    Implement interface for dkrcp arguments bound to tar stream as 
##    a failing TARGET.
##  
###########################################################################
dkrcp_arg_stream_bad_impl(){
  dkrcp_arg_stream_impl
  _Create(){
    local -r this_ref="$1"
    local regExpError="$3"
    _dkrcp_arg_stream_common_Create 'dkrcp_arg_stream_bad_impl' "$@"
    _reflect_field_Set "$this_ref" 'RegExpError' "$regExpError"
  }
  dkrcp_arg_output_Inspect(){
     dkrcp_arg_output_bad_Inspect "$1"
  }
}
###############################################################################
##
##  Purpose:
##    A dkrcp test may actually rely on the execution of one or more other
##    dkrcp tests to properly create its environment.  In particular, the dkrcp target argument
##    of one test may serve as the input for another test.  For example,
##    the execution of an initial dkrcp test may create an image, as defined
##    by its target argument, that is then used by a subsequent test to create
##    a new container derived from this image because it presents the
##    initial state needed by this subsequent test.  To accommodate
##    this situation, an abstraction named 'test element' was introduced
##    to support the recursive definition of a test.  However, for simple
##    (elemental) tests, tests whose input/source arguments aren't
##    produced by executing dkrcp, only one instance of a test element exists.
##
##    In addition to the test element abstraction, its encoding relies
##    on three other important ones:
##     1.  object - A entity that implements an interface.  See object_Context.
##     2.  dkrcp argument - An object implementing dkrcp_arg_interface.
##     3.  audit model - An obect implementing audit_model_impl.
##
##    The interface defined below identifies the function overrides necessary
##    to adapt a test for execution by test_element_impl.
##
###############################################################################
test_element_interface(){
  ###############################################################################
  ##
  ##  Purpose:
  ##    Provide a serialized definition of one or more objects that are members
  ##    of the test_element_impl.  The serialize definition consists of 
  ##    attributes enclosed in single quotes where definitions are delimited
  ##    by newline.  All member definitions begin with the following attributes:
  ##    '<ObjectName>' - Member name assigned to object
  ##    '<ObjectTypeConcrete>' - The concrete interface/obejct type that
  ##         implements the desired abstract interface.
  ##    In addition to these required positional attributes other property
  ##    values required by the interface's constructor can be specified.  These
  ##    property values must also be enclosed in single quotes and be separated
  ##    by at least a single space.
  ##
  ##  Inputs:
  ##    None
  ##
  ##  Outputs
  ##    STDOUT - Streams object definitions seperated by new line.
  ##
  ###############################################################################
  test_element_member_Def(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ###############################################################################
  ##
  ##  Purpose:
  ##    Lists zero or more tests that the current one relies on to produce its
  ##    environment.  If at least one prerequisite exists, the current test name
  ##    must appear as the last element.
  ##
  ##  Outputs:
  ##    When prerequisite(s) exist:
  ##      Single quoted encapsulated test names must be written to STDOUT in
  ##      test dependency order: the independent test appears first while the
  ##      most dependent one, the current one, appears last.
  ##
  ###############################################################################
  test_element_prequisite_test_Def(){
    true
  }
  ###############################################################################
  ##
  ##  Purpose:
  ##    Categorizes the arguments for a test element as either being one
  ##    or more dkrcp source argument(s), a target one. or a variable that these
  ##    (source/target) arguments depend on.  Source arguments
  ##    names are maintained in an array called testSourceArgList, the target 
  ##    argument is maintained in a variable named testTargetArg_ref, while
  ##    testDependArgList array manages all the other variables.
  ##
  ##  Inputs:
  ##    testSourceArgList - defined by function that calls this one.
  ##    testTargetArg_ref -           ""
  ##    testDependArgList -           "" 
  ##
  ##  Outputs:
  ##    testSourceArgList - updated to reflect list of source
  ##        dkrcp argument object names.
  ##    testTargetArg_ref - update to reflect the dkrcp target
  ##        argument name.
  ##    testDependArgList - updated to reflect variables needed to define
  ##        testSourceArgList & testTargetArg_ref.
  ##
  ###############################################################################
  test_element_args_Catgry(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ###############################################################################
  ##
  ##  Purpose:
  ##    Defines dkrcp command line options to include when its executed.
  ##
  ##  Inputs:
  ##    $1  -  Variable name to receive a string of space separated options.
  ##
  ##  Outputs:
  ##    $1  -  Updated to reflect a string of zero or more options.
  ##
  ###############################################################################
  test_element_cmd_options_Get(){
    # default implementation does not produce any options.
    ref_simple_value_Set "$1" ''
  } 
}
###############################################################################
##
##  Purpose:
##    Defines The the common implementation for all test element types.
##
##  Note:
##    A test may rely on the execution of another test (recursive definition)
##    to create its proper environment.
##
###############################################################################
test_element_impl(){
  #############################################################################
  ##
  ##  Purpose:
  ##    See: env_check_interface: env_Clean 
  ##
  ###############################################################################
  test_element_env_Clean(){
    test_env_Clean(){
      object_list_Iterate  'AtEndNotify' 'env_Clean'
    }
    _test_element_prereq_Iter 'test_env_Clean'
  }
  #############################################################################
  ##
  ##  Purpose:
  ##    See: env_check_interface: env_Check 
  ##
  ###############################################################################
  test_element_env_Check(){
    test_env_Check(){
      object_list_Iterate  'AtEndNotify' 'env_Check'
    }
    _test_element_prereq_Iter 'test_env_Check'
  }
  #############################################################################
  ##
  ##  Purpose:
  ##    Execute the defined test.  See comments associated to
  ##    test_element_interface.
  ##
  ##  Outputs:
  ##    When successful: Nothing, including expected failure behavior.
  ##    When error (unexpected behavior) unwind & send message to STDERR.
  ##
  ###############################################################################
  test_element_Run(){
    _test_element_prereq_Iter '_test_element_Run'
  }
  #############################################################################
  ##
  ##  Purpose:
  ##    Execute the identically named method for each prerequisite test matching
  ##    the one called for the current test.  Each test is executed within 
  ##    the inherited object_Context of every prerequisite (recursion),
  ##    permitting the current test to access the inherited variables as long
  ##    as the variable names aren't overridden by the currently running test.
  ##
  ##    If the prerequisite list is empty, then this function simply runs the
  ##    current test's method.
  ##
  ##  Inputs:
  ##    test_element_prequisite_test_Def - Override this function to provide the
  ##         list of prerequisite test names.  If there are none, the function
  ##         should simply return 'true'
  ##
  ###############################################################################
  _test_element_prereq_Iter(){
    local funcName="$1"
    local funcChain="$funcName"
    local objectContextFun="object_Context test_element_member_Def"
    local buildFirstCall='true'
    local testInterfaceImplName
    while read -r testInterfaceImplName; do
      eval set -- "$testInterfaceImplName"
      if $buildFirstCall; then
        buildFirstCall='false'
        objectContextFun="$1 && ${objectContextFun}"
        continue
      fi
      funcChain+=" && $1 && object_Context test_element_member_Def $funcName"
    done < <(test_element_prequisite_test_Def)
    eval $objectContextFun \"\$funcChain\"
  }
  ###############################################################################
  ##
  ##  Purpose:
  ##    A private method called to run a test.
  ##
  ###############################################################################
  _test_element_Run(){
    local -a testSourceArgList=()
    local -a testDependArgList=()
    local testTargetArg_ref=''
    ###############################################################################
    ##
    ##  Purpose:
    ##    A private method that iterates through all dkrcp source arguments
    ##    calling a provided function that expects the source argument as its
    ##    first parameter.
    ##
    ##  Inputs:
    ##    $1 - name of function to call
    ##    $2 - N - zero or more function arguments to forward to this function
    ##
    ###############################################################################
    _test_element_arg_source_Iter(){
      local -r funcName="$1"
      local argSource_ref
      local ixSource
      for (( ixSource=0; ixSource < ${#testSourceArgList[@]}; ixSource++ )); do
        argSource_ref="${testSourceArgList[ixSource]}"
        reflect_type_Active "$argSource_ref"
        $funcName "$argSource_ref" "${@:2}"
      done
    }
    ###############################################################################
    ##
    ##  Purpose:
    ##    A private method that iterates through all dkrcp dependent resources
    ##    calling a provided function that expects the source argument as its
    ##    first parameter.  A dependent resource is one required by either the
    ##    source or target arguments, like the files of a parent directory, 
    ##    needed to completely define the source or target argument.
    ##
    ##  Inputs:
    ##    $1 - name of function to call
    ##    $2 - N - zero or more function arguments to forward to this function
    ##
    ###############################################################################
    _test_element_dependent_resource_Iter(){
      local -r funcName="$1"
      local depend_ref
      local ixDepend
      for (( ixDepend=0; ixDepend < ${#testDependArgList[@]}; ixDepend++ )); do
        depend_ref="${testDependArgList[ixDepend]}"
        reflect_type_Active "$depend_ref"
        $funcName "$depend_ref" "${@:2}"
      done
    }
    ###############################################################################
    ##
    ##  Purpose:
    ##    Create the dkrcp command and execute it.  Creating the command requires:
    ##      > generating its argument list,
    ##      > generating any prequel function to feed dkrcp STDIN when necessary,
    ##      > capturing its STDOUT & STDERR to affirm its expected behavior
    ##
    ###############################################################################
    _dkrcp_Run(){
      local dkrcpSourcArgs=''
      local dkrcpPrequelCmdStream='true'
      ###############################################################################
      ##
      ##  Purpose:
      ##    Create the dkrcp source argument list by concatenating object references.
      ##
      ##  Inputs:
      ##    $1 - This pointer that encodes an implementation of dkrcp_arg_interface.
      ##
      ###############################################################################
      _dkrcp_source_args_Concat(){
        local dkrcpSourceArgValue
        dkrcp_arg_Get "$1" 'dkrcpSourceArgValue'
        dkrcpSourcArgs+="'$dkrcpSourceArgValue' "
      }
      ###############################################################################
      ##
      ##  Purpose:
      ##     Source arguments can contribute code snippets to the dkrcp pipeline
      ##     which executes dkrcp.  These code snippets form the body of the function
      ##     executed before dkrcp whose STDOUT is piped to dkrcp's STDIN.  For
      ##     example, the source argument '-' that defines a STDIN tar stream would
      ##     generate the commands necessary to produce the stream. 
      ##
      ###############################################################################
      _dkrcp_source_args_Prequel_Gen(){
        local dkrcpPrequelCmd
        dkrcp_arg_prequel_cmd_Gen "$1" 'dkrcpPrequelCmd'
        if [ -n "$dkrcpPrequelCmd" ]; then
          dkrcpPrequelCmdStream+=" && $dkrcpPrequelCmd"
        fi
      }
      ###############################################################################
      _test_element_arg_source_Iter _dkrcp_source_args_Concat
      local -r dkrcpSourcArgs
      _test_element_arg_source_Iter _dkrcp_source_args_Prequel_Gen
      local -r dkrcpPrequelCmdStream
      local dkrcpCmdOptions
      test_element_cmd_options_Get 'dkrcpCmdOptions'
      local -r dkrcpCmdOptions
      reflect_type_Active "$testTargetArg_ref"
      local dkrcpTargetArg
      dkrcp_arg_Get "$testTargetArg_ref" 'dkrcpTargetArg' 
      local -r dkrcpTargetArg
      #ScriptDebug "$LINENO" " dkrcp  $dkrcpCmdOptions \-\- '$dkrcpSourcArgs' '$dkrcpTargetArg' "
      eval "$dkrcpPrequelCmdStream" | eval dkrcp.sh $dkrcpCmdOptions \-\- "$dkrcpSourcArgs" "$dkrcpTargetArg" \2\>\&1 | dkrcp_arg_output_Inspect "$testTargetArg_ref"
      local -r dkrcpRunStatus="${PIPESTATUS[@]}"
      if ! [[ $dkrcpRunStatus =~ ^0.[0-9]+.0 ]]; then
        # output inspection detected an unexpected problem terminate testing
        exit 1
      fi
      if ! dkrcp_arg_environ_Inspect "$testTargetArg_ref" "$dkrcpCmdOptions"; then
        # environment inspection detected an unexpected problem - terminate testing
        exit 1
      fi
      if ! [[ $dkrcpRunStatus =~ ^..0.. ]]; then
        # dkrcp command indicated problem with command.  However the output inspector
        # indicated it was an expected outcome.
        false
      fi
    }
    ###############################################################################
    ##
    ##  Purpose:
    ##    Create the expected model by simulating dkrcp commands.
    ##
    ###############################################################################
    _test_element_model_expected_Create(){
      local argFilePathType
      local argFilePath
      local argFilePathExist
      _test_element_model_target_filepath_Calculate 'argFilePathType' 'argFilePath' 'argFilePathExist'
      local -r argFilePathType
      local -r argFilePath
      local -r argFilePathExist
      reflect_type_Active 'modelExpected'
      audit_model_path_write_Configure 'modelExpected' "$argFilePathType" "$argFilePath" "$argFilePathExist"
      local modelFilePath
      audit_model_path_write_Get 'modelExpected' 'modelFilePath'
      local -r modelFilePath
      _test_element_arg_source_Iter dkrcp_arg_model_Write "$modelFilePath"
    }
    ###############################################################################
    ##
    ##  Purpose:
    ##    Create the result model by copying the result from the target into the
    ##    result model directory.
    ##
    ###############################################################################
    _test_element_model_result_Create(){
      local argFilePathType
      local argFilePath
      local argFilePathExist
      _test_element_model_target_filepath_Calculate 'argFilePathType' 'argFilePath' 'argFilePathExist'
      local -r argFilePathType
      local -r argFilePath
      local -r argFilePathExist
      #ScriptDebug "$LINENO" "argFilePath: '$argFilePath'"
      reflect_type_Active 'modelResult'
      # on successful cps the target exists and becomes the source.  Using this knowledge, create
      # a model target path so it creates the last directory and populates it with the content
      # from the source.
      audit_model_path_write_Configure 'modelResult' "$argFilePathType" "$argFilePath" 'false'
      local modelFilePath
      audit_model_path_write_Get 'modelResult' 'modelFilePath'
      local -r modelFilePath
      reflect_type_Active "$testTargetArg_ref"
      dkrcp_arg_model_Write "$testTargetArg_ref" "$modelFilePath" "$argFilePath"
    }
    _test_element_model_target_filepath_Calculate(){
      local -r argFilePathType_ref="$1"
      local -r argFilePath_ref="$2"
      local -r argFilePathExist_ref="$3"
      reflect_type_Active "$testTargetArg_ref"
      dkrcp_arg_model_settings_Get "$testTargetArg_ref" "$argFilePathType_ref" "$argFilePath_ref" "$argFilePathExist_ref"
      local argFilePath_lcl
      eval argFilePath_lcl\=\"\$$argFilePath_ref\"
      while  [ -z "$argFilePath_lcl" ]; do
        # TARGET wasn't specified
        if (( ${#testSourceArgList[@]} > 1 )); then
          # multi-source :: the only target in this situation is root.
          ref_simple_value_Set "$argFilePathType_ref"  'd'
          ref_simple_value_Set "$argFilePath_ref"      '/'
          ref_simple_value_Set "$argFilePathExist_ref" 'true'
          break
        fi
        if (( ${#testSourceArgList[@]} != 1 )); then
          ScriptUnwind "$LINENO" "Should always have at least one SOURCE argument."
        fi
        # TARGET wasn't specified and single target :: assumes SOURCE filespec as TARGET.
        local -r testSourceArg_ref="${testSourceArgList[0]}"
        reflect_type_Active "$testSourceArg_ref"
        dkrcp_arg_model_settings_Get "$testSourceArg_ref" "$argFilePathType_ref" "$argFilePath_ref" "$argFilePathExist_ref"
        # ScriptDebug "$LINENO" "here" 
        break
      done
    }
    ###############################################################################
    ##
    ##  Purpose:
    ##    Compare the expected model to the result model.  Requires both models
    ##    to be created before calling this method.
    ##
    ###############################################################################
    _test_element_models_Compare(){
      reflect_type_Active 'modelResult'
      local modelFilePathResult
      audit_model_root_path_Get 'modelResult' 'modelFilePathResult'
      local -r modelFilePathResult
      reflect_type_Active 'modelExpected'
      local modelFilePathExpected
      audit_model_root_path_Get 'modelExpected' 'modelFilePathExpected'
      local -r modelFilePathExpected
      if ! diff -qr "$modelFilePathExpected" "$modelFilePathResult"; then 
        ScriptUnwind "$LINENO" "Unexpected differences between expected file model: '$modelFilePathExpected' and resultant model: '$modelFilePathResult'."
      fi
    }
    ###############################################################################
    # categorize member variable as dkrcp source, target, or ignore.
    test_element_args_Catgry
    # bind dkrcp source argument(s) to their resource(s).
    _test_element_arg_source_Iter dkrcp_arg_resource_Bind
    # bind supporting host source files target argument to its resource.
    _test_element_dependent_resource_Iter hostfilepathname_dependent_Bind
    # bind dkrcp target argument to its resource.
    reflect_type_Active "$testTargetArg_ref"
    dkrcp_arg_resource_Bind "$testTargetArg_ref"
    # invoke the dkrcp copy command.
    if _dkrcp_Run; then
      # since dkrcp copy was successful, compare models
      _test_element_model_expected_Create
      _test_element_model_result_Create
      _test_element_models_Compare
      #sleep 30
    fi
  }
}
###############################################################################
##
##  A test element doesn't require a this pointer. Since the implementation
##  is common to all tests, instantiate the common public implementation once.
##
###############################################################################
test_element_impl
###############################################################################
##
##  All tests below adhere to same interface, they all plugin to the testing
##  framework using the identical interface methods, therefore, define the
##  implementation of these framework methods only once.
##
###############################################################################
dkrcp_test_EnvCheck(){
  test_element_env_Check
}
dkrcp_test_Run(){
  test_element_Run
}
dkrcp_test_EnvClean(){
  test_element_env_Clean
}
##############################################################################
##
##  Section:
##    Tests definitions.
##
###############################################################################
dkrcp_test_1(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' '/a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'    'f' '/a' 'false' 'test_1' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a single host file into the image's root directory."  \
         "The host and target file paths are identical.  Outcome: new image with "         \
         "replica of host file in its root directory."
  }
}
###############################################################################
dkrcp_test_2(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'    'f' 'a' 'false' 'test_2'  "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a single host file into the image's root directory."  \
         "The host and target file names are identical.  Outcome: new image with "         \
         "replica of host file in its root directory."
  }
}
###############################################################################
dkrcp_test_3(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'    'f' ''  'false' 'test_3' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a single host file into the image's root directory."  \
         "The host file name is specified but not the target.  Outcome: new image with "   \
         "replica of host file in its root directory."
  }
}
###############################################################################
dkrcp_test_4(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'    'f' 'q' 'false' 'test_4' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a single host file into the image's root directory."     \
         "The target name differs from the source.  Outcome: new image with a file whose"   \
         "contents are identical to the host file but whose name differs located in the root."
  }
}
###############################################################################
dkrcp_test_5(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'      'imageNameTest'    'd' 'dirDoesNotExist/' 'false' 'test_5' '^.*no.such.directory' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying a single host file into a nonexistent  root directory."  \
         "Outcome: Failure target directory doesn't exist. Also, image should not exist."
  }
}
###############################################################################
dkrcp_test_6(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'     'd' 'dir_image' 'false' 'test_6' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a directory single host file into it. The target"  \
         "directory does not exist.  Outcome: New image created with target directory"  \
         "reflecting the contents of source directory."
  }
}
###############################################################################
dkrcp_test_7(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'     'd' 'dev/pts'   'true' 'test_7' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a directory single host file into it. The target"  \
         "directory exists.  Outcome: New image created with target directory"  \
         "containing the source directory."
  }
}
###############################################################################
dkrcp_test_8(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'     'd' 'dev/pts/'   'true' 'test_8' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a directory single host file into it. The target"  \
         "directory exists.  Outcome: New image created with target directory"  \
         "containing the source directory."
  }
}
###############################################################################
dkrcp_test_9(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a/.'   'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'     'd' 'dev/pts/.' 'true' 'test_9' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a directory single host file into it. The target"  \
         "directory exists.  Outcome: New image created with target directory"  \
         "containing the contents of the source directory."
  }
}
###############################################################################
dkrcp_test_10(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a/.'      'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'      'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'      'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'      'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'      'imageNameTest'     'f' 'etc/hostname' 'true' 'test_10' '^.*cannot.copy.directory' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying a host directory into a target"    \
         "file that exists.  Outcome: New image should not be created and process" \
         "should generate an error indicating you can't overwrite a an existing"   \
         "target file with a directory."
  }
}
###############################################################################
dkrcp_test_11(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'     'd' 'dev/pts'   'true' 'test_11:tagit' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image with a tag name by copying a directory into it. " \
         "The target directory already exists.  Outcome: New  tagged image " \
         "created with target directory containing the source directory."
  }
}
###############################################################################
dkrcp_test_12(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' ':dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' ':dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' ':dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' ':dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'     'd' ':dir_a'     'false' 'test_12:tagit' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a directory prefixed with a : to its"  \
         "root directory.  Test ensures delimiter of ':::' doesn't confuse" \
         "argument parser.  Outcome: Image should exist and have a colon"   \
         "prefixed directory in its root."
  }
}

###############################################################################
dkrcp_test_13(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' '/a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'f' '/a' 'false' 'test_13_source' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'                    'imageNameSource'  'f' '/a' 'true'  'test_13_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'f' '/a' 'false' 'test_13_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a single file from a pre-existing"       \
         "image into the targeted image's root directory.  The source and"    \
         "target file paths are identical.  Outcome: new image with "         \
         "replica of source file in its root directory."
  }
}
###############################################################################
dkrcp_test_14(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'f' 'a' 'false' 'test_14_source' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'                    'imageNameSource'  'f' 'a' 'true'  'test_14_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'f' 'a' 'false' 'test_14_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a single host file from a pre-existing"  \
         "image into the targeted image's root directory.  The source and"    \
         "target file paths are identical.  Outcome: new image with "         \
         "replica of source file in its root directory."
  }
}
###############################################################################
#  
#  dkrcp_test_15() - reserved until test_3 works.
#
###############################################################################
dkrcp_test_16(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'f' 'a' 'false' 'test_16_source' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'                    'imageNameSource'  'f' 'a' 'true'  'test_16_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'f' 'q' 'false' 'test_16_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a single file from a pre-existing"       \
         "image into the targeted image's root directory.  The target name"   \
         "differs from the source.  Outcome: new image with a file whose"     \
         "contents are identical to the host file but whose name differs located in the root."
  }
}
###############################################################################
dkrcp_test_17(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'f' 'a' 'false' 'test_17_source' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'                    'imageNameSource'  'f' 'a'                'true'  'test_17_source' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'      'imageNameTarget'  'd' 'dirDoesNotExist/' 'false' 'test_17_target' '^.*no.such.directory' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying a file from a pre-existing image" \
         "into a nonexistent  root directory.  Outcome: Failure - target"         \
         "directory doesn't exist. Also, image should not exist."
  }
}
###############################################################################
dkrcp_test_18(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_image' 'false' 'test_18_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'                    'imageNameSource'  'd' 'dir_image'  'true'  'test_18_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'd' 'dir_image'  'false' 'test_18_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying an existing directory from another"  \
         "image into it. The target directory does not exist."            \
         " Outcome: New image created with target directory reflecting"   \
         "the contents of source image's directory."
  }
}
###############################################################################
dkrcp_test_19(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dev/pts'   'true' 'test_19_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'                    'imageNameSource'  'd' 'dev/pts/dir_a'  'true'  'test_19_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'd' 'dev/pts'        'true'  'test_19_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying an existing directory from another"  \
         "image into it. The target directory exists."                    \
         " Outcome: New image created with target directory containing"   \
         "the source image's directory."
  }
}
###############################################################################
dkrcp_test_20(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dev/pts/'  'true' 'test_20_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'                    'imageNameSource'  'd' 'dev/pts/dir_a'  'true'  'test_20_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'd' 'dev/pts/'       'true'  'test_20_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying an existing directory from another"       \
         "image into it. The target directory exists and is terminated by / ." \
         " Outcome: New image created with target directory containing"        \
         "the source image's directory."
  }
}
###############################################################################
dkrcp_test_21(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'     'd' 'dir_a'     'false' 'test_21:tagit' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTest'
    }
    test_element_cmd_options_Get(){
      local options="--change 'EXPOSE 6767' --change 'ENV envVar=value' --change 'LABEL test_21_label=label_value'"
      options+=" --change 'USER test_21_user' --change 'ENTRYPOINT [\"executable\", \"parm1\"]'"
      options+=" --change 'ONBUILD COPY /a /b' --change  'VOLUME /var/log' --change 'WORKDIR /dev/pts/'"
      options+=" --change 'ONBUILD COPY /a /b' --change  'VOLUME /var/log' --change 'WORKDIR /dev/pts/'"
      options+=" --change 'CMD [\"param1\", \"param2\"]' "
      ref_simple_value_Set "$1" "$options"
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a directory to its root directory."          \
         "Specify all docker commit variables and ensure these variables are"     \
         "set to these values.  Outcome: Image should exist with the appropriate" \
         "docker commit option values created in its metadata"
  }
}
###############################################################################
dkrcp_test_22(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_stream_impl'                         'stream' 'a' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_a'      'f'  '/a'             'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget' 'd'  'dev/pts/'       'true'  'test_22_target' "
      echo " 'audit_model_impl'                              'modelExpected'        'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'          'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'stream' )
      testDependArgList=( 'hostFile_a' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by tar streaming a file to an existing image directory. "   \
         " Outcome: Image should exist with a single file in the targeted directory."
  }
}
###############################################################################
dkrcp_test_23(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_stream_impl'                         'stream' 'dir_a' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dev/pts/'  'true'  'test_23_target' "
      echo " 'audit_model_impl'                              'modelExpected'        'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'          'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'stream' )
      testDependArgList=(  'hostFile_dir_a' )
      testDependArgList+=( 'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by tar streaming a directory to an existing image directory. "   \
         " Outcome: Image should exist with the streamed directory in the targeted directory."
  }
}
###############################################################################
dkrcp_test_24(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_stream_impl'                         'stream' 'dir_a' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'      'imageNameTarget'   'd' 'dirDoesNotExist' 'false' 'test_24_target' '^.*must.be.a.directory' "
      echo " 'audit_model_impl'                              'modelExpected'        'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'          'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'stream' )
      testDependArgList=(  'hostFile_dir_a' )
      testDependArgList+=( 'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by tar streaming a directory to a non existent image directory. "   \
         " Outcome: Process should fail without generating an image."
  }
}
###############################################################################
dkrcp_test_25(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_25_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'f' 'dir_a/a' 'true'  'test_25_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'f' 'a'       'false' 'test_25_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying an existing file from a container into"  \
         "the image. The target directory is the image's root.  Outcome new"  \
         "image created with root containing the copied file."
  }
}
###############################################################################
dkrcp_test_26(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_26_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'f' 'dir_a/a' 'true'  'test_26_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'f' 'b'       'false' 'test_26_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying an existing file from a container into"  \
         "the image. The target file has a different name than the source."   \
         "The target directory is the image's root.  Outcome new image"       \
         "created with root containing the copied file that's been renamed."
  }
}
###############################################################################
dkrcp_test_27(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_27_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'd' 'dir_a'   'true'  'test_27_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'd' '/dir_b'  'false' 'test_27_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying an existing directory from a container into"  \
         "the image. The target directory does not exist.  Outcome new image"      \
         "created with specified target directory containing contents of"          \
         "source directory."
  }
}
###############################################################################
dkrcp_test_28(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_28_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'd' 'dir_a'      'true'  'test_28_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'd' '/dev/pts/'  'true'  'test_28_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying an existing directory from a container into"  \
         "the image. The target directory exists.  Outcome new image created with" \
         "container source directory copied to image target directory."
  }
}
###############################################################################
dkrcp_test_29(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_29_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'd' 'dir_a/.'     'true'  'test_29_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'd' '/dev/pts/'   'true'  'test_29_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying the contents of an existing directory from" \
         "a container into an image. The target directory exists.  Outcome new" \
         "image created with  container directory content copied to image"      \
         "target directory."
  }
}
###############################################################################
dkrcp_test_30(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_30_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'd' '/dir_a/.'   'true'  'test_30_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'd' '/dev/pts'   'true' 'test_30_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying the existing contents of a container's" \
          "directory into the image. The target directory exists.  Outcome"  \
          "new image with source container directory contents located in"    \
          "target directory."
  }
}
###############################################################################
dkrcp_test_31(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_31_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'     'containerSource'  'd' '/dir_a'        'true'  'test_31_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'      'imageNameTarget'  'f' 'noexist/'      'false' 'test_31_target' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying the existing contents of a"              \
         "container's directory into it. The target directory doesn't"        \
         "exist but has been designated as one using trailing '/'.  Outcome" \
         "image created and contents of the source container are copied to"   \
         "the newly created target directory."
  }
}
###############################################################################
dkrcp_test_32(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_32_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'd' '/dir_a/.'   'true'  'test_32_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'  'd' 'noexists/'  'false' 'test_32_target' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying the existing contents of a container's" \
          "directory into the image. The target directory does not exists"   \
          "it is an assumed directory due to trailing '/'.  Outcome"          \
          "new image with source container directory contents located in"    \
          "target directory."
  }
}
###############################################################################
dkrcp_test_33(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_33_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'd' '/dir_a'        'true' 'test_33_source' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'      'imageNameTarget'  'f' '/etc/hostname' 'true' 'test_33_target'  'cannot.copy.directory' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying the existing contents of a"   \
         "container's directory into the image. The target is a preexisting"  \
         "file.  Outcome image removed due to rollback initaited by failure."
  }
}
###############################################################################
dkrcp_test_34(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_34_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'd' '/dir_a'          'true' 'test_34_source' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'      'imageNameTarget'  'f' 'noexist/noexist' 'false' 'test_34_target'  'no.such.file.or.directory' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying the existing contents of a"   \
         "container's directory into the image. The target directory doesn't" \
         "exist, nor does its parent.  Outcome image removed due to rollback" \
         "initaited by failure."
  }
}
###############################################################################
dkrcp_test_35(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_35_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'd' '/dir_a/.'          'true' 'test_35_source' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'      'imageNameTarget'  'f' 'noexist/noexist' 'false' 'test_35_target'  'no.such.file.or.directory' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying the existing contents of a"   \
         "container's directory into the image. The target directory doesn't" \
         "exist, nor does its parent.  Outcome image removed due to rollback" \
         "initaited by failure."
  }
}
###############################################################################
dkrcp_test_36(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_36_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'd' '/dir_a/.'        'true' 'test_36_source' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'      'imageNameTarget'  'f' '/etc/hostname' 'true' 'test_36_target'  'cannot.copy.directory' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying the existing contents of a"   \
         "container's directory into the image. The target is a preexisting"  \
         "file.  Outcome image removed due to rollback initaited by failure."
  }
}
###############################################################################
dkrcp_test_37(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_37_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                'containerSource'  'f' '/dir_a/a'    'true' 'test_37_source' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'      'imageNameTarget'  'f' '/noexist/a'  'false' 'test_37_target'  'no.such.file.or.directory' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying the existing a container's"    \
         "file into the image. The target refers to a name that doesn't exist" \
         "nor does its parent directory.  Outcome image removed due to"        \
         "rollback initaited by failure."
  }
}
###############################################################################
dkrcp_test_38(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_38_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'     'containerSource'  'd' '/dir_a/.'   'true'  'test_38_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'      'imageNameTarget'  'd' 'noexist'    'false' 'test_38_target' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying the existing contents of a container's"  \
         "directory into the image. The target directory does not exist"      \
         " Outcome: image is created with contents of source directory"       \
         "copied into the newly created target directory."
  }
}
###############################################################################
dkrcp_test_39(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_39_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'     'containerSource'  'f' '/dir_a/a'   'true'  'test_39_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'      'imageNameTarget'  'd' '/dev/pts'   'true'  'test_39_target' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying an existing container file"  \
         "into the image. The target directory exists.  Outcome:" \
         "image is created with file created in the"              \
         "target directory."
  }
}
###############################################################################
dkrcp_test_40(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_40_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'             'containerSource'  'f' '/dir_a/a'          'true'  'test_40_source' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'   'imageNameTarget'  'd' '/noexist/noexist/' 'false' 'test_40_target' 'no.such.directory' "
      echo " 'audit_model_impl'                           'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                           'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'containerSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying an existing container file"  \
         "into the image. The target directory does not exist.  Outcome:"    \
         "failure rollsback image creation."
  }
}
###############################################################################
dkrcp_test_41(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_remote'        'imageNameSource'   'd' 'dir_a'  'true'  'whisperingchaos/dkrcp_test_test_41_remote' "
      echo " 'dkrcp_arg_image_no_exist_impl' 'imageNameTarget'   'd' 'dir_a'  'false' 'test_41_target' "
      echo " 'audit_model_impl'              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_cmd_options_Get(){
      ref_simple_value_Set "$1" '--ucpchk-reg'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a directory from a remote source image."   \
         "The target directory does not exist.  Outcome: new image constructed" \
         "with the contents of the remote image's directory copied to"          \
         "the target directory."
  }
}
###############################################################################
dkrcp_test_42(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_b'    'd' 'dir_b'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_b_d'  'f' 'dir_b/d'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_b_e'  'f' 'dir_b/e'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_b_f'  'f' 'dir_b/f'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_remote'        'imageNameTarget'   'd' 'dir_b'  'false'  'whisperingchaos/dkrcp_test_test_41_remote' "
      echo " 'audit_model_impl'              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_dir_b' )
      testDependArgList=(  'hostFile_dir_b_d' )
      testDependArgList+=( 'hostFile_dir_b_e' )
      testDependArgList+=( 'hostFile_dir_b_f' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_cmd_options_Get(){
      ref_simple_value_Set "$1" '--ucpchk-reg'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create a new local image by first pulling an existing remote image"  \
         "and then copying a host directory into it."                          \
         "The target directory does not exist.  Outcome: A new local image"    \
         "that shares the same name as the remote one but has an additional"   \
         "layer containing the contents of host file directory copied"         \
         "into the target directory."
  }
}
###############################################################################
dkrcp_test_43(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_remote'                         'imageNameSource'   'd' 'dir_a'  'true'  'whisperingchaos/dkrcp_test_test_41_remote' "
      echo " 'dkrcp_arg_image_no_exist_target_bad_impl'       'imageNameTarget'   'd' 'dir_a'  'false' 'test_43_target' '^Abort.+SOURCE.image.must.exist' "
      echo " 'audit_model_impl'              'modelExpected'  'modelexpected' "
      echo " 'audit_model_impl'              'modelResult'    'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a directory from a remote source image."   \
         "The target directory does not exist.  Outcome: new image constructed" \
         "with the contents of the remote image's directory copied to"          \
         "the target directory."
  }
}

###############################################################################
dkrcp_test_44(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_44_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_UUID_exist_impl'    'imageUUIDSource'  'f' '/dir_a/a'   'true'  'test_44_source' "
      echo " 'dkrcp_arg_image_no_exist_impl'      'imageNameTarget'  'd' '/dev/pts'   'true'  'test_44_target' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageUUIDSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a file from existing image.  The "  \
         "existing image is specified as an argument using its UUID."    \
         "The target directory exists.  Outcome: a file is created in"   \
         "the new image's target directory."
  }
}
###############################################################################
dkrcp_test_45(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_45_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_UUID_exist_impl'    'imageUUIDSource'  'f' '/dir_a/a'   'true'  'test_45_source' '12'"
      echo " 'dkrcp_arg_image_no_exist_impl'      'imageNameTarget'  'd' '/dev/pts'   'true'  'test_45_target' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageUUIDSource' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a file from existing image.  The "  \
         "existing image is specified as an argument using its UUID"     \
         "truncated to 12 characters.  The target directory exists."     \
         " Outcome: a file is created in the new image's target directory."
  }
}
###############################################################################
dkrcp_test_46(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_46_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'         'imageNameSource'  'd' 'dir_a'      'true'  'test_46_source' "
      echo " 'dkrcp_arg_image_UUID_exist_impl'    'imageUUIDTarget'  'd' '/dev/pts'   'true'  'test_46_source' '12' 'test_46_derived' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testTargetArg_ref='imageUUIDTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Update an existing image by copying a directory from itself to a"   \
         "different directory in the derived one.  The existing target"       \
         "image is specified as an argument using its UUID truncated"         \
         "to 12 characters.  The target directory exists.  Outcome: the"      \
         "source directory is created in the derived image's target directory."
  }
}
###############################################################################
dkrcp_test_47(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_47_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'     'containerSource'  'f' 'dir_a/a'   'true'  'test_47_source' "
      echo " 'dkrcp_arg_image_exist_impl'         'imageNameSource'  'd' 'dir_a'     'true'  'test_47_source' "
      echo " 'dkrcp_arg_stream_impl'              'streamSource' 'dir_b' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_b'    'd' 'dir_b'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_b_a'  'f' 'dir_b/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_b_b'  'f' 'dir_b/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_b_c'  'f' 'dir_b/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_c'    'd' 'dir_c'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_c_a'  'f' 'dir_c/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_c_b'  'f' 'dir_c/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_c_c'  'f' 'dir_c/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'      'imageNameTarget'   'd' '/dev/pts'  'true' 'test_47_target' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'imageNameSource' )
      testSourceArgList+=( 'containerSource' )
      testSourceArgList+=( 'streamSource' )
      testDependArgList=(  'hostFile_dir_b' )
      testDependArgList+=( 'hostFile_dir_b_a' )
      testDependArgList+=( 'hostFile_dir_b_b' )
      testDependArgList+=( 'hostFile_dir_b_c' )
      testSourceArgList+=( 'hostFile_dir_c' )
      testDependArgList+=( 'hostFile_dir_c_a' )
      testDependArgList+=( 'hostFile_dir_c_b' )
      testDependArgList+=( 'hostFile_dir_c_c' )
      testTargetArg_ref='imageNameTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image through multi-source argument list".  \
         "All four source types are tested: host file, image,"  \
         "container, and stream.  The target directory exists"  \
         " Outcome: All contributed file system elements are"   \
         "created in the new image's target directory."
  }
}
###############################################################################
dkrcp_test_48(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_cntSrc'   'd' 'cntSrc'    'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_cntSrc_a' 'f' 'cntSrc/a'  'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_cntSrc_b' 'f' 'cntSrc/b'  'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_cntSrc_c' 'f' 'cntSrc/c'  'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' '/sys/' 'true' 'test_48_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testSourceArgList+=( 'hostFile_cntSrc' )
      testDependArgList+=( 'hostFile_cntSrc_a' )
      testDependArgList+=( 'hostFile_cntSrc_b' )
      testDependArgList+=( 'hostFile_cntSrc_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'         'imageNameSource'  'd' '/sys/dir_a'     'true'  'test_48_source' "
      echo " 'dkrcp_arg_container_exist_impl'     'containerSource'  'd' '/sys/cntSrc'    'true'  'test_48_source' "
      echo " 'dkrcp_arg_stream_impl'              'streamSource' 'dir_b' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_b'    'd' 'dir_b'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_b_a'  'f' 'dir_b/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_b_b'  'f' 'dir_b/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_b_c'  'f' 'dir_b/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_c'    'd' 'dir_c'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_c_a'  'f' 'dir_c/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_c_b'  'f' 'dir_c/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'    'hostFile_dir_c_c'  'f' 'dir_c/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_container_exist_impl'     'containerTarget'   'd' '/dev/pts'  'true'  'test_48_source' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'imageNameSource' )
      testSourceArgList+=( 'containerSource' )
      testSourceArgList+=( 'streamSource' )
      testDependArgList=(  'hostFile_dir_b' )
      testDependArgList+=( 'hostFile_dir_b_a' )
      testDependArgList+=( 'hostFile_dir_b_b' )
      testDependArgList+=( 'hostFile_dir_b_c' )
      testSourceArgList+=( 'hostFile_dir_c' )
      testDependArgList+=( 'hostFile_dir_c_a' )
      testDependArgList+=( 'hostFile_dir_c_b' )
      testDependArgList+=( 'hostFile_dir_c_c' )
      testTargetArg_ref='containerTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Update an existing container through multi-source argument"  \
         "list. All four source types are tested: host file, image,"   \
         "container, and stream.  The target directory exists"         \
         " Outcome: All contributed file system elements are"          \
         "created in the updated container's target directory."
  }
}
###############################################################################
dkrcp_test_49(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_cntSrc'   'd' 'cntSrc'    'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_cntSrc_a' 'f' 'cntSrc/a'  'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_cntSrc_b' 'f' 'cntSrc/b'  'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_cntSrc_c' 'f' 'cntSrc/c'  'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' '/sys/' 'true' 'test_49_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testSourceArgList+=( 'hostFile_cntSrc' )
      testDependArgList+=( 'hostFile_cntSrc_a' )
      testDependArgList+=( 'hostFile_cntSrc_b' )
      testDependArgList+=( 'hostFile_cntSrc_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'         'imageNameSource'  'd' '/sys/dir_a'     'true'  'test_49_source' "
      echo " 'dkrcp_arg_container_exist_impl'     'containerSource'  'd' '/sys/cntSrc'    'true'  'test_49_source' "
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl'     'hostFileTarget'   'd'   'hostdir' 'file_content_dir_create' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'imageNameSource' )
      testSourceArgList+=( 'containerSource' )
      testTargetArg_ref='hostFileTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Update an existing host file directory using multi-source argument"  \
         "list. Only two source types are valid, image and container."         \
         "The target directory exists.  Outcome: All contributed file system"  \
         "elements are created in the target host directory."
  }
}
###############################################################################
dkrcp_test_50(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_cntSrc'   'd' 'cntSrc'    'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_cntSrc_a' 'f' 'cntSrc/a'  'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_cntSrc_b' 'f' 'cntSrc/b'  'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_cntSrc_c' 'f' 'cntSrc/c'  'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' '/sys/' 'true' 'test_50_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testSourceArgList+=( 'hostFile_cntSrc' )
      testDependArgList+=( 'hostFile_cntSrc_a' )
      testDependArgList+=( 'hostFile_cntSrc_b' )
      testDependArgList+=( 'hostFile_cntSrc_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'         'imageNameSource'  'd' '/sys/dir_a'     'true'  'test_50_source' "
      echo " 'dkrcp_arg_container_exist_impl'     'containerSource'  'd' '/sys/cntSrc'    'true'  'test_50_source' "
      echo " 'dkrcp_arg_stream_bad_impl'          'streamTarget' '/tmp' 'Error:.Target.does.not.support.more.than.one.source' "
      echo " 'audit_model_impl'                   'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                   'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'imageNameSource' )
      testSourceArgList+=( 'containerSource' )
      testTargetArg_ref='streamTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Attempt to generate a tar stream using multi-source argument"  \
         "list.  Outcome: failure as it's not currently implemented"     \
         "and should fail with specific error message."
  }
}
###############################################################################
dkrcp_test_51(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' 'dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' 'dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'     'false'  'test_51_source' "
      echo " 'audit_model_impl'                              'modelExpected'        'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'          'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList+=( 'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_image_exist_impl'      'imageNameSource' 'd'  '/dir_a' 'true' 'test_51_source' "
      echo " 'dkrcp_arg_stream_output_impl'    'streamTarget'         'streamit' "
      echo " 'hostfilepathname_dependent_impl' 'hostFile_stream' 'd'  'streamit'  'file_content_dir_create' "
      echo " 'audit_model_impl'                'modelExpected'    'modelexpected_2' "
      echo " 'audit_model_impl'                'modelResult'      'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'imageNameSource' )
      testDependArgList=( 'hostFile_stream' )
      testTargetArg_ref='streamTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Generate a tar stream from an existing image directory."   \
         " Outcome: A valid tar stream should be generated to STDOUT."
  }
}
###############################################################################
dkrcp_test_52(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' 'dir_a'  'file_content_dir_create'  "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTarget'   'd' 'dir_a'  'false' 'test_52_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_dir_a' )
      testTargetArg_ref='imageNameTarget'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_b'    'd' 'dir_b'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_b_a'  'f' 'dir_b/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_b_b'  'f' 'dir_b/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_b_c'  'f' 'dir_b/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_container_exist_name_impl'           'containerTarget'   'd' '/dir_a' 'true'  'test_52_source' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected_2' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult_2' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_b' )
      testDependArgList=(  'hostFile_dir_b_a' )
      testDependArgList+=( 'hostFile_dir_b_b' )
      testDependArgList+=( 'hostFile_dir_b_c' )
      testTargetArg_ref='containerTarget'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Update an existing container using its container name.  Copy"        \
         "a host file into an existing container target directory.  Outcome:"  \
         "container updated with host file directory."
  }
}
###############################################################################
dkrcp_test_53(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_dir_a'    'd' ':dir_a'     'file_content_dir_create'  "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_a'  'f' ':dir_a/a'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_b'  'f' ':dir_a/b'   'file_content_reflect_name' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_dir_a_c'  'f' ':dir_a/c'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_impl'                 'imageNameTest'     'd' ':dir_a'     'false' 'test_53:tagit' "
      echo " 'audit_model_impl'                              'modelExpected'     'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'       'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_dir_a' )
      testDependArgList=(  'hostFile_dir_a_a' )
      testDependArgList+=( 'hostFile_dir_a_b' )
      testDependArgList+=( 'hostFile_dir_a_c' )
      testTargetArg_ref='imageNameTest'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a directory prefixed with a : to its"  \
         "root directory.  Test ensures delimiter of ':::' doesn't confuse" \
         "argument parser.  Outcome: Image should exist and have a colon"   \
         "prefixed directory in its root."
  }
}
###############################################################################
FunctionOverrideCommandGet
source "ArgumentsMainInclude.sh";
###############################################################################
# 
# The MIT License (MIT)
# Copyright (c) 2014-2016 Richard Moyse License@Moyse.US
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
###############################################################################
#
# Docker and the Docker logo are trademarks or registered trademarks of Docker, Inc.
# in the United States and/or other countries. Docker, Inc. and other parties
# may also have trademark rights in other terms used herein.
#
###############################################################################