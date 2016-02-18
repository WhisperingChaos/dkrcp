source "MessageInclude.sh";
source "ArgumentsGetInclude.sh";
source "ArrayMapTestInclude.sh";
source "VirtCmmdInterface.sh";
#TODO: locate an include file providing frequently needed functions.
ref_simple_value_Set(){
  eval $1=\"\$2\"
}
#TODO: Add Digest support.
#TODO: remove ScriptDebug messages.
#TODO: support import as a mechanism --upc-import
#TODO: convert to more standard oo implementation
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdConfigSetDefault
##
##    Override usual implementation to define repeatable options, like --change,
##    and reclassify a solitary dash, ' - ', specified on the command line
##    as an argument and not, as is typically the case, delimiting the start
##    of the command's arguments (synonym for ' -- ').
##
###############################################################################
function VirtCmmdArgumentsParse () {
  local -a ucpOptRepeatList=( '--change' )
  ucpOptRepeatList+=( '-c' )
  ArgumentsParse "$1" "$2" "$3" 'ucpOptRepeatList' 'Argument'
}

VirtCmmdConfigSetDefault () {
  REG_EX_UUID='^[a-fA-F0-9]+'
  REG_EX_REPOSITORY_NAME_UUID='^([a-z0-9]([._-]?[a-z0-9]+)*/)*[a-z0-9]([._-]?[a-z0-9]+)*(:[A-Za-z0-9._-]*)?'
  REG_EX_CONTAINER_NAME_UUID='^[a-zA-Z0-9][a-zA-Z0-9_.-]*'
  UUID_LEN_MAX='64'
  local -r tempDir="$(dirname "$(mktemp -u)")"
  if [ -z "$tempDir" ]; then 
    ScriptUnwind "$LINENO" "Unable to determine temp dir from: 'mktemp -u'."
  fi
  HOST_FILE_ROOT="${tempDir}/$(basename "${BASH_SOURCE[4]}")"
  # note these must be synchronized with the options/arguments defined with this program
  IMAGE_OPTION_FILTER='[[ $optArg =~ ^--change=[1-9][0-9]*$ ]] || [[ $optArg =~ ^-c=[1-9][0-9]*$ ]] || [ "$optArg" == "--author" ] || [ "$optArg" == "--message" ]'
  NON_SOURCE_NON_TARGET_ONLY_OPTIONS_ARGS='[[ $optArg =~ ^Arg[1-9][0-9]*$ ]] || [ "$optArg" == "--help" ] || [ "$optArg" == "--version" ] || [ "$optArg" == "--ucpchk-reg" ]'
}
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdHelpDisplay
##
###############################################################################
VirtCmmdHelpDisplay () {
cat <<HELP_DOC

Usage: ${BASH_SOURCE[4]} [OPTIONS] SOURCE [SOURCE]... TARGET 

  SOURCE - Can be either: 
             host file path     : {<relativepath>|<absolutePath>}
             image file path    : [<nameSpace>/...]{<repositoryName>:[<tagName>]|<UUID>}::{<relativepath>|<absolutePath>}
             container file path: {<containerName>|<UUID>}:{<relativepath>|<absolutePath>}
             stream             : -
  TARGET - See SOURCE.

  Copy SOURCE to TARGET.  SOURCE or TARGET must refer to either a container/image.
  <relativepath> within the context of a container/image is relative to
  container's/image's '/' (root).

OPTIONS:
    --ucpchk-reg=false        Don't pull images from registry. Limits image name
                                resolution to Docker local repository for  
                                both SOURCE and TARGET names.
    --author="",-a            Specify maintainer when target is an image.
    --change[],-c             Apply specified Dockerfile instruction(s) when
                                target is an image. see 'docker commit'
    --message="",-m           Apply commit message when target is an image.
    --help=false,-h           Don't display this help message.
    --version=false           Don't display version info.

For more help: https://github.com/WhisperingChaos/dkrcp/blob/master/README.md#dkrcp

HELP_DOC
}
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdVersionDisplay
##
###############################################################################
VirtCmmdVersionDisplay () {
cat <<VERSION_DOC

Version : 0.5
Requires: bash 4.2+, Docker Client 1.8+
Issues  : https://github.com/WhisperingChaos/dkrcp/issues
License : The MIT License (MIT) Copyright (c) 2014-2016 Richard Moyse License@Moyse.US

VERSION_DOC
}
###############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdOptionsArgsDef
##
###############################################################################
VirtCmmdOptionsArgsDef () {
# optArgName cardinality default verifyFunction presence alias
cat <<OPTIONARGS
Arg1           single ''                "arg_type_format_Verify   '\\<Arg1\\>' "        required
Arg2           single '-'               "arg_type_format_Verify   '\\<Arg2\\>' "        required
ArgN           single ''                "arg_type_format_Verify   '\\<ArgN\\>' "        optional
--author       single ''                ''                                              optional '-a'
--change=N     single ''                ''                                              optional
-c=N           single ''                ''                                              optional
--message      single ''                ''                                              optional '-m'
--ucpchk-reg   single false=EXIST=true  "OptionsArgsBooleanVerify '\\<--ucpchk-reg\\>'" required
--help         single false=EXIST=true  "OptionsArgsBooleanVerify '\\<--help\\>'"       required "-h"
--version      single false=EXIST=true  "OptionsArgsBooleanVerify '\\<--version\\>'"    required
OPTIONARGS
}
###############################################################################
##
##  Purpose:
##    Verify the format of the copy argument conforms to one of the types
##    expected by the command.
##
##  Input:
##    $1 - An argument.
##    
###############################################################################
arg_type_format_Verify() {
  local typeNameValue=''
  if ! arg_type_format_decide "$1" 'typeNameValue'; then
    ScriptUnwind "$LINENO" "Unable to determine type: '$1'."
  fi
}
###############################################################################
##
##  Purpose:
##    Controls construction and interaction of source and target arguments
##    in order to cast/unify them into a type that can perform the role in
##    docker copy command.
##
##  Input:
##    $1 - Variable name representing the array of all options 
##         and arguments names in the order encountered on the command line.
##    $2 - Variable name representing an associative map of all
##         option and argument values keyed by the option/argument names.
##
###############################################################################
VirtCmmdExecute(){
  local -r optArgLst_ref="$1"
  local -r optArgMap_ref="$2"

  arg_source_target
  local -a argSourceList=()
  local argTarget
  arg_target_Get      "$optArgLst_ref" "$optArgMap_ref" 'argTarget'
  arg_source_list_Get "$optArgLst_ref" "$optArgMap_ref" 'argSourceList'
  local -r argSourceList
  local -r argTarget
  # determine the target argument type.
  local argTargetType
  arg_type_format_decide "$argTarget" 'argTargetType'
  local -r argTargetType
  # override target_type functions to reflect implementation required
  # by the type of target object.
  target_type_${argTargetType}
  # verify compatibility between source & target types.
  if ! arg_type_compatibility_Check 'argSourceList' 'argTargetType'; then return 1; fi
  # create target object
  local -A argTargetObj
  target_obj_Create "$optArgMap_ref" "$argTarget" 'argTargetObj'
  local -r argTargetObj
  # ensure specified options are valid for target object
  local errorMessage
  if ! target_obj_arg_options_Check 'argTargetObj' "$optArgLst_ref" "$optArgMap_ref" 'errorMessage'; then
      target_obj_Rollback 'argTargetObj'
      ScriptError "$errorMessage"
      return
  fi
  if (( ${#argSourceList[@]} > 1 )); then
    # linux cp -a requires the target refer to a directory when copying from multiple sources.
    if ! target_obj_arg_PermitsMultiSource 'argTargetObj' 'errorMessage'; then
      target_obj_Rollback 'argTargetObj'
      ScriptError "$errorMessage"
      return
    fi
  fi
  local targetReference
  target_obj_docker_arg_Get 'argTargetObj' 'targetReference'
  local -r targetReference
  # perform the copy operation for each source
  local ix_src
  for (( ix_src=0; ix_src < ${#argSourceList[@]}; ix_src++ ))
  do
    local argSourceType
    arg_type_format_decide "${argSourceList[$ix_src]}" 'argSourceType'
    # override (polymorphic) source_type functions to reflect implementation
    # required by the type of source object
    source_type_${argSourceType}
    local -A argSourceObj=()
    source_obj_Create "$optArgMap_ref" "${argSourceList[$ix_src]}" 'argSourceObj'
    local sourceReference
    source_obj_docker_arg_Get 'argSourceObj' 'sourceReference'
    local -r sourceReference
    # execute in a sub-shell in order to cleanup from copy exceptions  
    if ! $( cp_strategy_Exec "$argSourceType" "$sourceReference" "$argTargetType" "$targetReference" ); then
      #TODO: remove
      #cp_strategy_failure_Mess 'argSourceObj' 'argTargetObj'
      source_obj_Release 'argSourceObj'
      target_obj_Rollback 'argTargetObj'
      false
      return
    fi
    source_obj_Release 'argSourceObj'
  done
  # successfully completed copy operation commit changes to target.
  target_obj_Commit  'argTargetObj' "$optArgLst_ref" "$optArgMap_ref"
  target_obj_Release 'argTargetObj'
}
##############################################################################
##
##  Purpose:
##    Define a set of interfaces to segregate one or more source arguments
##    from the single targeted one.  Source arguments are the leftmost ones
##    while the last or rightmost is the target.
##
##  Input:
##    $1 - Source object map providing following interface:
##         'objType' - provides the source's type.
##    $2 - Target object map providing following interface:
##         'objType' - provides the target's type.
##
###############################################################################
arg_source_target(){
  ##############################################################################
  ##
  ##  Purpose:
  ##    Given a list of options and arguments, generate the source list by
  ##    selecting only the argument values located to the left of the last
  ##    one specified.  The order as they appeared in the provided argument
  ##    list must be preserved.
  ##
  ##  Input:
  ##    $1 - Variable name representing the array of all options 
  ##         and arguments names in the order encountered on the command line.
  ##    $2 - Variable name representing an associative map of all
  ##         option and argument values keyed by the option/argument names.
  ##    $3 - Variable name representing an array which will contain
  ##         all the source argument values.
  ##
  ###############################################################################
  arg_source_list_Get(){
    local -r optsArgList_ref="$1"
    local -r optsArgMap_ref="$2"
    local -r argSourceList_ref="$3"
    local -a argOnlyList_lcl
    local -A argOnlyMap_lcl

    args_Get "$optsArgList_ref" "$optsArgMap_ref" 'argOnlyList_lcl' 'argOnlyMap_lcl'
    # remove the last element in the array, as that's the target
    unset argOnlyList_lcl[${#argOnlyList_lcl[@]}-1]
    local ix_arg
    for (( ix_arg=0; ix_arg < ${#argOnlyList_lcl[@]}; ix_arg++ ))
    do 
      local argSource="${argOnlyMap_lcl["${argOnlyList_lcl[$ix_arg]}"]}"
      eval $argSourceList_ref\+\=\( \"\$argSource\" \)
    done
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Given a list of options and arguments, select only the single target
  ##    argument value that appears as the last/rightmost argument on the 
  ##    command line.
  ##
  ##  Input:
  ##    $1 - Variable name representing the array of all options 
  ##         and arguments names in the order encountered on the command line.
  ##    $2 - Variable name representing an associative map of all
  ##         option and argument values keyed by the option/argument names.
  ##    $3 - Variable name representing an array which will contain
  ##         only the singlet target argument value.
  ##
  ###############################################################################
  arg_target_Get(){
    local -r optsArgList_ref="$1"
    local -r optsArgMap_ref="$2"
    local -r argTarget_ref="$3"
    local -a argOnlyList_lcl
    local -A argOnlyMap_lcl

    args_Get "$optsArgList_ref" "$optsArgMap_ref" 'argOnlyList_lcl' 'argOnlyMap_lcl'
    local -r targetIx="${argOnlyList_lcl[ (( ${#argOnlyList_lcl[@]}-1 )) ]}"
    local -r argTarget_lcl="${argOnlyMap_lcl["$targetIx"]}"
    eval $argTarget_ref=\"\$argTarget_lcl\"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    A helper function to simply return all the argument values.
  ##
  ##  Input:
  ##    $1 - Variable name representing the array of all options 
  ##         and arguments names in the order encountered on the command line.
  ##    $2 - Variable name representing an associative map of all
  ##         option and argument values keyed by the option/argument names.
  ##    $3 - Variable name representing the array of all options 
  ##         and arguments names in the order encountered on the command line.
  ##    $4 - Variable name representing an associative map of all
  ##         option and argument values keyed by the option/argument names.
  ##
  ###############################################################################
  args_Get(){
    local -r optsArgList_ref="$1"
    local -r optsArgMap_ref="$2"
    local -r argOnlyList_ref="$3"
    local -r argOnlyMap_ref="$4"
    if ! OptionsArgsFilter "$optsArgList_ref" "$optsArgMap_ref" "$argOnlyList_ref" "$argOnlyMap_ref" '[[ "$optArg" =~ Arg[1-9][0-9]* ]]' 'true'; then
      ScriptUnwind "$LINENO" "Problem processing arguments."
    fi
  }
}
##############################################################################
##
##  Purpose:
##    Determine if source type can be copied to the desired target type.
##
##  Input:
##    $1 - Source arguments entered by the command line.
##    $2 - Target argument type determined by the target argument entered
##         on the command line.
##
##  Output:
##    When successful: Nothing - all source arguments are compatible with target.
##    Otherwise:       Message to STDERR
##
###############################################################################
arg_type_compatibility_Check(){
  local argSourceList_ref="$1"
  local argTargetType="$2"
  local typeCompatSuccess='true'
  local ix_src
  for (( ix_src=0; ix_src < ${#argSourceList[@]}; ix_src++ ))
  do
    local argSourceType
    eval local argSourceElem\=\"\$\{$argSourceList_ref\[\$ix_src\]\}\"
    arg_type_format_decide "$argSourceElem" 'argSourceType'
    if ! target_compatibility_Check "$argSourceType"; then
      ScriptError "Source type: '$argSourceType', source: '$argSourceElem', incompatible with target type: '$argTargetType'."
      typeCompatSuccess='false'
    fi
  done
  $typeCompatSuccess
}
##############################################################################
##
##  Purpose:
##    Define a unified interface for source types.  Any defined source type must
##    inherit and implement this interface.
##
###############################################################################
source_type_interface(){
  ##############################################################################
  ##
  ##  Purpose:
  ##    Create a source object from a source argument.  A source object provides
  ##    a public interface consisting of 'objRef' and 'objType' properties,
  ##    other private properties and implementation of the interface methods
  ##    below needed to transform a source argument into a reference needed
  ##    by the docker cp command.
  ##
  ##  Input:
  ##    $1 - Variable name representing an associative map of all
  ##         option and argument values keyed by the option/argument names.
  ##    $2 - The value of a source argument.
  ##    $3 - Variable name representing an associative map to
  ##         persist both public and private property values.
  ##
  ##  Output:
  ##    $3 - An updated associative map containig values for 
  ##         both public and private property values.
  ##
  ###############################################################################
  source_obj_Create(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Return the source object/argument type.
  ##
  ##  Input:
  ##    $1 - Variable name to receive type value string.
  ##
  ##  Output:
  ##    $1 - Updated to reflect the type value string.
  ##
  ###############################################################################
  source_obj_type_Get(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Return a source docker cp argument.
  ##
  ##  Input:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##    $2 - A variable name that will be assigned the docker cp argument value.
  ##
  ##  Output:
  ##    $2 - Updated to reflect the docker cp argument value.
  ##
  ###############################################################################
  source_obj_docker_arg_Get(){
    AssociativeMapAssignIndirect "$1" 'objRef' "$2"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Liberate any resources held by the source object/argument type.
  ##
  ##  Input:
  ##    $1 - Variable name representing the associative map constructed
  ##         by the source_obj_Create method.
  ##
  ###############################################################################
  source_obj_Release(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
}
##############################################################################
##
##  Purpose:
##    Inherit the source_type_interface and define default implementation
##    for source types already supported by docker cp.
##
###############################################################################
source_type_simple(){
  source_type_interface
  source_obj_Create(){
    local -r sourceArg="$2"
    local -r sourceObj_ref="$3"
    eval $sourceObj_ref\[objRef\]\=\"\$sourceArg\"
    local objType
    source_obj_type_Get 'objType'
    local -r objType
    eval $sourceObj_ref\[objType\]\=\"\$objType\"
  }
  source_obj_type_Get(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  source_obj_Release(){
    true
  }
}
##############################################################################
##
##  Purpose:
##    Create a unified interface for target types.  Any defined target type must
##    inherit and implement this interface.
##
###############################################################################
target_type_interface(){
  target_compatibility_Check(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Create a target object from a target argument.  A target object provides
  ##    a public interface consisting of 'objRef' and 'objType' properties,
  ##    other private properties and implementation of the interface methods
  ##    below needed to transform a target argument into a reference needed
  ##    by the docker cp command.
  ##
  ##  Input:
  ##    $1 - Variable name representing an associative map of all
  ##         option and argument values keyed by the option/argument names.
  ##    $2 - The value of a target argument.
  ##    $3 - Variable name representing an associative map to
  ##         persist both public and private property values.
  ##
  ##  Output:
  ##    $3 - An updated associative map containig values for 
  ##         both public and private property values.
  ##
  ###############################################################################
  target_obj_Create(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Return the target object/argument type.
  ##
  ##  Input:
  ##    $1 - Variable name to receive type value string.
  ##
  ##  Output:
  ##    $1 - Updated to reflect the type value string.
  ##
  ###############################################################################
  target_obj_type_Get(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Return a target docker cp argument.
  ##
  ##  Input:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##    $2 - A variable name that will be assigned the docker cp argument value.
  ##
  ##  Output:
  ##    $2 - Updated to reflect the docker cp argument value.
  ##
  ###############################################################################
  target_obj_docker_arg_Get(){
    AssociativeMapAssignIndirect "$1" 'objRef' "$2"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Determine if target options were specified that aren't supported by 
  ##    the targeted object.
  ##
  ##  Input:
  ##    $1 - Variable name representing the associative map constructed
  ##         by the target_obj_Create method.
  ##    $2 - Variable name representing the array of all options 
  ##         and arguments names in the order encountered on the command line.
  ##    $3 - Variable name representing an associative map of all
  ##         option and argument values keyed by the option/argument names.
  ##    $4 - Variable name to potentially return error message
  ##
  ##  Output:
  ##    When error:
  ##      Assign error message to $4 and return.
  ##
  ###############################################################################
  target_obj_arg_options_Check(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Does the target argument accept data from multiple sources.
  ##
  ##  Input:
  ##    $1 - This pointer - associative map variable name of the type that 
  ##         supports this interface.
  ##    $2 - A variable name that accepts a message explaining a detected
  ##         incompatibility.
  ##
  ##  Output:
  ##    When success: Nothing.
  ##    Otherwise: $2 - Updated with incompatibility reason.
  ##
  ###############################################################################
  target_obj_arg_PermitsMultiSource(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    After a successful copy, perform additional processing required to
  ##    complete the copy operation.
  ##
  ##  Input:
  ##    $1 - Variable name representing the associative map constructed
  ##         by the target_obj_Create method.
  ##    $2 - Variable name representing the array of all options 
  ##         and arguments names in the order encountered on the command line.
  ##    $3 - Variable name representing an associative map of all
  ##         option and argument values keyed by the option/argument names.
  ##
  ###############################################################################
  target_obj_Commit(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    Liberate any resources held by the target object/argument type.
  ##
  ##  Input:
  ##    $1 - Variable name representing the associative map constructed
  ##         by the target_obj_Create method.
  ##
  ###############################################################################
  target_obj_Release(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  ##############################################################################
  ##
  ##  Purpose:
  ##    When possible, revert to prior state.  Assumes error occurred befor
  ##    target_obj_Commit executed.
  ##
  ##  Input:
  ##    $1 - Variable name representing the associative map constructed
  ##         by the target_obj_Create method.
  ##
  ###############################################################################
  target_obj_Rollback(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
}
##############################################################################
##
##  Purpose:
##    Inherit the target_type_interface and define default implementation
##    for target types already supported by docker cp.
##
###############################################################################
target_type_simple(){
  target_type_interface
  target_compatibility_Check(){
    local typeName="$1"
    if   [ "$typeName" == 'imagefilepath' ]     \
      || [ "$typeName" == 'containerfilepath' ]; then
      return
    fi
    false
  }
  target_obj_Create(){
    local -r targetArg="$2"
    local -r targetObj_ref="$3"
    eval $targetObj_ref\[objRef\]\=\"\$targetArg\"
    local objType
    target_obj_type_Get 'objType'
    local -r objType
    eval $targetObj_ref\[objType\]\=\"\$objType\"
  }
  target_obj_type_Get(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
  target_obj_arg_options_Check(){
    # simple targets currently have no options.
    local targetTypeName
    target_obj_type_Get 'targetTypeName'
    target_arg_only_options_Exclude "$2" "$3" "$targetTypeName" '' "$4"
  }
  target_obj_arg_PermitsMultiSource(){
    ref_simple_value_Set "$errorMess_ref" "Target does not support more than one source."
    false
  }
  target_obj_Commit(){
    true
  }
  target_obj_Release(){
    true
  }
  target_obj_Rollback(){
    true
  }
}
##############################################################################
##
##  Purpose:
##    Inherit and define source and target type interfaces for the stream
##    type.
##
###############################################################################
source_type_stream(){
  source_type_simple
  source_obj_type_Get(){
    eval $1\=\'\stream\'
  }
}
###############################################################################
target_type_stream(){
  target_type_simple
  target_obj_type_Get(){
    eval $1\=\'\stream\'
  }
}
##############################################################################
##
##  Purpose:
##    Inherit and define source and target type interfaces for the
##    file path type.
##
###############################################################################
source_type_filepath(){
  source_type_simple
  source_obj_type_Get(){
    eval $1\=\'\filepath\'
  }
}
###############################################################################
target_type_filepath(){
  target_type_simple
  target_obj_type_Get(){
    eval $1\=\'\filepath\'
  }
  target_obj_arg_PermitsMultiSource(){
    local -r this_ref="$1"
    local -r errorMess_ref="$2"
    local hostFilePath
    target_obj_docker_arg_Get "$this_ref" 'hostFilePath'
    local -r hostFilePath
    if ! [ -d "$hostFilePath" ]; then
      ref_simple_value_Set "$errorMess_ref" "Multiple sources require target to be an existing directory."
      false
    fi
  }
}
##############################################################################
##
##  Purpose:
##    Inherit and define source and target type interfaces for the container
##    file path type.
##
###############################################################################
source_type_containerfilepath(){
  source_type_simple
  source_obj_type_Get(){
    eval $1\=\'\containerfilepath\'
  }
}
###############################################################################
target_type_containerfilepath(){
  target_type_simple
  target_compatibility_Check(){
    type_valid_AllIs "$1"
  }
  target_obj_type_Get(){
    eval $1\=\'\containerfilepath\'
  }
  target_obj_arg_PermitsMultiSource(){
    local -r this_ref="$1"
    local -r errorMess_ref="$2"
    local containerFilePath
    target_obj_docker_arg_Get "$this_ref" 'containerFilePath'
    local -r containerFilePath
    if ! container_filepath_IsDir "$containerFilePath"; then
      ref_simple_value_Set "$errorMess_ref" "Multiple sources require target to be an existing directory."
      false
    fi
  }
}
##############################################################################
##
##  Purpose:
##    Inherit and define source and target type interfaces for the image
##    file path type.
##
###############################################################################
source_type_imagefilepath(){
  source_type_interface
  source_obj_Create(){
    local -r optArgMap_ref="$1"
    local -r sourceArg="$2"
    local -r sourceObj_ref="$3"

    local nameResolveReg
    AssociativeMapAssignIndirect "$optArgMap_ref" '--ucpchk-reg' 'nameResolveReg'
    local -r nameResolveReg
    local imageNameUUID
    local imageFilePath
    image_nameUUID_filepath_Extract "$sourceArg" 'imageNameUUID' 'imageFilePath'
    local -r imageFilePath
    # source image must exist.
    local imageNmRepoIs
    if ! image_normalized_label_instance_Exists "$imageNameUUID" "$nameResolveReg" 'imageNameUUID' 'imageNmRepoIs'; then
      ScriptUnwind "$LINENO" "SOURCE image must exist. Could not locate: '$imageNameUUID'."
    fi
    local -r imageNmRepoIs
    local -r imageNameUUID
    # create a container from the source image.
    local sourceContainer
    local entryptNullify
    image_container_Create "$imageNameUUID" 'sourceContainer' 'entryptNullify'
    local -r sourceContainer
    local -r entryptNullify
    local -r sourceRef="${sourceContainer}:${imageFilePath}"
    # update source object standard properties.
    eval $sourceObj_ref\[objRef\]\=\"\$\sourceRef\"
    eval $sourceObj_ref\[objType\]\=\'imagefilepath\'
    # update source object derived properties.
    eval $sourceObj_ref\[sourceContainer\]\=\"\$sourceContainer\"
  }
  source_obj_docker_arg_Get(){
    AssociativeMapAssignIndirect "$1" 'objRef' "$2"
  }
  source_obj_type_Get(){
    eval $1\=\'\imagefilepath\'
  }
  source_obj_Release(){
    local -r sourceObj_ref="$1"
    eval local \-r sourceContainer\=\"\$\{$sourceObj_ref\[sourceContainer\]\}\"
    docker rm $sourceContainer>/dev/null
  }
}
###############################################################################
target_type_imagefilepath(){
  target_type_interface
  target_compatibility_Check(){
    type_valid_AllIs "$1"
  }
  target_obj_Create(){
    local -r optArgMap_ref="$1"
    local -r targetArg="$2"
    local -r targetObj_ref="$3" 
    # search for target image
    local nameResolveReg
    AssociativeMapAssignIndirect "$optArgMap_ref" '--ucpchk-reg' 'nameResolveReg'
    eval $targetObj_ref\[ImageIsNew\]\=\"\false\"
    local imageNameUUID
    local imageFilePath
    image_nameUUID_filepath_Extract "$argTarget" 'imageNameUUID' 'imageFilePath'
    local imageNmRepoIs
    if ! image_normalized_label_instance_Exists "$imageNameUUID" "$nameResolveReg" 'imageNameUUID' 'imageNmRepoIs'; then
      # target image doesn't exist create new image.
      image_Create "$imageNameUUID"
      eval $targetObj_ref\[ImageIsNew\]\=\"\true\"
    fi
    # convert image into container.
    local targetContainer
    local entryPtCurrent
    image_container_Create "$imageNameUUID" 'targetContainer' 'entryPtCurrent'
    local -r targetContainer
    local -r entryptNullify
    # update target object standard properties.
    eval $targetObj_ref\[objRef\]\=\"\$\{targetContainer\}\:\$\{imageFilePath\}\"
    eval $targetObj_ref\[objType\]\=\'imagefilepath\'
    # update target object derived properties.
    eval $targetObj_ref\[targetContainer\]\=\"\$targetContainer\"
    eval $targetObj_ref\[entryPtCurrent\]\=\"\$entryPtCurrent\"
    if $imageNmRepoIs; then
      eval $targetObj_ref\[imageName\]\=\"\$imageNameUUID\"
    fi
  }
  target_obj_type_Get(){
    eval $1\=\'\imagefilepath\'
  }
  target_obj_Commit(){
    local -r targetObj_ref="$1"
    local -r optArgList_ref="$2"
    local -r optArgMap_ref="$3"
    local -a dockerCommitOptList
    local -A dockerCommitOptMap
    if ! OptionsArgsFilter "$optArgList_ref" "$optArgMap_ref" 'dockerCommitOptList' 'dockerCommitOptMap' "$IMAGE_OPTION_FILTER" 'true'; then
      ScriptUnwind "$LINENO" "Problem filtering options for docker commit."
    fi
    local dockerCommitOpt=''
    if (( ${#dockerCommitOptList[@]} > 0 )); then
      if ! dockerCommitOpt="$( OptionsArgsGen 'dockerCommitOptList' 'dockerCommitOptMap' )"; then
        ScriptUnwind "$LINENO" "Problem generating options for docker commit."
      fi
    fi
    local -r dockerCommitOpt
    eval local \-r targetContainer\=\"\$\{$targetObj_ref\[targetContainer\]\}\"
    eval local \-r entryPtCurrent\=\"\$\{$targetObj_ref\[entryPtCurrent\]\}\"
    eval local \-r imageName\=\"\$\{$targetObj_ref\[imageName\]\}\"
    eval docker commit $entryptNullify $dockerCommitOpt \$targetContainer \$imageName
  }
  target_obj_arg_options_Check(){
    local imageFilePathType
    target_obj_type_Get 'imageFilePathType'
    target_arg_only_options_Exclude "$2" "$3" "$imageFilePathType" "$IMAGE_OPTION_FILTER" "$4"
  }
  target_obj_arg_PermitsMultiSource(){
    local -r this_ref="$1"
    local -r errorMess_ref="$2"
    local containerFilePath
    target_obj_docker_arg_Get "$this_ref" 'containerFilePath'
    local -r containerFilePath
    if container_filepath_IsDir "$containerFilePath"; then
      ref_simple_value_Set "$errorMess_ref" "Multiple sources require target to be an existing directory."
      false
    fi
  }
  target_obj_Release(){
    local -r targetObj_ref="$1"
    eval local \-r targetContainer\=\"\$\{$targetObj_ref\[targetContainer\]\}\"
    # remove the container from which the image was committed.
    docker rm $targetContainer>/dev/null
  }
  target_obj_Rollback(){
    local -r targetObj_ref="$1"
    target_obj_Release "$targetObj_ref"
    eval local \-r imageIsNew\=\"\$\{$targetObj_ref\[ImageIsNew\]\}\"
    if $imageIsNew; then 
      eval local \-r imageName\=\"\$\{$targetObj_ref\[imageName\]\}\"
      docker rmi $imageName >/dev/null
    fi
  }
}
##############################################################################
##
##  Purpose:
##    For all know types return true.
##
##  Input:
##    $1  - Type name string.
##
##  When success:
##    The input type matches one of the tested for types.
##
###############################################################################
type_valid_AllIs(){
  local typeName="$1"
  if   [ "$typeName" == 'imagefilepath' ]     \
    || [ "$typeName" == 'containerfilepath' ] \
    || [ "$typeName" == 'stream' ]            \
    || [ "$typeName" == 'filepath' ]; then
    return
  fi
  false
}
##############################################################################
##
##  Purpose:
##    Process command option/argument list and map to identify  entries
##    that aren't supported by the target argument.
##
##  Input:
##    $1 - Variable name representing the array of all options 
##         and arguments names in the order encountered on the command line.
##    $2 - Variable name representing an associative map of all
##         option and argument values keyed by the option/argument names.
##    $3 - Target type name string.
##    $4 - Option argument filter defining all valid options for a given
##         target type.
##    $5 - Variable name to potentially return error message
##
##  Output:
##    When success: nothing.
##    Otherwise:    $3 - set to error message.
##
###############################################################################
target_arg_only_options_Exclude(){
  local -r optArgList_ref="$1"
  local -r optArgMap_ref="$2"
  local -r targetTypeName="$3"
  local -r targetTypeOptsAllowFilter="$4"
  local -r errorMessage_ref="$5"
  local -a targetOnlyOptArgList
  local -A targetOnlyOptArgMap
  # remove source only options and any arguments.
  if ! OptionsArgsFilter "$optArgList_ref" "$optArgMap_ref" 'targetOnlyOptArgList' 'targetOnlyOptArgMap' "$NON_SOURCE_NON_TARGET_ONLY_OPTIONS_ARGS" 'false'; then
    ScriptUnwind "$LINENO" "Problem filtering target only options and arguments."
  fi
  if (( ${#targetOnlyOptArgList[@]} < 1 )); then
    # all options were source only options
    return
  fi
  # remove expected target options.
  local -a targetOnlyOptArgListResult
  local -A targetOnlyOptArgMapResult
  if [ -n "$targetTypeOptsAllowFilter" ] && ! OptionsArgsFilter 'targetOnlyOptArgList' 'targetOnlyOptArgMap' 'targetOnlyOptArgListResult' 'targetOnlyOptArgMapResult' "$targetTypeOptsAllowFilter" 'false'; then
    ScriptUnwind "$LINENO" "Problem filtering target type: '$targetTypeName' specific options."
  fi
  if (( ${#targetOnlyOptArgListResult[@]} > 0 )); then
    local -r unsupportedOptions="$( OptionsArgsGen 'targetOnlyOptArgListResult' 'targetOnlyOptArgMapResult' )"
    ref_simple_value_Set "$errorMessage_ref" "Unsupported options: '$unsupportedOptions' specified for TARGET type: '$targetTypeName'"
    return 1
  fi
}
##############################################################################
##
##  Purpose:
##    Determine the copy strategy to execute given the source and target
##    types.  
##
##  Input:
##    $1 - Type of source argument.
##    $2 - Source argument format accepted by docker cp
##    $3 - Type of target argument.
##    $4 - Target argument format accepted by docker cp
##
###############################################################################
cp_strategy_Exec(){
  local -r sourceType="$1"
  local -r sourceArgDockercp="$2"
  local -r targetType="$3"
  local -r targetArgDockercp="$4"

  # generally apply the 'simple' copy strategy
  local copyStrategy='cp_simple'
  if  ( [ "$sourceType" == 'containerfilepath' ] \
    ||  [ "$sourceType" == 'imagefilepath' ] )   \
    &&
      ( [ "$targetType" == 'containerfilepath' ] \
    ||  [ "$targetType" == 'imagefilepath' ] ); then
    # both source and target types are either containers/images :: apply
    # 'complex' strategy.
    local copyStrategy='cp_complex'
  fi
  local -r copyStrategy     
  $copyStrategy "$sourceArgDockercp" "$targetArgDockercp"
}
##############################################################################
##
##  Purpose:
##    Use the typical docker cp command to copy a source object to
##    the target one.
##
##  Input:
##    $1 - Source argument format accepted by docker cp
##    $2 - Target argument format accepted by docker cp
##
##  Output:
##    When successful:
##      nothing.
##    When failure:
##      STDERR reflects docker cp messages. 
##
###############################################################################
cp_simple(){
  local -r sourceArgDocker="$1"
  local -r targetArgDocker="$2"

  eval docker cp \"\$sourceArgDocker\" \"\$targetArgDocker\" \>\/dev\/null
}
##############################################################################
##
##  Purpose:
##    Copy from a source object representing a container to a target
##    object representing a container.  Copy attempts to employ
##    stream interface but if it fails, because the target directory doesn't
##    exist, it then executes a more expensive transfer which requires
##    copying the source object to the file system associated to this process
##    and then forward the contents of this local copy to the target.  
##
##  Input:
##    $1 - Source object map providing following interface:
##         'objRef' - provides the container file path
##    $2 - Target object map providing following interface:
##         'objRef' - provides the container file path
##
##  Output:
##    When successful:
##      nothing.
##    When failure:
##      STDERR reflects docker cp messages. 
##
###############################################################################
cp_complex(){
  local -r sourceArgDocker="$1"
  local -r targetArgDocker="$2"

  docker_stream_Copy(){
    local -r sourceArgDocker="$1"
    local -r targetArgDocker="$2"
    set -o pipefail
    # redirect first set of errors to null device. This prevents displaying 'write /dev/stdout: broken pipe' message
    # when target isn't valid.  It also silences other messages concerning the source.  However, since there's
    # only one error message that can be recovered from and it is issued by the second docker cp command,
    # these other messages can be safely ignored as the return code will reflect any failure in the pipleline.
    # not meant to be used outside its enclosing function.
    docker cp "$sourceArgDocker" - 2>/dev/null | docker cp - "$targetArgDocker"
  }
  if dockedMsg="$(docker_stream_Copy "$sourceArgDocker" "$targetArgDocker" 2>&1 )"; then
    return
  fi
  if ! [[ $dockedMsg =~ ^destination.+must.be.a.directory ]]; then
    echo "$dockedMsg">&2
    ScriptUnwind "$LINENO" "Unexpected failure detected during streamed,piped docker cp from: '$sourceArgDocker', to: '$targetArgDocker'."
  fi
  # unable to stream, convert into two simpler docker cp commands.
  # doing so requires temporarily copying the source then deleting
  # the copy.
  local    tmpHostRefTarget="$HOST_FILE_ROOT/$$/$sourceArgDocker"
  local -r tmpHostRefSource="$tmpHostRefTarget"
  if [ "${sourceArgDocker:${#sourceArgDocker}-2}" == '/.' ]; then
    tmpHostRefTarget="${tmpHostRefTarget:0:-2}"
  fi
  local -r tmpHostRefTarget
  rm -rf "$tmpHostRefTarget">/dev/null 2>/dev/null || true
  if ! mkdir -p "$( dirname "$tmpHostRefTarget" )">/dev/null; then
    ScriptUnwind "$LINENO" "rm failed for: '$tmpHostRefTarget'."
  fi
  if ! docker cp "$sourceArgDocker" "$tmpHostRefTarget">/dev/null; then
    ScriptUnwind "$LINENO" "docker cp '$sourceArgDocker', '$tmpHostRefTarget'."
  fi
  if ! docker cp "$tmpHostRefSource" "$targetArgDocker">/dev/null; then
    ScriptUnwind "$LINENO" "docker cp '$tmpHostRefSource', '$targetArgDocker'."
  fi
  if ! rm -rf "$tmpHostRefTarget">/dev/null; then
    ScriptUnwind "$LINENO" "rm failed for: '$tmpHostRefTarget'."
  fi
}
#TODO: if not necessary, remove
#cp_strategy_failure_Mess(){
  #  local -r argSourceObj_ref="$1"
  #  local -r argTargetObj_ref="$2"
  #  local argSourceType
  #  source_obj_type_Get 'argSourceType'
  #local argPathSource
  #source_obj_docker_arg_Get "$argSourceObj_ref" 'argPathSource'
  #local argPathTarget
  #target_obj_docker_arg_Get "$argTargetObj_ref" 'argPathTarget'
  #ScriptError "Copy failure source type: '$argSourceType', source: '$argPathSource', target type: '$argTargetType', target: '$argPathTarget'."
#}

##############################################################################
##
##  Purpose:
##    Determine the argument type by examining its format.
##
##  Input:
##    $1 - A SOURCE or TARGET command line argument.
##    $2 - A variable name to return the decided type.
##    
##  Output:
##    When Success:
##    $2 Reference assigned the decided type:
##      'stream', 'imagefilepath', 'containerimagefilepath', or 'filepath'.
##
###############################################################################
arg_type_format_decide() {
  local -r arg="$1"
  local -r typeName_ref="$2"

  while true; do
    if [ "$arg" == '-' ]; then
      typeName='stream'
      break
    fi
    if [ "${arg:0:1}" == '/' ] || [ "${arg:0:1}" == '.' ]; then 
      typeName='filepath'
      break
    fi
    if [[ $arg =~ ${REG_EX_REPOSITORY_NAME_UUID}::.*$ ]]; then
      typeName='imagefilepath'
      break
    fi
    if [[ $arg =~ ${REG_EX_CONTAINER_NAME_UUID}:.*$ ]]; then 
      typeName='containerfilepath'
      break
    fi
    if [ -n "$arg" ]; then 
      typeName='filepath'
      break
    fi
    return 1
  done
  eval $typeName_ref\=\$typeName
  return 0
}
##############################################################################
##
##  Purpose:
##    Determine if a container path refers to a directory.
##
##  Input:
##    $1 - Docker container path format accepted by docker cp command.
##
##  Output:
##    When success:
##       Container path refers to an existing directory
##
###############################################################################
container_filepath_IsDir(){
  local containerFilePath="$1"
  [[ $containerFilePath =~ $REG_EX_CONTAINER_NAME_UUID(:.*) ]]
  if (( ${#BASH_REMATCH[1]} < 3 )); then
    # optimization when referring to root directory
    if [ "${containerFilePath:(-1)}" == ':' ] ||  [ "${containerFilePath:(-1)}" == '/' ]; then
      true
      return
    fi
  fi
  if [ "${containerFilePath:(-2)}" != '/,' ]; then
    containerFilePath+='/.'
  fi
  local -r containerFilePath
  docker cp "$containerFilePath" - >/dev/null 2>/dev/null
}

##############################################################################
##
##  Purpose:
##    Extract the image name/UUID from its concatenated 'imagefilepath'.
##
##  Assumes:
##    A two '::' separate the image name/uuid from file path.
##
##  Input:
##    $1 - A name/UUID delimited by '::' from a concatenated file path.
##    $2 - A variable name to receive just the name or UUID portion.
##    $3 - A varialbe name to receive just the file path portion.
##    
##  Output:
##    When Success:
##    $2 - Updated variable whose value reflects only the image name/UUID.
##    $3 - Updated arialbe whose value reflects only the file path portion.
##
###############################################################################
image_nameUUID_filepath_Extract(){
  local -r nameUUIDfilepath="$1"
  local -r nameUUIDvalue_ref="$2"
  local -r filepathvalue_ref="$3"

  [[ $nameUUIDfilepath =~ (${REG_EX_REPOSITORY_NAME_UUID})::(.*$) ]]
  if [ -z "${BASH_REMATCH[1]}" ]; then
    ScriptUnwind "$LINENO" "Extraction of image name/UUID failed. Arg Value: '${BASH_REMATCH[1]}', RegEx: '$REG_EX_REPOSITORY_NAME_UUID'."
  fi
  eval $nameUUIDvalue_ref=\"\$\{BASH_REMATCH\[\1\]\}\"
  eval $filepathvalue_ref=\"\$\{BASH_REMATCH\[\6\]\}\"
  return 0
}
##############################################################################
##
##  Purpose:
##    Determine the existance of name/UUID for the specified Docker image.
##    If a partial UUID was specified, then extend it to reflect the complete
##    UUID.
##
##  Assumes:
##    Input label conforms to either image repository or image UUID format.
##
##  Input:
##    $1 - An image name or potential UUID.  
##    $2 - Extent scope of image name resolution to a registry:
##         'true' - scope includes registry.
##         'false'- limit scope to the local Docker repository.
##    $3 - A variable name to receive the normalized image name/UUID.  An
##         image repository name is already normalized, so this value will
##         simply reflect what was passed in by $1.  However, a partial
##         UUID will be extended to reflect a complete UUID.
##    $4 - A variable to receive a value that determines if $1 is a
##         repository name.  
## 
##  Output:
##    $2 - Updated variable containes normalized name.
##    $3 - Updated variable value:
##         'true' - $1 is a considered a repository name.
##         'false'- $1 is an existing UUID.
##    Return code:
##      0 - 'true' - The image name or UUID exists.
##      1 - 'false'- Image doesn't exist.
##
###############################################################################
image_normalized_label_instance_Exists(){
  local -r nameUUID="$1"
  local -r nameResolveReg="$2"
  local -r normName_ref="$3"
  local -r imageNmRepoIs_ref="$4"

  local existImage='false'
  local repoNameIs='false'
  local normName
  local argUUIDis
  if image_Search "$nameUUID" "$nameResolveReg" 'argUUIDis' 'normName'; then
    existImage='true'
    if ! $argUUIDis; then
      # image name/UUID is a name.
      local -r normName="$nameUUID"
      repoNameIs='true'
    fi
    local -r repoNameIs
  else
    local -r normName="$nameUUID"
    local -r repoNameIs='true'
  fi
  eval $normName_ref\=\"\$normName\"
  eval $imageNmRepoIs_ref\=\"\$repoNameIs\"
  $existImage
}
##############################################################################
##
##  Purpose:
##    Search repository image name and UUID name spaces for the given label.
##
##  Notes:
##    > Since the UUID and repository name, name spaces intersect, 
##      it's easy to impersonate an image UUID by crafting a repository name
##      that mimics a UUID.  At this time 11/2015 Docker doesn't provide a 
##      a mechanism to specify a resolution name space for an argument.
##
##  Input:
##    $1 - An image name or full/partial UUID.
##    $2 - A boolean value that determines the scope of the search.
##         'true' - scope includes a pull from the connected registry.
##         'false'- scope limited to Docker Engine's local repository.
##    $3 - A variable name to contain:
##         'true' -  $1 is most likely a UUID
##         'false' - $1 is a repository name
##    $4 - A variable name to contain the image's full UUID 
##
##  Output:
##    When success:
##      $3 - Variable indicates if $1 is or isn't UUID.
##      $4 - Variable assigned full UUID value.
##    When failure:
##      $3 - Variable value at call unchanged.
##      $4 - Variable value at call unchanged..
##
##  Return code:
##    0 - 'true' - The image name or UUID exists.
##    1 - 'false'- Image doesn't exist.
##
###############################################################################
image_Search(){
  local -r imageNameUUID="$1"
  local    nameResolveReg="$2"
  local -r argIsUUID_ref="$3"
  local -r UUIDout_ref="$4"
  local msgOut
  local UUIDout_lcl=''
  local argIsUUID_lcl='false'
  while true; do
    if msgOut="$(docker inspect --type=image --format='{{ .Id }}' -- $imageNameUUID 2>&1;)"; then
      if [[ $imageNameUUID =~ $REG_EX_UUID ]] && [ "$imageNameUUID" == "${msgOut:0:${#imageNameUUID}}" ]; then 
        # string of hexidecimal characters and partial/full match when comparing the returned
        # image UUID to the supplied argument value :: high confidence source argument is a UUID
        # return the full UUID.
        local -r argIsUUID_lcl='true'
      fi
      # high confidence supplied reference was a repository name.
      local -r UUIDout_lcl="$msgOut"
      break
    fi
    if ! [[ $msgOut =~ ^Error:.No.such.image ]]; then
      ScriptUnwind "$LINENO" "Unexpected failure: '$msgOut' from 'docker inspect' when testing for image with name/UUID: '$imageNameUUID'."
    fi
    # hopefully, calling agent knows that the provide refernece is a valid repository name,
    # however, if UUID was specified it will most likely not be be found when pulling from hub.  
    if $nameResolveReg && docker pull $imageNameUUID 2>&1 >/dev/null; then
      # prevent infinite loop when things go wrong
      local -r nameResolveReg='false'
      continue
    fi
    false
    return
  done
  eval $argIsUUID_ref\=\"\$argIsUUID_lcl\"
  eval $UUIDout_ref\=\"\$UUIDout_lcl\"
}
##############################################################################
##
##  Purpose:
##    Convert an image to a container.  As a container, the image can be
##    copied to/from using docker cp command introduced in 1.8.
##
##  Input:
##    $1 - Existing image name or image UUID.
##    $2 - A variable to contain the resulting container UUID created from
##         the given image.
##    $3 - A variable to contain ENTRYPOINT nullify directive.  If the image
##         lacks an ENTRYPOINT or CMD, a pseudo one is created to permit the
##         docker create to successfully complete.  However, to consistently
##         maintain this property value in the newly derived image,
##         the ENTRYPOINT must be nullified.  This variable records, if 
##         necessary, the nullify directive.
##
##  Output:
##    $2 - Variable updated to reflect newly created container UUID.
##    $3 - Variable updated to ENTRYPOINT directive.
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
  eval $entryptNullify_ref\=\"\$entryptNullify_lcl\"
  eval $targetContainer_ref\=\"\$targetContainer_lcl\"
}
##############################################################################
##
##  Purpose:
##    Create an new image from 'scratch'.  'scratch' generates a default
##    file system.
##
##  Input:
##    $1 - Image name.
##
##  Output:
##    A new image exists in the local repository with the repository name of $1.
##    STDOUT - suppressed.
##
###############################################################################
image_Create() {
  local -r imageNameUUID="$1"

  dockerfile_stream(){
    echo "FROM scratch"
    # Set the working directory to root.  Innocoulus, so
    # default file system is established for an empty container.
    # Unfortunately, it consumes a layer.
    echo "WORKDIR /"
  }
  # run a docker build to produce a default container - scratch is not completely empty.
  # suppress messages written to STDOUT and always, even if an error, remove intermediate containers
  if ! docker build --force-rm -t $imageNameUUID - >/dev/null < <(dockerfile_stream); then
    ScriptUnwind "$LINENO" "Build failed creating new version of destination image for: '$imageNameUUID'"
  fi
}
FunctionOverrideCommandGet
source "ArgumentsMainInclude.sh";
###############################################################################
# 
# The MIT License (MIT)
# Copyright (c) 2015-2016 Richard Moyse License@Moyse.US
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
