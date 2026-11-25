#include "backend.h"
#include "platform.h"

#include <algorithm>
#include <cmath>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDataStream>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QKeySequence>
#include <QLocalServer>
#include <QLocalSocket>
#include <QProcess>
#include <QQuickWindow>
#include <QRegion>
#include <QSaveFile>
#include <QScreen>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>

namespace {

QString configDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
}

QString kdeglobalsPath()
{
    return configDir() + QStringLiteral("/kdeglobals");
}

QColor parseColor(const QString &value)
{
    const QStringList parts = value.split(QLatin1Char(','));
    if (parts.size() >= 3)
        return QColor(parts[0].trimmed().toInt(), parts[1].trimmed().toInt(), parts[2].trimmed().toInt());
    return QColor(value.trimmed());
}

// Prefere o binário instalado (make install) ao da pasta de build.
QString installedBinary()
{
    const QString local = QDir::homePath() + QStringLiteral("/.local/bin/foco-max");
    if (QFile::exists(local))
        return local;
    const QString inPath = QStandardPaths::findExecutable(QStringLiteral("foco-max"));
    return inPath.isEmpty() ? QCoreApplication::applicationFilePath() : inPath;
}

// Retângulo com cantos arredondados (só os de baixo, se roundTop = false) e as "orelhas"
// côncavas do topo do notch, como região de pixels inteiros. Mesma curva do NotchShape.qml.
QRegion notchRegion(qreal x, qreal y, qreal w, qreal h, qreal r, qreal ear, bool roundTop)
{
    QRegion out;
    if (w < 1 || h < 1)
        return out;
    r = std::clamp(r, 0.0, std::min(w, h) / 2);
    ear = std::max(0.0, ear);
    const qreal earY = std::clamp(std::min(ear, h - r), 0.0, h);
    int spanStart = 0, spanL = 0, spanR = 0;
    bool open = false;
    const int top = int(std::floor(y)), bottom = int(std::ceil(y + h));
    for (int row = top; row <= bottom; ++row) {
        int l = 0, rgt = 0;
        bool has = row < bottom;
        if (has) {
            const qreal yc = row + 0.5 - y; // centro da linha, em coordenadas locais
            qreal inset = 0;
            if (r > 0 && yc > h - r) {
                const qreal dy = yc - (h - r);
                inset = r - std::sqrt(std::max(0.0, r * r - dy * dy));
            } else if (roundTop && r > 0 && yc < r) {
                const qreal dy = r - yc;
                inset = r - std::sqrt(std::max(0.0, r * r - dy * dy));
            }
            qreal extra = 0;
            if (earY > 0 && yc < earY) {
                const qreal t = std::sqrt(std::max(0.0, yc / earY)); // curva quadrática do PathQuad
                extra = ear * (1 - t) * (1 - t);
            }
            l = qRound(x + inset - extra);
            rgt = qRound(x + w - inset + extra);
            has = rgt > l;
        }
        if (open && (!has || l != spanL || rgt != spanR)) {
            out += QRect(spanL, spanStart, spanR - spanL, row - spanStart);
            open = false;
        }
        if (has && !open) {
            spanStart = row;
            spanL = l;
            spanR = rgt;
            open = true;
        }
    }
    return out;
}

QStringList keyLabels(const QKeySequence &seq)
{
    if (seq.isEmpty())
        return {QStringLiteral("—")};
    const QKeyCombination combo = seq[0];
    const Qt::KeyboardModifiers mods = combo.keyboardModifiers();
    QStringList out;
    if (mods & Qt::MetaModifier)
        out << QStringLiteral("Meta");
    if (mods & Qt::ControlModifier)
        out << QStringLiteral("Ctrl");
    if (mods & Qt::AltModifier)
        out << QStringLiteral("Alt");
    if (mods & Qt::ShiftModifier)
        out << QStringLiteral("Shift");
    out << (combo.key() == Qt::Key_Space ? QStringLiteral("Espaço")
                                          : QKeySequence(combo.key()).toString(QKeySequence::NativeText));
    return out;
}

} // namespace

