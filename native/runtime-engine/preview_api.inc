/* Private dispatch layout. Increment the owner protocol for layout or
   contract changes. Keep the discovery export name and signature stable. */
BC_ROUTE(bc_preview_engine_create, (uint32_t revision, bc_handle *out), (revision,out), (void)0)
BC_ROUTE(bc_preview_compile, (bc_handle engine, bc_slice source, bc_handle *out),
         (engine,source,out), (void)0)
BC_ROUTE(bc_preview_instance_create, (bc_handle engine, bc_handle program, uint64_t fuel, bc_handle *out),
         (engine,program,fuel,out), (void)0)
BC_ROUTE(bc_preview_step, (bc_handle instance, uint32_t quantum, bc_preview_event *out),
         (instance,quantum,out), (void)0)
BC_ROUTE(bc_preview_cancel, (bc_handle instance), (instance), (void)0)
BC_ROUTE(bc_preview_instance_destroy, (bc_handle instance), (instance), (void)0)
BC_ROUTE(bc_preview_program_release, (bc_handle engine, bc_handle program), (engine,program), (void)0)
BC_ROUTE(bc_preview_engine_destroy, (bc_handle engine), (engine), (void)0)
BC_ROUTE(bc_preview_compile_entry, (bc_handle engine, const bc_source *sources, uint32_t source_count,
         bc_slice catalog, bc_slice module, bc_slice function, bc_handle *out, bc_diagnostic *diagnostic),
         (engine,sources,source_count,catalog,module,function,out,diagnostic), clear_handle(out))
BC_ROUTE(bc_preview_instance_create_cancellable, (bc_handle engine, bc_handle program,
         bc_slice input, bc_slice config, void *cancel_event, bc_handle *out, bc_diagnostic *diagnostic),
         (engine,program,input,config,cancel_event,out,diagnostic), clear_handle(out))
BC_ROUTE(bc_preview_copy_output, (bc_handle instance, uint8_t *destination, size_t capacity, size_t *out_size),
         (instance,destination,capacity,out_size), (void)0)
BC_ROUTE(bc_engine_create, (uint32_t revision, bc_slice policy, bc_handle *out, bc_diagnostic *diagnostic),
         (revision,policy,out,diagnostic), clear_handle(out))
BC_ROUTE(bc_compile, (bc_handle engine, const bc_source *sources, uint32_t source_count,
         bc_slice catalog, bc_handle *out, bc_diagnostic *diagnostic),
         (engine,sources,source_count,catalog,out,diagnostic), clear_handle(out))
BC_ROUTE(bc_program_entry_info, (bc_handle engine, bc_handle program, bc_slice module, bc_slice function,
         bc_entry_info *out, bc_diagnostic *diagnostic), (engine,program,module,function,out,diagnostic), (void)0)
BC_ROUTE(bc_instance_create, (bc_handle engine, bc_handle program, bc_slice input, bc_slice config,
         bc_handle *out, bc_diagnostic *diagnostic), (engine,program,input,config,out,diagnostic), clear_handle(out))
BC_ROUTE(bc_step, (bc_handle instance, uint32_t quantum, bc_event *out), (instance,quantum,out), (void)0)
BC_ROUTE(bc_host_reply, (bc_handle instance, uint64_t request_id, uint32_t kind, bc_slice payload,
         bc_diagnostic *diagnostic), (instance,request_id,kind,payload,diagnostic), (void)0)
BC_ROUTE(bc_cancel, (bc_handle instance), (instance), (void)0)
BC_ROUTE(bc_instance_destroy, (bc_handle instance), (instance), (void)0)
BC_ROUTE(bc_program_release, (bc_handle engine, bc_handle program), (engine,program), (void)0)
BC_ROUTE(bc_engine_destroy, (bc_handle engine), (engine), (void)0)
