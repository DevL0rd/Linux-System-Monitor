.pragma library

// ---- numeric / unit formatting ----

function mbps(v) {
    if (v === undefined || v === null) return "0";
    if (v >= 1000) return (v / 1000).toFixed(2) + " Gb/s";
    if (v >= 100)  return v.toFixed(0) + " Mb/s";
    return v.toFixed(1) + " Mb/s";
}

function bytes(kb) {
    // input in KiB (router reports KiB for mem/storage)
    var u = ["KiB", "MiB", "GiB", "TiB"];
    var i = 0, v = kb;
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
    return v.toFixed(v < 10 && i > 0 ? 1 : 0) + " " + u[i];
}

function pct(v) {
    return (v === undefined || v === null ? 0 : v).toFixed(0) + "%";
}

// bytes/sec -> human bitrate; -1 or 0 shows a dash (unknown / idle)
function rate(bps) {
    if (bps === undefined || bps === null || bps < 0) return "—";
    var bits = bps * 8;
    if (bits >= 1e6) return (bits / 1e6).toFixed(1) + " Mb/s";
    if (bits >= 1e3) return (bits / 1e3).toFixed(0) + " Kb/s";
    if (bits < 1) return "idle";
    return bits.toFixed(0) + " b/s";
}

function duration(sec) {
    sec = Math.floor(sec || 0);
    var d = Math.floor(sec / 86400);
    var h = Math.floor((sec % 86400) / 3600);
    var m = Math.floor((sec % 3600) / 60);
    if (d > 0) return d + "d " + h + "h";
    if (h > 0) return h + "h " + m + "m";
    return m + "m";
}

function temp(v) {
    return Math.round(v || 0) + "°C";
}

function dbm(v) {
    return (v || 0) + " dBm";
}

// ---- colour helpers (used to tint values by health) ----

// returns a colour string given value and warn/crit thresholds
function heat(v, warn, crit, theme) {
    if (v >= crit) return theme.negativeTextColor;
    if (v >= warn) return theme.neutralTextColor;
    return theme.positiveTextColor;
}

// smooth fill gradient for a 0..100 value: blue when low/empty, through
// green/yellow, to red when full. Used for meters, bars and per-core fills.
function grad(v) {
    var t = Math.max(0, Math.min(1, (v || 0) / 100));
    return Qt.hsla((1 - t) * 0.66, 0.62, 0.55, 1.0);
}

// rssi: closer to 0 is better
function rssiColor(v, theme) {
    if (v >= -60) return theme.positiveTextColor;
    if (v >= -72) return theme.neutralTextColor;
    return theme.negativeTextColor;
}

// signal bars 0..4 from rssi
function rssiBars(v) {
    if (v >= -55) return 4;
    if (v >= -65) return 3;
    if (v >= -72) return 2;
    if (v >= -80) return 1;
    return 0;
}