Backend::Backend(QObject *parent)
    : QObject(parent)
    , m_platform(Platform::create(this))
{
    connect(m_platform, &Platform::shortcutActivated, this, [this](const QString &cmd) { runCommand(cmd, QString()); });
    connect(m_platform, &Platform::needsShapeChanged, this, &Backend::needsShapeChanged);

    // Bloqueio de tela: o KDE (e outros) avisam por org.freedesktop.ScreenSaver.ActiveChanged.
    QDBusConnection::sessionBus().connect(QString(), QStringLiteral("/ScreenSaver"),
                                          QStringLiteral("org.freedesktop.ScreenSaver"),
                                          QStringLiteral("ActiveChanged"), this, SLOT(onScreenSaverActive(bool)));
    QDBusConnection::sessionBus().connect(QString(), QStringLiteral("/org/freedesktop/ScreenSaver"),
                                          QStringLiteral("org.freedesktop.ScreenSaver"),
                                          QStringLiteral("ActiveChanged"), this, SLOT(onScreenSaverActive(bool)));

    m_accentChoice = QColor(QSettings(settingsPath(), QSettings::IniFormat).value(QStringLiteral("accent")).toString());
    reloadAccent();

    // O KDE regrava o kdeglobals de forma atômica, então observamos também o diretório.
    m_accentDebounce.setSingleShot(true);
    m_accentDebounce.setInterval(300);
    connect(&m_accentDebounce, &QTimer::timeout, this, [this] {
        reloadAccent();
        if (QFile::exists(kdeglobalsPath()) && !m_watcher.files().contains(kdeglobalsPath()))
            m_watcher.addPath(kdeglobalsPath());
    });
    if (QFile::exists(kdeglobalsPath()))
        m_watcher.addPath(kdeglobalsPath());
    m_watcher.addPath(configDir());
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, &m_accentDebounce, qOverload<>(&QTimer::start));
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_accentDebounce, qOverload<>(&QTimer::start));

    setupShortcuts();

    m_screenName = QSettings(settingsPath(), QSettings::IniFormat).value(QStringLiteral("screen")).toString();

    // Monitor conectado/desconectado ou principal trocado: reposiciona o notch.
    // (Quando o monitor some, o compositor descarta a superfície; sem isso o notch desaparecia.)
    m_screenDebounce.setSingleShot(true);
    m_screenDebounce.setInterval(400);
    connect(&m_screenDebounce, &QTimer::timeout, this, [this] { placeWindow(true); });
    auto screensChangedNow = [this] {
        emit screensChanged();
        m_screenDebounce.start();
    };
    connect(qApp, &QGuiApplication::screenAdded, this, screensChangedNow);
    connect(qApp, &QGuiApplication::screenRemoved, this, screensChangedNow);
    connect(qApp, &QGuiApplication::primaryScreenChanged, this, screensChangedNow);
}

QString Backend::serverName()
{
    return QStringLiteral("foco-max-") + qEnvironmentVariable("USER", QStringLiteral("user"));
}

void Backend::attachWindow(QQuickWindow *window)
{
    m_window = window;
    window->setColor(Qt::transparent);
    m_platform->setupWindow(window);
    placeWindow(false);
}

QString Backend::platform() const
{
    return m_platform->name();
}

bool Backend::needsShape() const
{
    return m_platform->needsShape();
}

QString Backend::shortcutsHint() const
{
    return m_platform->shortcutsHint();
}

void Backend::setAccentChoice(const QString &color)
{
    const QColor c(color);
    if (c == m_accentChoice || (!c.isValid() && !m_accentChoice.isValid()))
        return;
    m_accentChoice = c;
    QSettings(settingsPath(), QSettings::IniFormat).setValue(QStringLiteral("accent"), c.isValid() ? c.name() : QString());
    emit accentChanged();
}

QString Backend::settingsPath() const
{
    return configDir() + QStringLiteral("/foco-maxrc");
}

namespace {

QList<QScreen *> sortedScreens()
{
    QList<QScreen *> list = QGuiApplication::screens();
    std::sort(list.begin(), list.end(), [](QScreen *a, QScreen *b) {
        const QPoint pa = a->geometry().topLeft(), pb = b->geometry().topLeft();
        return pa.x() != pb.x() ? pa.x() < pb.x() : pa.y() < pb.y();
    });
    return list;
}

QString screenLabel(QScreen *s)
{
    if (s->name().startsWith(QLatin1String("eDP")) || s->name().startsWith(QLatin1String("LVDS")))
        return QStringLiteral("Notebook");
    const QString model = s->model().trimmed();
    return model.isEmpty() ? s->name() : model;
}

} // namespace

