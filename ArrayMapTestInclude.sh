##############################################################################
##
##  Purpose:
##    Implement buffer management functions.  A buffer is a serialized form
##    of a key value pair used to communicate this data via an interprocess
##    communication mechanism like a bash pipe.
##
##  Packet Format:
##    <lengthOfFieldName>/<fieldName><lengthOfFieldValue>/<fieldValue>...
##
##
##############################################################################

##############################################################################
##
##  Purpose:
##    Given an associative array, serialize its contents to a buffer - a
##    relatively simple text string.
##    
##  Buffer/String Format:
##    <lengthOfKeyName>/<keyField><lengthOfValue>/<value>...
##
##    <lengthOfFieldName> - Total length in bytes of the key field.
##    <keyField> - The key.
##    <lengthOfValue> - The length of the value field associated to this key.
##    <value> - The string associated to the key.
##
##    Example:
##       buffer: '3/Key5/value4/Key26/value2'
##       associative array/map:  map['Key']='value'; map['Key2']='value2';
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within a scope that 
##    includes this function.
##
##    The variable name of the associative array isn't the same as any
##    local variable name declared by this routine.
##
##  Inputs:
##    $1 - Variable name to bash associative array whose keys will
##         reflect the field name while its values reflect field values.
##    $2 - Optional variable name to receive serialized array format.
## 
##  Outputs:
##    When Successful:
##      if $2 provided, this variable will be assigned the serialized output,
##      otherwise:
##      SYSOUT - Provides a well formed buffer that can be deserialized back to
##               an associative array.
##
###############################################################################
function AssociativeMapToBuffer () {
  local mapNm="$1"
  local outputBufferNm="$2"
  local mapKeyList
  eval mapKeyList=\"\$\{\!$mapNm\[\@\]\}\"
  local buffer
  local key
  for key in $mapKeyList
  do
     buffer="$buffer${#key}/$key"
     local value
     eval value=\"\$\{$mapNm\[\"\$key\"\]\}\"
     buffer="$buffer${#value}/$value"
  done
  if [ -z "$outputBufferNm" ]; then
    echo "$buffer"
  else
    eval $outputBufferNm\=\$buffer
  fi
}
##############################################################################
##
##  Purpose:
##    Given buffer/string containing a serialized bash associative array, recreate
##    this associative array.
##    
##  Buffer/String Format:
##    see function: AssociativeMapToBuffer
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within a scope that 
##    includes this function.
##
##    The variable name of the associative array isn't the same as any
##    local variable name declared by this routine.
##
##    Duplicate key values will overlay last key-value.  The last key-value
##    pairs are ordered from first/leftmost to last/rightmost.
##
##  Inputs:
##    $1 - Buffer containing array serialize in format described above.
##    $2 - Variable name to bash associative array that will be assigned
##         the key value pairs located in the serialized buffer.
##         Note - This routine preserves key value pairs that already
##         exist in the array, unless key names overlap.
## 
##  Outputs:
##    When Successful:
##      $2 - Contain new key value pairs.
##
###############################################################################
function AssociativeMapFromBuffer () {
  local buffer="$1"
  local fieldNameMapNm="$2"
  local -i bufferPosCurr=0
  local fieldNameInd='true'
  local fieldName
  while [ $bufferPosCurr -lt ${#buffer} ]; do
    local -i fieldLen=`expr match "${buffer:$bufferPosCurr}" '\([0-9][0-9]*\)'`
    local -i fieldLenLen=${#fieldLen}
    if [ $fieldLenLen -lt 1 ]; then
      ScriptUnwind $LINENO "Invalid buffer field length format - not a numberic fieldLen: '$fieldLen'"
    fi
    bufferPosCurr+=$fieldLenLen
    if [ "${buffer:$bufferPosCurr:1}" != '/' ]; then
      ScriptUnwind $LINENO "Invalid buffer field length delimiter - should be '/' not: '${buffer:$bufferPosCurr:1}'"
    fi
    # include length of '/' seperator
    (( ++bufferPosCurr ))
    if $fieldNameInd; then
      fieldName="${buffer:$bufferPosCurr:$fieldLen}"
      fieldNameInd='false'
    else
      eval $fieldNameMapNm\[\"\$fieldName\"\]\=\"\$\{buffer\:\$bufferPosCurr\:\$fieldLen\}\"
      fieldNameInd='true'
    fi
    bufferPosCurr+=$fieldLen
  done
  return 0;
}
##############################################################################
##
##  Purpose:
##    Determine if given buffer conforms to serialized format.
##    
##  Buffer/String Format:
##    see function: AssociativeMapToBuffer
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within a scope that 
##    includes this function.
##
##    The variable name of the associative array isn't the same as any
##    local variable name declared by this routine.
##
##    Duplicate key values will overlay last key-value.  The last key-value
##    pairs are ordered from first/leftmost to last/rightmost.
##
##  Inputs:
##    $1 - Buffer contaiing array serialize in format described above.
##    $2 - Variable name to bash associative array that will be assigned
##         the key value pairs located in the serialized buffer.
##         Note - This routine preserves key value pairs that already
##         exist in the array, unless key names overlap.
## 
##  Outputs:
##    When Successful:
##      $2 - Contain new key value pairs.
##
###############################################################################
function AssociativeMapBufferIs () {
  local buffer="$1"
  local fieldNameInd='true'
  local -i bufferPosCurr=0
  while [ $bufferPosCurr -lt ${#buffer} ]; do
    local -i fieldLen=`expr match "${buffer:$bufferPosCurr}" '\([0-9][0-9]*\)'`
    local -i fieldLenLen=${#fieldLen}
    if [ $fieldLenLen -lt 1 ]; then
      # Doesn't start with a lenght control field.
      return 1;
    fi
    bufferPosCurr+=$fieldLenLen
    if [ "${buffer:$bufferPosCurr:1}" != '/' ]; then
      # Starts with a number but separator '/', that should exist between length encoding
      # and a field element doesn't.
      return 1;
    fi
    # include length of '/' seperator
    (( ++bufferPosCurr ))
    if $fieldNameInd; then
      fieldNameInd='false'
    else
      fieldNameInd='true'
    fi
     bufferPosCurr+=$fieldLen
  done
  # should be looking for a 
  if ! fieldNameInd; then return 1; fi
  # note - routine considers an empty buffer as correctly formatted.
  return 0;
}
###############################################################################
##
##  Purpose:
##    Assert that the passed key exists and is associated to the given value.
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within the same process
##    that's running this function. 
##
##  Inputs:
##    $1 - LINENO of assert 
##    $2 - Variable name to associative array whose keys will be validated.
##    $3-N The start of key|value pairs to be validated against
##         the associative array.
## 
##  Outputs:   
##    When Failure: 
##      Identifies key/vale that wasn't found & terminates entire script.
##
###############################################################################
function AssociativeMapAssertKeyValue () {
  local lineNumOfAssert="$1"
  local associativeMapToTest="$2"
  shift 2
  while [ $# -ne 0 ]; do
    AssociativeMapAssertKey "$lineNumOfAssert" "$associativeMapToTest" $1
    local value
    eval value\=\"\$\{$associativeMapToTest\[\"\$1\"\]\}\"
    if [ "$value" != "$2" ]; then
      ScriptUnwind $lineNumOfAssert "Map value assert failed! Key: '$1' Associative Array Name: '$associativeMapToTest' value expected: '$2' value actual: '$value'."
    fi
    shift 2
  done
  return 0;
}
###############################################################################
##
##  Purpose:
##    Assert that the passed key exists in the provided associative array.
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within the same process
##    that's running this function.
##
##    Unless there's a value to test, comparision grows linearly with the
##    number of elements.  Therefore, this algorithm can become slow very
##    quickly.
##
##  Inputs:
##    $1 - LINENO of assert 
##    $2 - Variable name to associative array whose keys will be validated.
##    $3 - The key to be validated as existing within the associative array.
## 
##  Outputs:   
##    When Failure: 
##      Identifies key that wasn't found & terminates entire script.
##
###############################################################################
function AssociativeMapAssertKey () {
  local lineNumOfAssert="$1"
  local associativeMapToTest="$2"
  local keyValue="$3"
  if !  AssociativeMapKeyExist "$associativeMapToTest" "$keyValue"; then 
    ScriptUnwind $lineNumOfAssert "Map key assert failed! Key: '$keyValue' Associative Array Name: '$associativeMapToTest'"
    exit 1
  fi
  return 0
}
###############################################################################
##
##  Purpose:
##    Determine if key exists in given associative map.
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within the same process
##    that's running this function.
##
##    The variable name of the associative array isn't the same as any
##    local variable name declared by this routine.
##
##    Unless there's a value to test, comparision grows linearly with the
##    number of elements.  Therefore, this algorithm can become slow
##    quickly.
##
##  Inputs:
##    $1 - Variable name to associative array whose keys will be validated.
##    $2 - The key to be validated as existing within the associative array.
## 
##  Outputs:
##    When Success:
##      return 0   
##    When Failure: 
##      return 1
##
###############################################################################
function AssociativeMapKeyExist () {
  local associativeMapToTest="$1"
  local keyValue="$2"
  local value
  eval value=\"\$\{$associativeMapToTest\[\"\$keyValue\"]\}\"
  if ! [ -z "$value" ]; then return 0; fi
  local mapKeyList
  eval mapKeyList=\"\$\{\!$associativeMapToTest\[\@\]\}\"
  local key
  for key in $mapKeyList
  do
     if [ "$key" == "$keyValue" ]; then return 0; fi
  done
  return 1; 
}
function AssociativeMapKeyValueEcho(){
  local associativeMapToTest="$1"
  eval set -- \"\$\{\!$associativeMapToTest\[\@\]\}\"
  while (( ${#} > 0 )); do
     eval local value\=\"\$\{$associativeMapToTest\[\"\$1\"\]\}\"
     echo "key='$1', value='$value'"
     shift
  done
}
###############################################################################
##
##  Purpose:
##    Simplify the assignment statement when resolving an indirect associative
##    array element.
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within the same process
##    that's running this function.
##
##    The variable name of the associative array isn't the same as any
##    local variable name declared by this routine.
##
##  Inputs:
##    $1 - Variable name to associative array.
##    $2 - Variable name to a key value.
##    $3 - Optional Variable name of the variable receiving the value associated to
##         the key value.
## 
##  Outputs:
##    When Success:
##	SYSOUT: if $3 not specified, SYSOUT reflects the value associated to
##              the key. Otherwise, $3 is modified to reflect the key value.    
##
###############################################################################
function AssociativeMapAssignIndirect () {
  local associativeMapToTestNm="$1"
  local keyValue="$2"
  local variableNameToAssignValueNm="$3"
  if [ -n "$variableNameToAssignValueNm" ]; then
    eval $variableNameToAssignValueNm=\"\$\{$associativeMapToTestNm\[\"\$keyValue\"]\}\"
  else
    eval echo \"\$\{$associativeMapToTestNm\[\"\$keyValue\"]\}\"
  fi
}
###############################################################################
##
##  Purpose:
##    Assert that the passed values exist in the given array according to
##    the provided order.
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within the same process
##    that's running this function. 
##
##  Inputs:
##    $1 - LINENO of assert 
##    $2 - Variable name to an array whose contents will be validated.
##    $3-N - A list of values to assert according to the order provided
##           by the argument placement.
## 
##  Outputs:   
##    When Failure: 
##      Identifies key that wasn't found & terminates entire script.
##
###############################################################################
function ArrayAssertValues (){
  local lineNumOfAssert="$1"
  local arrayToTestNm="$2"
  shift 2
  local -i arrayIx=0
  while [ $# -ne 0 ]; do
    local value
    eval value=\"\$\{$arrayToTestNm\[\$arrayIx]\}\"
    if [ "$value" != "$1" ]; then
      ScriptUnwind $lineNumOfAssert "Array value assert failed! LINENO: '$lineNumOfAssert' index: '$arrayIx' Array Name: '$arrayToTestNm' value expected: '$1' value actual: '$value'."
    fi
    (( ++arrayIx ))
    shift
  done
}
###############################################################################
##
##  Purpose:
##    Assert that the passed values exist in the given array according to
##    the provided order and the number of array elements passed as arguments
##    to this function equals the number of arguments in the actual array.
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within the same process
##    that's running this function. 
##
##  Inputs:
##    $1 - LINENO of assert 
##    $2 - Variable name to an array whose contents will be validated.
##    $3-N - A list of values to assert according to the order provided
##           by the argument placement.
## 
##  Outputs:   
##    When Failure: 
##      Identifies key that wasn't found & terminates entire script.
##
###############################################################################
function ArrayAssertValuesAll (){
  local lineNumOfAssert="$1"
  local arrayToTestNm="$2"
  shift 2
  local -i arrayIx=0
  local -i arrayElementCount=$#
  ArrayMapAssertElementCount "$lineNumOfAssert" "$arrayToTestNm" $arrayElementCount
  while [ $# -ne 0 ]; do
    local value
    eval value=\"\$\{$arrayToTestNm\[\$arrayIx]\}\"
    if [ "$value" != "$1" ]; then
      ScriptUnwind $lineNumOfAssert "Array value assert failed! LINENO: '$lineNumOfAssert' index: '$arrayIx' Array Name: '$arrayToTestNm' value expected: '$1' value actual: '$value'."
    fi
    (( ++arrayIx ))
    shift
  done
}
###############################################################################
##
##  Purpose:
##    Assert that the number of elements in either a plain array or associative
##    one is equal to the count passed to this routine.
##
##  Assumptions:
##    All bash variable names supplied as arguments to this function, like
##    the associative array, have been declared within the same process
##    that's running this function.
##
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its decendents.
##
##  Inputs:
##    $1 - LINENO of assert 
##    $2 - Variable name to plain/associative array whose size will be tested.
##    $3 - The count to be compared to the array's size.
## 
##  Outputs:   
##    When Failure: 
##      Identifies key that wasn't found & terminates entire script.
##
###############################################################################
function ArrayMapAssertElementCount () {
  local -r lineNumOfAssert="$1"
  local -r arrayMapToTestNm="$2"
  local -r -i arrayElementCount=$3
  eval local -r -i arraySize=\"\$\{\#$arrayMapToTestNm\[\@\]\}\"
  if [ $arrayElementCount -ne $arraySize ]; then 
    ScriptUnwind $lineNumOfAssert "Array size:'$arraySize' not equal to expected size of: '$arrayElementCount' for array name: '$arrayMapToTestNm'."
    exit 1
  fi
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
