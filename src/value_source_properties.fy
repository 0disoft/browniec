module value_source_properties;
import value_properties as properties;
import value_properties_work as work;
import metadata_budget as budget;
// Private compiler adapter. Runtime inspectors keep their existing path.
pub fn Result<properties::Plan,properties::Error> inspect(ref properties::Catalog catalog){
    var work::State w=work::empty();var budget::State meter=budget::empty();
    while(!w.done){switch(budget::reset(ref mut meter,0)){case .ok(_):{}case .err(_):{return .err(.Metadata);}};
        let bool done=work::advance(catalog,ref mut w,ref mut meter)?;}
    return work::prepared(ref w);
}