QVariantList Backend::screens() const
{
    QVariantList out;
    QScreen *primary = QGuiApplication::primaryScreen();
    for (QScreen *s : sortedScreens()) {
        out.append(QVariantMap{
            {QStringLiteral("name"), s->name()},
            {QStringLiteral("label"), screenLabel(s)},
            {QStringLiteral("primary"), s == primary},
        });
    }
    return out;
}

QScreen *Backend::targetScreen() const
{
    if (!m_screenName.isEmpty()) {
        for (QScreen *s : QGuiApplication::screens())
            if (s->name() == m_screenName)
                return s;
    }
    return QGuiApplication::primaryScreen();
}

void Backend::setScreenName(const QString &name)
{
    if (name == m_screenName)
        return;
    m_screenName = name;
    QSettings settings(settingsPath(), QSettings::IniFormat);
    settings.setValue(QStringLiteral("screen"), name);
    emit screenNameChanged();
    placeWindow(true);
}

void Backend::nextScreen()
{
    const QList<QScreen *> list = sortedScreens();
    if (list.size() < 2)
        return;
    const int i = list.indexOf(targetScreen());
    setScreenName(list.at((i + 1) % list.size())->name());
}

void Backend::placeWindow(bool remap)
{
    QScreen *screen = targetScreen();
    if (!m_window || !screen)
        return;
    m_platform->placeWindow(m_window, screen, remap);
    if (m_currentScreen != screen->name()) {
        m_currentScreen = screen->name();
        emit currentScreenChanged();
    }
}

void Backend::runCommand(const QString &name, const QString &arg)
{
    if (name == QLatin1String("screen")) {
        if (arg.isEmpty() || arg == QLatin1String("next"))
            nextScreen();
        else if (arg == QLatin1String("primary") || arg == QLatin1String("principal"))
            setScreenName(QString());
        else
            setScreenName(arg);
        return;
    }
    emit command(name, arg);
}

bool Backend::startServer()
{
    QLocalServer::removeServer(serverName());
    m_server = new QLocalServer(this);
    m_server->setSocketOptions(QLocalServer::UserAccessOption);
    if (!m_server->listen(serverName()))
        return false;
    connect(m_server, &QLocalServer::newConnection, this, [this] {
        while (QLocalSocket *socket = m_server->nextPendingConnection())
            handleSocket(socket);
    });
    return true;
}

void Backend::handleSocket(QLocalSocket *socket)
{
    auto drain = [this, socket] {
        while (socket->canReadLine())
            dispatch(QString::fromUtf8(socket->readLine()).trimmed());
    };
    connect(socket, &QLocalSocket::readyRead, this, drain);
    connect(socket, &QLocalSocket::disconnected, this, [socket, drain] {
        drain();
        socket->deleteLater();
    });
    drain();
}

void Backend::dispatch(const QString &line)
{
    if (line.isEmpty())
        return;
    const int space = line.indexOf(QLatin1Char(' '));
    const QString name = space < 0 ? line : line.left(space);
    const QString arg = space < 0 ? QString() : line.mid(space + 1).trimmed();
    runCommand(name, arg);
}

void Backend::reloadAccent()
{
    QColor accent;
    QColor selection;
    QFile file(kdeglobalsPath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        QString group;
        while (!stream.atEnd()) {
            const QString line = stream.readLine().trimmed();
            if (line.startsWith(QLatin1Char('['))) {
                group = line;
                continue;
            }
            if (group == QLatin1String("[General]") && line.startsWith(QLatin1String("AccentColor=")))
                accent = parseColor(line.mid(12));
            else if (group == QLatin1String("[Colors:Selection]") && line.startsWith(QLatin1String("BackgroundNormal=")))
                selection = parseColor(line.mid(17));
        }
    }
    if (!accent.isValid())
        accent = selection;
    if (!accent.isValid())
        accent = QColor(49, 91, 239); // azul padrão do WhiteSur
    if (accent != m_accent) {
        m_accent = accent;
        if (!m_accentChoice.isValid())
            emit accentChanged();
    }
}

