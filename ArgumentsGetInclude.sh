#!/bin/bash
###############################################################################
##
##  Purpose:
##    Parse command line arguments into an associative array and preserve their
##    positioning via a regular array.  There are essentially two
##    classes of arguments: options and arguments.  Options control behavior
##    while arguments identify the objects as targets of a command
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its descendants.
##
##  Input:
##    $1 - Variable name to a standard array containing the option/argument
##         values passed from the command line.
##    $2 - Variable name to standard array which will contain 
##         associative array keys ordered by their position
##         in command line.
##    $3 - Variable name to associative array which will contain
##         argument values and be keyed by either the option
##         label or "ArgN" for arguments that don't immediately
##         follow an option.  Where "N" is the argument's position
##         relative to other arguments.
##    $4 - (optional or '') Variable name to a standard array enumerating
##         options that can be used more than once on the command line.
##    $5 - (optional or '') Token type to assign to a single - surrounded
##         by whitespace.  
## 
##  Output:
##    $2 - Variable name to standard array which will contain 
##         associative array keys ordered by their position
##         in command line.
##    $3 - associative array which will contain
##         argument values and be keyed by either the option
##         label or "ArgN" for arguments that don't immediately
##         follow an option.
##
##  Return Code:     
##    When Failure: 
##      Indicates unknown parse state or token type.
##
###############################################################################
function ArgumentsParse () {
  local -r cmmdLnArgListNm="$1"
  local -r argumentListNm="$2"
  local -r argumentMapNm="$3"
  local -A optionRepeatMap
  local optionRepeatCheckFun=''
  if [ -n "$4" ]; then
    OptionRepeatMapInit 'optionRepeatMap' "$4"
  fi
  if (( ${#optionRepeatMap[@]} > 0 )); then
    optionRepeatCheckFun='OptionRepeatCheck optionRepeatMap optionName'
  fi
  local -r optionRepeatCheckFun
  local singleDashTokenClass='BeginArgs'
  if [ "$5" == 'Argument' ]; then singleDashTokenClass='Argument'; fi
  local -r singleDashTokenClass
  eval local -r tokenMaxCnt=\"\$\{\#$cmmdLnArgListNm\[\@\]\}\"
  local tokenClass
  local tokenValue
  local -i argumentCntr=1
  local -i argumentListIx=0
  local stateCurr='stateOptArg'
  local -i tokenIx
  for (( tokenIx=0 ; tokenIx < tokenMaxCnt ; ++tokenIx )); do
    eval local tokenValue=\"\$\{$cmmdLnArgListNm\[\$tokenIx\]\}\"
    TokenClass "$tokenValue" "$singleDashTokenClass" 'tokenClass'
    case "$stateCurr" in
      stateOptArg)
        if [ "$tokenClass" == 'Option' ]; then
          OptionSplit "$tokenValue" 'optionName' 'optionValue'
          $optionRepeatCheckFun
          eval $argumentMapNm\[\"\$optionName\"\]=\"\$optionValue\"
          eval $argumentListNm\[\$argumentListIx\]=\"\$optionName\"
          (( ++argumentListIx ))
          if [ -z "$optionValue" ]; then stateCurr='stateOption'; fi
        elif [ "$tokenClass" == 'Argument' ]; then
          eval $argumentMapNm\[\"Arg\$argumentCntr\"\]=\"\$tokenValue\"
          eval $argumentListNm\[\$argumentListIx\]=\"Arg\$argumentCntr\"
          (( ++argumentListIx ))
          (( ++argumentCntr ))
        elif [ "$tokenClass" == 'BeginArgs' ]; then
          stateCurr='stateArgOnly'
        else return 1; fi
        ;;
      stateOption)
        if [ "$tokenClass" == 'Option' ]; then
          OptionSplit "$tokenValue" 'optionName' 'optionValue'
          $optionRepeatCheckFun
          eval $argumentMapNm\[\"\$optionName\"\]=\"\$optionValue\"
          eval $argumentListNm\[\$argumentListIx\]=\"\$optionName\"
          (( ++argumentListIx ))
          if [ -n "$optionValue" ]; then stateCurr='stateOptArg'; fi
        elif [ "$tokenClass" == 'Argument' ]; then
          eval $argumentMapNm\[\"\$optionName\"\]=\"\$tokenValue\"
          stateCurr='stateOptArg'
        elif [ "$tokenClass" == 'BeginArgs' ]; then
          stateCurr='stateArgOnly'
        else return 1; fi      
        ;;
      stateArgOnly)
        eval $argumentMapNm\[\"Arg\$argumentCntr\"\]=\"\$tokenValue\"
        eval $argumentListNm\[\$argumentListIx\]=\"Arg\$argumentCntr\"
        (( ++argumentListIx ))
        (( ++argumentCntr ))
        ;;
      *) return 1 ;;
    esac
  done
}
###############################################################################
##
##  Purpose:
##    Examines the current token to determine its token class:
##      1. 'Option'    - an option: begins with '-' is immediately followed
##                       one or more characters that aren't whitespace.
##      2. 'BeginArgs' - end of option/begining of only arguments indicator:
##                       equals only: '--' or '-'
##      3. 'Argument'  - otherwise its considered an argument.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Input:
##    $1 - Token value: can be an entire option, argument or directive like '--' 
##    $2 - Token class assigned to a '-' surrounded by whitespace. It can be
##         configured as BeginArgs or as an 'Argument'. 
##    $3 - Variable name to return the determined class for the current token.
## 
##  Output:
##    $3 - Variable name will be assigned token class.
##
###############################################################################
function TokenClass () {
  local -r tokenValue="$1"
  local -r singleDashTokenClass="$2"
  local -r tokenClassNM="$3"
  # default classification is 'Argument'
  eval $tokenClassNM\=\'Argument\'
  if [ "${tokenValue:0:1}" == '-' ]; then
    if [ "${tokenValue}" == '--' ] ; then 
      eval $tokenClassNM\=\'BeginArgs\'
    elif [ "${tokenValue}" == '-' ]; then
      eval $tokenClassNM\=\"\$singleDashTokenClass\"
    else
      # begins with a dash but isn't just a dash :: 'Option'
      eval $tokenClassNM\=\'Option\'
    fi
  fi
}
###############################################################################
##
##  Purpose:
##    Extract option name and potentially it's associated value from token
##    classified as an option.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Input:
##    $1 - Token string.
##    $2 - Variable name that will be assigned the option's name.
##    $3 - Variable name that might contain a value.
## 
##  Output:
##    $2 - Variable name containing the option's name.
##    $3 - Variable name that might contain a value.
##
###############################################################################
function OptionSplit () {
  local -r tokenValue="$1"
  local -r optionNameNM="$2"
  local -r optionValueNm="$3"
  local -r name_np="${tokenValue%%=*}"
  local -r value_np="${tokenValue:${#name_np}+1}"
  eval $optionNameNM=\"\$name_np\"
  eval $optionValueNm=\"\$value_np\"
}
###############################################################################
##
##  Purpose:
##    Initialize map of option names that can be repeated on the command line.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its descendants.
##
##  Input:
##    $1 - Variable name referring to a bash map representing an
##         an option repeat list.  The map associates the option name
##         with its current repetition count.
##    $2 - Variable name referring to a list of options that may 
##         appear more than once on the command line.
## 
##  Output:
##    $1 - Bash map now updated to reflect the options that can repeat with
##         current occurrence count initialized to 1.
##
###############################################################################
function OptionRepeatMapInit(){
  local -r optionRepMap_ref="$1"
  local -r optionRepList_ref="$2"
  eval local \-r repLstMax\=\"\$\{\#$optionRepList_ref\[\@\]\}\"
  for (( ix=0; ix < repLstMax; ix++ )); do
    eval let $optionRepMap_ref\[\"\$\{$optionRepList_ref\[\$ix\]\}\"\]\=1
  done
}
###############################################################################
##
##  Purpose:
##    Determine if named option can be repeated.  If so, then format the option
##    name: <optionName>=<repetitionCount>.  RepetitionCount starts at 1.
##    given option named "-c" its first named occurrence would be '-c=1'
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its descendants.
##
##  Input:
##    $1 - Variable name referring to a bash map representing an
##         an option repeat list.  The map associates the option name
##         with its current repetition count.
##    $2 - Variable name referring to the option name, which includes 
##         '-' and '--' prefixes and will be applied as a key for $1 
## 
##  Output:
##    $1 - Bash map may be updated to reflect new repetition count.
##    $2 - Option name, if it appears in the map, will be renamed
##         to reflect its repetition instance.
##
###############################################################################
function OptionRepeatCheck(){
  local -r optionRepMap_ref="$1"
  local -r optionName_ref="$2"
  eval local \-r repeatTotal\=\"\$\{$optionRepMap_ref\[\"\$$optionName_ref\"\]\}\"
  if [ -z "$repeatTotal" ]; then return; fi
  eval let $optionRepMap_ref\[\"\$$optionName_ref\"\]\+\+
  eval $optionName_ref=\"\$$optionName_ref\=\$\{repeatTotal\}\"
}
###############################################################################
##
##  Purpose:
##    Given an array and corresponding map of options and arguments, 
##    produce a result array and map that are reflective of only the
##    options/arguments and their values selected by a boolean expression
##    passed as a filter to this routine.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Inputs:
##    $1 - Variable name of array containing list of option and argument labels.
##    $2 - Variable name of corresponding associative map potentially 
##         containing option/argument values.
##    $3 - Variable name of array to receive filtered list of option and
##         argument labels.  Position reflects the ordering of the original
##         array $1.
##    $4 - Variable name of map to receive the filtered option/argument values.
##    $5 - A bash boolean expression passed into this routine.  Typically
##         encapsulated in single quotes.
##         Ex: The following expression includes any option that isn't
##             a dlw option:'( [[ "$optArg"  =~ ^-[^-].*$ ]] || [[ "$optArg"  =~ ^--.*$ ]] ) && ! [[ "$optArg"  =~ ^--dlw.*$ ]]'
##    $6 - A boolean valuethat determines if the filter
##         specified by $5:
##           'true' -  When the expression evaluates to true, include the
##                     option/argument in the result.
##           'false' - When the expression evaluates to true, exclude the
##                     option/argument from the result.
## 
##  Outputs:
##    When Failure: 
##      Either it silently fails or causes a bash scripting error.
##    When Success:
##      The passed array variables $3 & $4 contain only those options matching
##      the provided filter.
##
###############################################################################
function OptionsArgsFilter () {
  local optArgListNm="$1"
  local optArgMapNm="$2"
  local optArgListMmNew="$3"
  local optArgMapNmNew="$4"
  local filterExpression="$5"
  local includeFilter="$6"
  local branchThen='true;'
  local branchElse='continue;'
  if ! $includeFilter; then
    branchThen='continue;'
    branchElse='true;'
  fi
  eval local -r optionList_np=\"\$\{$optArgListNm\[\@\]\}\"
  local optArg
  for optArg in $optionList_np
  do
    eval \i\f $filterExpression\;\ \t\h\e\n\ $branchThen \e\l\s\e $branchElse \f\i
    eval $optArgListMmNew\+\=\(\"\$optArg\"\)
    eval $optArgMapNmNew\[\"\$optArg\"\]\=\$\{$optArgMapNm\[\"\$optArg\"\]\}
  done
}
###############################################################################
##
##  Purpose:
##    Examines the provided options and arguments to normalize aliases and
##    ensure that required ones are supplied and their values are acceptable.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Inputs:
##    $1 - Callback function name:  Callback load a table that defines
##         the valid options/arguments for a command and other traits too.
##    $2 - Variable name of an e Array detailing provided options
##         and arguments.
##    $3 - Variable Name An associative array of option and argument values.
## 
##  Outputs:
##    When Failure: 
##      SYSERR - A message indicating reason for an error.
##
###############################################################################
function OptionsArgsVerify () {
  local -r callbackFunctionName="$1"
  local -r optArgListNm="$2"
  local -r optArgMapNm="$3"
  local successInd='true'
  if ! OptionsArgsAliasNormalize "$callbackFunctionName" "$optArgListNm" "$optArgMapNm"; then successInd='false'; fi
  if ! OptionsArgsRequireVerify  "$callbackFunctionName" "$optArgListNm" "$optArgMapNm"; then successInd='false'; fi
  if ! OptionsArgsValueVerify    "$callbackFunctionName" "$optArgListNm" "$optArgMapNm"; then successInd='false'; fi
  $successInd;
}
###############################################################################
##
##  Purpose:
##    Consolidate one or more option aliases for a given option to a 
##    normalized (primary) name.  If an option's normalized name and
##    its alias(es)option are specified more than once for a command,
##    this function preserves the most recent option value, the one
##    typed last, on the command line.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Inputs:
##    $1 - Callback function name.  This function must stream the table
##         which defines option argument metadata. 
##    $2 - Array detailing the provided options and arguments in the
##         order they were entered.
##    $3 - An associative array of option and argument values.
## 
##  Outputs:
##    When Success: 
##      All aliased options are converted to the given normalized names.
##
###############################################################################
function OptionsArgsAliasNormalize () {
  local callbackFunctionName="$1"
  local optArgListNm="$2"
  local optArgMapNm="$3"
  declare -A defNormMap
  if ! OptionsArgsDefNormMap "$callbackFunctionName" 'defNormMap'; then 
    ScriptUnwind "$LINENO" "Callback function: '$callbackFunctionName' failed."
  fi
  if [ ${#defNormMap[@]} -lt 1 ]; then return 0; fi
  declare remUnsetArryEntries=false
  declare -i optArgListIx=-1
  eval local -r optionList_np=\"\$\{$optArgListNm\[\@\]\}\"
  local optArgName
  for optArgName in $optionList_np
  do
    (( ++optArgListIx ))
    local defNormNm="${defNormMap["$optArgName"]}"
    if [ -z "$defNormNm" ]; then continue; fi
    local optPrimaryNmExists=false
    local -i optPrimaryNmIx=0
    eval local optionListSearch_np=\"\$\{$optArgListNm\[\@\]\}\"
    local optNmSearch
    for optNmSearch in $optionListSearch_np
    do 
      if [ "$optNmSearch" == "$defNormNm" ]; then
        optPrimaryNmExists=true
        break;
      fi
      (( ++optPrimaryNmIx ))
    done
    if $optPrimaryNmExists; then
      if [ $optArgListIx -gt $optPrimaryNmIx ]; then
        eval $optArgMapNm\[\"\$defNormNm\"\]\=\"\$\{$optArgMapNm\[\"\$optArgName\"\]\}\"
      fi
      unset $optArgListNm[$optArgListIx]
      remUnsetArryEntries=true
    else
      eval $optArgMapNm\[\"\$defNormNm\"\]\=\"\$\{$optArgMapNm\[\"\$optArgName\"\]\}\"
      eval $optArgListNm\[\$optArgListIx\]\=\"\$defNormNm\"
    fi
    unset $optArgMapNm["$optArgName"]
  done
  if $remUnsetArryEntries; then eval $optArgListNm\=\(\"\$\{$optArgListNm\[\@\]\}\"\); fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Create an associative array which maps a given option alias name to
##    its primary option name.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Inputs:
##    $1 - Callback function name.  This function must stream the table
##         which defines option/argument metadata. 
##    $2 - Bash variable name to contain alias to primary option name
##         mapping.
## 
##  Outputs:
##    When Success: 
##      $2 - Reflects all alias to primary name mappings for every option
##           defined by $1.
##    When Failure: 
##      SYSERR - A message indicating failure.
##
###############################################################################
function OptionsArgsDefNormMap () {
  local callbackFunctionName="$1"
  local defNormMapNm="$2"
  local -A argOpt_aliases
  local -r columnMapSelect=' aliases '
  local  callbackErr
  if ! OptionsArgsDefTbl "$callbackFunctionName" 'argOpt' 'callbackErr' "$columnMapSelect"; then
    ScriptUnwind "$LINENO" "Callback function: '$callbackFunctionName' failed. $callbackErr"
  fi
  local argOptName
  for argOptName in "${!argOpt_aliases[@]}"
  do
    if [ -z "${argOpt_aliases["$argOptName"]}" ]; then continue; fi
    eval set -- ${argOpt_aliases["$argOptName"]}
    while [ $# -gt 0 ]; do
      eval $defNormMapNm\[\"\$1\"\]=\"\$argOptName\"
      shift 
    done
  done
  return 0;
}
###############################################################################
##
##  Purpose:
##    Determine if all required options/arguments have been specified.  If 
##    one or more are omitted, then check to determine if a default
##    value has been specified.  If so, add the missing option/argument
##    to the parameter list.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its descendants.
##
##  Inputs:
##    $1 - Callback function name.  This function must stream 
##    $2 - Array detailing the provided options and arguments in the
##         order they were entered.
##    $3 - An associative array of option and argument values.
## 
##  Outputs:
##    When Success: 
##      Either all the required parameters were specified by the user or
##      this routine added the required ones that were defined with
##      default values.
##    When Failure: 
##      SYSOUT - A message listing the missing parameters.
##
###############################################################################
function OptionsArgsRequireVerify () {
  local -r callbackFunctionName="$1"
  local -r optArgListNm="$2"
  local -r optArgMapNm="$3"
  local -A argOpt_optArgName
  local -A argOpt_default
  local -A argOpt_presence
  local -r columnMapSelect=' optArgName default presence '
  local  callbackErr
  if ! OptionsArgsDefTbl "$callbackFunctionName" 'argOpt' 'callbackErr' "$columnMapSelect"; then
    ScriptUnwind "$LINENO" "Callback function: '$callbackFunctionName' failed. $callbackErr"
  fi
  local requiredMissing
  local errorInd=false
  for optArgNm in ${argOpt_optArgName[@]}
  do
    local presence="${argOpt_presence["$optArgNm"]}"
    if ! [ "$presence" == 'required' -o "$presence" == 'optional' ]; then 
      ScriptUnwind "$LINENO" "Invalid 'presence' value: '$presence' in command's option table.  See Callback function: '$callbackFunctionName'."
    fi
    local value
    AssociativeMapAssignIndirect "$optArgMapNm" "$optArgNm" 'value'
    if [ -n "$value" ]; then continue; fi
    #  No detectable opt/arg value :: determine if a default value exists
    if [ -n "${argOpt_default["$optArgNm"]}" ]; then
      local defaultValue="${argOpt_default["$optArgNm"]}"
      if AssociativeMapKeyExist "$optArgMapNm" "$optArgNm"; then
        # Since opt/arg exists, doesn't matter if optional/required update its null value with assigned default.
        local defaultValueWhenExist="${defaultValue#*=EXIST=}"
        if [ -n "$defaultValueWhenExist" ]; then defaultValue="$defaultValueWhenExist"; fi
        eval $optArgMapNm\[\"\$optArgNm\"\]\=\"\$defaultValue\"
      elif [ "${argOpt_presence["$optArgNm"]}" == 'required' ]; then
        # Only add to opt/arg list if doesn't already exist and is required.
        eval $optArgListNm\+\=\(\"\$optArgNm\"\)
        defaultValue="${defaultValue%%=EXIST=*}"
        eval $optArgMapNm\[\"\$optArgNm\"\]\=\"\$defaultValue\"
      fi
    elif [ "$presence" == 'required' ]; then
      requiredMissing="$optArgNm $requiredMissing"
      errorInd=true
    elif AssociativeMapKeyExist "$optArgMapNm" "$optArgNm"; then
      # Expecting optional value to be assigned default value - none specified in the table.
      requiredMissing="$optArgNm $requiredMissing"
      errorInd=true
    fi
  done
  if $errorInd; then OptionsArgsMessageErrorIssue "Required opt/arg absent or no default value: $requiredMissing"; return 1; fi
}
###############################################################################
##
##  Purpose:
##    Generates a series of associative arrays for every option or argument
##    that must be processed by the command.  Each array represents a
##    trait, like the trait of 'default value', associated to an option or
##    argument.  The option or argument value represents a primary key
##    value employed to select the desired trait's value.
##
##  Inputs:
##    $1 - Callback function name:  Callback load a table that defines
##         the valid options/arguments for a command and other traits too.
##    $2 - A name you want to prefix all the column map arrays.
##         analogous to a table/relation name in a DB.
##    $3 - A variable name to contain error messages generated by this
##         routine.   
##    $4 - A string specifying the desired traits to retrieve.  The string
##         contains a trait's column name delimited by a space that both
##         precedes and succeeds it.
## 
## 
##  Outputs:
##    When Failure: 
##      Either it silently fails or writes an error message to $3.
##    When Success:
##      A series of associative arrays prefixed by the the provided "table name"
##      containing the traits of all the options/arguments specified for
##      the command.
##
###############################################################################
function OptionsArgsDefTbl () {
  local callbackFunctionName="$1"
  local -r metadataCallback="`type -t $callbackFunctionName`"
  local callbackErrNm="$3"
  local columnMapSelect="$4"
  if ! [ "$metadataCallback" == 'function' ]; then
    eval $callbackErrNm=\"Please check that the callback function exists: \'$callbackFunctionName\'. It\'s name is typed to \'$metadataCallback\'\"
    return 1;
  fi
  local tableName="$2"
  local defRec
  while read defRec; do
    eval set -- $defRec
    if [ "`expr match \"$columnMapSelect\" '.* optArgName .*'`" -gt '0' ]; then
      eval ${tableName}_optArgName\[\"\$1\"\]\=\"\$1\"
    fi
    if [ "`expr match \"$columnMapSelect\" '.* cardinality .*'`" -gt '0' ]; then
      eval ${tableName}_cardinality\[\"\$1\"\]\=\"\$2\"
    fi
    if [ "`expr match \"$columnMapSelect\" '.* default .*'`" -gt '0' ]; then
      eval ${tableName}_default\[\"\$1\"]\=\"\$3\"
    fi
    if [ "`expr match \"$columnMapSelect\" '.* verifyFunction .*'`" -gt '0' ]; then
      eval ${tableName}_verifyFunction\[\"\$1\"\]=\"\$4\"
    fi
    if [ "`expr match \"$columnMapSelect\" '.* presence .*'`" -gt '0' ]; then
      eval ${tableName}_presence\[\"\$1\"\]\=\"\$5\"
    fi
    if [ "`expr match \"$columnMapSelect\" '.* aliases .*'`" -gt '0' ]; then
      eval ${tableName}_aliases\[\"$1\"]=\"\$6\"
    fi
  done < <( $callbackFunctionName )
}
###############################################################################
##
##  Purpose:
##    Verify the parameter values to ensure that they are reasonable.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its descendants.
##
##  Inputs:
##    $1 - Callback function name:  Callback load a table that defines
##         the valid options/arguments for a command and other traits too.
##    $2 - Array listing the option/argument labels
##    $3 - Map containing the option/argument values.
## 
##  Outputs:
##    When Successful:
## 
##    When Failure: 
##      SYSERR - A message indicating reason for an error.
##
###############################################################################
function OptionsArgsValueVerify () {
  local callbackFunctionName="$1"
  local optArgListNm="$2"
  local optArgMapNm="$3"
  local -A argOpt_optArgName
  local -A argOpt_verifyFunction
  local -r columnMapSelect=' optArgName verifyFunction '
  local  callbackErr
  if ! OptionsArgsDefTbl "$callbackFunctionName" 'argOpt' 'callbackErr' "$columnMapSelect"; then
    ScriptUnwind "$LINENO" "Callback function: '$callbackFunctionName' failed. $callbackErr"
  fi
  local argArgValueInvalid=""
  eval local -r optionList_np=\"\$\{$optArgListNm\[\@\]\}\"
  for optArg in $optionList_np
  do
    local optArgValue
    eval optArgValue=\"\$\{$optArgMapNm\[\"\$optArg\"\]\}\"
    local optArgVerifyFunIx
    if [ "${argOpt_optArgName["$optArg"]}" == "$optArg" ]; then
      optArgVerifyFunIx="$optArg"
    elif [[ "$optArg" =~ ^Arg[1-9][0-9]*$ ]] && [ "${argOpt_optArgName['ArgN']}" == 'ArgN' ]; then
      optArgVerifyFunIx='ArgN'
    elif [[ "$optArg" =~ ^(-[^=]+=)[1-9][0-9]*$ ]] && [ "${argOpt_optArgName["${BASH_REMATCH[1]}N"]}" == "${BASH_REMATCH[1]}N" ]; then
      optArgVerifyFunIx="${BASH_REMATCH[1]}N"
    else
      if ! [ "${argOpt_optArgName['--Ignore-Unknown-OptArgs']}" == '--Ignore-Unknown-OptArgs' ]; then
        argArgValueInvalid+="Unknown OptArg: '$optArg', value: '$optArgValue' "
      fi
      continue
    fi         
    verifyFunction="${argOpt_verifyFunction["$optArgVerifyFunIx"]}"
    if [ -z "$verifyFunction" ]; then continue; fi
    verifyFunction="${verifyFunction//\<$optArgVerifyFunIx\>/$optArgValue}"
    local errorMsg
    if ! eval errorMsg=\`$verifyFunction \2\>\&\1\`; then
      argArgValueInvalid+="Invalid value for OptArg: '$optArg'. $errorMsg "
    fi
  done
  if ! [ -z "$argArgValueInvalid" ]; then
    OptionsArgsMessageErrorIssue "Error: $argArgValueInvalid">&2
    return 1;
  fi
  return 0;
}
###############################################################################
##
##  Purpose:
##    Test that a boolean type is being assigned a value of either 
##    'true' or 'false' value.
##
##  Inputs:
##    $1 - Value being assigned to the boolean.
## 
##  Outputs:
##    When Successful:
##    When Failure: 
##      SYSERR - A message indicating reason for an error.
##
###############################################################################
function OptionsArgsBooleanVerify () {
  if [ "$1" == "true" -o "$1" == "false" ]; then return 0; fi
  OptionsArgsMessageErrorIssue "Value: '$1' invalid.  Please specify either 'true' or 'false'."
  return 1;
}
###############################################################################
##
##  Purpose:
##    Issue error message to SYSERR.
##
##  Inputs:
##    $1 - Message to write to SYSERR
## 
##  Outputs:
##    When Successful: 
##      SYSERR - Provides an error message & return code is set to failure.
##
###############################################################################
function OptionsArgsMessageErrorIssue () {
  echo "$1">&2
}
##############################################################################
##
##  Purpose:
##    Remove specified argument or option from both the array listing the
##    parameters as well as the associative array containing the values
##    associated with the provided argument/option.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##    The bash variable names supplied for parameters $2-$5 cannot have
##    overlapping names.
##
##  Inputs:
##    $1 - name of the option/argument. 
##    $2 - The varialble name of an array detailing the provided options and
##         arguments in the order they were entered.
##    $3 - The variable name of an associative array of option and argument values.
##    $4 - The varialble name of an array that will accept the 
##         resultant list of options and arguments in the order presented by $2.
##    $5 - The varialble name of an associative array to receive
##         option and argument values for the items identified by $4.  
## 
##  Outputs:
##    When Success: 
##      $4 - The array absent the provided option/argument.
##      $5 - All the option/argument values except the one associated to
##           the removed option/argument.
##
###############################################################################
function OptionsArgsRemove () {
  local optArgToRemove="$1"
  local optArgListNm="$2"
  local optArgMapNm="$3"
  local optArgListNmOutput="$4"
  local optArgMapNmOutput="$5"
  eval local -r optionList_np=\"\$\{$optArgListNm\[\@\]\}\"
  local optArg
  for optArg in $optionList_np
  do
    if [ "$optArg" == "$optArgToRemove" ]; then continue; fi
    eval $optArgListNmOutput\+\=\( \"\$optArg\"\)
    eval local optArgValue=\"\$\{$optArgMapNm\[\"\$optArg\"\]\}\"
    if [ -n "$optArgValue" ]; then eval $optArgMapNmOutput\[\"\$optArg\"\]\=\"\$optArgValue\"; fi
  done
}
##############################################################################
##
##  Purpose:
##    Encapsulate the given options and arguments in single quotes to prevent
##    further substitution of their values.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##    The bash variable names supplied for parameters $2-$5 cannot have
##    overlapping names.
##
##  Inputs:
##    $1 - The varialble name of an array detailing the provided options and
##         arguments in the order they were entered.
##    $2 - The variable name of an associative array of option and argument values.
## 
##  Outputs:
##    When Success: 
##      SYSOUT - A single line where each option/argument is delimited by a single
##               whitespace and arguments are encapsulated in single quotes.
##               The element order of option/argument array ($2) determines
##               the order of options/arguments appearing in SYSOUT.
##               This single line starts with a single whitespace before any 
##               option or argument.
##
###############################################################################
function OptionsArgsGen () {
  local optArgListNm="$1"
  local optArgMapNm="$2" 
  local optOutBuf
  local argOutBuf
  eval local -r optionList_np=\"\$\{$optArgListNm\[\@\]\}\"
  local optArg
  for optArg in $optionList_np
  do
    eval local value=\"\$\{$optArgMapNm\[\"\$optArg\"\]\}\"
    value=${value//\'/\'\"\'\"\'}
    value="'${value}'"
    if [[ "$optArg" =~ ^Arg[1-9][0-9]*$ ]]; then
      argOutBuf+=" $value";
    else
      if [[ "$optArg" =~ ^(-[^=]+)=[1-9][0-9]*$ ]]; then
        # handle repeatable options
        optOutBuf+=" ${BASH_REMATCH[1]}"
      else
        optOutBuf+=" $optArg"
      fi
      if [ "$value" != "''" ]; then
        optOutBuf+="=$value"
      fi
    fi
  done
  # encode a hard coded end of option list delimiter on command line,
  # because there may have been one on the original command line
  # and without it, the first argument in the argument list won't
  # be recognized.
  if [ -n "$argOutBuf" ]; then optOutBuf="$optOutBuf -- $argOutBuf"; fi
  echo "$optOutBuf"
}
##############################################################################
##
##  Purpose:
##    Bypass the given command's general description and extract the option
##    settings that begin with the first '-'.  Also, write a header and the
##    extracted options to SYSOUT.
##
##  Inputs:
##    $1 - The name assigned to the option settings.  Typically, the 
##         command's name.
##    VirtOptionsExtractHelpDisplay - A virtual function that generates
##         help output for the desired comand.
##    
## 
##  Outputs:
##    When Success: 
##      SYSOUT - Reflects a list with a section title followed by 
##               a list of valid options that will be forwarded to the 
##               actual one.
##
###############################################################################
function OptionsExtract () {
  echo
  echo "OPTIONS: $1:"
  local cmdHelp
  local parseState='removeHdr'
  while read cmdHelp; do
    if [ "$parseState" == 'removeHdr' ]; then
      if ! [[ "$cmdHelp" =~ ^-.+$ ]]; then continue; fi
      parseState='optionSection';
    fi
    echo "    $cmdHelp"
  done < <( VirtOptionsExtractHelpDisplay )
  return 0
}
function VirtOptionsExtractHelpDisplay () {
  ScriptUnwind $LINENO "Please provide an override for: '$FUNCNAME'"
}
FunctionOverrideIncludeGet
###############################################################################
#
# The MIT License (MIT)
# Copyright (c) 2014-2015 Richard Moyse License@Moyse.US
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
