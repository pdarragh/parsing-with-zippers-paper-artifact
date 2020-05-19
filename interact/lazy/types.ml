type lab = string
type tag = int
type pos = int ref
type tok = tag * lab

type exp = exp_m Lazy.t
and exp_m = {
  mutable m  : mem;
  e' : exp';
}
and exp' =
  | Tok of tok
  | Seq of lab * (exp list)
  | Alt of (exp list) ref
and cxt =
  | TopC
  | SeqC of mem * lab * (exp list) * (exp list)
  | AltC of mem
and mem = {
  start_pos       : pos;
  mutable parents : cxt list;
  mutable end_pos : pos;
  mutable result  : exp;
}

type zipper = exp' * mem

let l_bottom     : lab = "<l_bottom>"
let t_eof        : tok = (-1, l_bottom)
let p_bottom     : pos = ref (-1)
let e'_bottom    : exp' = Alt (ref [])
let rec e_bottom : exp = lazy {
  m  = m_bottom;
  e' = e'_bottom;
}
and m_bottom : mem = {
  start_pos  = p_bottom;
  parents    = [];
  end_pos    = p_bottom;
  result     = e_bottom;
}

let tok (t : tok)                 : exp_m = { m = m_bottom; e' = Tok(t) }
let seq (l : lab) (es : exp list) : exp_m = { m = m_bottom; e' = Seq(l, es) }
let alt (es : exp list)           : exp_m = { m = m_bottom; e' = Alt(ref es) }
