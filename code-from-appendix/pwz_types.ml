open Pwz_abstract_types

type exp = { mutable m : mem; e' : exp' }
and exp' = Tok of tok
         | Seq of sym * exp list
         | Alt of (exp list) ref
and cxt  = TopC
         | SeqC of mem * sym * exp list * exp list
         | AltC of mem
and mem  = { start_pos : pos;
             mutable parents : cxt list;
             mutable end_pos : pos;
             mutable result : exp }

type zipper = exp' * mem

let rec e_bottom = { m = m_bottom; e' = Alt (ref []) }
    and m_bottom = { start_pos = p_bottom; parents = []; end_pos = p_bottom; result = e_bottom }
