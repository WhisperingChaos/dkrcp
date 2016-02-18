ref_simple_value_Set(){
  eval $1=\"\$2\"
}
resource_File_Path_Name_Prefix(){
   local filePath_lcl="$1"
   if [ "${filePath_lcl:0:1}" == '/' ]; then
     filePath_lcl="${filePath_lcl:1}"
   fi
   ref_simple_value_Set "$2" "${TEST_FILE_ROOT}${filePath_lcl}"
}
file_path_safe_Remove(){
    if [[ $1 =~ ^/tmp.* ]]; then
      rm -rf "$1" >/dev/null
    else
      ScriptUnwind "$LINENO" "Danger! Danger!  A recursive rm isn't rooted in '/tmp' but here: '$1'. rm command not executed." 
    fi
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
    local imageName
    local imageFilePath
    local argFileType
    _reflect_field_Get "$this_ref"      \
      'ImageName'        'imageName'    \
      'ArgFileType'      'argFileType'  \
      'ArgFilePath'      'imageFilePath'
    local -r imageName
    local -r argFileType
    local -r imageFilePath
    local containerID
    image_container_Create "$imageName" 'containerID'
    local -r containerID
    if ! docker cp "$containerID:$imageFilePath" "$modelPath" >/dev/null; then
      ScriptUnwind "$LINENO" "Failure when attempting to copy: '$imageFilePath' from container: '$containerID' derived from image: '$imageName' to model path: '$modelPath'."
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
    PipeFailCheck 'docker inspect --type=image --format='"'{{ .Id }}'"' -- '"$imageName"' | grep '"$dkrcpSTDOUT"' >/dev/null' "$LINENO" "Expected imageUUID: '$dkrcpSTDOUT' to correspond to image name: '$imageName'."
  }
  dkrcp_arg_Destroy(){
    local -r this_ref="$1"
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
    local -r imageName
    container_Clean "$imageName"
    local dockerMsg
    if ! dockerMsg="$(docker rmi -- $imageName 2>&1)"; then
      if ! [[ $dockerMsg =~ ^Error.+:.could.not.find.image: ]] && ! [[ $dockerMsg =~ ^Error.+:.No.such.image.*$ ]]; then
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
      local -r dockerMsg
      if ! [[ $dockerMsg =~ ^Error:.No.such.image.*$ ]]; then
        ScriptUnwind "$LINENO" "Unexpected error: '$dockerMsg', when testing for image name: '$imageName'."
      fi
      return
    done
  }
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
  dkrcp_arg_environ_Inspect(){
    local -r this_ref="$1"
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName'   'imageName'
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
dkrcp_arg_container_exist_impl(){
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
  ##    $4 - Image name.
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
    local containerID
    local containerFilePath
    _reflect_field_Get "$this_ref"     \
      'ContainerID'     'containerID'  \
      'ArgFilePath'     'containerFilePath'
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
      eval "$dkrcpPrequelCmdStream" | eval dkrcp.sh $dkrcpCmdOptions "$dkrcpSourcArgs" "$dkrcpTargetArg" \2\>\&1 | dkrcp_arg_output_Inspect "$testTargetArg_ref"
      local -r dkrcpRunStatus="${PIPESTATUS[@]}"
      if ! [[ $dkrcpRunStatus =~ ^0.[0-9]+.0 ]]; then
        # output inspection detected an unexpected problem terminate testing
        exit 1
      fi
      if ! dkrcp_arg_environ_Inspect "$testTargetArg_ref"; then
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
      reflect_type_Active "$testTargetArg_ref"
      local argFilePathType
      local argFilePath
      local argFilePathExist
      dkrcp_arg_model_settings_Get "$testTargetArg_ref" 'argFilePathType' 'argFilePath' 'argFilePathExist'
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
      reflect_type_Active "$testTargetArg_ref"
      local argFilePathType
      local argFilePath
      local argFilePathExist
      dkrcp_arg_model_settings_Get "$testTargetArg_ref" 'argFilePathType' 'argFilePath' 'argFilePathExist'
      reflect_type_Active 'modelResult'
      # on successful cps the target exists and becomes the source.  Using this knowledge, create
      # a model target path so it creates the last directory and populates it with the content
      # from the source.
      audit_model_path_write_Configure 'modelResult' "$argFilePathType" "$argFilePath" 'false'
      local modelFilePath
      audit_model_path_write_Get 'modelResult' 'modelFilePath'
      local -r modelFilePath
      reflect_type_Active "$testTargetArg_ref"
      dkrcp_arg_model_Write "$testTargetArg_ref" "$modelFilePath"
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
#  Although test 3 fails due to bug in Docker cp command, it currently passes.
#  However it will fail once Docker fixes cp.
###############################################################################
dkrcp_test_3(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_a'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_image_no_exist_docker_bug_impl'      'imageNameTest'    'f' ''  'false' 'test_3' "
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
      options+=" --message 'message for test_21' --author 'author for test_21'"
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