void Backend::setupShortcuts()
{
    QList<Platform::Shortcut> defs = {
        {QStringLiteral("quick-add"), QStringLiteral("Nova demanda"), QKeySequence(Qt::META | Qt::ALT | Qt::Key_N), QStringLiteral("add")},
        {QStringLiteral("toggle-panel"), QStringLiteral("Abrir/fechar painel"), QKeySequence(Qt::META | Qt::ALT | Qt::Key_F), QStringLiteral("toggle")},
        {QStringLiteral("toggle-hide"), QStringLiteral("Esconder/mostrar (bolinha)"), QKeySequence(Qt::META | Qt::ALT | Qt::Key_H), QStringLiteral("hide")},
        {QStringLiteral("complete"), QStringLiteral("Concluir demanda em foco"), QKeySequence(Qt::META | Qt::ALT | Qt::Key_D), QStringLiteral("done")},
        {QStringLiteral("next-screen"), QStringLiteral("Mover para o próximo monitor"), QKeySequence(Qt::META | Qt::ALT | Qt::Key_M), QStringLiteral("screen")},
        // Meta+Alt+P é do Plasma (focar painéis); o id mudou para não herdar o atalho antigo salvo
        {QStringLiteral("music-toggle"), QStringLiteral("Música: tocar / pausar"), QKeySequence(Qt::META | Qt::ALT | Qt::Key_Space), QStringLiteral("play")},
        {QStringLiteral("music-next"), QStringLiteral("Música: próxima"), QKeySequence(Qt::META | Qt::ALT | Qt::Key_Period), QStringLiteral("next")},
        {QStringLiteral("music-prev"), QStringLiteral("Música: anterior"), QKeySequence(Qt::META | Qt::ALT | Qt::Key_Comma), QStringLiteral("prev")},
    };
    m_platform->registerShortcuts(defs);
    for (const Platform::Shortcut &s : std::as_const(defs))
        m_shortcutKeys.insert(s.cmd, keyLabels(s.seq));
}

QString Backend::statePath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/state.json");
}

QString Backend::loadState() const
{
    QFile file(statePath());
    if (!file.open(QIODevice::ReadOnly))
        return QString();
    return QString::fromUtf8(file.readAll());
}

void Backend::saveState(const QString &json) const
{
    QSaveFile file(statePath());
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(json.toUtf8());
    file.commit();
}

void Backend::setInputRect(qreal x, qreal y, qreal w, qreal h)
{
    if (!m_window)
        return;
    const QRect rect(qRound(x), qRound(y), qMax(1, qRound(w)), qMax(1, qRound(h)));
    m_platform->setInputRegion(m_window, QRegion(rect));
}

void Backend::setInputRegion(const QVariantList &rects)
{
    if (!m_window)
        return;
    QRegion region;
    for (const QVariant &v : rects) {
        const QRectF r = v.toRectF();
        if (r.width() >= 1 && r.height() >= 1)
            region += r.toAlignedRect();
    }
    if (region.isEmpty())
        region = QRegion(0, 0, 1, 1); // máscara vazia = janela inteira clicável; evita isso
    m_platform->setInputRegion(m_window, region);
}

void Backend::setShape(const QVariantList &shapes)
{
    if (!m_window || !m_platform->needsShape())
        return;
    QRegion region;
    for (const QVariant &v : shapes) {
        const QVariantMap m = v.toMap();
        region += notchRegion(m.value(QStringLiteral("x")).toReal(), m.value(QStringLiteral("y")).toReal(),
                              m.value(QStringLiteral("w")).toReal(), m.value(QStringLiteral("h")).toReal(),
                              m.value(QStringLiteral("r")).toReal(), m.value(QStringLiteral("ear")).toReal(),
                              m.value(QStringLiteral("roundTop")).toBool());
    }
    m_platform->setShape(m_window, region);
}

void Backend::grabKeyboard(bool exclusive)
{
    if (!m_window)
        return;
    m_platform->grabKeyboard(m_window, exclusive);
}

QString Backend::autostartPath() const
{
    return configDir() + QStringLiteral("/autostart/foco-max.desktop");
}

bool Backend::autostart() const
{
    return QFile::exists(autostartPath());
}

