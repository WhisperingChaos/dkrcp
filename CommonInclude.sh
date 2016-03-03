###########################################################################
##
##  Purpose:
##    Assign simple, single valued bash variable references a value.
##
##  Input:
##    $1 - Variable name to a single valued bash variable.
##    $2 - The value to assign to this variable.
##
##  Output:
##    $1 - Variable assigned value provided by $2.
##
###########################################################################
ref_simple_value_Set(){
  eval $1=\"\$2\"
}
###########################################################################
##
##  Purpose:
##    Perform recursive removal of file system objects.  However, do
##    so only when anchored to the root temporary directory. 
##
##  Input:
##    $1 - File path to remove.
##
##  Output:
##    Either (rm return code and potentially STDERR) or an execption
##    with message to STDERR.
##
###########################################################################
file_path_safe_Remove(){
  if [[ $1 =~ ^/tmp.* ]]; then
    rm -rf "$1" >/dev/null
  else
    ScriptUnwind "$LINENO" "Danger! Danger!  A recursive rm isn't rooted in '/tmp' but here: '$1'. rm command not executed." 
  fi
}
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