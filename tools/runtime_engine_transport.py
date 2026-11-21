"""Derive private Engine binding roles from pinned Fairy C transport."""

import re


def project_layouts(t, c, *, host_compile=True):
    c['bindings']={}
    for number,tail in re.findall(r'bc_runtime_engine_binding\(UINT32_C\((\d+)\)\);(.*?)(?=bc_runtime_engine_binding|\Z)',t,re.S):
     found=re.search(r'(fy_fn_\d+)\(',tail)
     if found:
      if number in c['bindings']:raise RuntimeError('Duplicate binding marker '+number)
      c['bindings'][number]=found.group(1)
    # MSVC transport orders the reply witness after a forward block jump. Resolve
    # that jump within the witness definition before reading the typed callee.
    reply_body=re.search(r'^static void fy_fn_\d+\([^\n]*\) \{\n(?:(?!^}).)*bc_runtime_engine_binding\(UINT32_C\(40\)\);(?:(?!^}).)*^}',t,re.M|re.S).group()
    reply_target=re.search(r'bc_runtime_engine_binding\(UINT32_C\(40\)\);\s+goto (fy_b_\d+);',reply_body).group(1)
    reply_block=re.search(r'^'+reply_target+r':\n((?:    [^\n]*\n)+)',reply_body,re.M).group(1)
    c['bindings']['40']=re.search(r'\b(fy_fn_\d+)\(',reply_block).group(1)
    definitions=list(re.finditer(r'^static [^\n]+\b(fy_fn_\d+)\([^\n]*\) \{',t,re.M))
    marked=[]
    for i,match in enumerate(definitions):
     block=t[match.end():definitions[i+1].start() if i+1<len(definitions) else len(t)]
     if 'bc_runtime_engine_binding(UINT32_C(29));' in block:marked.append(match.group(1))
    assert len(marked)==1,marked
    c['bindings']['29']=marked[0]
    def decl(n):return re.search(r'^static [^\n]+\b'+c['bindings'][str(n)]+r'\([^\n]*\);$',t,re.M).group()
    c['reviewedDeclarations']={n:decl(n) for n in c['bindings']}
    def arg(n,i):
     a=decl(n).split('(',1)[1].split(',')[i];return re.search(r'\bfy_(?:struct|resource)_\d+\b',a).group()
    for n,i,k in [(4,2,'incomingType'),(9,2,'inputEntryType'),(10,5,'snapshotType'),(11,4,'snapshotVectorType'),(16,2,'outputVectorType'),(21,1,'programVectorType'),(22,0,'instanceType'),(25,0,'programType'),(28,0,'machineType'),(30,0,'outputType'),(31,0,'pendingVectorType'),(31,1,'completionType'),(31,2,'publishedVectorType')]:c[k]=arg(n,i)
    c['coreType']=arg(28,1)
    c['entryTypes']={'ordinary':arg(19,0),'input':arg(20,0)}
    output_layout=re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(c['outputType'])+';$',t,re.M).group()
    c['executionType']=re.search(r'\b(fy_resource_\d+) f_1;',output_layout).group(1)
    def field_type(owner,index):
     layout=re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(owner)+';$',t,re.M).group()
     return re.search(r'\b(fy_(?:struct|resource)_\d+) f_'+str(index)+r';',layout).group(1)

    # Resolve resource roles from typed projections, never previous numeric IDs.
    def vector_element(vector):
     matches=set(re.findall(r'^static (?:const )?(fy_(?:struct|resource)_\d+) \* fy_fn_\d+\((?:const )?'+re.escape(vector)+r' \* [^,]+, uintptr_t [^;]+;',t,re.M))
     assert len(matches)==1,(vector,matches)
     return matches.pop()
    c['sourceIndexType']=field_type(c['entryTypes']['ordinary'],0)
    c['sourceIndexVectorType']=field_type(c['sourceIndexType'],0)
    c['boundInputType']=vector_element(arg(10,3))
    for variant,index in [('ordinary',3),('input',4),('output',5)]:
     program=vector_element(field_type(c['programType'],index))
     c['programVariants'][variant]={'program':program,'stored':vector_element(field_type(program,0))}
    engine_candidates=[]
    for layout,name in re.findall(r'^(typedef struct \{\n[^}]*\} (fy_resource_\d+);)$',t,re.M):
     if re.search(r'\b'+re.escape(arg(1,0))+r' f_0;',layout) and re.search(r'\b'+re.escape(c['programVectorType'])+r' f_1;',layout):engine_candidates.append(name)
    assert len(engine_candidates)==1,engine_candidates
    c['engineType']=engine_candidates[0]
    c['compileWorkVectorType']=field_type(c['engineType'],9)
    c['compileWorkType']=vector_element(c['compileWorkVectorType'])
    assert arg(42,2)==arg(44,1)==arg(45,1)==arg(46,0)==c['compileWorkVectorType']
    c['compileCandidateVectorType']=field_type(c['engineType'],11)
    c['compileCandidateType']=vector_element(c['compileCandidateVectorType'])
    c['compileProofVectorType']=field_type(c['compileCandidateType'],9)
    c['compileProofType']=arg(50,2)
    assert arg(53,0)==c['compileProofVectorType']
    c['compileProofImageType']=field_type(c['compileCandidateType'],10)
    c['compileOutputProofVectorType']=field_type(c['compileCandidateType'],11)
    c['compileOutputProofType']=vector_element(c['compileOutputProofVectorType'])
    assert arg(60,0)==arg(61,2)
    assert arg(60,1)==arg(61,3)
    assert arg(62,2)==c['compileOutputProofType']
    assert arg(61,2)==field_type(c['compileOutputProofType'],0)
    assert arg(61,3)==field_type(c['compileOutputProofType'],1)
    assert arg(59,1)==arg(61,1)==arg(62,1)==c['compileProofImageType']
    assert arg(62,5)==field_type(c['programType'],5)
    assert arg(59,0)==arg(51,1)==field_type(c['compileCandidateType'],1)
    assert arg(61,0)==arg(62,0)==arg(50,0)==field_type(c['compileCandidateType'],0)
    assert arg(61,4)==arg(62,3)==field_type(vector_element(c['sourceIndexVectorType']),0)
    assert arg(61,5)==arg(50,4)
    assert arg(50,2)==arg(52,2)==arg(58,2)==c['compileProofType']
    assert arg(50,1)==arg(51,2)==arg(52,1)==arg(58,1)==c['compileProofImageType']
    assert arg(42,4)==arg(45,3)==arg(47,0)==arg(55,4)==arg(56,3)==c['compileCandidateVectorType']
    assert arg(48,1)==arg(49,1)==arg(50,3)==arg(51,4)==c['sourceIndexType']
    assert arg(58,3)==c['entryTypes']['input']
    assert arg(58,4)==field_type(c['programType'],4)
    assert arg(42,3)==arg(43,0)==arg(44,2)==arg(44,3)==arg(45,2)==field_type(c['engineType'],10)==c['incomingType']
    assert arg(54,2)==arg(54,3)==arg(55,3)==arg(56,2)==arg(57,0)==field_type(c['engineType'],12)==c['inputEntryType']
    assert arg(54,1)==arg(55,2)==arg(56,1)==c['compileWorkVectorType']
    c['hostProgramVectorType']=field_type(c['programType'],9)
    assert arg(38,2)==c['hostProgramVectorType']
    c['hostProgramType']=vector_element(c['hostProgramVectorType'])
    if host_compile:
        host_ir_vector=field_type(c['hostProgramType'],0)
        host_ir=set(re.findall(r'^static fy_tagged_\d+ fy_fn_\d+\('+re.escape(host_ir_vector)+r' \* [^,]+, (fy_struct_\d+) [^;]+;',t,re.M))
        assert len(host_ir)==1,host_ir
        c['hostIRType']=host_ir.pop()
    else:
        c.pop('hostIRType',None)
    c['hostExchangeVectorType']=field_type(c['outputType'],3)
    c['hostExchangeType']=vector_element(c['hostExchangeVectorType'])
    c['hostRunConfigType']=arg(39,5)
    c['hostTransitionType']=arg(41,7)
    assert arg(41,0)==c['hostExchangeVectorType']
    assert arg(63,0)==c['hostExchangeVectorType']
    assert arg(63,1)==c['completionType'] and arg(63,2)==c['publishedVectorType']
    assert arg(40,1)==c['programVectorType'] and arg(40,3)==arg(40,4)==c['outputVectorType']
    c['policyVectorType']=field_type(c['engineType'],8)
    c['policyType']=vector_element(c['policyVectorType'])
    assert arg(37,0)==c['policyVectorType']
    c['pendingMetaType']=arg(26,2)
    c['cursorType']=field_type(c['pendingMetaType'],0)
    c['outputCopyType']=field_type(c['cursorType'],2)
    c['arrayFillType']=field_type(c['cursorType'],3)
    c['callCopyType']=field_type(c['cursorType'],4)
    c['returnWorkType']=field_type(c['cursorType'],5)
    c['metadataBudgetType']=field_type(c['cursorType'],6)
    c['callMetadataType']=field_type(c['coreType'],7)
    c['callContextWorkType']=field_type(c['callMetadataType'],8)
    c['callArgumentWorkType']=field_type(c['callContextWorkType'],0)
    c['callOwnedWorkType']=field_type(c['callContextWorkType'],1)
    c['returnPreparationType']=field_type(c['callMetadataType'],9)
    c['returnRecordPlanType']=field_type(c['returnPreparationType'],0)
    c['returnCatalogWorkType']=field_type(c['returnRecordPlanType'],0)
    c['callCopyPlanType']=field_type(c['coreType'],8)
    assert arg(26,11)==c['callCopyPlanType']
    c['returnMetadataType']=field_type(c['cursorType'],9)
    c['lifecycleType']=field_type(c['pendingMetaType'],6)
    c['setupWorkType']=field_type(c['lifecycleType'],0)
    c['preparationWorkType']=field_type(c['lifecycleType'],1)
    c['cleanupWorkType']=field_type(c['lifecycleType'],2)
    c['inputWindowsType']=field_type(c['machineType'],5)
    c['storageBufferType']=field_type(c['machineType'],0)
    assert field_type(c['inputWindowsType'],0)==c['storageBufferType']
    c['runtimeMetadataType']=field_type(c['callMetadataType'],1)
    c['cleanupRuntimeType']=field_type(c['runtimeMetadataType'],0)
    assert arg(27,7)==c['runtimeMetadataType'] and arg(34,2)==c['pendingMetaType'] and arg(35,2)==c['coreType']

    assert arg(26,10)==c['callMetadataType']
    assert re.fullmatch(r'\s*'+re.escape(c['callMetadataType'])+r'\s*\*\s*fy_l_\d+\s*',decl(26).split('(',1)[1].split(',')[10])
    c['transactionType']=field_type(c['machineType'],6)
    c['preparationType']=field_type(c['programVariants']['output']['stored'],4)
    c['capturePlanType']=field_type(c['preparationType'],8)
    types={k:c[k] for k in ['engineType','programType','instanceType','boundInputType','outputType','sourceIndexType','sourceIndexVectorType','programVectorType','snapshotType','snapshotVectorType','machineType','coreType','executionType','pendingVectorType','completionType','publishedVectorType','pendingMetaType','cursorType','outputCopyType','transactionType']}
    for variant,rows in c['programVariants'].items():types.update({variant+'_'+k:v for k,v in rows.items()})
    types.update({k+'_entry':v for k,v in c['entryTypes'].items()})
    types['preparationType']=c['preparationType']
    types['arrayFillType']=c['arrayFillType']
    types['callCopyType']=c['callCopyType']
    types['returnWorkType']=c['returnWorkType']
    types['metadataBudgetType']=c['metadataBudgetType']
    types['callMetadataType']=c['callMetadataType']
    for key in ['callContextWorkType','callArgumentWorkType','callOwnedWorkType','returnPreparationType','returnRecordPlanType','returnCatalogWorkType']:types[key]=c[key]
    types['callCopyPlanType']=c['callCopyPlanType']
    types['returnMetadataType']=c['returnMetadataType']
    types['policyVectorType']=c['policyVectorType']
    types['policyType']=c['policyType']
    types['capturePlanType']=c['capturePlanType']
    for key in ['hostProgramVectorType','hostProgramType','hostIRType','hostExchangeVectorType','hostExchangeType','hostRunConfigType','hostTransitionType']:
        if key in c:types[key]=c[key]
    c['reviewedLayouts']={k:re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(v)+';$',t,re.M).group() for k,v in types.items()}
    assert len(c['bindings'])==63 and len(c['reviewedLayouts'])==51+host_compile
    for key in ['lifecycleType','setupWorkType','preparationWorkType','cleanupWorkType','runtimeMetadataType','cleanupRuntimeType','inputWindowsType','storageBufferType']:
     c['reviewedLayouts'][key]=re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(c[key])+';$',t,re.M).group()
    for key in ['compileWorkType','compileWorkVectorType','compileCandidateType','compileCandidateVectorType','compileProofType','compileProofVectorType','compileProofImageType','compileOutputProofType','compileOutputProofVectorType']:
     c['reviewedLayouts'][key]=re.search(r'^typedef struct \{\n[^}]*\} '+re.escape(c[key])+';$',t,re.M).group()
    assert len(c['reviewedLayouts'])==68+host_compile


