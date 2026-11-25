#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QVariant>

class QQuickWindow;
class QScreen;
class QLocalServer;
class QLocalSocket;
class Platform;

// Ponte entre o QML e o sistema: persistência, cor de destaque, autostart, monitores e
// IPC de instância única. O que depende do ambiente (KDE/Wayland ou X11/Openbox) fica no Platform.
class Backend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QColor accent READ accent NOTIFY accentChanged)
    // Cor escolhida à mão nos ajustes ("" = seguir o sistema). Usada fora do KDE.
    Q_PROPERTY(QString accentChoice READ accentChoice WRITE setAccentChoice NOTIFY accentChanged)
    // "kde" ou "x11"
    Q_PROPERTY(QString platform READ platform CONSTANT)
    // X11 sem compositor: o QML precisa mandar a forma do notch (setShape) a cada quadro.
    Q_PROPERTY(bool needsShape READ needsShape NOTIFY needsShapeChanged)
    // Teclas de cada atalho, por comando: {"add": ["Meta", "Alt", "N"], ...}
    Q_PROPERTY(QVariantMap shortcutKeys READ shortcutKeys CONSTANT)
    Q_PROPERTY(QString shortcutsHint READ shortcutsHint CONSTANT)
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY autostartChanged)
    // Monitores conectados, da esquerda para a direita: [{name, label, primary}].
    Q_PROPERTY(QVariantList screens READ screens NOTIFY screensChanged)
    // Monitor escolhido (nome do conector, ex.: "HDMI-A-1"); vazio = sempre o principal.
    Q_PROPERTY(QString screenName READ screenName WRITE setScreenName NOTIFY screenNameChanged)
    // Monitor em que o notch está de fato agora.
    Q_PROPERTY(QString currentScreen READ currentScreen NOTIFY currentScreenChanged)
    // Tela bloqueada (org.freedesktop.ScreenSaver). Serve para o lembrete de pausa saber que você saiu.
    Q_PROPERTY(bool screenLocked READ screenLocked NOTIFY screenLockedChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    static QString serverName();

    void attachWindow(QQuickWindow *window);
    bool startServer();

    QColor accent() const { return m_accentChoice.isValid() ? m_accentChoice : m_accent; }
    QString accentChoice() const { return m_accentChoice.isValid() ? m_accentChoice.name() : QString(); }
    void setAccentChoice(const QString &color);
    QString platform() const;
    bool needsShape() const;
    QVariantMap shortcutKeys() const { return m_shortcutKeys; }
    QString shortcutsHint() const;
    bool autostart() const;
    void setAutostart(bool enabled);

    QVariantList screens() const;
    QString screenName() const { return m_screenName; }
    void setScreenName(const QString &name);
    QString currentScreen() const { return m_currentScreen; }
    Q_INVOKABLE void nextScreen();
    bool screenLocked() const { return m_screenLocked; }

    // Toca o sininho do lembrete de pausa (pw-play, paplay ou aplay; sem dependência nova).
    Q_INVOKABLE void playChime();

    // Comandos de atalho/IPC: os de monitor são tratados aqui, o resto vai pro QML.
    void runCommand(const QString &name, const QString &arg);

    Q_INVOKABLE QString loadState() const;
    Q_INVOKABLE void saveState(const QString &json) const;
    Q_INVOKABLE void setInputRect(qreal x, qreal y, qreal w, qreal h);
    Q_INVOKABLE void setInputRegion(const QVariantList &rects);
    // Forma visível do notch: [{x, y, w, h, r, ear, roundTop}] (só tem efeito quando needsShape).
    Q_INVOKABLE void setShape(const QVariantList &shapes);
    Q_INVOKABLE void grabKeyboard(bool exclusive);
    Q_INVOKABLE void quit();

signals:
    void accentChanged();
    void autostartChanged();
    void screensChanged();
    void screenNameChanged();
    void currentScreenChanged();
    void needsShapeChanged();
    void screenLockedChanged();
    // Comando vindo de atalho global ou de outra instância (ex.: "add Comprar pão").
    void command(const QString &name, const QString &arg);

private:
    void reloadAccent();
    Q_SLOT void onScreenSaverActive(bool active);
    QString chimePath();
    QScreen *targetScreen() const;
    void placeWindow(bool remap);
    QString settingsPath() const;
    void setupShortcuts();
    void handleSocket(QLocalSocket *socket);
    void dispatch(const QString &line);
    QString statePath() const;
    QString autostartPath() const;

    Platform *m_platform = nullptr;
    QColor m_accent;
    QColor m_accentChoice;
    QVariantMap m_shortcutKeys;
    QPointer<QQuickWindow> m_window;
    QFileSystemWatcher m_watcher;
    QTimer m_accentDebounce;
    QLocalServer *m_server = nullptr;
    QString m_screenName;
    QString m_currentScreen;
    QTimer m_screenDebounce;
    bool m_screenLocked = false;
    QString m_chimePath;
    QString m_player;
};
