#!/bin/bash
###############################################################################
##
##  Purpose:
##    Issue an error message to SYSERR prefixed by "Error: Module: '$0'
##    followed by provided message text and return to the caller.
##
##  Input:
##    $1 - Message text. 
##
##  Ouptut:
##    Writes a message to SYSERR.
##
###############################################################################
function ScriptError (){
  local messageText="$1"
  if [ -z "$messageText" ]; then messageText="Message not provided"; fi
  local moduleName
  if [ -n "$VERBOSE_OUTPUT" ] && [ "$VERBOSE_OUTPUT" == 'true' ]; then
    moduleName="Module: '$0', "
  fi
  echo "Error: ${moduleName}$messageText" >&2
  return 1
}
###############################################################################
##
##  Purpose:
##    Provide debugging message output.
##
##  Input:
##    $1 - LINENO. 
##    $2 - Message text. 
##
##  Ouptut:
##    Writes a debug message to SYSERR.
##
###############################################################################
function ScriptDebug () {
  local messText="$2"
  if [ -z "$messText" ]; then messText="Debug message not supplied."; fi
  ScriptMessageBasic "$1" "$0" 'Debug' "$messText"
}
###############################################################################
##
##  Purpose:
##    Issue an informative message to SYSOUT prefixed by "Inform: Module: '$0'
##    followed by provided message text and return to the caller.
##
##  Input:
##    $1 - Message text. 
##
##  Ouptut:
##    Writes a message to STDOUT.
##
###############################################################################
function ScriptInform (){
  local messageText="$1"
  if [ -z "$messageText" ]; then messageText="Message not provided"; fi
  local moduleName
  if [ -n "$VERBOSE_OUTPUT" ] && [ "$VERBOSE_OUTPUT" == 'true' ]; then
    moduleName="Module: '$0', "
  fi
  echo "Inform: ${moduleName}$messageText"
}
###############################################################################
##
##  Purpose:
##    Terminates the execution of the script if one of the pipline components
##    should signal a failure.
##
##    Note:
##      This does not generate a complete function call stack.
##
##  Input:
##    $1 - Pipeline to execute.
##    $2 - LINENO of calling location. 
##    $3 - Optional message text.
##
##  Ouptut:
##    if pipline fails writes the provided message, prefixed by "Abort: ' to SYSERR.
##
###############################################################################
function PipeFailCheck (){
  local -r PipeCurrent="$( shopt -p -o pipefail )"
  set -o pipefail
  eval $1
  local -r pipeStatus="$?"
  eval "$PipeCurrent"
  if [ "$pipeStatus" -ne '0' ]; then
     ScriptUnwind "$2"  "$3"
     exit 1
  fi
}
###############################################################################
##
##  Purpose:
##    Terminates the execution of the script while providing minimal
##    debugging information that includes: the script line
##    number of the offending command, its module name, and optional
##    message text.
##
##    Call this function for unrecoverable errors.
##
##    Note:
##      This does not generate a complete function call stack.
##
##  Input:
##    $1 - LINENO of calling location: 
##    $2 - Optional message text.
##
##  Ouptut:
##    Writes a message, prefixed by "Abort: ' to SYSERR.
##
###############################################################################
function ScriptUnwind (){
  ScriptMessageBasic "$1" "$0" 'Abort' "$2"
  exit 1
}
###############################################################################
##
##  Purpose:
##    Issue a message message indicating a fault in a standard format.
##
##  Input:
##    $1 - LINENO of calling location: 
##    $2 - Module nameOptional message text.
##    $3 - Fault type: {'Abort'|'Error'}
##    $4 - Optional message text.
##
##  Ouptut:
##    Writes a message, prefixed by fault type: to SYSERR.
##
###############################################################################
function ScriptMessageBasic (){
  local lineInfo="$1"
  local moduleName="$2"
  local -r faultType="$3"
  local messageText="$4"

  if [ -z "$messageText" ]; then messageText="Unwinding script stack."; fi
  if [ -n "$VERBOSE_OUTPUT" ] && [ "$VERBOSE_OUTPUT" == 'true' ]; then
    lineInfo=" LINENO: '$lineInfo'"
  else
    moduleName="`basename "$moduleName"`"
    unset lineInfo
  fi
  echo "${faultType}: Module: '$moduleName'$lineInfo, $messageText" >&2
}
###############################################################################
##
##  Purpose:
##    Determine if a global environment variable has already been defined and
##    if so, terminate this shell.
##
##    Note - It's a flimsy mechanism but it's better than nothing.  This global
##    variable is being created to improve performance by eliminating 
##    subshell spawning.
##
###############################################################################
if [ -n "$PIPE_ERROR_ENCOUNTERED" ] && [ "$PIPE_ERROR_ENCOUNTERED" != 'PipeErrorEncountered' ]; then 
  ScriptUnwind $LINENO "Global variable already defined: PIPE_ERROR_ENCOUNTERED: '$PIPE_ERROR_ENCOUNTERED'"
