#pragma once

#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QVariant>

class QNetworkAccessManager;
class QNetworkReply;

// Conexão com o Hub de Demandas: tudo que é anotado no Foquinho aparece no telão.
//
// O Foquinho é a fonte da verdade: a cada mudança o Store manda o estado inteiro
// (foco, fila e concluídas do mês) e o Hub envia para /api/foquinho/sync. Sem internet,
// guarda o último estado e tenta de novo sozinho. O token fica em hub.json (só o dono lê).
class Hub : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl NOTIFY configChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY configChanged)
    Q_PROPERTY(QString userName READ userName NOTIFY configChanged)
    Q_PROPERTY(int sectorId READ sectorId NOTIFY configChanged)
    Q_PROPERTY(QString sectorName READ sectorName NOTIFY configChanged)
    Q_PROPERTY(QString sectorColor READ sectorColor NOTIFY configChanged)
    // "off" (desconectado), "syncing", "ok", "offline" (sem internet / hub fora), "error", "expired" (token recusado)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString message READ message NOTIFY statusChanged)
    Q_PROPERTY(double lastSyncAt READ lastSyncAt NOTIFY statusChanged)
    // Setores do hub para escolher: [{id, name, color}]
    Q_PROPERTY(QVariantList sectors READ sectors NOTIFY sectorsChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    // Endereço sugerido no primeiro uso.
    Q_PROPERTY(QString defaultServer READ defaultServer CONSTANT)

public:
    explicit Hub(QObject *parent = nullptr);

    QString serverUrl() const { return m_server; }
    bool connected() const { return !m_token.isEmpty(); }
    QString userName() const { return m_userName; }
    int sectorId() const { return m_sectorId; }
    QString sectorName() const { return m_sectorName; }
    QString sectorColor() const { return m_sectorColor; }
    QString status() const { return m_status; }
    QString message() const { return m_message; }
    double lastSyncAt() const { return m_lastSyncAt; }
    QVariantList sectors() const { return m_sectors; }
    bool busy() const { return m_busy; }
    QString defaultServer() const;

    // Busca os setores do hub (url vazia = servidor atual).
    Q_INVOKABLE void fetchSectors(const QString &url = QString());
    Q_INVOKABLE void connectTo(const QString &url, const QString &name, const QString &teamCode, int sectorId);
    Q_INVOKABLE void changeSector(int sectorId);
    Q_INVOKABLE void disconnectHub();
    // Estado do Store: {"focus": [...], "queue": [...], "done": [...]}. Envia com um pequeno atraso.
    Q_INVOKABLE void push(const QString &stateJson);
    // Reenvia agora (botão "tentar de novo").
    Q_INVOKABLE void retryNow();

signals:
    void configChanged();
    void statusChanged();
    void sectorsChanged();
    void busyChanged();
    void connectFailed(const QString &message);
    void connectSucceeded();

private:
    QNetworkReply *request(const QByteArray &verb, const QString &path, const QJsonObject &body = {},
                           const QString &server = QString());
    static QString normalizeUrl(const QString &url);
    static QString errorMessage(QNetworkReply *reply, const QJsonObject &json);
    void applyUser(const QJsonObject &user);
    void sendNow();
    void scheduleRetry();
    void setStatus(const QString &status, const QString &message = QString());
    void setBusy(bool busy);
    void forgetToken(const QString &message);
    QString configPath() const;
    void load();
    void save() const;

    QNetworkAccessManager *m_net = nullptr;
    QString m_server;
    QString m_token;
    QString m_userName;
    int m_sectorId = 0;
    QString m_sectorName;
    QString m_sectorColor;

    QString m_status = QStringLiteral("off");
    QString m_message;
    double m_lastSyncAt = 0;
    QVariantList m_sectors;
    bool m_busy = false;

    QJsonObject m_pending;       // último estado recebido do Store
    QByteArray m_lastSentKey;    // estado (sem "now") enviado com sucesso por último
    bool m_dirty = false;
    QPointer<QNetworkReply> m_inFlight;
    QTimer m_debounce;
    QTimer m_retry;
    int m_failures = 0;
};
