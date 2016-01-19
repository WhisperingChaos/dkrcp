env_check_interface(){
  env_check(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
}
env_clean_interface(){
  env_clean(){
    ScriptUnwind "$LINENO"  "Please override '$FUNCNAME'"
  }
}

reflect_impl(){
  reflect_type_Active(){
    local typeName
    reflect_type_Get "$1" 'typeName'
    local -r typeName
    $typeName
  }
  reflect_type_Get(){
    eval $2\=\"\$\{$1\[TypeName\]\}\"
  }
  _reflect_type_Set(){
    eval $1\[TypeName\]\=\"\$2\"
  }
}
reflect_impl


test_element_interface(){
  test_element_source_arg_Def(){
  }
  test_element_target_arg_Def(){
  }
  _test_element_source_arg_Convert(){
    local sourceArgDef;
    while read -r sourceArgDef; do 
      eval set -- "$sourceArgDef"
      local -r resourceArgVar_ref="$1"
      local -r sourceArgType="$2"
      local -r sourceArgFilePath="$3"

      local resourceArgType
      reflect_type_Get "$resourceArgVar_ref" 'resourceArgType'
      local -r resourceArgType
      ${resourceArgType}_to_${sourceArgType} "$resourceArgVar_ref" 



      ${typeName}_obj_name_Gen 'objName' "${@}"
      eval local \-\A $objName\=\(\)
      ${typeName}_Create "$objName" "${@}"
      objList+=( "$objName" )
    done < <( ${typeName}_Def)


  }
  _test_element_target_arg_Convert(){
  }
  _test_element_model_expected_Create(){
  }
  test_element_Run(){
    local sourceArgList
    _test_element_source_arg_Convert
    local targetArg
    _test_element_target_arg_Convert
    local modelExpected
    _test_element_model_expected_Create
    _dkrcp_Run
    local modelResult
    _test_element_model_result_Create
    _test_element_models_Compare
  }
  _dkrcp_Run(){
  }
  _test_element_model_result_Copy(){
  }
  _test_element_models_Compare(){
  }
}




host_file_interface(){
  env_clean_interface
  env_clean(){
    host_file_Delete "$1"
  }
  env_check_interface
  env_check(){
    local -r this_ref="$1"
    local -r existInd_ref="$2"
    local fileName
    host_file_name_Get "$this_ref" 'fileName'
    local -r fileName
    if [ -e "$fileName" ]; then
      ScriptError "Detected existance of host file: '$fileName', involved in testing."
      eval $existInd_ref\=\'true\'
    fi
  }
  host_file_obj_name_Gen(){
    local -r objName_ref="$1" 
    local fileName="$2" 
    name_normalize "$fileName" 'fileName'
    local -r fileName
    local -r objName_lcl="host_file_${fileName}"
    eval $objName_ref\=\"\$objName_lcl\"
  }
  host_file_Create(){
    local -r this_ref="$1"
    local -r fileName="$2"
    local -r funcNameContentGen="$3"
    local objName
    host_file_obj_name_Gen 'objName' "$2"
    local -r objName     
    eval $this_ref\[Name\]\=\"\$objName\"
    _reflect_type_Set "$this_ref" 'host_file_interface'
    eval $this_ref\[FileName\]\=\"\$\{TEST_FILE_ROOT\}\$\fileName\"
    eval $this_ref\[FuncNameContentGen\]\=\"\$funcNameContentGen\"
  }
  host_file_name_Get(){
    local -r this_ref="$1"
    local -r fileName_ref="$2"
    eval $fileName_ref\=\"\$\{$this_ref\[FileName\]\}\"
  }
  host_file_Gen(){
    local -r this_ref="$1"
    eval local \-r fileName=\"\$\{$this_ref\[FileName\]\}\"
    eval local \-r funcNameContentGen=\"\$\{$this_ref\[FuncNameContentGen\]\}\"             
    $funcNameContentGen "$fileName"
  }
  host_file_Delete(){
    local -r this_ref="$1"
    ScriptDebug "$LINENO" "$FUNCNAME"
    eval local \-r fileName=\"\$\{$this_ref\[FileName\]\}\"
    rm -rf "$fileName" >/dev/null
  }
}
image_reference_interface(){
  env_clean_interface
  env_clean(){
    image_reference_Delete "$1"
  }
  env_check_interface
  env_check(){
    local -r this_ref="$1"
    local -r existInd_ref="$2"
    while true; do
      local imageNameUUID
      image_reference_nameUUID_Get "$1" 'imageNameUUID'
      local -r imageNameUUID
      docker ps -a | grep "$imageNameUUID" | awk '{ print $1;}' | xargs -I ID -- ScriptError "Found container: 'ID' associated to image: '$2'"
      if [ "${PIPESTATUS[1]}" -eq '0' ]; then
        break
      fi
      local msg
      if msg="$(docker inspect --type=image -- $imageNameUUID 2>&1)"; then
        ScriptError "Detected image: '$2'."
        break
      fi
      local -r msg
      if ! [[ $msg =~ ^Error:.No.such.image.*$ ]]; then
        ScriptUnwind "$LINENO" "Unexpected error: '$msg', when testing for image name: '$imageNameUUID'."
      fi
      return
    done
    eval $existInd_ref\=\'true\'    
  }
  image_reference_obj_name_Gen(){
    local -r objName_ref="$1" 
    local imageName="$2" 
    name_normalize "$imageName" 'imageName'
    local -r imageName
    local -r objName_lcl="image_${imageName}"
    eval $objName_ref\=\"\$objName_lcl\"
  }
  image_reference_Create(){
    local -r this_ref="$1"
    local -r imageNameDkr="$2"
    local -r imageScope="$3" 
    local objName
    image_reference_obj_name_Gen 'objName' "$imageNameDkr"
    local -r objName     
    eval $this_ref\[Name\]\=\"\$objName\"
    _reflect_type_Set "$this_ref" 'image_reference_interface'
    if [ "$imageScope" == 'NameLocal' ]; then 
      eval $this_ref\[ImageNameUUID\]\=\"\$\{TEST_NAME_SPACE\}\$\imageNameDkr\"
    else
      eval $this_ref\[ImageNameUUID\]\=\"\$\imageNameDkr\"
    fi
  }
  image_reference_nameUUID_Get(){
    local -r this_ref="$1"
    local -r imageNameUUID_ref="$2"
    eval $imageNameUUID_ref\=\"\$\{$this_ref\[ImageNameUUID\]\}\"
  }
  image_reference_Delete(){
    local -r this_ref="$1"
    eval local -r imageNameUUID=\"\$\{$this_ref\[ImageNameUUID\]\}\"
    ScriptDebug "$LINENO" "$FUNCNAME"
    local msg
    if ( ! msg="$(docker rmi -f -- $imageNameUUID 2>&1)"  \
      && ! [[ $msg =~ ^Error.+:.No.such.image.*$ ]] ); then
      ScriptError "Unexpected error: '$msg', when removing image name: '$imageNameUUID'."
    fi
  }
}
name_normalize(){
 local -r nameNorm="$( echo "$1" | sed 's/[^0-9a-zA-Z_]/_/g' )"
 eval $2\=\"\$nameNorm\"
}
test_obj_Context(){
  local -r funcClosure="$1"
  local ixType
  for (( ixType=0; ixType < ${#objTypeList[@]}; ixType++ )) 
  do
    local typeName="${objTypeList[$ixType]}"
    ${typeName}_interface
    local objConstruct
    while read -r objConstruct; do 
      eval set -- "$objConstruct"
      local objName
      ${typeName}_obj_name_Gen 'objName' "${@}"
      eval local \-\A $objName\=\(\)
      ${typeName}_Create "$objName" "${@}"
      objList+=( "$objName" )
    done < <( ${typeName}_Def)
  done
  obj_list_iterate(){
    local -r funcClosure="$1"
    local ixObj
    local typeCurrent=''
    for (( ixObj=0; ixObj < ${#objList[@]}; ixObj++ )) 
    do
      local objName="${objList[$ixObj]}"
      # performance optimization
      local typeNew
      reflect_type_Get "$objName" 'typeNew'
      if [ "$typeNew" != "$typeCurrent" ]; then
        reflect_type_Active "$objName"
        typeCurrent="$typeNew"
      fi
      $funcClosure "$objName" "${@:2}"
    done
  }
  eval $funcClosure 
}
dkrcp_test_1() {
  test_obj_Closure(){
    local -a objTypeList=()
    objTypeList+=( 'host_file' )
    objTypeList+=( 'image_reference' )
    local -r objTypeList
    local -a objList=()
    test_obj_Context "$1"
  }
  host_file_Def(){
    echo "'a'      'file_content_reflect_name'"
    echo "'replicaExpected' 'file_content_dir_create'"
    echo "'replicaProduced' 'file_content_dir_create'"
  }
  image_reference_Def(){
    echo "'test_1' 'NameLocal'"
  }
  dkrcp_test_Desc() {
    echo "hello there"
  }
  dkrcp_test_EnvCheck() {
    local -r existInd_ref="$1"
    test_env_Check(){
      obj_list_iterate 'env_check' "$existInd_ref"
    }
    test_obj_Closure 'test_env_Check'
  }
  dkrcp_test_Run() {
    obj_Echo(){
      obj_EchoIt(){
        echo "Start: $1"
        AssociativeMapKeyValueEcho "$1"
        echo "end: $1"
      }
      obj_list_iterate 'obj_EchoIt'
      
    }
    test_obj_Closure 'obj_Echo'
  }
  dkrcp_test_EnvClean() {
    test_env_Clean(){
      obj_list_iterate 'env_clean'
    }
    test_obj_Closure 'test_env_Clean'
  }
}
