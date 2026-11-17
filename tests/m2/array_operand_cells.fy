module tests::m2::array_operand_cells;
import array_operand_work as operands;
import metadata_budget as budget;
import lexer as lexer;
import ir as ir;
import locals as locals;

fn void captured(usize reg,bool accepted){
    var ir::Program code=ir::empty();code.registers=128;code.types[127]=1;
    let locals::Table names=locals::empty();var lexer::State token=lexer::empty();token.kind=93;
    var operands::Frame frame=operands::begin(0,1,0,1,true,64,0);frame.phase=5;frame.value=reg;
    var u8[1] cells=[99];var usize used=0;var budget::State meter=budget::empty();
    switch(operands::advance(b"",ref token,ref mut code,ref names,ref mut frame,ref mut cells,ref mut used,ref mut meter)){
        case .ok(_):{assert(accepted && used==1 && cells[0]==127 && frame.count==1);}
        case .err(error):{assert(!accepted && error.kind==3 && used==0 && cells[0]==99 && frame.count==0);}
    };
}
@test fn void compact_cells_preserve_register_127_and_reject_before_narrowing(){
    captured(127,true);captured(128,false);captured(256,false);
}
