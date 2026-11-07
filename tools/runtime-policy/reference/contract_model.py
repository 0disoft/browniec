"""Small independent contract models. Not a Brownie interpreter or secure parser.
The production metadata parser must enforce budgets while scanning; this offline
reference checks small bounded fixtures and does not provide that guarantee.
"""
from __future__ import annotations
import json
import struct
from typing import Any

class ContractError(ValueError):
    pass

def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)

def strict_json(data: bytes, max_bytes: int = 65536) -> Any:
    require(len(data) <= max_bytes, 'json byte budget')
    text = data.decode('utf-8', errors='strict')
    require(not text.startswith('\ufeff'), 'json BOM')
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        out: dict[str, Any] = {}
        for key, value in items:
            require(key not in out, 'duplicate key')
            out[key] = value
        return out
    def integer(token: str) -> int:
        require(token != '-0' and len(token) <= 21, 'integer spelling/length')
        value = int(token)
        require(-(1 << 63) <= value <= (1 << 64)-1, 'integer range')
        return value
    def no_float(token: str) -> None:
        raise ContractError('noninteger token ' + token[:24])
    obj = json.loads(text, object_pairs_hook=pairs, parse_int=integer,
                     parse_float=no_float, parse_constant=no_float)
    tokens = 0
    def visit(x: Any, depth: int) -> None:
        nonlocal tokens
        tokens += 1
        require(tokens <= 8192 and depth <= 16, 'json structural budget')
        if isinstance(x, str):
            x.encode('utf-8', errors='strict')  # Reject lone surrogate escapes.
        elif isinstance(x, dict):
            for key, val in x.items():
                visit(key, depth+1); visit(val, depth+1)
        elif isinstance(x, list):
            for val in x: visit(val, depth+1)
    visit(obj, 0)
    return obj

def validate_policy_relations(p: dict[str, Any]) -> None:
    c,e,r,w = (p[k] for k in ('compile','engine','run','worker'))
    for key in ('object_bytes','input_bytes','output_bytes','host_request_bytes','host_response_bytes'):
        require(r[key] <= r['memory_bytes'], key + ' exceeds Instance')
    require(r['memory_bytes'] <= e['instances_bytes'], 'Instance exceeds set')
    require(e['program_bytes'] <= e['total_program_bytes'], 'Program exceeds set')
    for val in (c['working_bytes'],e['control_bytes'],e['total_program_bytes'],e['instances_bytes']):
        require(val <= e['memory_bytes'], 'component exceeds Engine')
    require(e['memory_bytes']+w['transport_bytes']+(4+32)*1024*1024 <= w['memory_bytes'], 'worker headroom')
    require(c['source_bytes'] <= c['working_bytes'], 'source exceeds compiler')
    require(w['startup_ms'] <= w['session_ms'] and c['deadline_ms'] <= w['session_ms']
            and r['deadline_ms'] <= w['session_ms'], 'phase exceeds session')

def validate_run(p: dict[str, Any], config: dict[str, Any], required: set[str]) -> None:
    require(required <= set(config['requires']), 'requires mismatch')
    require(set(config['requires']) <= set(config['grants']) <= set(p['capabilities']), 'capability denied')
    require(set(config['limits']) == set(p['run']), 'run field mismatch')
    require(all(0 <= v <= p['run'][k] for k,v in config['limits'].items()), 'run limit escalation')
    candidate = {**p, 'run': config['limits']}
    validate_policy_relations(candidate)

def canonical_catalog(catalog: dict[str, Any]) -> bytes:
    imports = catalog['imports']
    require(len(imports) <= 64, 'catalog size')
    names = [i['module']+'::'+i['symbol'] for i in imports]
    require(names == sorted(set(names)), 'catalog ordering/duplicate')
    require([i['id'] for i in imports] == list(range(len(imports))), 'catalog IDs')
    out=bytearray(b'BRC-CATALOG-1\n'+struct.pack('<I',len(imports)))
    def string(s: str) -> None:
        b=s.encode('ascii'); out.extend(struct.pack('<I',len(b)));out.extend(b)
    for item in imports:
        out.extend(struct.pack('<I', item['id']))
        for key in ('module','symbol','result','effect','capability','adapter_revision'):string(item[key])
        out.extend(struct.pack('<I',len(item['parameters'])))
        for param in item['parameters']:string(param)
    return bytes(out)

TAGS={'bool':1,'u8':2,'i32':3,'i64':4,'u32':5,'usize':6,'bytes':7}
WIDTH={'bool':1,'u8':1,'i32':4,'i64':8,'u32':4,'usize':8}

def encode_tlv(types: list[str], values: list[str], request: bool) -> bytes:
    require(len(types)==len(values) and (len(types)<=32 if request else len(types)==1),'TLV arity')
    out=bytearray(struct.pack('<H',len(types)) if request else b'')
    for typ, value in zip(types,values):
        if typ=='bytes':data=bytes.fromhex(value)
        elif typ=='bool':
            require(value in ('true','false'),'bool spelling');data=bytes([value=='true'])
        else:data=int(value).to_bytes(WIDTH[typ],'little',signed=typ.startswith('i'))
        out.extend(struct.pack('<B3xI',TAGS[typ],len(data)));out.extend(data)
    return bytes(out)

