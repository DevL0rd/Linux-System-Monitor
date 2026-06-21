.pragma library
/*
 * Fixed-size ring buffer of numbers for rolling history: O(1) push that
 * overwrites the oldest sample -- no Array.shift() re-indexing and no per-sample
 * reallocation. Linearise to a plain array only when a chart actually renders it.
 */
function make(cap) { return { buf: new Array(cap), head: 0, len: 0, cap: cap } }

function push(r, v) {
    r.buf[r.head] = v
    r.head = (r.head + 1) % r.cap
    if (r.len < r.cap) r.len++
}

// oldest -> newest, as a plain array (what Sparkline wants)
function values(r) {
    var n = r.len, out = new Array(n)
    var start = (r.head - n + r.cap) % r.cap
    for (var i = 0; i < n; i++) out[i] = r.buf[(start + i) % r.cap]
    return out
}

// mean over the kept window (order-independent, so no linearise needed)
function avg(r) {
    if (r.len === 0) return 0
    var s = 0
    for (var i = 0; i < r.len; i++) s += r.buf[i]
    return s / r.len
}
