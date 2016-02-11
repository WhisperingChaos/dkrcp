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
  echo 'Requires: bash 4.2+, Docker Client 1.8+'
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
  ! TestDependenciesScanSuccess 'Testdependency_define_Bash'            '4.2'   && depndSuccess='false'
  ! TestDependenciesScanSuccess 'dkrcp_dependency_dkrcp'                '0.5'   && depndSuccess='false'
  ! TestLocalRepositoryIsEmpty && depndSuccess='false'
  ! $depndSuccess && ScriptUnwind "$LINENO" "Detected problematic dependencies.  Repair or try '--no-depnd'."
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
##    Given a string of characters, encapsulate them in a single quoted string.
##    If the string contains single quotes, use a concatenation technique to 
##    preserve them.
##
##  Input:
##    $1 - The source string to encapsulate.
##    $2 - A variable name that will receive the resulting encapsulated value
##         of $1.
##
###############################################################################
single_quote_Encapsulate(){
  local -r sourceString="$1"
  local -r encapOut_ref="$2"
  local -r result_lcl=${sourceString//\'/\'\"\'\"\'}
  eval $encapOut_ref\=\"\'\$result_lcl\'\"
}
###############################################################################
##
##  Purpose:
##    Encapsulate an argument in single quotes to prevent further substitutions.
##
##  Input:
##    $1 - A variable name to return the encapsulated string value.
##    $2 - One or more arguments to encapsulate in single quotes.
##
###############################################################################
args_single_quote_Encapsulate(){
  local -r argsQuoted_ref="$1"
  local args_lcl
  local arg
  for arg in "${@:2}"
  do
    single_quote_Encapsulate "$arg" 'arg' 
    args_lcl+="$arg "
  done
  eval $argsQuoted_ref=\"\$args_lcl\"
}
###############################################################################
##
##  Section:
##    Host file functions.
##
###############################################################################
###############################################################################
##
##  Purpose:
##    Determine if host files aready exist and generate an error message
##    when they are detected.
##
##  Input:
##    $1 - A variable name to receive the value 'true'.
##
##  Output:
##    $1 - Set to 'true' when an existing file reflects a name given
##         to a test file.  Otherwise, the value remains untouched.
##
###############################################################################
host_file_ExistCheck(){
  local -r existInd_ref="$1"
  if host_file_root_Prepend "$TEST_FILE_ROOT" | host_file_exist_Error; then
    eval $exist_ref\=\'true\'
  fi
}
###############################################################################
##
##  Purpose:
##    Determine if host files aready exist and generate an error message
##    when they are detected.
##
##  Input:
##    STDIN - A stream of file names encapsulated in single quotes.
##
##  Output:
##    STDERR - Reflects error messages detailing the files whose names overlap
##         those assign by a test.
##
###############################################################################
host_file_exist_Error(){
  host_file_Method(){
    if [ -e "$1" ]; then
      ScriptError "Detected existance of host file: '$1', involved in testing."
    fi
  }
  ! [ host_file_Interator ]
}
###############################################################################
##
##  Purpose:
##    For current Test, remove any detectable test files from environment.
##
###############################################################################
host_file_Clean(){
  PipeFailCheck 'host_file_root_Prepend '"'$TEST_FILE_ROOT'"' | host_file_Delete' "$LINENO" "File cleanup failed."
}
###############################################################################
##
##  Purpose:
##    Delete all the files accessed by iterator
##
###############################################################################
host_file_Delete(){
  host_file_Method(){
    if [ -e "$1" ]; then 
      if ! rm -fr "$1" > /dev/null; then
        ScriptUnwind "$LINENO" "Failed to remove host file:'$1'."
      fi
    fi
  }
  host_file_Interator
}
###############################################################################
##
##  Purpose:
##    Create and assert one or more host files.
##
###############################################################################
host_file_CreateAssert(){
  PipeFailCheck 'host_file_root_Prepend '"'$TEST_FILE_ROOT'"' | host_file_Create' "$LINENO" "Failure while creating test files."
}
###############################################################################
##
##  Purpose:
##    Create one or more host files.
##
###############################################################################
host_file_Create(){
  host_file_Method(){
#    ScriptDebug "$LINENO" "1: '$1', 2: '$2'"
    $2 "$1"
  }  
  host_file_Interator
}
###############################################################################
##
##  Purpose:
##    Prefix all host file names with a common root directory path.
##
##  Input:
##    $1 - Specifies root directory for file.
##    host_file_List  - A function, possibly overidden, whose output consists
##         of two strings.  The first string represents a file name, while
##         the second defines a content generation function.
##
##  Output:
##    STDOUT - two strings, the first a file name with a specified host root
##         directory and 
##
###############################################################################
host_file_root_Prepend(){
  local rootDir="$1"
  local filenameencap
  local functionNameencap
  host_file_Method(){
    single_quote_Encapsulate "${rootDir}$1" 'filenameencap' 
    single_quote_Encapsulate "$2" 'functionNameencap'
    echo "$filenameencap $functionNameencap"
  }
  host_file_Def | host_file_Interator
}
###############################################################################
##
##  Purpose:
##    Iterate through a list of file names each associated to a content
##    generation routine and for each element in this list, execute an
##    operation.
##
##    Currently the iterator will continue to processing the next element
##    in the list even though the prior one generated an error.
##
##  Input:
##    STDIN - A row consisting of a file name encapsulated in single quotes
##       delimited by a space from a function name encapsulatd in single 
##       quotes specifying a content generation function.
##    host_file_Method - An overriden function that accepts the file name and
##       content generation function name as arguments and then applies some
##       operation with them.
##
##   Output:
##       
##
###############################################################################
host_file_Interator(){
  local rtnCode='true'
  local filename
  while read -r filename; do 
    eval set -- "$filename"
    if ! host_file_Method "$1" "$2"; then 
      rtnCode='false'
    fi
  done
  $rtnCode
}
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
    ScriptError "Failed to create file:'$1'."
  fi
}


