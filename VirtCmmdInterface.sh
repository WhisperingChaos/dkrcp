#!/bin/bash
###############################################################################
##
##  Section: Abstract Interface:
##    Defines an abstract command processing interface and
##    for now, couple it do a default implementation.
##
###############################################################################
##
###############################################################################
##
##  Purpose:
##    Define a generic command processing framework.  Framework outline:
##    1.  Obtain configuration settings.
##    2.  Parse command line arguments.
##    3.  Determine if call for help (give precedence to --help option above
##        all otheres).
##    4.  When help requested, display the command's help text.
##    5.  Determine if call for version info (give precedence to --version 
##        option after --help but before all others).
##    6.  When version requested, display the command's version text.
##    7.  Verify the arguments passed to the command.
##    8.  Execute the command.
##
##  Input:
##    $1 - Variable name containing the submitted arguments/options for a 
##         given command.  To create this variable see: "ArgumentsMainInclude.sh"
##    
##  Output:
##    When Failure: 
##      A return code of 1.
##      SYSERR - One or more messages prefixed with either "Error:" or "Abort:"
##           explaining the reason for the failure.
##
###############################################################################
function main () {
  local -r mainArgListNm="$1"
  if ! VirtCmmdConfigSet; then
    ScriptUnwind "$LINENO" "Command context could not be properly established"
  fi
  local -a mainArgList
  local -A mainArgMap
  if ! VirtCmmdArgumentsParse "$mainArgListNm" 'mainArgList' 'mainArgMap'; then
    ScriptUnwind "$LINENO" "Parsing command line options failed."
  fi

  if ! VirtCmmdOptionHelpVerify 'mainArgList' 'mainArgMap'; then
    ScriptUnwind "$LINENO" "Command options/arguments invalid.  Try 'help'."
  fi
  if VirtCmmdHelpIsDisplay 'mainArgList' 'mainArgMap'; then
    VirtCmmdHelpDisplay
    return 0
  fi
  if ! VirtCmmdOptionVersionVerify 'mainArgList' 'mainArgMap'; then
    ScriptUnwind "$LINENO" "Command options/arguments invalid.  Try 'help'."
  fi
  if VirtCmmdVersionIsDisplay 'mainArgList' 'mainArgMap'; then
    VirtCmmdVersionDisplay
    return 0
  fi
  if ! VirtCmmdOptionsArgsVerify 'mainArgList' 'mainArgMap'; then
    ScriptUnwind "$LINENO" "Command options/arguments invalid.  Try 'help'."
  fi 
  if ! VirtCmmdExecute 'mainArgList' 'mainArgMap'; then
    ScriptUnwind "$LINENO" "Problem occurred while executing command"
  fi
}
################################################################################
##
##  Purpose:
##    To establish a configuration interface used to load a script's
##    statically, from the perspective of the running script, defined
##    execution enviroment.  For example, loading a series of bash environment
##    variables.  The default implementation can be overridden by redefining
##    the bash function in the script file that includes it.
##
##    This implementation will first attempt to load a script's execution
##    environment by running yet another script, assigned the same name but
##    located in directory/symbolic link named "config" that's subordinate
##    to the directory containing the script that's running which included
##    this one.  If this file isn't found, then a function that loads 
##    a "default" environment is executed.
##
##  Input:
##    $0 - Name of running script that included this configuration interface.
##
##  Output:
##    When Failure:
##      SYSERR - Reflects reason for failure.
##
#################################################################################
function  VirtCmmdConfigSet (){
  local -r script_dir=$(dirname "${BASH_SOURCE[0]}")
  local -r script_name=$(basename "$0")
  local -r script_config="$script_dir/config/$script_name"
  if [ -e  "$script_config" ]; then
    "$script_config"
  else
    VirtCmmdConfigSetDefault
  fi
  return
}
###############################################################################
##
##  Purpose:
##    Establish a "default" configuration environment for the running script.
##
##  Input:
##    $0 - Name of running script that included this configuration interface.
##
##  Output:
##    When Failure: 
##      SYSERR - Reflect message indicating reason for error
##
#################################################################################
function VirtCmmdConfigSetDefault (){
  ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
}
###############################################################################
##
##  Purpose:
##    Parse command line options and arguments into an array and an associative
##    array.  The standard array contains the option labels and a generated
##    argument label name.  The ordering of theses labels in the array
##    reflects its position specified on the command line.  The associative
##    is keyed by these label names and its values reflect the values assigned
##    to the option/arguments.  
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Input:
##    $1 - Variable name whose value contains the command's options and
##         specified on the command line arguments.
##    $2 - Variable name to an array whose values will contain label names
##         of the options and agruments appearing on the command line in the
##         order specified by it. An option label is simply the option while
##         arguments other than options are assigned labels 'Arg<N>' where
##         <N> represents the order in which the argument was encountered
##         starting with 1.
##    $3 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
## 
##  Output:
##    When Successful:
##      $2 - This array variable contains entries of all the option/argument
##           labels submitted on the command line.
##      $3 - This associative array contains the values associated to
##           each label.
##    When Failure: 
##      SYSERR - Identifies the reason for failure.
##
###############################################################################
function VirtCmmdArgumentsParse () {
  ArgumentsParse "$1" "$2" "$3"
}
###############################################################################
##
##  Purpose:
##    Validate the help option on the command line, if entered, without
##    considering the other command options.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Input:
##    $1 - Variable name to an array whose values contain label names
##         of the options and agruments appearing on the command line in the
##         order specified by it. An option label is simply the option while
##         arguments other than options are assigned labels 'Arg<N>' where
##         <N> represents the order in which the argument was encountered
##         starting with 1.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
## 
##  Output:
##    When Failure: 
##      SYSERR - Identifies the reason for failure.
##
###############################################################################
function VirtCmmdOptionHelpVerify () {
  OptionsArgsVerify  'VirtCmmdOptionHelpDef' "$1" "$2"
}
VirtCmmdOptionHelpDef () {
cat <<OPTIONARGS_HELP
--help single false=EXIST=true "OptionsArgsBooleanVerify \\<--help\\>" optional "-h -help"
--Ignore-Unknown-OptArgs single --Ignore-Unknown-OptArgs "" optional ""
OPTIONARGS_HELP
return 0
}
###############################################################################
##
##  Purpose:
##    Examine command line options/arguments to ensure reasonable values
##    were provided.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Input:
##    $1 - Variable name to an array whose values contain the label names
##         of the options and agruments appearing on the command line in the
##         order specified by it.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
##    'VirtCmmdOptionsArgsDef' - A callback function that supplies a table
##         containing constraint information used, for example, to
##         verify the values of the arguments/options.
## 
##  Output:
##    When Successful:
##      All the arguments/options passes a "sniff' test.
##    When Failure: 
##      SYSERR - Contains a message that specifically indicates why the
##               option/argument failed its verification.
##
###############################################################################
function VirtCmmdOptionsArgsVerify () {
  OptionsArgsVerify  'VirtCmmdOptionsArgsDef' "$1" "$2"
}
###############################################################################
##
##  Purpose:
##   Provides an interface to obtain a list of the options/arguments accepted
##   by the command in question.
## 
##  Output:
##    When Successful:
##      SYSOUT - Each argument's/option's constraint information is written
##               as a separate line out.
##
###############################################################################
function VirtCmmdOptionsArgsDef () {
# optArgName cardinality default verifyFunction presence
cat <<OPTIONARGS
Arg1 single Error "OptionsArgsMessageIssue \'Please override VirtCmmdOptionsArgsDef.\'" required
OPTIONARGS
return 1
}
##############################################################################
##
##  Purpose:
##    Determine if command specific help should be generated instead of
##    running the command.
##
##  Input:
##    $1 - Variable name to an array whose values contain the label names
##         of the options and agruments appearing on the command line in the
##         order specified by it.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
## 
##  Output:
##    When Successful:
##      Indicates request to display help for running command.
##    When Failure:
##      Indicates absence of request to display help.
##
###############################################################################
function VirtCmmdHelpIsDisplay () {
  if AssociativeMapKeyExist "$2" '--help'; then
    eval local -r helpIndValue=\"\$\{$2\[\'\-\-help\'\]\}\"
    return `eval $helpIndValue`;
  fi
  return 1;
}
##############################################################################
##
##  Purpose:
##    To generate 'standard' help documention for this given command.  Help 
##    documentation succinctly describes the command's prupose, format, 
##    option label names, their values, expected arguments and perhaps
##    examples.
##
##  Input:
##    $1 - Variable name to an array whose values contain the label names
##         of the options and agruments appearing on the command line in the
##         order specified by it.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
## 
##  Output:
##    When Successful:
##      SYSOUT - Provides help text.
##    When Failure:
##      SYSERR - Reflects reason for failure.
##
###############################################################################
function VirtCmmdHelpDisplay () {
  ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
}
##############################################################################
##
##  Purpose:
##    Determine if command specific help should be generated instead of
##    running the command.
##
##  Input:
##    $1 - Variable name to an array whose values contain the label names
##         of the options and agruments appearing on the command line in the
##         order specified by it.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
## 
##  Output:
##    When Successful:
##      Indicates request to display help for running command.
##    When Failure:
##      Indicates absence of request to display help.
##
###############################################################################
function VirtCmmdVersionIsDisplay () {
  if AssociativeMapKeyExist "$2" '--version'; then
    eval local -r versionIndValue=\"\$\{$2\[\'\-\-version\'\]\}\"
    return `eval $versionIndValue`;
  fi
  return 1;
}
###############################################################################
##
##  Purpose:
##    Validate the version option on the command line, if entered, without
##    considering the other command options.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Input:
##    $1 - Variable name to an array whose values contain label names
##         of the options and agruments appearing on the command line in the
##         order specified by it. An option label is simply the option while
##         arguments other than options are assigned labels 'Arg<N>' where
##         <N> represents the order in which the argument was encountered
##         starting with 1.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
## 
##  Output:
##    When Failure: 
##      SYSERR - Identifies the reason for failure.
##
###############################################################################
function VirtCmmdOptionVersionVerify () {
  OptionsArgsVerify  'VirtCmmdOptionVersionDef' "$1" "$2"
}
VirtCmmdOptionVersionDef () {
cat <<OPTIONARGS_VERSION
--version single false=EXIST=true "OptionsArgsBooleanVerify \\<--version\\>" optional "-version --ver -ver"
--Ignore-Unknown-OptArgs single --Ignore-Unknown-OptArgs "" optional ""
OPTIONARGS_VERSION
return 0
}
##############################################################################
##
##  Purpose:
##    Generate standard version documention for given command.  Version 
##    documentation provides component version number, licensing, and 
##    link to issue reporting.
##
##  Input:
##    $1 - Variable name to an array whose values contain the label names
##         of the options and agruments appearing on the command line in the
##         order specified by it.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
## 
##  Output:
##    When Successful:
##      SYSOUT - Provides version text.
##    When Failure:
##      SYSERR - Reflects reason for failure.
##
###############################################################################
function VirtCmmdVersionDisplay () {
  ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
}
##############################################################################
##
##  Purpose:
##    Execute the command's implementation.
##
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Input:
##    $1 - Variable name to an array whose values contain the label names
##         of the options and agruments appearing on the command line in the
##         order specified by it.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
## 
##  Output:
##    When failure:
##      SYSERR - Reflects error message.
##
###############################################################################
function VirtCmmdExecute () {
  ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
}
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
