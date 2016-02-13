#TODO: conurrently run tests.
#TODO: Determine if detection pipeline functions for scanning are still necessary
##############################################################################
##
##  Purpose:
##    Test component dependencies, like Docker CLI version, to ensure
##    they exist and are of proper verison.
##
##  Note:
##    Although this function should unwind itself when it detects
##    dependency problems, it should attempt to identify as many dependency
##    and environment setup problems as it can before executing the uwind.
## 
##  Inputs:
##    None.
##
##  Outputs:
##    When successful - none.
##    Otherwise - Write error messages to STDERR.
##
###############################################################################
TestEnvironentDependenciesAssert(){
  ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'."
}
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdConfigSetDefault
##    However, this called after the framework adds its own default settigs.
##
###############################################################################
TestConfigSetDefault(){
  ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'."
}
##############################################################################
##
##  Purpose:
##    Display "Usage:" information for the specific test.
##
###############################################################################
TestHelpCmmdUsageDisplay(){
  ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'."
}
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdConfigSetDefault
##
###############################################################################
VirtCmmdConfigSetDefault(){
  TEST_SELECT_ALL='[0-9]*'
  TestConfigSetDefault
}
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdHelpDisplay
##
###############################################################################
VirtCmmdHelpDisplay() {
  echo
  TestHelpCmmdUsageDisplay
  cat <<COMMAND_HELP
TEST_NUM:  {'${TEST_SELECT}'| REGEX_SPEC [REGEX_SPEC...]}
    '${TEST_SELECT}'    Execute every test in numerical order.  Default value.
    REGEX_SPEC  A regular expression that selects the desired integer test label
                set. Must select at least one test to be considered valid. 
                Selected set executed in numerical order.
OPTIONS:
    --no-depnd=false     Execute dependency testing to ensure that dependent components
                           exist and are in correct state. 
    --no-scan=false      Execute tests without initially scanning the environment for 
                           every artifact created, used, and destroyed by every test.
                           Test artifact names may overlap with existing ones, not
                           produced by testing that share identical names/identities.
                           Detecting artifacts during a scan terminates testing 
                           before executing any tests or performing cleanup.
    --no-clean=false     Retain current testing environment and begin executing tests.
                           Otherwise, clean the environment before testing begins.
                           In any case, each test's cleanup routine will be executed
                           after its successful completion.
    --help               Provide command description.
    --ver                Display version and dependencies.
COMMAND_HELP
}
###############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdOptionsArgsDef
##
###############################################################################
VirtCmmdOptionsArgsDef(){
cat <<OPTIONARGS
Arg1 single '[0-9]*' "TestSelectSpecificationVerify \\<Arg1\\>" required ""
ArgN single ''       "TestSelectSpecificationVerify \\<ArgN\\>" optional ""
--no-depnd single false=EXIST=true "OptionsArgsBooleanVerify \\<--no-depnd\\>" required ""
--no-scan  single false=EXIST=true "OptionsArgsBooleanVerify \\<--no-scan\\>"  required ""
--no-clean single false=EXIST=true "OptionsArgsBooleanVerify \\<--no-clean\\>" required ""
OPTIONARGS
}
###############################################################################
##
##  Purpose:
##    Ensure test selection specification selects at least one test.
##
##  Input:
##    $1 - A potential RegEx expression.
##
##  Output:
##    When failure:
##      SYSERR    
##
###############################################################################
TestSelectSpecificationVerify(){
  local -r testSelectSpec="$1"
  if ! read < <( TestSelectSpecificationApply "$testSelectSpec" ); then
    ScriptError "Regex spec of: '$testSelectSpec' must select at least one test."
  fi
}
###############################################################################
##
##  Purpose:
##    Ensure specification selects at least one test.
##
##  Input:
##    $1 - A possible RegEx
##
##  Output:
##    SYSOUT - zero or more test function names matching RegEx filter.
##
###############################################################################
TestSelectSpecificationApply(){
  declare -F | awk '{ print $3 }' | grep "^${TEST_NAME_SPACE}$1\$"
}
##############################################################################
##
##  Purpose:
##    Execute Test Framework:
##      TestEnvironentDependenciesAssert:
##        Ensure proper component dependencies & global environment.
##      TestEnvironmentAssert:
##        For every selected test, ensure that any objects it creates
##        doesn't already exist.  Each test is responsible for creating
##        or obtaining the components necessary to execute the test.  
##      TestEnvironmentClean:
##        For every selected test, clean up any objects it produced.
##      TestExecuteAssert:
##        Execute the following interface when running a test:
##          $TEST_NAME_SPACE_NNN()
##            $TEST_NAME_SPACE:
##              A prefix encoded for every test function.
##            NNN:
##              The number assigned to a given test.
##            Purpose:
##              This particular function exposes the remaining
##              functions so they can be called.  It acts as a
##              name space
##            Inputs:
##          ${TEST_NAME_SPACE}_Desc()
##            Purpose:
##              Method outputs single line description to STDOUT
##          ${TEST_NAME_SPACE}_EnvCheck()
##            Purpose:
##              Method checks environment to determine if previous
##              test run left remnants or overlapping artifacts produced
##              by other processes.
##            Inputs:
##              $1 - variable name whose value is set according to the
##                   outputs below .
##            Outputs:
##              $1 - variable value set:
##                'false'- no remnants detected.
##                'true' - remnant detected.
##              STDERR - Error messages revealing found remnants or overlapping artifacts.
##          ${TEST_NAME_SPACE}_Run()
##            Purpose:
##              Execute the test.  Each test creates its required artifacts and 
##              runs its validation to assert that the output of the test matches what's
##              expected.  A failed assert immediately terminates the test leaving behind
##              any test artifacts.  These remnants hopefully permit debugging 
##              the test's failure.
##            Inputs:
##              None.
##            Outputs:
##              When successful - None.
##              Otherwise:
##                STDERR - Assert message explaining failure's cause.
##          ${TEST_NAME_SPACE}_EnvClean()
##            Purpose:
##              After executing the test, cleanup any artifacts produced by it.  By design
##              a test failure will ignore running this function so it's artifacts
##              can be reviewed to ascertain the failure's cause.  This routine should
##              eliminate as much of the failed artifacts as is reasonable so re-execution
##              of the test at a future point within the same contained environment won't
##              trigger asserts in EnvCheck() nor affect the test Run method.
##            Inputs:
##              None.
##            Outputs:
##              When successful - None.
##              Otherwise:
##                STDERR - Assert message explaining why EnvClean() failured.
## 
##  Assumption:
##    Since bash variable names are passed to this routine, these names
##    cannot overlap the variable names locally declared within the
##    scope of this routine or its descendants.
##
##  Input:
##    $1 - Variable name to an array whose values contain the label names
##         of the options and arguments appearing on the command line in the
##         order specified by it.
##    $2 - Variable name to an associative array whose key is either the
##         option or argument label and whose value represents the value
##         associated to that label.
## 
##  Output:
##    When success:
##      
##    When failure:
##      STDERR - Reflects error message generated by an Assert..
##
###############################################################################
VirtCmmdExecute(){
  local argOptList_ref="$1"
  local argOptMap_ref="$2"
  # assert testing dependencies are sufficient to support testing environment
  local -r ignoreDepend="`AssociativeMapAssignIndirect "$argOptMap_ref" '--no-depnd'`"
  if ! $ignoreDepend; then
    TestEnvironentDependenciesAssert
  fi

  local -a regexList
  local -A regexExpressMap
  if ! OptionsArgsFilter "$argOptList_ref" "$argOptMap_ref" 'regexList' 'regexExpressMap' '[[ "$optArg" =~ Arg[0-9][0-9]* ]]' 'true'; then
    ScriptUnwind $LINENO "Unexpectd return code."
  fi
  local regexArgList="`OptionsArgsGen 'regexList' 'regexExpressMap'`"
  regexArgList="${regexArgList:4}"
  local -r ignoreScan="`AssociativeMapAssignIndirect "$argOptMap_ref" '--no-scan'`"
  if ! $ignoreScan; then
    eval TestEnvironmentAssert $regexArgList
  fi
  local -r ignoreClean="`AssociativeMapAssignIndirect "$argOptMap_ref" '--no-clean'`"
  if ! $ignoreClean; then
    eval TestEnvironmentClean $regexArgList
  fi
  local remnantScan='true'
  if $ignoreScan; then remnantScan='false'; fi 
  eval TestExecuteAssert \"\$remnantScan\" $regexArgList
  ScriptInform "Testing Complete & Successful!"
}
##############################################################################
##
##  Purpose:
##    Scan current test environment for test artifacts that are either
##    remnants produced by prior test interation that failed or overlapping
##    artifacts, generated by so other process, that happen to have
##    identical names.
##
##    This scan is optionally performed before executing any tests to ensure
##    the environment is free of test artifacts that potentially affect 
##    a test's outcome.
##
##  Input:
##    $1-$N    - One to N regex instructions that specify the set of 
##               executed tests.  This set determines the scope/subset
##               of the environment scanned.
##    EnvCheck - Every test must define this method.
##
##  Output:
##    STDOUT - Displays scanning report.
##    When failure:
##      STDERR - Reflects error message.
##      STDOUT - Should identify failed test.
##
###############################################################################
TestEnvironmentAssert(){
  ScriptInform "Scanning: Start: Test Environment for remnants."
  local regexArgs
  args_single_quote_Encapsulate 'regexArgs' "$@"
  if ! ( PipeFailCheck 'TestSelect '"$regexArgs"' | TestFunctionExecTemplate AtEndNotify EnvCheck '  "$LINENO" "Failed environment scan."); then
    ScriptError 'One or more remnants were detected during the scan.'
    ScriptError 'Check to ensure remnants refer to test artifacts.'
    ScriptError 'If the remnants are unwanted test artifacts, rerun specifying'
    ScriptError '"'"--no-scan"'" option to delete them before executing'
    ScriptError 'a specific test.'
    ScriptUnwind "$LINENO" "Scan detected artifacts in environment that overlap ones produced during testing."
  fi
  ScriptInform "Scanning: Complete: Test Environment for remnants."
}
ScriptDetectNotify(){
  ScriptError 'Detected existence of '"$1"
}
##############################################################################
##
##  Purpose:
##    Destroy artifacts generated by the selected set of tests.
##    
##    This scan is optionally executed before running the selected tests to
##    to avoid test failures produced by artifacts that exist before
##    they were created (science fiction?) by the current testing iteration.
##
##  Input:
##    $1-$N    - One to N regex instructions that specify the set of 
##               executed tests.  This set determines the scope/subset
##               of the environment scanned.
##    EnvClean - Every test must define this method.
##
##  Output:
##    STDOUT - Displays clean report.
##    When failure:
##      STDERR - Reflects error message.
##      STDOUT - Should identify failed test.
##
###############################################################################
TestEnvironmentClean(){
  ScriptInform "Cleaning: Start: Test Environment of remnants."
  local regexArgs
  args_single_quote_Encapsulate 'regexArgs' "$@"      
  PipeFailCheck 'TestSelect '"$regexArgs"' | TestFunctionExecTemplate ImmediateNotify EnvClean'  "$LINENO" "Failed environment clean."
  ScriptInform "Cleaning: Complete: Test Environment of remnants."
}
##############################################################################
##
##  Purpose:
##    Template function to execute a single testing method.
##
##  Input:
##    $1    - Error notify response:
##            'AtEndNotify' - When error continue processing but generate
##                            error at end.
##            'ImmediateNotify - When error terminate processing immediately.
##    $2    - Test method name to execute.
##    $3-$N - Arguments to pass to the test method.
##    STDIN - Stream of Test function names.
##
##  Output:
##    STDOUT - Displays information messages.
##
###############################################################################
TestFunctionExecTemplate(){
  local -r notifyWhen="$1"
  local -r funcToExecute="$2"
  local errorInd='false'
  local errorSemantics
  if     [ "$notifyWhen" == "ImmediateNotify" ]; then errorSemantics='break'
  elif ! [ "$notifyWhen" == "AtEndNotify" ]; then
    ScriptUnwind "$LINENO" "Uknown error behavior: '$notifyWhen'.  Should be 'ImmediateNotify' or 'AtEndNotify'."
  fi
  local -r errorSemantics
  local testFunctionName
  while read testFunctionName; do
    $testFunctionName
    ScriptInform "Test: '$testFunctionName' Function: '$funcToExecute'."
    if ! ${TEST_NAME_SPACE}$funcToExecute "${@:3}"; then
      ScriptError "Test: '$testFunctionName' Function: '$funcToExecute' Failed.'"
      errorInd='true'
      $errorSemantics
    fi
    ScriptInform "Test: '$testFunctionName' Function: '$funcToExecute' Successful.'"
  done
  if $errorInd; then false; fi
}
###############################################################################
##
##  Purpose:
##   Execute the selected tests, assert successful completion, and clean the
##   environment of test artifacts.  Execution optionally includes an initial environment scan to ensure that previous
##   tests run during same test iteration don't have bugs in their clean up
##   methods that will trigger a execution failure during subsequent tests.
##   
##
##  Input:
##    $1-$N  - Regex compliant expressions identifying the test(s) to be 
##             selected (included) for execution.
##
##  Output:
##    STDOUT - Displays progress information messages.
##
###############################################################################
function TestExecuteAssert () {
  local -r remnantScan="$1"
  local testFunctionName
  TestExecuteApply(){
    while read testFunctionName; do
      $testFunctionName
      ScriptInform "Test: '$testFunctionName' Desc: `${TEST_NAME_SPACE}Desc`"
      if $remnantScan; then
        ScriptInform "Test: '$testFunctionName' Function: 'EnvCheck'."
        if ! "${TEST_NAME_SPACE}EnvCheck"; then
          ScriptUnwind "$LINENO" 'One or more remnants were detected between running tests.'
        fi 
      fi
      ScriptInform "Test: '$testFunctionName' Function: 'Run'."
      if ! ${TEST_NAME_SPACE}Run; then ScriptUnwind $LINENO "Unexpected failure detected. Function 'Run'."; fi
      ScriptInform "Test: '$testFunctionName' Function: 'EnvClean'."
      if ! ${TEST_NAME_SPACE}EnvClean; then ScriptUnwind $LINENO "Unexpected failure detected. Function 'EnvClean'."; fi
      ScriptInform "Test: '$testFunctionName' Successful.'"       
    done
  }
  local regexArgs
  args_single_quote_Encapsulate 'regexArgs' "${@:2}"      
  PipeFailCheck 'TestSelect '"$regexArgs"' | TestExecuteApply ' "$LINENO" "Failure while executing test."
}
###############################################################################
##
##  Purpose:
##   Select the desired tests given a regex.  The result set is then ordered
##   according to the test's sequence number.
##
##  Input:
##    $1-$N  - Regex compliant expressions identifying the test(s) to be 
##             selected (included) for execution.
##  Output:
##    STDOUT - Function names of the desired tests ordered by function
##             number.
##
###############################################################################
TestSelect(){
  local -i testNumStartPos=${#TEST_NAME_SPACE}+1
  TestSelectRegexApply(){
    while [ "$#" -gt '0' ]; do
      local regExpress="$1"
      TestSelectSpecificationApply "$regExpress"
      shift
    done
  }
  local regexArgs
  args_single_quote_Encapsulate 'regexArgs' "$@"
  PipeFailCheck 'TestSelectRegexApply '"$regexArgs"' | sort -k1.'"$testNumStartPos"'n' "$LINENO" "Failure during regex text selection"
}
###############################################################################
##
##  Purpose:
##   Helping function to verify component dependencies exist and are of
##   at least a minimal version.
##
##  Input:
##    $1 - Function name that encapsulates the following interface:
##           dependency_Exist
##             Purpose:
##               Determines if the component exists.
##           dependency_version_Get
##             Purpose:
##               Obtains the component's version specifier.
##           dependency_version_Violation_Gen       
##             Purpose:
##               Provides a message identifying the component
##               and the version detected.
##            Inputs:
##              $1 - minimal version specifier.
##              $2 - detected version specifier.
##               
##  Output:
##    When successful:
##      nothing.
##    When failure:
##      STDERR - Display informative message.
##
###############################################################################
TestDependenciesScanSuccess(){
  local -r dependencyDefineFunc="$1"
  local -r dependencyMin="$2"
  #load common interface to verify dependencies.
  $dependencyDefineFunc
 
  local localVer=''
  local minDetectedVer=''
  local depndSuccess='false'
  while true; do 
    if ! dependency_Exist; then
      ScriptError "Dependency defined by: '$dependencyDefineFunc' not detected."
      break
    fi
    if ! localVer="$(dependency_version_Get)"; then
      ScriptError "Dependency defined by: '$dependencyDefineFunc' exists but unable to determine its version."
      break
    fi
    if ! minDetectedVer="$(sort -V <( echo "$dependencyMin"; echo "$localVer") | head -n 1)"; then
      break
    fi
    if [ "$minDetectedVer" != "$dependencyMin" ]; then 
      dependency_version_Violation_Gen "$dependencyMin" "$localVer" 
      break
    fi
    # same or newer version than desired minimum (oldest) version 
    depndSuccess='true'
    break
  done
  $depndSuccess
}
###############################################################################
##
##  Section:
##   Common dependency checks.
##
###############################################################################
Testdependency_define_Docker_Client(){
  dependency_Exist(){
    docker version -f "{{ .Client.Version }}" >/dev/null 2>/dev/null
  }
  dependency_version_Get(){
    docker version -f "{{ .Client.Version }}" 2>/dev/null
  }
  dependency_version_Violation_Gen(){
    ScriptError "Requires Docker Client version:'$1', detected:'$2'"
  }
}
Testdependency_define_Bash(){
  dependency_Exist(){
    bash --help >/dev/null 2>/dev/null
  }
  dependency_version_Get(){
    echo "$BASH_VERSION"
  }
  dependency_version_Violation_Gen(){
    ScriptError "Requires bash version:'$1', detected:'$2'"
  }
}
###############################################################################
##
##  Purpose:
##    Determine if local repository is empty.  If not, suggest using official
##   'docker'
##     count of named object type that exist in the local Docker
##    repository.
##
##  Input:
##    $1 - The object type name: 'Images' or 'Containers'
##    $2 - A variable name that will receive the object count.
##
###############################################################################
TestLocalRepositoryIsEmpty(){
  local imageCnt
  TestLocalRepositoryObjectCntGet 'Images' 'imageCnt'
  local containerCnt
  TestLocalRepositoryObjectCntGet 'Containers' 'containerCnt'
  if [ "$imageCnt" -gt '0' ] || [ "$containerCnt" -gt '0' ]; then
    ScriptError "Local repository contains: '$imageCnt' images and '$containerCnt' containers."
    ScriptError "Although testing attempts to isolate its images and cleanup its containers,"
    ScriptError "remnants may remain that can pollute the local repository."
    ScriptError "Suggest using official 'docker' image which runs docker-in-docker."
    ScriptError "docker-in-docker establishes a separate repository to avoid polluting"
    ScriptError "your current one."
  fi
}
###############################################################################
##
##  Purpose:
##    Obtain count of named object type that exist in the local Docker
##    repository.
##
##  Input:
##    $1 - The object type name: 'Images' or 'Containers'
##    $2 - A variable name that will receive the object count.
##
###############################################################################
TestLocalRepositoryObjectCntGet(){
  local objName="$1"
  local objCnt_ref="$2"
  local objCnt_lcl="$(docker info 2>/dev/null | grep "^${objName}: ")"
  if ! [[ $objCnt_lcl =~ (^${objName}: )([0-9]+) ]]; then
    ScriptUnwind "$LINENO" "Count of :'$objName' missing.  'docker info' changed."
  fi
  objCnt_lcl="${BASH_REMATCH[2]}"
  eval $objCnt_ref\=\"\$objCnt_lcl\"
}
FunctionOverrideCommandGet
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
