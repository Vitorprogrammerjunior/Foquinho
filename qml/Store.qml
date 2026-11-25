pragma Singleton
import QtQuick

// Estado do app: demandas em foco, fila, concluídas e configurações.
QtObject {
    id: store

    property var backend: null
    property var media: null

    property ListModel focusModel: ListModel {}
    property ListModel queueModel: ListModel {}
    property ListModel doneModel: ListModel {}

    property double now: Date.now()
    property int revision: 0
    property int runningCount: 0
    property double celebrateUntil: 0
    property bool loaded: false
    property bool firstRun: false

    // configurações
    property string petKind: "cat"
    property string petName: "Foquinho"
    property bool autoAdvance: true
    property bool hidden: false
    property int totalDone: 0
    property bool tipsEnabled: true
    property bool musicEnabled: true
    property string lastTipDay: ""
    property bool tipTalking: false

    // ---------- lembrete de pausa (levantar do PC) ----------
    property bool breakEnabled: true
    property int breakMinutes: 90
    property double sitStart: Date.now()   // desde quando você está sentado sem pausa
    property bool breakRinging: false
    property double breakRangAt: 0
    property double lockedAt: 0
    property double lastTick: Date.now()
    readonly property double breakDueAt: sitStart + breakMinutes * 60000
    readonly property bool breakDue: breakEnabled && loaded && !breakRinging && now >= breakDueAt
                                     && !(backend && backend.screenLocked)
    // Saiu de perto por pelo menos isto (tela bloqueada ou PC suspenso)? Conta como pausa.
    readonly property int awayResetMs: 3 * 60000

    // falas curtas do mascote (aparecem no lugar da frase de status)
    property string quip: ""
    property Timer quipTimer: Timer { interval: 2600; onTriggered: store.quip = "" }
    function say(text) { quip = text; quipTimer.restart() }

    // Teclas do atalho global de um comando (o X11 deixa trocar no foco-maxrc)
    function keysFor(cmd, letter) {
        const k = backend && backend.shortcutKeys ? backend.shortcutKeys[cmd] : undefined
        return k && k.length ? k : ["Meta", "Alt", letter]
    }
    function sayOneOf(list) { say(list[Math.floor(Math.random() * list.length)]) }

    readonly property int level: 1 + Math.floor(totalDone / 5)
    readonly property real xp: (totalDone % 5) / 5

    signal completed(string title, double spentMs)
    signal added(string title, bool toFocus)
    signal petEvent(string name)

    onPetKindChanged: saveLater()
    onPetNameChanged: saveLater()
    onAutoAdvanceChanged: saveLater()
    onHiddenChanged: saveLater()
    onTipsEnabledChanged: saveLater()
    onMusicEnabledChanged: saveLater()
    onLastTipDayChanged: saveLater()
    onBreakEnabledChanged: { if (loaded) { resetSitting(); breakRinging = false } saveLater() }
    onBreakMinutesChanged: saveLater()

    property Timer ticker: Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            const n = Date.now()
            // PC suspenso/hibernado: o relógio pula. Ficou longe tempo suficiente, conta como pausa.
            if (n - store.lastTick > store.awayResetMs) store.tookBreak(true)
            store.lastTick = n
            store.now = n
        }
    }

    property Connections lockWatch: Connections {
        target: store.backend
        function onScreenLockedChanged() {
            if (store.backend.screenLocked) {
                store.lockedAt = Date.now()
            } else if (store.lockedAt > 0) {
                if (Date.now() - store.lockedAt >= store.awayResetMs) store.tookBreak(true)
                store.lockedAt = 0
            }
        }
    }
    property Timer saveTimer: Timer { interval: 400; onTriggered: store.save() }
    property Timer heartbeat: Timer { interval: 30000; running: true; repeat: true; onTriggered: store.save() }

    // ---------- derivados ----------
    readonly property string petMood: {
        now; revision
        if (now < celebrateUntil) return "happy"
        if (focusModel.count === 0) return "sleep"
        if (runningCount === 0) return "idle"
        for (let i = 0; i < focusModel.count; i++) {
            const t = focusModel.get(i)
            if (t.running && t.accMs + (now - t.startedAt) > 50 * 60000) return "tired"
        }
        return "focus"
    }

    readonly property string petLine: {
        if (quip) return quip
        if (petMood === "sleep" && media && media.playing) return "♪ Curtindo " + media.title + " com você"
        switch (petMood) {
        case "sleep": return queueModel.count > 0
                ? "Zzz… tem " + queueModel.count + " na fila te esperando"
                : "Zzz… me dá uma demanda?"
        case "idle": return "Pausado. Volto quando você voltar."
        case "happy": return "Uhuul! Mais uma concluída!"
        case "tired": return "Já passou de 50 min. Bora uma pausa?"
        default: return focusModel.count > 1
                ? focusModel.count + " demandas em foco. Vamos lá!"
                : "Foco total. Uma coisa de cada vez."
        }
    }

    readonly property var today: {
        revision; now
        const sod = startOfDay()
        let count = 0, ms = 0
        for (let i = 0; i < doneModel.count; i++) {
            const t = doneModel.get(i)
            if (t.doneAt < sod) break
            count++
            ms += t.spentMs
        }
        for (let j = 0; j < focusModel.count; j++)
            ms += elapsedOf(focusModel.get(j))
        return { count: count, ms: ms }
    }

    // ---------- utilidades ----------
    function uid() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 7) }
    function dayKey() { const d = new Date(); return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate() }
    function startOfDay() { const d = new Date(); d.setHours(0, 0, 0, 0); return d.getTime() }
    function pad(n) { return n < 10 ? "0" + n : "" + n }

    function elapsedOf(t) {
        if (!t) return 0
        return t.accMs + (t.running ? Math.max(0, now - t.startedAt) : 0)
    }

    function fmt(ms) {
        const s = Math.floor(Math.max(0, ms) / 1000)
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : pad(m) + ":" + pad(sec)
    }

    function fmtShort(ms) {
        const m = Math.floor(Math.max(0, ms) / 60000)
        if (m < 1) return "<1m"
        const h = Math.floor(m / 60)
        return h > 0 ? h + "h " + pad(m % 60) + "m" : m + "m"
    }

    function makeTask(title) {
        return { tid: uid(), title: title, accMs: 0, startedAt: 0, running: false,
                 createdAt: Date.now(), doneAt: 0, spentMs: 0 }
    }

    function copyTask(it) {
        return { tid: String(it.tid), title: String(it.title), accMs: Number(it.accMs) || 0,
                 startedAt: Number(it.startedAt) || 0, running: !!it.running,
                 createdAt: Number(it.createdAt) || 0, doneAt: Number(it.doneAt) || 0,
                 spentMs: Number(it.spentMs) || 0 }
    }

    function pauseObj(t) {
        if (t.running) {
            t.accMs += Math.max(0, Date.now() - t.startedAt)
            t.running = false
            t.startedAt = 0
        }
        return t
    }

    function touch() {
        let r = 0
        for (let i = 0; i < focusModel.count; i++)
            if (focusModel.get(i).running) r++
        runningCount = r
        revision++
        saveLater()
    }

    function saveLater() { if (loaded) saveTimer.restart() }

    // ---------- pausas ----------
    function resetSitting() { sitStart = Date.now(); saveLater() }

    function ringBreak() {
        if (breakRinging) return
        breakRinging = true
        breakRangAt = Date.now()
        petEvent("surprised")
    }

    // Levantou (pelo botão, ou bloqueou a tela / suspendeu por alguns minutos).
    function tookBreak(silent) {
        const wasRinging = breakRinging
        breakRinging = false
        resetSitting()
        if (!silent || wasRinging) {
            petEvent("celebrate")
            sayOneOf(["Boa! Alongou?", "Isso! Seu corpo agradece.", "Água também conta, hein!"])
        }
    }

    function snoozeBreak(minutes) {
        breakRinging = false
        sitStart = Date.now() - Math.max(0, breakMinutes - minutes) * 60000
        saveLater()
        say("Tá bom, mais " + minutes + " min. Mas levanta!")
    }

    // "1h30", "45 min"
    function fmtMinutes(m) {
        m = Math.max(0, Math.round(m))
        const h = Math.floor(m / 60), r = m % 60
        if (h === 0) return m + " min"
        return r === 0 ? h + "h" : h + "h" + pad(r)
    }

    // ---------- ações ----------
    function addTask(title, toFocus) {
        title = (title || "").trim()
        if (!title) return
        const t = makeTask(title)
        const goFocus = toFocus || (autoAdvance && focusModel.count === 0)
        if (goFocus) {
            t.running = true
            t.startedAt = Date.now()
            focusModel.append(t)
        } else {
            queueModel.append(t)
        }
        touch()
        added(title, goFocus)
        petEvent(goFocus ? "ready" : "surprised")
        goFocus ? sayOneOf(["Bora focar!", "Partiu! Tô contigo.", "Foco ligado!"])
                : sayOneOf(["Anotado!", "Guardei na fila!", "Pode deixar comigo!"])
    }

    function focusFromQueue(i, silent) {
        if (i < 0 || i >= queueModel.count) return
        const t = copyTask(queueModel.get(i))
        queueModel.remove(i)
        t.running = true
        t.startedAt = Date.now()
        focusModel.append(t)
        touch()
        if (!silent) { petEvent("ready"); sayOneOf(["Bora focar!", "Uma de cada vez!", "Foco ligado!"]) }
    }

    function togglePause(i) {
        const it = focusModel.get(i)
        if (!it) return
        const n = Date.now()
        if (it.running) {
            focusModel.setProperty(i, "accMs", it.accMs + Math.max(0, n - it.startedAt))
            focusModel.setProperty(i, "startedAt", 0)
            focusModel.setProperty(i, "running", false)
        } else {
            focusModel.setProperty(i, "startedAt", n)
            focusModel.setProperty(i, "running", true)
            petEvent("ready")
            say("De volta ao foco!")
        }
        touch()
    }

    function toggleAll() {
        const anyRunning = runningCount > 0
        for (let i = 0; i < focusModel.count; i++)
            if (focusModel.get(i).running === anyRunning) togglePause(i)
    }

    function unfocus(i) {
        if (i < 0 || i >= focusModel.count) return
        const t = pauseObj(copyTask(focusModel.get(i)))
        focusModel.remove(i)
        queueModel.insert(0, t)
        touch()
    }

    function complete(i) {
        if (i < 0 || i >= focusModel.count) return
        const t = pauseObj(copyTask(focusModel.get(i)))
        focusModel.remove(i)
        t.doneAt = Date.now()
        t.spentMs = t.accMs
        doneModel.insert(0, t)
        while (doneModel.count > 300) doneModel.remove(doneModel.count - 1)
        totalDone++
        celebrateUntil = Date.now() + 3200
        if (autoAdvance && queueModel.count > 0) focusFromQueue(0, true)
        touch()
        completed(t.title, t.spentMs)
        petEvent("celebrate")
        sayOneOf(["Uhuul! Mais uma concluída!", "Mandou bem demais!", "Isso aí! Próxima!", "Arrasou!"])
    }

    function completeFirst() { if (focusModel.count > 0) complete(0) }

    function removeQueue(i) {
        if (i < 0 || i >= queueModel.count) return
        queueModel.remove(i)
        touch()
    }

    function renameQueue(i, title) {
        title = (title || "").trim()
        if (!title || i < 0 || i >= queueModel.count) return
        queueModel.setProperty(i, "title", title)
        touch()
    }

    function moveQueue(from, to) {
        if (from === to || from < 0 || to < 0 || from >= queueModel.count || to >= queueModel.count) return
        queueModel.move(from, to, 1)
        touch()
    }

    function restoreDone(i) {
        if (i < 0 || i >= doneModel.count) return
        const t = copyTask(doneModel.get(i))
        doneModel.remove(i)
        t.doneAt = 0
        t.spentMs = 0
        queueModel.insert(0, t)
        totalDone = Math.max(0, totalDone - 1)
        touch()
    }

    // ---------- persistência ----------
    function modelToArray(m) {
        const a = []
        for (let i = 0; i < m.count; i++) a.push(copyTask(m.get(i)))
        return a
    }

    function save() {
        if (!backend || !loaded) return
        backend.saveState(JSON.stringify({
            version: 1,
            lastSeen: Date.now(),
            settings: { petKind: petKind, petName: petName, autoAdvance: autoAdvance, hidden: hidden,
                        tipsEnabled: tipsEnabled, lastTipDay: lastTipDay, musicEnabled: musicEnabled,
                        breakEnabled: breakEnabled, breakMinutes: breakMinutes },
            sitStart: sitStart,
            totalDone: totalDone,
            focus: modelToArray(focusModel),
            queue: modelToArray(queueModel),
            done: modelToArray(doneModel)
        }, null, 1))
    }

    function load() {
        const raw = backend ? backend.loadState() : ""
        if (!raw) {
            firstRun = true
        } else {
            try {
                const d = JSON.parse(raw)
                const s = d.settings || {}
                if (s.petKind) petKind = s.petKind
                if (s.petName) petName = s.petName
                if (s.autoAdvance !== undefined) autoAdvance = !!s.autoAdvance
                hidden = !!s.hidden
                if (s.tipsEnabled !== undefined) tipsEnabled = !!s.tipsEnabled
                if (s.musicEnabled !== undefined) musicEnabled = !!s.musicEnabled
                lastTipDay = s.lastTipDay || ""
                if (s.breakEnabled !== undefined) breakEnabled = !!s.breakEnabled
                if (s.breakMinutes > 0) breakMinutes = Math.max(15, Math.min(240, s.breakMinutes))
                totalDone = d.totalDone || 0
                const n = Date.now()
                // Cronômetros que estavam rodando contam só até a última vez que o app esteve vivo.
                const lastSeen = Math.min(d.lastSeen || n, n)
                // Reabriu logo (atualização, reinício do app): continua contando o tempo sentado.
                if (d.sitStart > 0 && n - lastSeen < awayResetMs) sitStart = Math.min(d.sitStart, n)
                for (const f of (d.focus || [])) {
                    const t = copyTask(f)
                    if (t.running) {
                        t.accMs += Math.max(0, lastSeen - t.startedAt)
                        t.startedAt = n
                    }
                    focusModel.append(t)
                }
                for (const q of (d.queue || [])) queueModel.append(pauseObj(copyTask(q)))
                for (const x of (d.done || [])) doneModel.append(copyTask(x))
            } catch (e) {
                console.warn("Foquinho: estado inválido, começando do zero:", e)
            }
        }
        loaded = true
        touch()
        save()
    }
}