def bindings_header(contract):
    bindings = f'typedef {contract["engineType"]} bc_engine;\ntypedef {contract["incomingType"]} bc_engine_input;\n'
    bindings += f'typedef {contract["inputEntryType"]} bc_engine_input_entry;\ntypedef {contract["snapshotType"]} bc_engine_snapshot;\n'
    bindings += f'typedef {contract["snapshotVectorType"]} bc_engine_snapshots;\n'
    bindings += f'typedef {contract["outputVectorType"]} bc_engine_outputs;\n'
    bindings+=f'typedef {contract["machineType"]} bc_pending_machine;\ntypedef {contract["coreType"]} bc_pending_core;\n'
    bindings+=f'typedef {contract["preparationType"]} bc_output_preparation;\n'
    bindings+=f'typedef {contract["arrayFillType"]} bc_array_fill_work;\ntypedef {contract["cursorType"]} bc_dispatch_cursor;\n'
    bindings += f'typedef {contract["callCopyType"]} bc_call_copy_work;\n'
    bindings += f'typedef {contract["returnWorkType"]} bc_return_work;\n'
    bindings += f'typedef {contract["callMetadataType"]} bc_call_metadata_work;\ntypedef {contract["metadataBudgetType"]} bc_metadata_budget;\n'
    bindings += f'typedef {contract["capturePlanType"]} bc_call_capture_plan;\n'
    for key, alias in [('programType', 'bc_engine_program'), ('instanceType', 'bc_engine_instance'),
                       ('boundInputType', 'bc_engine_bound_input'), ('outputType', 'bc_engine_output')]:
        bindings += f'typedef {contract[key]} {alias};\n'
    for variant, types in contract['programVariants'].items():
        for role, name in types.items():
            bindings += f'typedef {name} bc_{variant}_{role};\n'
    for key, name in contract['entryTypes'].items():
        bindings += f'typedef {name} bc_{key}_entry;\n'
    bindings += f'typedef {contract["policyType"]} bc_engine_policy;\n'
    bindings += f'typedef {contract["compileWorkType"]} bc_compile_work;\n'
    bindings += f'typedef {contract["compileCandidateType"]} bc_compile_candidate;\n'
    bindings += f'typedef {contract["compileProofType"]} bc_compile_proof;\n'
    bindings += f'typedef {contract["compileOutputProofType"]} bc_compile_output_proof;\n'
    bindings += f'typedef {contract["compileCandidateVectorType"]} bc_compile_candidates;\n'
    bindings += f'typedef {contract["hostProgramType"]} bc_host_program;\n'
    if 'hostIRType' in contract:
        bindings += f'typedef {contract["hostIRType"]} bc_host_ir;\n'
    bindings += f'typedef {contract["hostExchangeType"]} bc_host_exchange;\n'
    bindings += '\n'.join(f'#define B{key} {value}' for key, value in contract['bindings'].items()) + '\n'
    return bindings