void Backend::setAutostart(bool enabled)
{
    if (enabled == autostart())
        return;
    if (enabled) {
        QDir().mkpath(configDir() + QStringLiteral("/autostart"));
        QSaveFile file(autostartPath());
        if (file.open(QIODevice::WriteOnly)) {
            const QString content = QStringLiteral(
                                        "[Desktop Entry]\n"
                                        "Type=Application\n"
                                        "Name=Foquinho\n"
                                        "Comment=Notch de foco\n"
                                        "Exec=%1\n"
                                        "Icon=foco-max\n"
                                        "X-KDE-autostart-phase=2\n")
                                        .arg(m_platform->autostartExec(installedBinary()));
            file.write(content.toUtf8());
            file.commit();
        }
    } else {
        QFile::remove(autostartPath());
    }
    m_platform->autostartChanged(enabled, installedBinary());
    emit autostartChanged();
}

void Backend::quit()
{
    QCoreApplication::quit();
}

void Backend::onScreenSaverActive(bool active)
{
    if (active == m_screenLocked)
        return;
    m_screenLocked = active;
    emit screenLockedChanged();
}

// Gera (uma vez) um sininho de três notas em WAV, no cache. Nada de Qt Multimedia.
QString Backend::chimePath()
{
    if (!m_chimePath.isEmpty() && QFile::exists(m_chimePath))
        return m_chimePath;
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    const QString path = dir + QStringLiteral("/pausa-v1.wav");
    if (!QFile::exists(path)) {
        const int rate = 44100;
        const double total = 1.6;
        const int n = int(rate * total);
        QVector<double> buf(n, 0.0);
        // Mi5, Sol#5, Si5: um acorde maior subindo, macio, com um harmônico de sino
        const double notes[3] = {659.25, 830.61, 987.77};
        for (int k = 0; k < 3; ++k) {
            const int start = int(rate * 0.16 * k);
            for (int i = start; i < n; ++i) {
                const double t = double(i - start) / rate;
                const double attack = std::min(1.0, t / 0.008);
                const double env = attack * std::exp(-t * 3.2);
                const double w = 2 * M_PI * notes[k] * t;
                buf[i] += env * (std::sin(w) + 0.28 * std::sin(2.01 * w) + 0.08 * std::sin(3.98 * w));
            }
        }
        double peak = 0;
        for (double v : buf)
            peak = std::max(peak, std::abs(v));
        const double gain = peak > 0 ? 0.55 / peak : 0;

        QByteArray pcm;
        pcm.reserve(n * 2);
        for (int i = 0; i < n; ++i) {
            const double fade = i > n - 2000 ? double(n - i) / 2000.0 : 1.0;
            const qint16 v = qint16(std::lround(std::clamp(buf[i] * gain * fade, -1.0, 1.0) * 32767));
            pcm.append(char(v & 0xff));
            pcm.append(char((v >> 8) & 0xff));
        }
        QByteArray wav;
        QDataStream out(&wav, QIODevice::WriteOnly);
        out.setByteOrder(QDataStream::LittleEndian);
        out.writeRawData("RIFF", 4);
        out << quint32(36 + pcm.size());
        out.writeRawData("WAVEfmt ", 8);
        out << quint32(16) << quint16(1) << quint16(1) << quint32(rate) << quint32(rate * 2)
            << quint16(2) << quint16(16);
        out.writeRawData("data", 4);
        out << quint32(pcm.size());
        out.writeRawData(pcm.constData(), pcm.size());

        QSaveFile file(path);
        if (!file.open(QIODevice::WriteOnly))
            return QString();
        file.write(wav);
        if (!file.commit())
            return QString();
    }
    m_chimePath = path;
    return path;
}

void Backend::playChime()
{
    const QString path = chimePath();
    if (path.isEmpty())
        return;
    if (m_player.isEmpty()) {
        for (const char *p : {"pw-play", "paplay", "aplay"}) {
            m_player = QStandardPaths::findExecutable(QString::fromLatin1(p));
            if (!m_player.isEmpty())
                break;
        }
        if (m_player.isEmpty()) {
            m_player = QStringLiteral("-"); // nenhum player: fica em silêncio
            qWarning("Foquinho: sem pw-play/paplay/aplay, o lembrete de pausa vai ficar mudo");
        }
    }
    if (m_player == QLatin1String("-"))
        return;
    QStringList args;
    if (m_player.endsWith(QLatin1String("aplay")))
        args << QStringLiteral("-q");
    args << path;
    QProcess::startDetached(m_player, args);
}
