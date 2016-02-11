###########################################################################
##
##  Purpose:
##    Defines concrete introspection methods for all objects.
##
###########################################################################
reflect_impl(){
  ###########################################################################
  ##
  ##  Purpose:
  ##    Object types encode their specific concrete implementation of 
  ##    an abstract interface via a set of bash functions whose names
  ##    mirror the ones defined by the given abstract interface.  These
  ##    concrete functions are encapsulated (defined) within a function whose
  ##    name matches the concrete type (a.k.a object's type name).  To ensure
  ##    the proper execution of a given object's concrete methods, this
  ##    encapsulating function should/must be executed before invoking any of
  ##    the object's methods, as it will define new/override existing function
  ##    definitions potentially implemented by other object types which
  ##    implement the same abstract interface.
  ##
  ##  Inputs:
  ##    $1 - The this pointer - reference to an associative map variable.
  ##
  ##  When successful:
  ##    bash maintained function definition table reflects the concrete 
  ##    implementation of one or more abstract interfaces.
  ##
  ###########################################################################
  reflect_type_Active(){
    local typeNameConcrete
    reflect_type_Get "$1" 'typeNameConcrete'
    local -r typeNameConcrete
    if ! $typeNameConcrete; then
      ScriptUnwind "$LINENO" "Unknown concrete type name: '$typeNameConcrete'."
    fi
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Optimizes function overriding by comparing the given object's
  ##    concrete interface implementation with a value that reflects the
  ##    most recently defined/invoked concrete interface to determine
  ##    if it's necessary to update bash's function definition table.
  ##
  ##  Inputs:
  ##    $1 - An object's this pointer.
  ##    $2 - A variable name whose value reflects the most recently
  ##         invoked concrete object type
  ##
  ##  When successful:
  ##    bash maintained function definition table reflects the concrete 
  ##    implementation of one or more abstract interfaces.
  ##    $2 - The variable value reflects the most recent concrete interface
  ##         name.
  ##
  ###########################################################################
  reflect_type_ActiveOptimize(){
    local -r typeNameCurrVarName_ref="$2"
    eval local \-r typeNameCurrValue_lcl\=\"\$$typeNameCurrVarName_ref\"
    local _typeNameConcrete
    reflect_type_Get "$1" '_typeNameConcrete'
    local -r _typeNameConcrete
    if [ "${_typeNameConcrete}" == "$typeNameCurrValue_lcl" ]; then return; fi
    if ! ${_typeNameConcrete} 2>/dev/null; then
      ScriptUnwind "$LINENO" "Unknown concrete type name: '${_typeNameConcrete}'."
    fi
    ref_simple_value_Set "$typeNameCurrVarName_ref" "${_typeNameConcrete}"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Return an object's concrete type name.  This name is the same one
  ##    assigned to a bash function that encapsulates an object's
  ##    implemented interface(s).
  ##
  ##    Why would this be public?  
  ##      > Permits access by type converters and optimizers.
  ##
  ##  Inputs:
  ##    $1 - The this pointer - reference to an associative map variable.
  ##    $2 - Variable name that accepts the type name value.
  ##
  ##  Outputs:
  ##    $2 - Value of this variable is assigned this object's concrete type name.
  ##
  ###########################################################################
  reflect_type_Get(){
    _reflect_field_Get $1 'TypeName' "$2"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    A private function used by object constructor to remember the object's
  ##    concrete interface name.
  ##
  ##  Inputs:
  ##    $1 - An object's this pointer.
  ##    $2 - The object's concrete type.
  ##
  ##  Outputs:
  ##    $1 - 'TypeName' field reflect's object's concrete type.
  ##
  ###########################################################################
  _reflect_type_Set(){
    _reflect_field_Set $1 'TypeName' "$2"
  }
  ###########################################################################
  ##
  ##  Purpose:
  ##    Facilitate assignment to an object's properties.
  ##
  ##  Inputs:
  ##    $1 - The this pointer - reference to an associative map variable.
  ##    $2 - Object field name
  ##    $3   Object field value
  ##    $n+1 - see $2
  ##    $n+2 - see $3
  ##  Outputs:
  ##    $1 - update to reflect assigned object key value pairs.
  ##
  ###########################################################################
  _reflect_field_Set(){
    local -r this_ref="$1"
    set -- "${@:2}"
    while (( $# > 1 )); do
      eval $this_ref\[\"\$1\"\]\=\"\$2\"
      shift 2
    done
    if (( $# > 0 )); then
      ScriptUnwind "$LINENO" "Field name: '$1' lacks value."
    fi
  }
  #############################################################################
  ##
  ##  Purpose:
  ##    Encode recurrent method to an object's property value(s).
  ##
  ##  Inputs:
  ##    $1 - The this pointer - reference to an associative map variable.
  ##    $2 - Object field name
  ##    $3   Variable to receive field's value.
  ##    $n+1 - see $2
  ##    $n+2 - see $3
  ##  Outputs:
  ##    $n+2 - update to reflect field value for given field name ($n+1).
  ##
  #############################################################################
  _reflect_field_Get(){
    local -r this_ref="$1"
    set -- "${@:2}"
    while (( $# > 1 )); do
      eval $2\=\"\$\{$this_ref\[\"\$1\"\]\}\"
      shift 2
    done
    if (( $# > 0 )); then
      ScriptUnwind "$LINENO" "Field name: '$1' lacks receiving variable name."
    fi
  }
}
reflect_impl
###############################################################################
##
##  Purpose:
##    Construct an object's context and then execute a function within this
##    context.  An object's context refers to all the sub-objects, data members,
##    encapsulated with in the object itself.
##
##  Inputs:
##    $2 - A function to execute within the constructed context.  The function
##         must not pass variables.  To pass variables, encapsulate the desired
##         function call within the body of function.
##    $1 - A function which generates a serialized stream of object definitions
##         to SYSOUT.  The serialized stream is defined as:
##         '<ObjectName>' '<ConcreteObjectType>' ['<ConstructorArgument>']...
##         '<ObjectName>' = The bash variable name (member name) assigned a 
##           bash map variable type.
##         '<ConcreteObjectType>' The concrete type assigned to the object.  A
##           concrete object type refers to a function that implements one or
##           more interfaces for the given type.  By convention and necessity,
##           one of the implemented methods must be named '<ConcreteObjectType>_Create()' 
##         '<ConstructorArgument>' an argument to be passed to the constructor.
##
###############################################################################
object_Context(){
  local -r objectSerialFunc="$1"
  local -r funcClosure="$2"
  local -a objList
  local objConstruct
  while read -r objConstruct; do 
    eval set -- "$objConstruct"
    ## $2 represents <ObjectName> 
    eval local \-\A $2\=\(\)
    ## $1 represents <ConcreteObjectType>. Establish concrete type's functions as the current ones.
    $1
    _Create "${@:2}"
    objList+=( "$2" )
  done < <( $objectSerialFunc)
  ###############################################################################
  ##
  ##  Purpose:
  ##    Iterate over every object in the current object context and execute 
  ##    a method, implemented by each one that accepts a this pointer and
  ##    potentially one or more other arguments.
  ##
  ##  Note:
  ##   The current object context may include other inherited object contexts.  If
  ##   a derived object context defines a variable with same name as an inherited
  ##   one, the variable within the derived context hides the inherited one.
  ##
  ##  Inputs:
  ##    $1 - A function name to execute that's implemented for every object in
  ##         the provided context.  The function may pass variables.
  ##
  ###############################################################################
  object_list_Iterate(){
    local -r funcClosure="$1"
    local ixObj
    local typeCurrent=''
    for (( ixObj=0; ixObj < ${#objList[@]}; ixObj++ )) 
    do
      local objName="${objList[$ixObj]}"
      # performance optimization
      reflect_type_ActiveOptimize "$objName" 'typeCurrent'
      $funcClosure "$objName" "${@:2}"
    done
  }
  eval $funcClosure
}