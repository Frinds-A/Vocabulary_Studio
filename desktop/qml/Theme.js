.pragma library

// ---------------------------------------------------------------------------
// 词序 design tokens — a quiet, white system inspired by the DSH desktop UI.
// White surfaces, hairline borders, near-black type and a quiet grayscale accent.
// No gradients: every surface is a single flat colour.
// ---------------------------------------------------------------------------

// Core surfaces
var white = "#FFFFFF"
var canvas = "#F7F8FA"
var canvasWarm = "#FFFFFF"
var sidebar = "#F9FAFB"
var neutralPale = "#F3F4F6"
var neutralSoft = "#F9FAFB"

// Type
var ink = "#2A3038"
var inkSoft = "#3F4650"
var muted = "#5A626C"
var faint = "#737A84"
var line = "#E4E7EC"
var lineStrong = "#CFD4DA"

// Accent and states
var accent = "#3A4048"
var accentSoft = "#F0F1F3"
var green = "#2F343B"
var greenPale = "#F0F1F3"
var red = "#6B7078"
var redPale = "#F7F7F8"
// Low-saturation error highlight for per-letter spelling marks.
var mistakePale = "#F7E9E9"
var mistakeInk = "#7A4F4F"
var mistakeLine = "#D9BDBD"
var amber = "#F59E0B"
var amberPale = "#FFFBEB"

// Legacy aliases used across the QML. They intentionally collapse to the same
// restrained palette so no old saturated colour survives.
var cyan = accent
var teal = accent
var mint = accent
var greenBright = accent
var lime = accent
var yellow = accent
var violet = ink
var pink = inkSoft
var rose = muted
var coral = muted
var lemon = muted

var paleViolet = neutralPale
var palePink = neutralPale
var paleRose = neutralPale
var paleCoral = neutralPale
var paleAmber = neutralPale
var paleLemon = neutralPale

var palette = ["#3A4048", "#5A5F66", "#7A7F87", "#9A9FA6", "#B8BCC2", "#D5D8DC"]
var paletteDeep = ["#3A4048", "#5A5F66", "#7A7F87", "#9A9FA6", "#B8BCC2", "#D5D8DC"]

var fontCN = "Microsoft YaHei UI"
var fontEN = "Times New Roman"

var shadowViolet = "#140F1115"
var shadowPink = "#120F1115"
var shadowWarm = "#100F1115"

function deckTheme(deck) {
    return {
        c1: ink,
        c2: ink,
        pale1: neutralSoft,
        pale2: neutralPale,
        deep: ink,
        tagBg: neutralPale,
        onCta: white
    }
}

function deckShort(deck) {
    var short = String((deck && deck.short) || "")
    if (short) return short
    var exam = String((deck && deck.exam) || "")
    if (exam === "cet4") return "CET-4"
    if (exam === "cet6") return "CET-6"
    if (exam === "cet") return "CET-4/6"
    if (exam === "postgrad") return "NPEE"
    if (exam === "自定义" || exam === "custom") return "CUSTOM"
    return "WORD"
}

function deckTag(deck) {
    return String((deck && (deck.tag || deck.type)) || "词库")
}

function deckTitle(deck) {
    return String((deck && deck.name) || "未命名词库")
}

function progressOf(deck) {
    var total = Number((deck && deck.total) || 0)
    if (!total) return 0
    return Math.max(0, Math.min(1, Number((deck && deck.learned) || 0) / total))
}

function displayStat(value, fallback) {
    return value === undefined || value === null || value === "" ? String(fallback) : String(value)
}

function posLabel(value) {
    var raw = String(value || "").trim()
    var key = raw.toLowerCase().replace(/\.$/, "")
    var known = {
        "n": "n.", "noun": "n.", "v": "v.", "verb": "v.",
        "vt": "vt.", "vi": "vi.", "adj": "adj.", "adjective": "adj.",
        "adv": "adv.", "adverb": "adv.", "pron": "pron.", "pronoun": "pron.",
        "prep": "prep.", "preposition": "prep.", "conj": "conj.",
        "conjunction": "conj.", "aux": "aux.", "aux.v": "aux.v.",
        "modal v": "modal v.", "num": "num.", "det": "det.",
        "exclam": "exclam.", "phrase": "词组", "phr": "词组"
    }
    return known[key] || (raw.length ? (/[.。]$/.test(raw) ? raw : raw + ".") : "")
}

function senseRows(entry) {
    var e = entry || {}
    if (e.senses && e.senses.length)
        return e.senses
    var meaningText = String(e.meaning || "")
    var parts = meaningText.split(/[;；\n]+/).map(function (s) { return s.trim() }).filter(function (s) { return s.length })
    return [{ pos: e.pos || (e.phrase ? "phrase" : ""), meanings: parts.length ? parts : [meaningText] }]
}

function rowMeaning(row) {
    if (row && row.meanings && typeof row.meanings.join === "function")
        return row.meanings.join("；")
    if (row && row.meanings && row.meanings.length)
        return String(row.meanings)
    return String((row && row.meaning) || "")
}

function isLetterAt(text, at) {
    return /[a-zà-ÿ]/i.test(String(text || "").charAt(at))
}

function slotIndexAt(text, at) {
    var count = 0
    for (var i = 0; i < at; ++i)
        if (isLetterAt(text, i)) count++
    return count
}

function wordLetterCount(text) {
    var count = 0
    for (var i = 0; i < String(text || "").length; ++i)
        if (isLetterAt(text, i)) count++
    return count
}

function todayLabel() {
    var names = ["日", "一", "二", "三", "四", "五", "六"]
    var d = new Date()
    return (d.getMonth() + 1) + "月" + d.getDate() + "日 · 星期" + names[d.getDay()]
}

function greeting() {
    var h = new Date().getHours()
    if (h < 6) return "夜深了，也别太累。"
    if (h < 11) return "早上好，今天也向前一点。"
    if (h < 14) return "中午好，给记忆留一点时间。"
    if (h < 19) return "下午好，慢一点也很稳。"
    return "晚上好，今天辛苦了。"
}

function weekLabel(index) {
    return ["一", "二", "三", "四", "五", "六", "日"][index] || ""
}

function weekMax(values) {
    var max = 0
    for (var i = 0; i < values.length; ++i)
        max = Math.max(max, Number(values[i]) || 0)
    return Math.max(1, max)
}

function dailyQuote(_revision) {
    var quotes = [
        { en: "The limits of my language mean the limits of my world.",
          zh: "语言的边界，就是世界的边界。" },
        { en: "We are what we repeatedly do.",
          zh: "我们反复做的事，塑造了我们。" },
        { en: "The unexamined life is not worth living.",
          zh: "未经省察的人生，不值得过。" },
        { en: "Memory is the scribe of the soul.",
          zh: "记忆，是灵魂的书记官。" },
        { en: "Knowing yourself is the beginning of all wisdom.",
          zh: "认识自己，是一切智慧的开端。" },
        { en: "I know that I know nothing.",
          zh: "我唯一知道的，是我一无所知。" }
    ]
    var d = new Date()
    var index = (d.getFullYear() * 372 + d.getMonth() * 31 + d.getDate()) % quotes.length
    return quotes[index]
}