else
  export PIPE_ERROR_ENCOUNTERED='PipeErrorEncountered'
fi
###############################################################################
##
##  Purpose:
##    Issue an unwind request and communicate to the next process listening
##    on the pipe.
##
##    This function should never be called directly.  Instead, it replaces 
##    'ScriptUnwind' implementation by encoding:
##
##    function ScriptUnwind (){
##      ScriptUnwindImplPipe "$1" "$2"
##    }
##    Executing the above code at the point you wish this implementation
##    to override the current implementation of 'ScriptUnwind'.
##
##  Input:
##    $1 - LINENO of calling location: 
##    $2 - Optional message text.
##
##  Ouptut:
##    SYSERR - An abort message.
##    SYSOUT - The token/signal: PIPE_ERROR_ENCOUNTERED
##
###############################################################################
function ScriptUnwindImplPipe () {
  ScriptMessageBasic "$1" "$0" 'Abort' "$2"
  echo "$PIPE_ERROR_ENCOUNTERED"
  exit 1
}
###############################################################################
##
##  Purpose:
##    Test for an upstream pipe error.  If an error is encountered, this
##    routine immediately terminates the current process and forwards the 
##    notification token to a possible next process in the chain.
##
##  Assume:
##    * PIPE_ERROR_ENCOUNTERED is properly defined.
##    * The token is the ony value for a given line of input.
##    * A cleanup process at the chain's end that removes the token
##      from SYSOUT. 
##
##  Input:
##    $1 - A line read from the pipe.
##
##  Ouptut:
##    SYSOUT - When upstream failure detected: PIPE_ERROR_ENCOUNTERED
##
###############################################################################
function PipeScriptNotifyAbort (){
  if [ "$1" == "$PIPE_ERROR_ENCOUNTERED" ]; then
    echo "$PIPE_ERROR_ENCOUNTERED"
    exit 1
  fi
  return 0
}
###############################################################################
##
##  Purpose:
##    Implement a function override mechanism so others can repair and
##    extend the behavior of all bash source inculded in this product without
##    having to apply changes directly to the files that contain the code.
##    
##  Note:
##    1.  This function must be used for bash scripts that are directly
##        invoked by their name, creating their own command shell -
##       'mainline' programs.
##    
##
##  Input:
##    None 
##
###############################################################################
function FunctionOverrideCommandGet (){
  FunctionOverrideIncludeSource "$0"
}
###############################################################################
##
##  Purpose:
##    Implement a function override mechanism so others can repair and
##    extend the behavior of all bash source inculded in this product without
##    having to apply changes directly to the files that contain the code.
##
##  Note:
##    >  This function must be used for bash scripts that are included, 
##       using the 'source' keyword into the same command shell that serves
##       as a 'mainline' program/shell.
##
##  Assume:
##    >  At the time the source is included, that there is only a single
##       layer of source between the invocation of this function and its
##       definition in this file, as more than one level will cause 
##       the reference of ${BASH_SOURCE[1]} to incorrectly resolve 
##       to one of these intermediate layers.
##
##  Input:
##    None.
##
###############################################################################
function FunctionOverrideIncludeGet (){
  FunctionOverrideIncludeSource "${BASH_SOURCE[1]}"
}
###############################################################################
##
##  Purpose:
##    Implement a function override mechanism so others can repair and
##    extend the behavior of all bash source inculded in this product without
##    having to apply changes directly to the files that contain the code.
##    
##    Permits others to have their own local customizations without concern
##    that they will be overwritten by a new release of the project code.
##
##  Note:
##    >  This function should not be directly called, instead, one of the
##       functions above, that call this routine should be called.
##    >  The files containing the source need not exist as their non-existence
##       will be suppressed.
##
##  Assume:
##    >  All source module names in the project are unique.
##    >  All extension modules must be placed in their appropriate directories.
##       Otherwise, overriding mechanism may fail.
##    >  The PATH variable has been properly established to include all
##       extension directories in appropriate search order.
##
##  Input:
##    $1 - file name of bash module to extend.
##
##  Ouptut:
##    SYSERR - All messages generated while including the source should
##        appear in SYSERR except for "not exist"
##    SYSOUT - All messages generated while including the source 
##        that are written SYSOUT.
##
###############################################################################
function FunctionOverrideIncludeSource (){
  local -r functionOverrideName="`basename "$1" .sh`"
  source "${functionOverrideName}Override.sh" 2> >( grep -v '.*MessageInclude.sh:.*: No such file or directory'>&2)
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
