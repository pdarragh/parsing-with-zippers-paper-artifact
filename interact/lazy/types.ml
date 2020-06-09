type pos = int ref (* Using ref makes it easy to create values that are not pointer equal *)
let p_bottom = ref (-1)

type sym = string
let s_bottom = "<s_bottom>"

type tag = int
type tok = tag * sym
let t_eof = (-1, "<t_eof>")

type exp = exp_ Lazy.t
and exp_ = { mutable m  : mem; e' : exp'; }
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

let rec e_bottom = lazy { m = m_bottom; e' = Alt (ref []) }
    and m_bottom = { start_pos = p_bottom; parents = []; end_pos = p_bottom; result = e_bottom }

let tok (t : tok)                 : exp_ = { m = m_bottom; e' = Tok(t) }
let seq (s : sym) (es : exp list) : exp_ = { m = m_bottom; e' = Seq(s, es) }
let alt (es : exp list)           : exp_ = { m = m_bottom; e' = Alt(ref es) }
