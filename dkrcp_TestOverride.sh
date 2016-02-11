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
    local -r targetFileType="$2
    local -r targetFilePath="$3
    local -r targetDirExist="$4"
    local modelRootPath
    audit_model_root_path_Get "$this_ref" 'modelRootPath'
    local -r modelRootPath
    dirInModel="$targetFilePath"
    if [ "$targetFileType" == 'f' ]; then
      dirInModel="$(dirname "$targetFilePath")"
    fi
    _reflect_field_Set "$this_ref" 'ModelWritePath' "${modelRootPath}${dirInModel}"
    local dirToReplicate="$dirInModel"
    if [ "$targetFileType" == 'd' ] && ! $targetDirExist; then
      dirToReplicate="$(dirname "$targetFilePath")"
    fi
    if ! mkdir -p "${modelRootPath}${dirToReplicate}" >/dev/null; then
      ScriptUnwind "$LINENO" "Replicating target directory path:'${dirToReplicate}' within model failed: '${modelRootPath}'"
    fi
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
    file_path_safe_Remove "$resourceFilePath" >/dev/null
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
##  Members:
##   'ArgFilePath'      - The host source/destination file path for
##                        dkrcp command.
##   'ResourceFilePath' - A file path to the resource representing
##                        the host file path.
###########################################################################
dkrcp_arg_hostfilepath_hostfilepathExist_impl(){
  dkrcp_arg_interface
  hostfilepathname_dependent_impl
  _Create(){
    hostfilepathname_Create 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' "$@"
  }
  dkrcp_arg_Get(){
    local -r this_ref="$1"
    _reflect_field_Get "$this_ref" 'ResourceFilePath' "$2"
  }
  dkrcp_arg_resource_Bind(){
    hostfilepathname_dependent_Bind "$1"
  }
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
    _reflect_field_Get "$this_ref" 'ResourceFilePath' 'resourceFilePath'
    local -r resourceFilePath
    cp -a "$resourceFilePath" "$modelPath"
  }
  dkrcp_arg_Destroy(){
    local -r this_ref="$1"
    local resourceFilePath
    _reflect_field_Get "$this_ref" 'ResourceFilePath' 'resourceFilePath'
    local -r resourceFilePath
    file_path_safe_Remove "$resourceFilePath" >/dev/null
  }
  env_clean_interface
  env_Clean(){
    dkrcp_arg_Destroy "$1"
  }
  env_check_interface
  env_Check(){
    hostfilepathname_dependent_Check "$1"
  }
}
dkrcp_arg_hostfilepath_hostfilepathNotExist_impl(){
  dkrcp_arg_hostfilepath_hostfilepathExist_impl
  ###########################################################################
  ##
  ##  Purpose:
  ##    Factory function to construct a host file argument that refers to
  ##    a non-existent host file resource.
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
    local -r argFileType="$2"
    local -r argFilePath="$3"
    _reflect_type_Set "$this_ref" 'dkrcp_arg_hostfilepath_hostfilepathNotExist_impl'
    local resourceFilePath
    resource_File_Path_Name_Prefix "$argFilePath" 'resourceFilePath'
    local -r resourceFilePath
    local resourceFilePathRoot=''
    local -r argFileRoot="$( dirname "$argFilePath" )"
    if [ -n "$argFileRoot" ]; then
      resource_File_Path_Name_Prefix "$argFileRoot" 'resourceFilePathRoot'
    fi
    local -r resourceFilePathRoot
    _reflect_field_Set "$this_ref"                  \
      'ArgFileType'          "$argFileType"         \
      'ArgFilePath'          "$argFilePath"         \
      'ResourceFilePath'     "$resourceFilePath"    \
      'ResourceFilePathRoot' "$resourceFilePathRoot"
    }
  dkrcp_arg_Get(){
    local -r this_ref="$1"
    _reflect_field_Get "$this_ref" 'ResourceFilePath' "$2"
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
  dkrcp_arg_model_Write(){
    local -r this_ref="$1"
    local -r modelPath="$2"
    local resourceFilePath
    _reflect_field_Get "$this_ref" 'ResourceFilePath' 'resourceFilePath'
    local -r resourceFilePath
    cp -a "$resourceFilePath" "$modelPath"
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
dkrcp_arg_Image_NoExist_impl(){
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
    local -r this_ref="$1"
    _reflect_type_Set "$this_ref" 'dkrcp_arg_Image_NoExist_impl'
    _dkrcp_arg_Image_NoExist_Create "${@}"
  }
  _dkrcp_arg_Image_NoExist_Create(){
    local -r this_ref="$1"
    local -r argFileType="$2"
    local -r argFilePath="$3"
    local -r imageName="${TEST_NAME_SPACE}$4"
    _reflect_field_Set "$this_ref"    \
      'ArgFileType' "$argFileType"    \
      'ArgFilePath' "$argFilePath"    \
      'ImageName'   "$imageName"
  }
  _dkrcp_arg_image_noexist_typename_set(){
    local -r this_ref="$1"
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
    local -r this_ref="$1"
    local -r argFileType_ref="$2"
    local -r argFilePath_ref="$3"
    local -r argFilePathExist_ref="$4"
    _reflect_field_Get "$this_ref"                \
      'ArgFileType'        "$argFileType_ref"     \
      'ArgFilePath'        "$argFilePath_ref"
    ref_simple_value_Set "$argFilePathExist_ref" 'false'
  }
  dkrcp_arg_model_Write(){
    local -r this_ref="$1"
    local -r modelPath="$2"
    local imageName
    local imageFilePath
    _reflect_field_Get "$this_ref"   \
      'ImageName'       'imageName'  \
      'ArgFilePath'     'imageFilePath'
    local -r imageName
    local -r imageFilePath
    local containerID
    image_container_Create "$imageName" 'containerID'
    local -r containerID
    if ! docker cp "$containerID:$imageFilePath" "$modelPath" >/dev/null; then
      ScripUnwind "$LINENO" "Failure when attempting to copy: '$imageFilePath' from container: '$containerID' derived from image: '$imageName' to model path: '$modelPath'."
    fi
    if ! docker rm $containerID >/dev/null; then
      ScripUnwind "$LINENO" "Failure while deleting container: '$containerID' derived from image: '$imageName' after constructing model."
    fi
  }
  dkrcp_arg_output_Inspect(){
    local -r this_ref="$1"
    local dkrcpSTDOUT
    read -r dkrcpSTDOUT
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
    local -r imageName
    PipeFailCheck 'docker inspect --type=image --format='{{ .Id }}' -- '"$imageName"' | grep '"$dkrcpSTDOUT"' >/dev/null' "$LINENO" "Expected imageUUID: '$dkrcpSTDOUT' to correspond to image name: '$imageName'."
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
dkrcp_arg_Image_NoExist_Target_bad_impl(){
  dkrcp_arg_Image_NoExist_impl
  _Create(){
    local -r this_ref="$1"
    local -r regExpError="$5"
    _reflect_type_Set "$this_ref" 'dkrcp_arg_Image_NoExist_Target_bad_impl'
    _dkrcp_arg_Image_NoExist_Create "${@}"
    _reflect_field_Set "$this_ref" 'RegExpError' "$regExpError"
  }
  dkrcp_arg_output_Inspect(){
    local -r this_ref="$1"
    local dkrcpSTDOUT
    read -r dkrcpSTDOUT
    local regExpError
    local imageName
    _reflect_field_Get "$this_ref"  \
       'RegExpError' 'regExpError'  \
       'ImageName'   'imageName'
    local -r regExpError
    local -r imageName
    if ! [[ $dkrcpSTDOUT =~ $regExpError ]]; then
      ScriptUnwind "$LINENO" "Expected error message to match: '$regExpError', but dkrcp produced: '$dkrcpSTDOUT'."
    fi
  }
}
dkrcp_arg_Image_NoExist_Docker_Bug_impl(){
  dkrcp_arg_Image_NoExist_impl
    #  Implementation below only temporary due to docker cp bug.  Once addressed,
    #  should be able to delete this interface implementation and
    #  revert to 'dkrcp_arg_Image_NoExist_impl'"
  _Create(){
    local -r this_ref="$1"
    _reflect_type_Set "$this_ref" 'dkrcp_arg_Image_NoExist_Docker_Bug_impl'
    _dkrcp_arg_Image_NoExist_Create "${@}"
  }
  dkrcp_arg_output_Inspect(){
    local -r this_ref="$1"
    local dkrcpSTDOUT
    read -r dkrcpSTDOUT
    local imageName
    _reflect_field_Get "$this_ref" 'ImageName' 'imageName'
    local -r imageName
    if docker images --no-trunc -- $imageName | grep "$dkrcpSTDOUT" >/dev/null; then
      ScriptUnwind "$LINENO" "Docker fixed cp bug replace 'dkrcp_arg_Image_NoExist_Docker_Bug_impl' with 'dkrcp_arg_Image_NoExist_impl'"
    fi
    if ! [[ $dkrcpSTDOUT =~ .*no.such.directory ]]; then 
      ScriptUnwind "$LINENO" "Expected existing docker cp bug to generate: 'no such directory' message but it produced: '$dkrcpSTDOUT'."
    fi
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
    local -r this_ref="$1"
    local -r argFileType="$2"
    local -r argFilePath="$3"
    local -r imageName="${TEST_NAME_SPACE}$4"
    _reflect_type_Set "$this_ref" 'dkrcp_arg_container_exist_impl'
    _reflect_field_Set "$this_ref"    \
      'ArgFileType' "$argFileType"    \
      'ArgFilePath' "$argFilePath"    \
      'ImageName'   "$imageName"
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
    local -r this_ref="$1"
    local -r argFileType_ref="$2"
    local -r argFilePath_ref="$3"
    local -r argFilePathExist_ref="$4"
    _reflect_field_Get "$this_ref"                \
      'ArgFileType'        "$argFileType_ref"     \
      'ArgFilePath'        "$argFilePath_ref"
    ref_simple_value_Set "$argFilePathExist_ref" 'true'
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
      ScripUnwind "$LINENO" "Failure when attempting to copy: '$containerFilePath' from container: '$containerID' to model path: '$modelPath'."
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
      ScripUnwind "$LINENO" "Failure when attempting to remove container: '$containerID'."
    fi
  }
  env_clean_interface
  env_Clean(){
    dkrcp_arg_Destroy "$1"
  }
  env_check_interface
  env_Check(){
    # derived from an image constructed by the same test.
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
  ##    or more dkrcp source argument(s) or a target one.  Source arguments
  ##    names are maintained in an array called testSourceArgList while 
  ##    the variable named testTargetArg_ref stores the target argument's name.
  ##
  ##  Inputs:
  ##    testSourceArgList - defined by function that calls this one.
  ##    testTargetArg_ref - defined by function that calls this one.
  ##
  ##  Outputs:
  ##    testSourceArgList - updated to reflect list of source
  ##        dkrcp argument object names.
  ##    testTargetArg_ref - update to reflect the dkrcp target
  ##        argument name.
  ##
  ###############################################################################
  test_element_args_Catgry(){
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
  ##    Nothing if expected environment matches actual one.  Otherwise a 
  ##    message to STDERR which terminates execution.
  ##
  ###############################################################################
  test_element_environ_Inspect(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
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
      object_list_Iterate 'env_Clean'
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
      object_list_Iterate 'env_Check'
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
      reflect_type_Active "$testTargetArg_ref"
      local dkrcpTargetArg
      dkrcp_arg_Get "$testTargetArg_ref" 'dkrcpTargetArg' 
      local -r dkrcpTargetArg
      eval "$dkrcpPrequelCmdStream" | eval dkrcp.sh "$dkrcpSourcArgs" "$dkrcpTargetArg" \2\>\&1 | dkrcp_arg_output_Inspect "$testTargetArg_ref"
      local -r dkrcpRunStatus="${PIPESTATUS[@]}"
      if ! [[ $dkrcpRunStatus =~ ^0.[0-9]+.0 ]]; then
        # output inspection detected an unexpected problem terminate testing
        exit 1
      fi
      if ! test_element_environ_Inspect; then
        # environment inspection detected an unexpected problem terminate testing
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
      audit_model_path_write_Configure 'modelResult' "$argFilePathType" "$argFilePath" "$argFilePathExist"
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
##############################################################################
##
##  Section:
##    Tests definitions.
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



dkrcp_test_1(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFileA'       'f' '/a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_Image_NoExist_impl'                  'imageNameTest1'  'f' '/a' 'test_1' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFileA' )
      testTargetArg_ref='imageNameTest1'
    }
    test_element_environ_Inspect(){
      true
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
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFileA'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_Image_NoExist_impl'                  'imageNameTest1'  'f' 'a' 'test_2' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFileA' )
      testTargetArg_ref='imageNameTest1'
    }
    test_element_environ_Inspect(){
      true
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
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFileA'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_Image_NoExist_Docker_Bug_impl'       'imageNameTest1'  'f' ''  'test_3' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFileA' )
      testTargetArg_ref='imageNameTest1'
    }
    test_element_environ_Inspect(){
      true
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
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFileA'       'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_Image_NoExist_Target_bad_impl'       'imageNameTest1'  'd' 'dirDoesNotExist/z'  'test_4' '^Error.+no.such.file.or.directory' "
      echo " 'audit_model_impl'                              'modelExpected'    'modelexpected' "
      echo " 'audit_model_impl'                              'modelResult'      'modelresult' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFileA' )
      testTargetArg_ref='imageNameTest1'
    }
    test_element_environ_Inspect(){
      if docker inspect --type=image -- $imageName 2>&1 >/dev/null; then 
        ScriptUnwind "$LINENO" "Image: '$imageName' should not exist but it does."
      fi
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Attempt to create an image by copying a single host file into a nonexistent  root directory."  \
         "Outcome: Copy should fail because target directory doesn't exist and image should not exist."
  }
}
###############################################################################
dkrcp_test_x(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_test_3_a'          'f' 'a' 'file_content_reflect_name' "
      echo " 'dkrcp_arg_Image_NoExist_impl'                  'imageName_test_3_a'         'f' 'a' 'test_3_a' "
      echo " 'audit_model_impl'                              'modelExpected'              'modelexpected_test_3_a' "
      echo " 'audit_model_impl'                              'modelResult'                'modelresult_test_3_a' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'hostFile_test_3_a' )
      testTargetArg_ref='imageName_test_3_a'
    }
  }
  test_element_test_2_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_container_exist_impl'                   'container_test_3_b'      'f' 'a' 'test_3_a' "
      echo " 'dkrcp_arg_hostfilepath_hostfilepathNotExist_impl' 'hostFileTarget_test_3_b' 'f' 'test_3_b/a' "
      echo " 'audit_model_impl'                                 'modelExpected'           'modelexpected_test_3_b' "
      echo " 'audit_model_impl'                                 'modelResult'             'modelresult_test_3_b' "
    }
    test_element_args_Catgry(){
      testSourceArgList=( 'container_test_3_b' )
      testTargetArg_ref='hostFileTarget_test_3_b'
    }
    test_element_prequisite_test_Def(){
      echo 'test_element_test_1_imp'
      echo 'test_element_test_2_imp'
    }
  }
  test_element_test_2_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a single host file into it. The host" \
         "and target files are identical.  The target file should exist "  \
         "in the root directory of the image."
  }
}
dkrcp_test_x4(){
  test_element_test_1_imp(){
    test_element_interface
    test_element_member_Def(){
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_test_4_dir_a'          'd' 'dir_a'     'file_content_dir_create' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_test_4_dir_a_a'        'f' 'dir_a/a'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_hostfilepath_hostfilepathExist_impl' 'hostFile_test_4_dir_b'          'd' 'dir_b'     'file_content_dir_create' "
      echo " 'hostfilepathname_dependent_impl'               'hostFile_test_4_dir_b_a'        'f' 'dir_b/a'   'file_content_reflect_name' "
      echo " 'dkrcp_arg_Image_NoExist_impl'                  'imageName_test_4'               'd' 'dir_image' 'test_4' "
      echo " 'audit_model_impl'                              'modelExpected'                  'modelexpected_test_4' "
      echo " 'audit_model_impl'                              'modelResult'                    'modelresult_test_4' "
    }
    test_element_args_Catgry(){
      testSourceArgList=(  'hostFile_test_4_dir_a' )
      testSourceArgList+=( 'hostFile_test_4_dir_b' )
      testDependArgList=( 'hostFile_test_4_dir_a_a' )
      testDependArgList+=( 'hostFile_test_4_dir_b_a' )
      testTargetArg_ref='imageName_test_4'
    }
  }
  test_element_test_1_imp
  dkrcp_test_Desc(){
    echo "Create an image by copying a single host file into it. The host" \
         "and target files are identical.  The target file should exist "  \
         "in the root directory of the image."
  }
}