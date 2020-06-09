type pos = int ref (* Using ref makes it easy to create values that are not pointer equal *)
let p_bottom = ref (-1)

type sym = string
let s_bottom = "<s_bottom>"

type tok = string
let t_eof = "<t_eof>"