file_content_dir_create(){
  if ! mkdir -p "$1" >/dev/null; then
    ScriptError "Unable to create directory: '$1'"
  fi
}
##############################################################################
##
##  Section:
##    Image file functions.
##
###############################################################################
image_ExistCheck(){
  local -r errorInd_ref="$1"
  local imageInd='false'
  if ! image_NoExist; then 
    imageInd='true'
    ScriptError "Detected existance of one or more images involved in testing."
  fi
  eval $errorInd_ref\=\"\$imageInd\"
}
##############################################################################
##
##  Purpose:
##    Verify existance of one or more image UUID/Name references.  Returns
##    true, if at least one reference exists.
##
##  Inputs:
##    image_name_Prepend - One or more image references to operate on.
##
##  Outputs:
##    When at least one reference exists, return true.
##
###############################################################################
image_NoExist(){

  local containerNoExists='true'
  if ! container_NoExist; then containerNoExists='false'; fi

  image_Method(){
    local imageNameUUID="$2"
    local msg
    if msg="$(docker inspect --type=image -- $imageNameUUID 2>&1)"; then
      ScriptError "Detected image: '$2'."
      return 1
    fi
    if ! [[ $msg =~ ^Error:.No.such.image.*$ ]]; then
      ScriptUnwind "$LINENO" "Unexpected error: '$msg', when testing for image name: '$imageNameUUID'."
    fi
  }
  image_name_Prepend "$TEST_NAME_SPACE" | image_Iterator
  if [ "$?" -eq '0' ] && $containerNoExists; then true; else false; fi
}
##############################################################################
##
##  Purpose:
##    Remove images from local repository and dependent containers.
##
##  Inputs:
##    image_name_Prepend - One or more image references to operate on.
##
##  Outputs:
##    When successful: Nothing.
##
###############################################################################
image_Clean(){
  container_Clean
  image_Method(){
    local -r imageNameUUID="$2"
    local msg
#   ScriptDebug "$LINENO" "Deleting image: '$imageNameUUID'."
    if msg="$(docker rmi -f -- $imageNameUUID 2>&1)"; then return 0; fi
    if ! [[ $msg =~ ^Error.+:.No.such.image.*$ ]]; then
      ScriptError "Unexpected error: '$msg', when removing image name: '$imageNameUUID'."
    fi
  }
  PipeFailCheck 'image_name_Prepend '"'$TEST_NAME_SPACE'"' | image_Iterator' "$LINENO" "Image Cleanup Failed." 
}
##############################################################################
##
##  Purpose:
##    Prefix local image names with image name space.
##
##  Inputs:
##    image_reference_Def - Provides list of rows.  Each row contains a type specifier
##         and an image name/UUID.  The type specifier determines if the
##         image reference is implemented as a name or UUID.
##
##  Outputs:
##    When success: STDOUT should generate one or more rows such that local
##       image names are prefixed by the test's name space.
##
###############################################################################
image_name_Prepend(){
  local imageNameSpace="$1"
  image_Method(){
    local imageTypeSpec
    local imageNameUUID
    single_quote_Encapsulate "$1" 'imageTypeSpec' 
    if [ "$1" == 'NameLocal' ]; then 
      single_quote_Encapsulate "${imageNameSpace}$2" 'imageNameUUID'
    else
      single_quote_Encapsulate "$2" 'imageNameUUID'
    fi
    echo "$imageTypeSpec $imageNameUUID"
  }
  PipeFailCheck 'image_reference_Def | image_Iterator'
}
##############################################################################
##
##  Purpose:
##    Iterate through specified image name/UUID and perform specified method.
##
##  Inputs:
##    STDIN - Provides list of rows.  Each row contains a type specifier
##         and an image name/UUID.  The type specifier determines if the
##         image reference is implemented as a name or UUID.
##    image_Method - An overriden function name that accepts each row of 
##         STDIN and performs some operation involving its data.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
image_Iterator(){
  local rtnCode='true'
  local imageNameUUID
  while read -r imageNameUUID; do 
    eval set -- "$imageNameUUID"
    if ! image_Method "$1" "$2"; then 
      rtnCode='false'
    fi
  done
  $rtnCode
}
##############################################################################
##
##  Purpose:
##    Copy file/directory from host file system into an image.  Then examine
##    the image to ensure the target(s) was correctly copied.
##
##  Inputs:
##    $1 - Relative reference to either file or directory being copied from 
##         host file system to image.
##    $2 - Source type:
##         'f' - file type
##         'd' - directory
##    $3 - The image name or UUID. To differenciate between them, a name
##         must include and a UUID must exclude ':'
##    $4 - Relative or absolute reference to either a file or directory within an
##         image.  If relative reference, then referene is relative to the root
##         directory of an image.
##    $5 - Append source reference to target:
##           'true' - append
##           'false'- do not append.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
dkrcp_host_imageAssert(){
  dkrcp_host_xAssert 'image' "$@"
}
##############################################################################
dkrcp_host_xAssert(){
  local -r targetType="$1"

  dkrcp_source_Assert(){
    local -r sourceFilePath="$1"
    local -r targetNameUUID="$2"
    local -r targetPathRelRef="$3"

    if ! dkrcp.sh "$sourceFilePath" "${targetNameUUID}:$targetPathRelRef">/dev/null; then
      ScriptUnwind "$LINENO" "Failure while copying from source: '$sourceFilePath', into: 'targetType', target: '$targetNameUUID', relative reference to root: '$targetPathRelRef'."
    fi
  }
  dkrcp_X_to_${targetType}Assert "$2" "$3" "$4" "$5" "$6"
}
##############################################################################
##
##  Purpose:
##    Copy file/directory from host file system into an image.  Then examine
##    the image to ensure the target(s) was correctly copied.
##
##  Inputs:
##    $1 - Image name/UUID of source image.
##    $2 - Relative reference to either file or directory being copied from 
##         host file system to image.
##    $3 - Source type:
##         'f' - file type
##         'd' - directory
##    $4 - The image name or UUID. To differenciate between them, a name
##         must include and a UUID must exclude ':'
##    $5 - Relative or absolute reference to either a file or directory within an
##         image.  If relative reference, then referene is relative to the root
##         directory of an image.
##    $6 - Append source reference to target:
##           'true' - append
##           'false'- do not append.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
dkrcp_image_imageAssert(){
  dkrcp_image_xAssert 'image' "$@"
}
##############################################################################
dkrcp_image_xAssert(){
  local -r targetType="$1"
  local imageNameUUIDsource="$2"
  image_name_local_namespace_Prefix "$imageNameUUIDsource" 'imageNameUUIDsource'
  local -r imageNameUUIDsource

  dkrcp_source_Assert(){
    local sourceFilePath="$1"
    local -r targetNameUUID="$2"
    local -r targetPathRelRef="$3"

    host_file_source_path_root_PrefixRemove "$sourceFilePath" 'sourceFilePath'  

    if ! dkrcp.sh "${imageNameUUIDsource}:$sourceFilePath" "${targetNameUUID}:$targetPathRelRef">/dev/null; then
      ScriptUnwind "$LINENO" "Failure while copying from source image: '${imageNameUUIDsource}:$sourceFilePath', into target ${targetType}: '$targetNameUUID', relative reference to root: '$targetPathRelRef'."
    fi
  }
  dkrcp_X_to_${targetType}Assert "$3" "$4" "$5" "$6" "$7"
}
##############################################################################
##
##  Purpose:
##    Copy file/directory from host file system into an image.  Then examine
##    the image to ensure the target(s) was correctly copied.
##
##  Inputs:
##    $1 - Relative reference to either file or directory being copied from 
##         host file system to image.
##    $2 - Source type:
##         'f' - file type
##         'd' - directory
##    $3 - The image name or UUID. To differenciate between them, a name
##         must include and a UUID must exclude ':'
##    $4 - Relative or absolute reference to either a file or directory within an
##         image.  If relative reference, then referene is relative to the root
##         directory of an image.
##    $5 - Append source reference to target:
##           'true' - append
##           'false'- do not append.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
dkrcp_stream_imageAssert(){
  dkrcp_stream_xAssert 'image' "$@"
}
###############################################################################
dkrcp_stream_xAssert(){
  local -r targetType="$1"

  dkrcp_source_Assert(){
    local -r sourceFilePath="$1"
    local -r targetNameUUID="$2"
    local -r targetPathRelRef="$3"

    local -r tarDirCurr="$( dirname "$sourceFilePath")"
    local -r tarBaseName="$( basename "$sourceFilePath")"

    if ! tar -C "$tarDirCurr" -cf- "$tarBaseName" | dkrcp.sh '-' "${targetNameUUID}:$targetPathRelRef">/dev/null; then
      ScriptUnwind "$LINENO" "Failure while copying from source tar: '$tarBaseName', into target ${targetType}: '$targetNameUUID', relative reference to root: '$targetPathRelRef'."
    fi
  }
  dkrcp_X_to_${targetType}Assert "$2" "$3" "$4" "$5" "$6"
}
##############################################################################
##
##  Purpose:
##    Create a source container from the provided image.  Next, copy the
##    file/directory from it to a targeted container.  Then examine
##    the targeted container to ensure the source was correctly copied.
##
##  Inputs:
##    $1 - Container parent image name/UUID.
##    $2 - Relative/absolute reference to source container file/directory.
##    $3 - Source type:
##         'f' - file type
##         'd' - directory
##    $4 - Targeted container name or UUID. To differenciate between them, a name
##         must include and a UUID must exclude ':'
##    $5 - Relative/absolute reference to a file/directory within an
##         image.
##    $6 - Copy directory to target indicator:
##           'true' - Copy source directory to target.
##           'false'- Copy source directory content to target.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
dkrcp_container_containerAssert(){
  dkrcp_container_xAssert 'container' "$1" "$2" "$4" "$3" "$5" "$6"
}
dkrcp_container_imageAssert(){
  dkrcp_container_xAssert 'image' "$@"
}
###############################################################################
dkrcp_container_xAssert(){
  local -r targetType="$1"
  local imageNameUUIDsource="$2"
  image_name_local_namespace_Prefix "$imageNameUUIDsource" 'imageNameUUIDsource'
  local -r imageNameUUIDsource

  dkrcp_source_Assert(){
    local -r sourceFilePath="$1"
    local -r targetNameUUID="$2"
    local -r targetPathRelRef="$3"

    local derivedContainerID
    image_container_Create "$imageNameUUIDsource" 'derivedContainerID'
    local -r derivedContainerID
    if ! dkrcp.sh "${containerNameUUIDsource}:$sourceFilePath" "${targetNameUUID}:$targetPathRelRef">/dev/null; then
      ScriptUnwind "$LINENO" "Failure while copying from source: '$sourceFilePath', into target ${targetType}: '$targetNameUUID', relative reference to root: '$targetPathRelRef'."
    fi
    if ! docker rm -f "$derivedContainerID">/dev/null; then
      ScriptUnwind "$LINENO" "Unexpected failure while deleting container: '$derivedContainerID'."
    fi
  }
  ScriptDebug "$LINENO" "3-'$3' 4-'$4' 5:'$5' 6-'$6' 7-'$7'"
  dkrcp_X_to_${targetType}Assert "$3" "$4" "$5" "$6" "$7"
}
##############################################################################
##
##  Purpose:
##    Copy file/directory from host file system into an image.  Then examine
##    the image to ensure the target(s) was correctly copied.
##
##  Inputs:
##    $1 - Relative reference to either file or directory being copied from 
##         host file system to image.
##    $2 - Source type:
##         'f' - file type
##         'd' - directory
##    $3 - The image name or UUID. To differenciate between them, a name
##         must include and a UUID must exclude ':'
##    $4 - Relative or absolute reference to either a file or directory within an
##         image.  If relative reference, then referene is relative to the root
##         directory of an image.
##    $5 - Append source reference to target:
##           'true' - append
##           'false'- do not append.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
dkrcp_X_to_imageAssert(){
  local -r sourceFilePathRelRef="$1"
  local sourceFilePath
  host_file_source_path_root_Prefix "$sourceFilePathRelRef" 'sourceFilePath'
  local -r sourceFilePath
  local -r sourceType="$2"
  local imageNameUUID
  image_name_local_namespace_Prefix "$3" 'imageNameUUID'
  local -r imageNameUUID
  local -r imageTargetPathRelRef="$4"
  local -r appendSourceToTtargetRelRef="$5"

  ScriptDebug "$LINENO" "dkrcp.sh '$sourceFilePath'  '${imageNameUUID}:$imageTargetPathRelRef'"

  dkrcp_source_Assert "$sourceFilePath" "${imageNameUUID}:" "$imageTargetPathRelRef"

  ScriptDebug "$LINENO" "after assert:  '$imageNameUUID'"

  local derivedContainerID
  image_container_Create "$imageNameUUID" 'derivedContainerID'
  local -r derivedContainerID

  container_host_Compare  "$derivedContainerID" "$sourceFilePathRelRef" "$sourceType" "$imageTargetPathRelRef"  "$appendSourceToTtargetRelRef"

  if ! docker rm $derivedContainerID >/dev/null; then
    ScriptUnwind "$LINENO" "Unexpected failure while removing temporary container ID: '$derivedContainerID'."
  fi
}
##############################################################################
##
##  Purpose:
##    Creates a new or modifies an existing image allowing the configuration
##    of the container's file system state before creating the container and
##    performing the actual copy operation.  
##
##    After creating the image, a container is created from it which becomes
##    the target of the drcp command.
##
##    This function next routes execution to the dkrcp command that accepts
##    the appropriate source copy type.
##
##    Finally, the function deletes the constructed before returning.
##
##  Inputs:
##    $1 - Source type:
##         'host' - source is a host file path.
##    dkrcp_container_config_Def - Due to complexity of parameter list,
##         encode a function interface to provide a means to pass parameters.
##         This function defines/overrides two parameter functions:
##         image_parent_config - Provides parameter list to create/modify
##            an image.  This image becomes the prototype for the container
##            targeted by the dkrcp command.
##         container_derived_CopyArgs - Provides parameter list to modify
##            an existing container.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
dkrcp_containerAssert(){
  local -r sourceType="$1" 
  dkrcp_container_config_Def
  # create/modify parent image of container
  local hostImageArgs
  image_parent_args_Copy 'hostImageArgs'
  local -r hostImageArgs
  eval dkrcp_host_imageAssert $hostImageArgs
  # create the targeted container
  eval set \-\- $hostImageArgs
  local imageNameUUID
  image_name_local_namespace_Prefix "$3" 'imageNameUUID'
  local -r imageNameUUID
  local derivedContainerID
  image_container_Create "$imageNameUUID" 'derivedContainerID'
  local -r derivedContainerID
  # perform the appropriate source type copy operation
  local containerArgs
  container_derived_args_Copy 'containerArgs'
  local -r containerArgs
  eval set \-\- $containerArgs
  ScriptDebug "$LINENO" "1-'$1' 2-'$2' contID: '$derivedContainerID' 3-'$3' 4-'$4'"
  dkrcp_${sourceType}_containerAssert "$1" "$2" "$derivedContainerID" "$3" "$4"
  # delete the container.
  if ! docker rm $derivedContainerID >/dev/null; then
    ScriptUnwind "$LINENO" "Unexpected failure when removing container: '$derivedContainerID',  derived from image: '$imageNameUUID'" 
  fi
}
##############################################################################
##
##  Purpose:
##    Copy file/directory from host file system into a container.  Then examine
##    the container to ensure the target(s) was correctly copied.
##
##  Inputs:
##    $1 - Relative reference to either file or directory being copied from 
##         some given source.
##    $2 - Source file path type:
##         'f' - file type
##         'd' - directory
##    $3 - The container name or UUID. To differenciate between them, a name
##         must include while a UUID must exclude ':'.
##    $4 - Relative or absolute reference to either a file or directory within a
##         container.  If relative reference, then referene is relative to the root
##         directory of a container.
##    $5 - Append source reference to target:
##           'true' - append
##           'false'- do not append.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
dkrcp_host_containerAssert(){
  dkrcp_host_xAssert 'container' "$@"
}
##############################################################################
##
##  Purpose:
##    Copy file/directory from host file system into an image.  Then examine
##    the image to ensure the target(s) was correctly copied.
##
##  Inputs:
##    $1 - Relative reference to either file or directory being copied from 
##         host file system to image.
##    $2 - Source type:
##         'f' - file type
##         'd' - directory
##    $3 - The image name or UUID. To differenciate between them, a name
##         must include and a UUID must exclude ':'
##    $4 - Relative or absolute reference to either a file or directory within an
##         image.  If relative reference, then referene is relative to the root
##         directory of an image.
##    $5 - Append source reference to target:
##           'true' - append
##           'false'- do not append.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
dkrcp_stream_containerAssert(){
  dkrcp_stream_xAssert 'container' "$@"
}
##############################################################################
##
##  Purpose:
##    Copy file/directory from some source to the targeted container..  Then
##    examine the container's contents to ensure the target(s) was
##    correctly copied.
##
##  Inputs:
##    $1 - Relative reference to either file or directory being copied from 
##         some given source.
##    $2 - Source file path type:
##         'f' - file type
##         'd' - directory
##    $3 - The container name or UUID. To differenciate between them, a name
##         must include while a UUID must exclude ':'.
##    $4 - Relative or absolute reference to either a file or directory within a
##         container.  If relative reference, then referene is relative to the root
##         directory of a container.
##    $5 - Append source reference to target:
##           'true' - append
##           'false'- do not append.
##    dkrcp_source_containerAssert - Override this function to handle copying
##         the various source object types.
##
##  Outputs:
##    When error: STDERR should reflect some message providing means to 
##       debug problem.
##
###############################################################################
dkrcp_X_to_containerAssert(){
  local -r sourceFilePathRelRef="$1"
  local sourceFilePath
  host_file_source_path_root_Prefix "$sourceFilePathRelRef" 'sourceFilePath'
  local -r sourceFilePath
  local -r sourceType="$2"
  local -r containerNameUUID="$3"
  local -r containerTargetPathRelRef="$4"
  local -r appendSourceToTtargetRelRef="$5"

  dkrcp_source_Assert "$sourceFilePath" "$containerNameUUID" "$containerTargetPathRelRef"

  container_host_Compare  "$derivedContainerID" "$sourceFilePathRelRef" "$sourceType" "$containerTargetPathRelRef"  "$appendSourceToTtargetRelRef"
}
##############################################################################
##
##  Purpose:
##    Compare contents of specified container file/directory with contents
##    of host file/directory.
##
##  Inputs:
##    $1 - Reference to an existing container.
##    $2 - Relative or absolute reference to the content located in the
##         container that will be compared to the content of the host.
##    $3 - Source type:
##         'f' - file type
##         'd' - directory
##    $4 - An absolute reference to either a host file or directory.
##    $5 - (potentiallhy optional) Must be specified when container source
##         references a directory. Append source reference to target:
##           'true' - append
##           'false'- do not append.
##
##  Outputs:
##    When success: nothing.
##    When error:   Comparision fails: STDERR emits message identifying 
##                  content differences between container/host file
##                  and unwinds process.
##
###############################################################################
container_host_Compare(){
  local -r containerNameUUID="$1"
  local -r sourceFilePathRelRef="$2"
  local -r sourceType="$3"
  local targetPath="$4"
  local -r appendSourceToTtargetRelRef="$5"
  local -r compareFilePath="${TEST_FILE_ROOT}output/"

  if [ "$sourceType" == 'd' ] && $appendSourceToTtargetRelRef; then
    targetPath="${targetPath}/$sourceFilePathRelRef"
  fi
  local -r targetPath
  if ! docker cp "$containerNameUUID:$targetPath" "$compareFilePath"; then
    ScriptUnwind "$LINENO" "Failure while attempting to verify newly added source file(s): '$sourceFilePath', into target image: '$imageNameUUID', path: '$targetPath'."
  fi

  local compareTargetPath="$targetPath"
  if [ "$sourceType" == 'f' ] || [ "$sourceType" == 'd' ] && $appendSourceToTtargetRelRef; then
    compareTargetPath="$( basename "$targetPath" )"
  fi
  local -r compareTargetPath
#  ScriptDebug "$LINENO" "source: '$sourceFilePath' compare: '${compareFilePath}$compareTargetPath'"

  if ! diff -qr "$sourceFilePath" "${compareFilePath}$compareTargetPath"; then 
    ScriptUnwind "$LINENO" "Unexpected differences between newly added source file(s): '$sourceFilePath', into target image: '$imageNameUUID', path: '$targetPath'."
  fi
}
##############################################################################
##
##  Purpose:
##    Use dkrcp.sh to perform a copy operation without auditing its operation.
##
##  Inputs:
##    $1 - Source file path.
##    $2 - An image UUID or name.
##    $3 - Relative or absolute reference to either a file or directory within an
##         image.  If relative reference, then referene is relative to the root
##         directory of an image.
##
##  Outputs:
##    When successful:
##      nothing.
##
###############################################################################
dkrcp_host_imageCopyAssert(){
  local sourceFilePath
  host_file_source_path_root_Prefix "$1" 'sourceFilePath'
  local imageNameUUID
  image_name_local_namespace_Prefix "$2" 'imageNameUUID'
  local -r imageTargetPathRelRef="$3"

  if ! dkrcp.sh "$sourceFilePath" "${imageNameUUID}:$imageTargetPathRelRef">/dev/null; then
    ScriptUnwind "$LINENO" "Failure while copying from source: '$sourceFilePath', into target image: '$imageNameUUID', relative reference to root: '$imageTargetPathRelRef'."
  fi
}
##############################################################################
##
##  Purpose:
##    Prefix host file with common root directory.
##
##  Inputs:
##    $1 - file path relative to root directory.
##    $2 - A variable to contain the resulting absolute host file path.
##
##  Outputs:
##    $2
##
###############################################################################
host_file_source_path_root_Prefix(){
  eval $2\=\"\$\{TEST_FILE_ROOT\}\$1\"
}
host_file_source_path_root_PrefixRemove(){
  local -r hostFilePathAbsolute="$1"
  local -r fileOrPath="${hostFilePathAbsolute:${#TEST_FILE_ROOT}}"
  eval $2\=\"\$fileOrPath\"
}
##############################################################################
##
##  Purpose:
##    Prefix name of locally stored, named image with a namespace.  If the
##    image name begins with a namespace: '<namespace>/<imageName>' it 
##    is considered a nonlocal name and isn't prefixed but is returned
##    unchanged.
##
##  Inputs:
##    $1 - A Docker image name.
##    $2 - A variable to contain the image's name.  
##
##  Outputs:
##    $2
##
###############################################################################
image_name_local_namespace_Prefix(){
  eval $2\=\"\$1\"
  if [[ $1 =~ ^[^:/]+:.*$ ]]; then
    eval $2\=\"\$\{TEST_NAME_SPACE\}\$1\"
  fi
}
##############################################################################
##
##  Purpose:
##    Prefix name of locally stored, named image with a namespace.  If the
##    image name begins with a namespace: '<namespace>/<imageName>' it 
##    is considered a nonlocal name and isn't prefixed but is returned
##    unchanged.
##
##  Inputs:
##    $1 - A Docker image name.
##    $2 - A variable to contain the image's name.  
##
##  Outputs:
##    $2
##
###############################################################################
#image_name_local_namespace_PrefixRemove(){
#  eval $2\=\"\$1\"
#  if [[ $1 =~ ^[^:/]+:.*$ ]]; then
#    local -r imageName="${1:${#TEST_NAME_SPACE}}"
#    eval $2\=\"\$imageName\"
#  fi
#}
##############################################################################
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
##############################################################################
##
##  Purpose:
##    Scan for at least one container derived from provided image. 
##
##  Inputs:
##    image_name_Prepend - Obtains list of image names/UUIDs.
##
##  Outputs:
##    When container exists:
##      STDOUT - Issue message identifying container(s)
##      return false.
##    When no containers are detected:
##      No output
##      return true 
##
###############################################################################
container_NoExist(){
  image_Method(){
    docker ps -a | grep "$2" | awk '{ print $1;}' | xargs -I ID -- ScriptError "Found container: 'ID' associated to image: '$2'"
    [ "${PIPESTATUS[1]}" -ne '0' ]
  }
  image_name_Prepend "$TEST_NAME_SPACE" | image_Iterator
}
##############################################################################
##
##  Purpose:
##    Remove dangling containers from local repository in tests exercising
##    failure modes that leave intermediate containers as remnants.
##
##  Inputs:
##    image_name_Prepend - Obtains list of image names/UUIDs.
##
###############################################################################
container_Clean(){
  image_Method(){
    local errorMsg
    if ! errorMsg="$( docker rm $( docker ps -a --no-trunc | grep "$2" | awk '{ print $1 }') 2>&1 )"; then
      if ! [[ $errorMsg =~ 'docker: "rm" requires a minimum of 1 argument' ]]; then
        false
      fi
    fi
  }
PipeFailCheck 'image_name_Prepend '"'$TEST_NAME_SPACE'"' | image_Iterator' "$LINENO" "Container Clean Failed."
}
##############################################################################
##
##  Section:
##    Tests definitions.
##
###############################################################################
###############################################################################
dkrcp_test_2() {
  host_file_Def(){
    echo "'a'      'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_2'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a single host file into it. The host" \
         "and target files differ.  The target file should exist in the"   \
         "root directory of the image."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_2:' 'a2'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_3() {
  host_file_Def(){
    echo "'a'      'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_3'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a single host file into it. The host" \
         "and target files names differ.  Also the target location"        \
         "specifies a relative reference to the existing etc directory."   \
         "Therefore, the file should exist in then /etc directory of the image."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_3:' 'etc/a2'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_4() {
  host_file_Def(){
    echo "'a'      'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_4'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a single host file into it. The host" \
         "and target files names differ.  Also the target location"        \
         "specifies an absolute reference to the existing /etc directory." \
         "Therefore, the file should exist in then /etc directory of the image."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_4:' '/etc/a2'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_5() {
  host_file_Def(){
    echo "'a'      'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_5'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a single host file into it. The host" \
         "and target files names are identical.  Also the target location" \
         "specifies a relative reference to the existing etc directory."   \
         "Therefore, the file should exist in then /etc directory of the image."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_5:' 'etc/'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_6() {
  host_file_Def(){
    echo "'a'      'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_6'"
  }
  dkrcp_test_Desc() {
    echo "Attempt to copy a single host file that doesn't exist." \
         "Must faile and generate a message indicating the file's absence."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    if ! dkrcp_host_imageAssert 'q' 'f' 'test_6:' 'etc' 2>&1 | grep 'lstat.*q: no such file or directory'  >/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure indicating source file 'q' doesn't exist but didn't receive expected message."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_7() {
  host_file_Def(){
    echo "'a'      'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_7'"
  }
  dkrcp_test_Desc() {
    echo "Attempt to create an image by copying a single host file into it." \
         "However the attempt should fail and generate a message indicating."\
         "that the target refers to a nonexistent directory."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    if ! dkrcp_host_imageAssert 'a' 'f' 'test_7:' 'rjm/' 2>&1 | grep 'no such directory' >/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure indicating target 'rjm/' reference doesn't exist."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_8() {
  host_file_Def(){
    echo "'dir'    'file_content_dir_create'"
    echo "'dir/a'  'file_content_reflect_name'"
    echo "'dir/b'  'file_content_reflect_name'"
    echo "'dir/c'  'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_8'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a host directory into it."      \
         "Since the targeted name doesn't exist, a directory"        \
         "should be created and the files from the host's source"    \
         "directory should exist in this new target directory."      \
         "In this test the source and target directory names are"    \
         "identical."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'dir' 'd' 'test_8:' 'dir' 'false' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_9() {
  host_file_Def(){
    echo "'dir'    'file_content_dir_create'"
    echo "'dir/a'  'file_content_reflect_name'"
    echo "'dir/b'  'file_content_reflect_name'"
    echo "'dir/c'  'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_9'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a host directory into it."  \
         "Since the target directory exists, the host directory" \
         "is copied into the image's target directory." 
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'dir' 'd' 'test_9:' 'etc' 'true' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_10() {
  host_file_Def(){
    echo "'dir'    'file_content_dir_create'"
    echo "'dir/a'  'file_content_reflect_name'"
    echo "'dir/b'  'file_content_reflect_name'"
    echo "'dir/c'  'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_10'"
  }
  dkrcp_test_Desc() {
    echo "Generate a failure while creating an image by copying a host" \
         "directory into an already existing file." 
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    if ! dkrcp_host_imageAssert 'dir' 'd' 'test_10:' 'etc/hostname' 'false' 2>&1 | grep 'cannot copy directory' >/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure indicating host source directory: 'dir' cannot be copied in an existing image target file: '/etc/hostname'."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_11() {
  host_file_Def(){
    echo "'dir'    'file_content_dir_create'"
    echo "'dir/a'  'file_content_reflect_name'"
    echo "'dir/b'  'file_content_reflect_name'"
    echo "'dir/c'  'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_11'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a host directory into it."      \
         "Since the targeted name doesn't exist, a directory"        \
         "should be created and the files from the host's source"    \
         "directory should exist in this new target directory."      \
         "In this test the source and target directory names are"    \
         "different."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'dir' 'd' 'test_11:' 'mydir' 'false' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_12() {
  host_file_Def(){
    echo "'mydir'   'file_content_dir_create'"
    echo "'dir'     'file_content_dir_create'"
    echo "'dir/a'   'file_content_reflect_name'"
    echo "'dir/b'   'file_content_reflect_name'"
    echo "'dir/c'   'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_12'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying the contents of a host directory" \
         "into it.  The targeted name exists as a directory.  Since"   \
         "the source directory ends with '/.', source files should be" \
         "copied directly to the target directory."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageCopyAssert 'mydir/.' 'test_12:' '/mydir'
    dkrcp_host_imageAssert 'dir/.' 'd' 'test_12:' 'mydir' 'false' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_13() {
  host_file_Def(){
    echo "'mydir'   'file_content_dir_create'"
    echo "'a'       'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_13'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a tar stream containing a single file. The" \
         "targeted name exists as an empty directory, therefore, the source"     \
         "file should be copied to the target directory."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageCopyAssert 'mydir/.' 'test_13:' '/mydir'
    dkrcp_stream_imageAssert 'a' 'f' 'test_13:' 'mydir' 'false' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_14() {
  host_file_Def(){
    echo "'mydir'        'file_content_dir_create'"
    echo "'dir'          'file_content_dir_create'"
    echo "'dir/dirsub'   'file_content_dir_create'"
    echo "'dir/a'        'file_content_reflect_name'"
    echo "'dir/b'        'file_content_reflect_name'"
    echo "'dir/c'        'file_content_reflect_name'"
    echo "'dir/dirsub/a' 'file_content_reflect_name'"
    echo "'dir/dirsub/b' 'file_content_reflect_name'"
    echo "'dir/dirsub/c' 'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_14'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a tar stream containing a single file. The" \
         "targeted name exists as an empty directory, therefore, the source"     \
         "file should be copied to the target directory."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageCopyAssert 'mydir/.' 'test_14:' '/mydir'
    dkrcp_stream_imageAssert 'dir' 'd' 'test_14:' 'mydir' 'true' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_15() {
  host_file_Def(){
    echo "'dir'          'file_content_dir_create'"
    echo "'dir/a'        'file_content_reflect_name'"
    echo "'dir/b'        'file_content_reflect_name'"
    echo "'dir/c'        'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_15'"
  }
  dkrcp_test_Desc() {
    echo "Generate a failure while creating an image by copying a tar stream" \
         "containing a directory to a nonexistent target."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    if ! dkrcp_stream_imageAssert 'dir' 'd' 'test_15:' 'mydir' 'true' 2>&1 | grep 'destination[^:]*:mydir" must be a directory'>/dev/null; then 
      ScriptUnwind "$LINENO" "Expected failure indicating missing image target directory:'mydir'."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_16() {
  host_file_Def(){
    echo "'dir'          'file_content_dir_create'"
    echo "'dir/a'        'file_content_reflect_name'"
    echo "'dir/b'        'file_content_reflect_name'"
    echo "'dir/c'        'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_16'"
    echo "'NameLocal' 'test_16_source'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a directory from a source image."  \
         "The targeted directory doesn't exist, therefore, the content" \
         "of the source directory should appear in the newly created"   \
         "target directory."
  }
  dkrcp_test_EnvCheck(){
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'dir' 'd' 'test_16_source:' 'dir' 'false'
    dkrcp_image_imageAssert  'test_16_source:' 'dir' 'd' 'test_16:' 'dir' 'false'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_17() {
  host_file_Def(){
    echo "'a'       'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_17'"
    echo "'NameLocal' 'test_17_source'"
  }
  dkrcp_test_Desc() {
    echo "Create an image by copying a file from a source image. The" \
         "targeted name doesn't exist, therefore, the source"         \
         "file should be copied into the newly created target file."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_17_source:' 'a'
    dkrcp_image_imageAssert  'test_17_source:' 'a' 'f' 'test_17:' 'b'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_18() {
  host_file_Def(){
    echo "'dir'     'file_content_dir_create'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'dir/a'   'file_content_reflect_name'"
    echo "'dir/b'   'file_content_reflect_name'"
    echo "'dir/c'   'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_18'"
    echo "'NameLocal' 'test_18_source'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing image by copying a directory from another"     \
         "image into an already existing directory of this targeted image." \   
         "Since the targeted directory already exists, the source directory"\
	 "is copied into it."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'mydir' 'd' 'test_18:' 'mydir' 'false'
    dkrcp_host_imageAssert 'dir' 'd' 'test_18_source:' 'dir' 'false'
    dkrcp_image_imageAssert 'test_18_source:' 'dir' 'd' 'test_18:' 'mydir' 'true'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_19() {
  host_file_Def(){
    echo "'dir'     'file_content_dir_create'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'dir/a'   'file_content_reflect_name'"
    echo "'dir/b'   'file_content_reflect_name'"
    echo "'dir/c'   'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_19'"
    echo "'NameLocal' 'test_19_source'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing image by copying the contents of directory"  \
         "from another image into an already existing directory of this"  \
         "targeted image.  Since the targeted directory already exists,"  \
         "the contents of the source directory is copied into it."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'mydir' 'd' 'test_19:' 'mydir' 'false'
    dkrcp_host_imageAssert 'dir' 'd' 'test_19_source:' 'dir' 'false'
    dkrcp_image_imageAssert 'test_19_source:' 'dir/.' 'd' 'test_19:' 'mydir' 'false'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_20() {
  host_file_Def(){
    echo "'dir'     'file_content_dir_create'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'dir/a'   'file_content_reflect_name'"
    echo "'dir/b'   'file_content_reflect_name'"
    echo "'dir/c'   'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_20'"
    echo "'NameLocal' 'test_20_source'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing image by copying the contents of directory"  \
         "from another image into a nonexistent directory of this"        \
         "targeted image.  Since the target directory doesn't exist,"     \
         "the target directory will be created and the contents of the"   \
         "source directory are then copied into it."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'dir' 'd' 'test_20_source:' 'dir' 'false'
    dkrcp_image_imageAssert 'test_20_source:' 'dir/.' 'd' 'test_20:' 'mydir' 'false'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_21() {
  host_file_Def(){
    echo "'a'       'file_content_reflect_name'"
    echo "'dir'     'file_content_dir_create'"
    echo "'dir/a'   'file_content_reflect_name'"
    echo "'dir/b'   'file_content_reflect_name'"
    echo "'dir/c'   'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_21'"
    echo "'NameLocal' 'test_21_source'"
  }
  dkrcp_test_Desc() {
    echo "Generate failure by updating an existing image through"  \
         "copying contents of a source directory from another"     \
         "image to an existing file in the target image."          \
         "This should fail."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_21:' 'a'
    dkrcp_host_imageAssert 'dir' 'd' 'test_21_source:' 'dir' 'false'
    if ! dkrcp_image_imageAssert 'test_21_source:' 'dir' 'd' 'test_21:' 'a' 'false' 2>&1 | grep 'cannot copy directory' >/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure of image copy didn't occur."
    fi
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_22() {
  host_file_Def(){
    echo "'a'       'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_22'"
    echo "'NameLocal' 'test_22_source'"
  }
  dkrcp_test_Desc() {
    echo "Test failure mode by attempting to create an image by copying"   \
         "an existing file from a source image to a nonexistent directory" \
         "that ends in '/'."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_22_source:' 'a'
    if ! dkrcp_image_imageAssert 'test_22_source:' 'a' 'f' 'test_22:' '/b/' 2>&1 | grep 'no such directory'; then
      ScriptUnwind "$LINENO" "Expected failure: 'no such directory', didn't occur."
    fi
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_23() {
  host_file_Def(){
    echo "'a'       'file_content_reflect_name'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_23'"
    echo "'NameLocal' 'test_23_source'"
  }
  dkrcp_test_Desc() {
    echo "Copy a file from a source image to an existing directory in"   \
         "in a target image.  Specify an absolute target directory path" \
         "and end it with an '/'"
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_23_source:' 'a'
    dkrcp_host_imageAssert 'mydir' 'd' 'test_23:' 'mydir' 'false'
    dkrcp_image_imageAssert 'test_23_source:' 'a' 'f' 'test_23:' '/mydir/'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_24() {
  host_file_Def(){
    echo "'a'       'file_content_reflect_name'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_24'"
    echo "'NameLocal' 'test_24_source'"
  }
  dkrcp_test_Desc() {
    echo "Copy a file from a source image to an existing directory in" \
         "a target image."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_24_source:' 'a'
    dkrcp_host_imageAssert 'mydir' 'd' 'test_24:' 'mydir' 'false'
    dkrcp_image_imageAssert 'test_24_source:' 'a' 'f' 'test_24:' 'mydir'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_25() {
  host_file_Def(){
    echo "'a'       'file_content_reflect_name'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_25'"
    echo "'NameLocal' 'test_25_source'"
  }
  dkrcp_test_Desc() {
    echo "Copy a file from a source container to an existing directory in" \
         "a target image."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_25_source:' 'a'
    dkrcp_host_imageAssert 'mydir' 'd' 'test_25:' 'mydir' 'false'
    dkrcp_container_imageAssert "test_25_source:" 'a' 'f' 'test_25:' 'mydir'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_26() {
  host_file_Def(){
    echo "'a'       'file_content_reflect_name'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_26'"
    echo "'NameLocal' 'test_26_source'"
  }
  dkrcp_test_Desc() {
    echo "Copy a file from a source container to an existing directory in" \
         "a target image.  Rename the source file while copying to target."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_26_source:' 'a'
    dkrcp_host_imageAssert 'mydir' 'd' 'test_26:' 'mydir' 'false'
    dkrcp_container_imageAssert "test_26_source:" 'a' 'f' 'test_26:' 'mydir/b'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_27() {
  host_file_Def(){
    echo "'a'       'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_27'"
    echo "'NameLocal' 'test_27_source'"
  }
  dkrcp_test_Desc() {
    echo "Generate a failure by copying a file from a source container to a"
         "nonexistent target image path reference ending in '/'.  "
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_27_source:' 'a'
    if ! dkrcp_container_imageAssert "test_27_source:" 'a' 'f' 'test_27:' 'mydir/' 2>&1 | grep 'no such directory'>/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure: 'no such directory', didn't occur."
    fi
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_28() {
  host_file_Def(){
    echo "'dir'     'file_content_dir_create'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'dir/a'   'file_content_reflect_name'"
    echo "'dir/b'   'file_content_reflect_name'"
    echo "'dir/c'   'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_28'"
    echo "'NameLocal' 'test_28_source'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing image by copying a directory from another"         \
         "container into an already existing directory of this targeted image." \   
         "Since the targeted directory already exists, the source directory"    \
	 "is copied into it."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'mydir' 'd' 'test_28:' 'mydir' 'false'
    dkrcp_host_imageAssert 'dir' 'd' 'test_28_source:' 'dir' 'false'
    dkrcp_container_imageAssert 'test_28_source:' 'dir' 'd' 'test_28:' 'mydir' 'true'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_29() {
  host_file_Def(){
    echo "'dir'     'file_content_dir_create'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'dir/a'   'file_content_reflect_name'"
    echo "'dir/b'   'file_content_reflect_name'"
    echo "'dir/c'   'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_29'"
    echo "'NameLocal' 'test_29_source'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing image by copying the contents of directory"  \
         "from a container into an already existing directory of this"    \
         "targeted image.  Since the targeted directory already exists,"  \
         "the contents of the source directory is copied into it."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'mydir' 'd' 'test_29:' 'mydir' 'false'
    dkrcp_host_imageAssert 'dir' 'd' 'test_29_source:' 'dir' 'false'
    dkrcp_container_imageAssert 'test_29_source:' 'dir/.' 'd' 'test_29:' 'mydir' 'false'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_30() {
  host_file_Def(){
    echo "'dir'     'file_content_dir_create'"
    echo "'mydir'   'file_content_dir_create'"
    echo "'dir/a'   'file_content_reflect_name'"
    echo "'dir/b'   'file_content_reflect_name'"
    echo "'dir/c'   'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_30'"
    echo "'NameLocal' 'test_30_source'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing image by copying the contents of directory"  \
         "from a container into a nonexistent directory of this"          \
         "targeted image.  Since the target directory doesn't exist,"     \
         "the target directory will be created and the contents of the"   \
         "source directory are then copied into it."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'dir' 'd' 'test_30_source:' 'dir' 'false'
    dkrcp_container_imageAssert 'test_30_source:' 'dir/.' 'd' 'test_30:' 'mydir' 'false'
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_31() {
  host_file_Def(){
    echo "'a'       'file_content_reflect_name'"
    echo "'dir'     'file_content_dir_create'"
    echo "'dir/a'   'file_content_reflect_name'"
    echo "'dir/b'   'file_content_reflect_name'"
    echo "'dir/c'   'file_content_reflect_name'"
    echo "'output'  'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_31'"
    echo "'NameLocal' 'test_31_source'"
  }
  dkrcp_test_Desc() {
    echo "Generate failure by updating an existing image through"  \
         "copying contents of a source directory from another"     \
         "image to an existing file in the target image."          \
         "This should fail."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_31:' 'a'
    dkrcp_host_imageAssert 'dir' 'd' 'test_31_source:' 'dir' 'false'
    if ! dkrcp_container_imageAssert 'test_31_source:' 'dir' 'd' 'test_31:' 'a' 'false' 2>&1 | grep 'cannot copy directory' >/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure of image copy didn't occur."
    fi
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_32() {
  host_file_Def(){
    echo "'a'      'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_32'"
    echo "'NameLocal' 'test_32_source'"
  }
  dkrcp_test_Desc() {
    echo "Generate a failure while creating an image by copying a single container" \
         "file to a monexistent targeted directory reference."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_32_source:' 'a'
    if ! dkrcp_container_imageAssert 'test_32_source:' 'a' 'f' 'test_31:' 'dir/a'  2>&1 | grep 'Error response from daemon: lstat.*/dir: no such file or directory' >/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure of container copy didn't occur."
    fi
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_33() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'ignoreDir' 'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_33'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by copying a single host file into it." \
         "The host and target files are identically named.  Once complete,"    \
         "the target file should exist in the root directory of the container."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'ignoreDir' 'd' 'test_33:' 'ignoreDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'a' 'f' 'a'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'host' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_34() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'ignoreDir' 'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_34'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by copying a single host file into it."     \
         "The host and target files are assigned different names.  Once complete," \
         "the target file should exist in the root directory of the container."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'ignoreDir' 'd' 'test_34:' 'ignoreDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'a' 'f' 'b'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'host' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_35() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'ignoreDir' 'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_35'"
  }
  dkrcp_test_Desc() {
    echo "Generate a failure by copying a host file to a" \
         "nonexistent target container path reference ending in '/'.  "
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'ignoreDir' 'd' 'test_35:' 'ignoreDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'a' 'f' 'mydir/'"
        eval $1=\"\$args\"
      }
    }
    if ! dkrcp_containerAssert 'host'  2>&1 | grep 'no such directory'>/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure: 'no such directory', didn't occur."
    fi
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_36() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'b'         'file_content_reflect_name'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_36'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by copying a single host file into it."     \
         "The host and target files are assigned different names.  However, "      \
         "the target file already exists in the container with different content." \
         "Once complete, the target file should exist in the root directory of the container."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'b' 'f' 'test_36:' 'b'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'a' 'f' 'b'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'host' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_37() {
  host_file_Def(){
    echo "'mydir'     'file_content_dir_create'"
    echo "'a'         'file_content_reflect_name'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_37'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by copying a single host file into it."     \
         "The host and target files are assigned same names.  However, the target" \
         "path places the file in a preexisting suddirectory of 'mydir'."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'mydir' 'd' 'test_37:' 'mydir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'a' 'f' 'mydir'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'host' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_38() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'mydir'     'file_content_dir_create'"
    echo "'mydir/a'   'file_content_reflect_name'"
    echo "'mydir/b'   'file_content_reflect_name'"
    echo "'mydir/c'   'file_content_reflect_name'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_38'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by copying a host directory into it."  \
         "The target directory doesn't exist so the directory is created and" \
	 "the contents of the host directory are copied into this newly"      \
         "created target."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'a' 'f' 'test_38:' 'a'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'mydir' 'd' 'mydir' 'false'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'host' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_39() {
  host_file_Def(){
    echo "'targetDir' 'file_content_dir_create'"
    echo "'mydir'     'file_content_dir_create'"
    echo "'mydir/a'   'file_content_reflect_name'"
    echo "'mydir/b'   'file_content_reflect_name'"
    echo "'mydir/c'   'file_content_reflect_name'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_39'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by copying a host directory into it."  \
         "The target directory exists so the source directory is copied"      \
	 "to the target."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'targetDir' 'd' 'test_39:' 'targetDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'mydir' 'd' 'targetDir' 'true'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'host' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_40() {
  host_file_Def(){
    echo "'targetDir' 'file_content_dir_create'"
    echo "'mydir'     'file_content_dir_create'"
    echo "'mydir/a'   'file_content_reflect_name'"
    echo "'mydir/b'   'file_content_reflect_name'"
    echo "'mydir/c'   'file_content_reflect_name'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_40'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by copying a host directory into it."  \
         "The host directory ends with '/.' and the target directory exists," \
         "therefore the source directory contents are copied to the target"   \
         "directory."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'targetDir' 'd' 'test_40:' 'targetDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'mydir/.' 'd' 'targetDir' 'false'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'host' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_41() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'mydir'     'file_content_dir_create'"
    echo "'mydir/a'   'file_content_reflect_name'"
    echo "'mydir/b'   'file_content_reflect_name'"
    echo "'mydir/c'   'file_content_reflect_name'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_41'"
  }
  dkrcp_test_Desc() {
    echo "Generate a failure by attempting to copy a host directory into"  \
         "an existing container's file."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'a' 'f' 'test_41:' 'a'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'mydir/.' 'd' 'a' 'false'"
        eval $1=\"\$args\"
      }
    }
    if ! dkrcp_containerAssert 'host' 2>&1 | grep 'cannot copy directory' >/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure indicating host source directory: 'mydir' cannot be copied in an existing container file: '/a'."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_42() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'mydir'     'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_42'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by streaming a single file into it."     \
         "The steam and target files are identically named.  Once complete,"    \
         "the target file should exist in the root directory of the container."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'mydir' 'd' 'test_42:' 'mydir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'a' 'f' 'mydir'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'stream' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_43() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'ignoreDir' 'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_43'"
  }
  dkrcp_test_Desc() {
    echo "Generate a failure while updating a container by copying a tar stream" \
         "of a file to a nonexistent target."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'ignoreDir' 'd' 'test_43:' 'ignoreDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'a' 'f' 'a'"
        eval $1=\"\$args\"
      }
    }
    if ! dkrcp_containerAssert 'stream' 2>&1 | grep 'destination[^:]*:a" must be a directory'>/dev/null; then 
      ScriptUnwind "$LINENO" "Expected failure indicating nonexistent target:'a', must be a directory."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_43() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'ignoreDir' 'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_43'"
  }
  dkrcp_test_Desc() {
    echo "Generate a failure while updating a container by copying a tar stream" \
         "of a file to a nonexistent target."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'ignoreDir' 'd' 'test_43:' 'ignoreDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'a' 'f' 'a'"
        eval $1=\"\$args\"
      }
    }
    if ! dkrcp_containerAssert 'stream' 2>&1 | grep 'destination[^:]*:a" must be a directory'>/dev/null; then 
      ScriptUnwind "$LINENO" "Expected failure indicating nonexistent target:'a', must be a directory."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_44() {
  host_file_Def(){
    echo "'a'           'file_content_reflect_name'"
    echo "'sourceDir'   'file_content_dir_create'"
    echo "'sourceDir/a' 'file_content_reflect_name'"
    echo "'sourceDir/b' 'file_content_reflect_name'"
    echo "'sourceDir/c' 'file_content_reflect_name'"
    echo "'targetDir'   'file_content_dir_create'"
    echo "'output'      'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_44'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by streaming a directory into a" \
         "pre-existing directory. Once complete, the target directory"  \ 
         "should contain the source directory"
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'targetDir' 'd' 'test_44:' 'targetDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'sourceDir' 'd' 'targetDir' 'true'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'stream' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_45() {
  host_file_Def(){
    echo "'sourceDir'   'file_content_dir_create'"
    echo "'sourceDir/a' 'file_content_reflect_name'"
    echo "'sourceDir/b' 'file_content_reflect_name'"
    echo "'sourceDir/c' 'file_content_reflect_name'"
    echo "'targetDir'   'file_content_dir_create'"
    echo "'output'      'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_45'"
  }
  dkrcp_test_Desc() {
    echo "Update an existing container by streaming a directory into a" \
         "pre-existing directory. Once complete, the target directory"  \ 
         "should contain the content of the source directory"
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'targetDir' 'd' 'test_45:' 'targetDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'sourceDir/.' 'd' 'targetDir' 'false'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'stream' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_46() {
  host_file_Def(){
    echo "'a'           'file_content_reflect_name'"
    echo "'sourceDir'   'file_content_dir_create'"
    echo "'sourceDir/a' 'file_content_reflect_name'"
    echo "'sourceDir/b' 'file_content_reflect_name'"
    echo "'sourceDir/c' 'file_content_reflect_name'"
    echo "'output'      'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_46'"
  }
  dkrcp_test_Desc() {
    echo "Generate failure by streaming an existig source directory" \
         "into a nonexistent container target directory."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'a' 'f' 'test_46:' 'a'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'sourceDir/.' 'd' 'targetDir' 'false'"
        eval $1=\"\$args\"
      }
    }
    if ! dkrcp_containerAssert 'stream' 2>&1 | grep 'destination[^:]*:targetDir" must be a directory'>/dev/null; then 
      ScriptUnwind "$LINENO" "Expected failure indicating missing image target directory:'targetDir'."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_47() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'ignoreDir' 'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_47'"
    echo "'NameLocal' 'test_47_source'"
  }
  dkrcp_test_Desc() {		
    echo "Copy a single file from an existing source container to a target" \
         "container. The target file doesn't exist. The source and target"  \
         "files are identically named.  Once complete, the target file"     \
         "should exist in the root directory of the container."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_47_source:' 'a'
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'ignoreDir' 'd' 'test_47:' 'ignoreDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'test_47_source:' 'a' 'f' 'a'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'container' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_48() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'ignoreDir' 'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_48'"
    echo "'NameLocal' 'test_48_source'"
  }
  dkrcp_test_Desc() {		
    echo "Copy a single file from an existing source container to a target" \
         "container. The target file doesn't exist. The source and target"  \
         "files names are different.  Once complete, the target file"       \
         "should exist in the root directory of the container."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_48_source:' 'a'
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'ignoreDir' 'd' 'test_48:' 'ignoreDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'test_48_source:' 'a' 'f' 'b'"
        eval $1=\"\$args\"
      }
    }
    dkrcp_containerAssert 'container' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_49() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'ignoreDir' 'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_49'"
    echo "'NameLocal' 'test_49_source'"
  }
  dkrcp_test_Desc() {		
    echo "Generate a failure by copying a single file from an existing"  \
         "source container to a nonexistent directory in a target"      \
	 "container."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_49_source:' 'a'
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'ignoreDir' 'd' 'test_49:' 'ignoreDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'test_49_source:' 'a' 'f' 'targetDir/b'"
        eval $1=\"\$args\"
      }
    }
    if ! dkrcp_containerAssert 'container'  2>&1 | grep 'lstat.*targetDir: no such file or directory'  >/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure indicating target directory: 'targetDir' doesn't exist but didn't receive expected message."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_50() {
  host_file_Def(){
    echo "'a'         'file_content_reflect_name'"
    echo "'ignoreDir' 'file_content_dir_create'"
    echo "'output'    'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_50'"
    echo "'NameLocal' 'test_50_source'"
  }
  dkrcp_test_Desc() {		
    echo "Generate a failure by attempting to copy a nonexistent source" \
         "file from an existing container to a target container."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_50_source:' 'a'
    dkrcp_container_config_Def(){
      image_parent_args_Copy(){
        local args="'ignoreDir' 'd' 'test_50:' 'ignoreDir' 'false'"
        eval $1=\"\$args\"
      }
      container_derived_args_Copy(){
        local args="'test_50_source:' 'b' 'f' 'b'"
        eval $1=\"\$args\"
      }
    }
    if ! dkrcp_containerAssert 'container'  2>&1 | grep 'lstat.*b: no such file or directory'  >/dev/null; then
      ScriptUnwind "$LINENO" "Expected failure indicating source: 'a' doesn't exist but didn't receive expected message."
    fi 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
  }
}
###############################################################################
dkrcp_test_61() {
  host_file_Def(){
    echo "'a'      'file_content_reflect_name'"
    echo "'output' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'NameLocal' 'test_61:good'"
  }
  dkrcp_test_Desc() {
    echo "Create an image with a specified tag by copying a single host file into it. The host" \
         "and target files are identical.  The target file should exist "  \
         "in the root directory of the image."
  }
  dkrcp_test_EnvCheck() {
    host_file_ExistCheck "$1"
    image_ExistCheck "$1"
  }
  dkrcp_test_Run() {
    host_file_CreateAssert
    dkrcp_host_imageAssert 'a' 'f' 'test_61:good' 'a' 
  }
  dkrcp_test_EnvClean() {
    host_file_Clean
    image_Clean
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
