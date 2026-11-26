#include "backend.h"
#include "hub.h"
#include "media.h"
#include "platform.h"

#include <QGuiApplication>
#include <QLocalSocket>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>

// Uso:
//   foco-max                 inicia (ou abre o painel da instância que já roda)
//   foco-max add [texto]     nova demanda (sem texto abre o campo de digitação)
//   foco-max focus <texto>   cria a demanda direto em foco
//   foco-max toggle|hide|show|done|quit
//   foco-max start           inicia, sem abrir nada se já estiver rodando (autostart)
//   foco-max screen [next|primary|<conector>]   move o notch de monitor
//   foco-max play|next|prev                     controla a música tocando
//   foco-max break                              dispara o lembrete de pausa agora (teste)
int main(int argc, char *argv[])
{
    Platform::preInit();
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("foco-max"));
    app.setApplicationDisplayName(QStringLiteral("Foquinho"));
    app.setDesktopFileName(QStringLiteral("foco-max"));
    app.setQuitOnLastWindowClosed(false);

    QStringList args = app.arguments().mid(1);
    const QString commandLine = args.join(QLatin1Char(' ')).trimmed();

    // Instância única: se já existe uma rodando, só repassa o comando.
    {
        QLocalSocket probe;
        probe.connectToServer(Backend::serverName());
        if (probe.waitForConnected(250)) {
            const QString line = commandLine.isEmpty() ? QStringLiteral("toggle") : commandLine;
            probe.write(line.toUtf8() + '\n');
            probe.waitForBytesWritten(500);
            probe.disconnectFromServer();
            return 0;
        }
    }

    Backend backend;
    backend.startServer();

    Media media;
    media.setVisualize(true);

    Hub hub; // conexão com o Hub de Demandas (o telão)

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("Media"), &media);
    engine.rootContext()->setContextProperty(QStringLiteral("HubSync"), &hub);
    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().value(0));
    if (!window)
        return 1;

    backend.attachWindow(window); // configura a janela para a plataforma (layer-shell ou X11)
    window->show();

    if (!commandLine.isEmpty()) {
        QTimer::singleShot(700, &backend, [&backend, commandLine] {
            const int space = commandLine.indexOf(QLatin1Char(' '));
            backend.runCommand(space < 0 ? commandLine : commandLine.left(space),
                               space < 0 ? QString() : commandLine.mid(space + 1).trimmed());
        });
    }

    return app.exec();
}