def decode_tlv(data: bytes, expected: list[str], request: bool, cap: int=1048576) -> list[str]:
    require(len(data)<=cap,'TLV cap')
    pos=0
    if request:
        require(len(data)>=2,'argc truncated');count=struct.unpack_from('<H',data)[0];pos=2
        require(count<=32 and count==len(expected),'argc')
    else:require(len(expected)==1,'reply arity')
    result=[]
    for typ in expected:
        require(len(data)-pos>=8,'field truncated')
        tag=data[pos];reserved=data[pos+1:pos+4];length=struct.unpack_from('<I',data,pos+4)[0];pos+=8
        require(tag==TAGS[typ] and reserved==b'\0\0\0','tag/reserved')
        require(length<=len(data)-pos,'data truncated')
        part=data[pos:pos+length];pos+=length
        if typ=='bytes':result.append(part.hex())
        else:
            require(length==WIDTH[typ],'scalar length')
            if typ=='bool':
                require(part[0]<=1,'bool canonical');result.append('true' if part[0] else 'false')
            else:result.append(str(int.from_bytes(part,'little',signed=typ.startswith('i'))))
    require(pos==len(data),'trailing TLV data')
    return result

KINDS={1:'HELLO',2:'COMPILE',3:'COMPILED',4:'RUN',5:'HOST_REQUEST',6:'HOST_REPLY',7:'CANCEL',8:'RESULT',9:'ERROR'}
HEADER=struct.Struct('<4sHHIIIIII')

def encode_frame(kind: int, command: int, run: int, request: int, metadata: dict[str,Any], blob: bytes=b'') -> bytes:
    raw=json.dumps(metadata,ensure_ascii=False,separators=(',',':')).encode('utf-8')
    return HEADER.pack(b'BRC2',2,kind,len(raw),len(blob),command,run,request,0)+raw+blob

def decode_frame(frame: bytes) -> dict[str,Any]:
    require(len(frame)>=HEADER.size,'short header')
    magic,ver,kind,n,m,cmd,run,req,flags=HEADER.unpack_from(frame)
    require(magic==b'BRC2' and ver==2 and kind in KINDS and flags==0,'header')
    require(n<=65536 and m<=1048576,'frame cap')
    require(len(frame)==HEADER.size+n+m,'frame length')
    meta=strict_json(frame[HEADER.size:HEADER.size+n])
    require(meta.get('kind')==KINDS[kind] and meta.get('schema')=='brownie.ipc/2','frame metadata kind')
    return dict(kind=kind,command_id=cmd,run_id=run,request_id=req,metadata=meta,blob_hex=frame[HEADER.size+n:].hex())

def arithmetic(typ: str, op: str, operands: list[str]) -> dict[str,str]:
    bits={'u8':8,'i32':32,'i64':64,'u32':32,'usize':64}[typ]
    signed=typ.startswith('i');lo=-(1<<(bits-1)) if signed else 0;hi=(1<<(bits-1 if signed else bits))-1
    vals=list(map(int,operands));require(all(lo<=v<=hi for v in vals),'operand range')
    a=vals[0];b=vals[1] if len(vals)>1 else None
    if op in ('div','rem'):
        if b==0:return {'trap':'division_by_zero'}
        if signed and a==lo and b==-1:return {'trap':'integer_overflow'}
        q=abs(a)//abs(b)
        if (a<0)!=(b<0):q=-q
        v=q if op=='div' else a-q*b
    elif op in ('shl','shr'):
        if b<0 or b>=bits:return {'trap':'invalid_shift'}
        v=a*(1<<b) if op=='shl' else a>>b
    elif op=='add':v=a+b
    elif op=='sub':v=a-b
    elif op=='mul':v=a*b
    elif op=='neg':v=-a
    elif op=='band':v=a & b
    else:raise ContractError('unmodeled arithmetic '+op)
    return {'value':str(v)} if lo<=v<=hi else {'trap':'integer_overflow'}

def reserve(limit: int, used: int, request: int) -> bool:
    return 0<=used<=limit and 0<=request<=limit-used

def copy_plan(length: int, quantum: int) -> tuple[int,int]:
    require(length>=0 and 1<=quantum<=4096,'copy input')
    pending=length;started=False;calls=0;fuel=0
    while not started or pending:
        calls+=1;left=quantum
        if not started:
            started=True;fuel+=1+length//16+int(length%16!=0);left-=1
        while left and pending:
            pending-=min(4096,pending);left-=1
    return calls,fuel

def state_trace(actions: list[str]) -> tuple[str,int,int]:
    """Independent narrow state model: state, accepted replies, published outputs."""
    state='RUNNABLE';accepted=0;published=0;cause=None
    for action in actions:
        if action=='destroy':
            require(state!='DISPOSED','already destroyed');state='DISPOSED';continue
        if state in ('DONE','TRAPPED','FAILED'):
            require(action in ('poll','cancel'),'terminal mutation');continue
        if state=='RUNNABLE':
            if action=='host_request':state='WAITING_HOST'
            elif action=='yield':pass
            elif action=='done':state='DONE';published+=1
            elif action in ('cancel','deadline','trap','internal','engine_poison'):state='STOPPING';cause=action
            else:raise ContractError('runnable action')
        elif state=='WAITING_HOST':
            if action in ('reply_invalid','reply_oom','poll'):pass
            elif action=='reply_valid':state='RUNNABLE';accepted+=1
            elif action in ('cancel','deadline','reply_quota','internal','engine_poison'):state='STOPPING';cause=action
            else:raise ContractError('waiting action')
        elif state=='STOPPING':
            if action in ('cleanup_yield','cancel'):pass
            elif action=='cleanup_internal_done':
                require(cause in ('internal','engine_poison'),'wrong terminal cause');state='FAILED'
            elif action=='cleanup_trap_done':
                require(cause not in ('internal','engine_poison'),'wrong terminal cause');state='TRAPPED'
            else:raise ContractError('stopping action')
        else:raise ContractError('disposed action')
    return state,accepted,published
