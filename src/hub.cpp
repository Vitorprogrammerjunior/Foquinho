#include "hub.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>

#include <iterator>

namespace {
constexpr int kDebounceMs = 1200;
// Sem mudança nenhuma, ainda manda o estado de tempos em tempos: é o "estou vivo" da TV.
constexpr qint64 kHeartbeatMs = 55000;
constexpr int kTimeoutMs = 15000;
const char *kUserAgent = "Foquinho";
}

Hub::Hub(QObject *parent)
    : QObject(parent)
    , m_net(new QNetworkAccessManager(this))
{
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(kDebounceMs);
    connect(&m_debounce, &QTimer::timeout, this, &Hub::sendNow);

    m_retry.setSingleShot(true);
    connect(&m_retry, &QTimer::timeout, this, &Hub::sendNow);

    load();
    if (connected())
        setStatus(QStringLiteral("syncing"));
}

// Endereço sugerido no formulário. Vem do build (make HUB_SERVER=https://...),
// para o código público não carregar o endereço de nenhuma empresa.
#ifndef FOCO_HUB_SERVER
#define FOCO_HUB_SERVER ""
#endif

QString Hub::defaultServer() const
{
    return QStringLiteral(FOCO_HUB_SERVER);
}

// ---------- configuração ----------

QString Hub::configPath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/hub.json");
}

void Hub::load()
{
    QFile file(configPath());
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject o = QJsonDocument::fromJson(file.readAll()).object();
    m_server = o.value(QStringLiteral("server")).toString();
    m_token = o.value(QStringLiteral("token")).toString();
    m_userName = o.value(QStringLiteral("userName")).toString();
    m_sectorId = o.value(QStringLiteral("sectorId")).toInt();
    m_sectorName = o.value(QStringLiteral("sectorName")).toString();
    m_sectorColor = o.value(QStringLiteral("sectorColor")).toString();
}

void Hub::save() const
{
    QSaveFile file(configPath());
    if (!file.open(QIODevice::WriteOnly))
        return;
    const QJsonObject o{
        {QStringLiteral("server"), m_server},
        {QStringLiteral("token"), m_token},
        {QStringLiteral("userName"), m_userName},
        {QStringLiteral("sectorId"), m_sectorId},
        {QStringLiteral("sectorName"), m_sectorName},
        {QStringLiteral("sectorColor"), m_sectorColor},
    };
    file.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner); // o token é segredo
    file.commit();
}

// ---------- rede ----------

QString Hub::normalizeUrl(const QString &url)
{
    QString u = url.trimmed();
    while (u.endsWith(QLatin1Char('/')))
        u.chop(1);
    if (u.isEmpty())
        return u;
    if (!u.contains(QLatin1String("://")))
        u.prepend(QStringLiteral("https://"));
    return u;
}

QNetworkReply *Hub::request(const QByteArray &verb, const QString &path, const QJsonObject &body, const QString &server)
{
    const QString base = server.isEmpty() ? m_server : server;
    QNetworkRequest req(QUrl(base + QStringLiteral("/api/foquinho/") + path));
    req.setHeader(QNetworkRequest::UserAgentHeader, QByteArray(kUserAgent));
    req.setRawHeader("Accept", "application/json");
    req.setTransferTimeout(kTimeoutMs);
    if (!m_token.isEmpty() && server.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());

    QByteArray data;
    if (verb != "GET") {
        req.setHeader(QNetworkRequest::ContentTypeHeader, QByteArray("application/json"));
        data = QJsonDocument(body).toJson(QJsonDocument::Compact);
    }
    return m_net->sendCustomRequest(req, verb, data);
}

QString Hub::errorMessage(QNetworkReply *reply, const QJsonObject &json)
{
    // Mensagem do hub (validação, código errado...) tem prioridade.
    const QJsonObject errors = json.value(QStringLiteral("errors")).toObject();
    for (auto it = errors.begin(); it != errors.end(); ++it) {
        const QJsonArray list = it.value().toArray();
        if (!list.isEmpty())
            return list.first().toString();
    }
    const QString msg = json.value(QStringLiteral("message")).toString();
    if (!msg.isEmpty())
        return msg;

    switch (reply->error()) {
    case QNetworkReply::HostNotFoundError:
        return QStringLiteral("Endereço do hub não encontrado.");
    case QNetworkReply::ConnectionRefusedError:
    case QNetworkReply::RemoteHostClosedError:
    case QNetworkReply::TimeoutError:
    case QNetworkReply::OperationCanceledError:
    case QNetworkReply::TemporaryNetworkFailureError:
    case QNetworkReply::NetworkSessionFailedError:
    case QNetworkReply::UnknownNetworkError:
        return QStringLiteral("Sem conexão com o hub.");
    case QNetworkReply::SslHandshakeFailedError:
        return QStringLiteral("Falha no certificado do hub (HTTPS).");
    case QNetworkReply::ContentNotFoundError:
        return QStringLiteral("Esse endereço não parece ser um Hub de Demandas.");
    default:
        break;
    }
    const int code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    return code ? QStringLiteral("O hub respondeu com erro %1.").arg(code) : reply->errorString();
}

static QJsonObject readJson(QNetworkReply *reply)
{
    return QJsonDocument::fromJson(reply->readAll()).object();
}

static int httpCode(QNetworkReply *reply)
{
    return reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
}

void Hub::applyUser(const QJsonObject &user)
{
    if (user.isEmpty())
        return;
    m_userName = user.value(QStringLiteral("name")).toString(m_userName);
    const QJsonObject sector = user.value(QStringLiteral("sector")).toObject();
    m_sectorId = sector.value(QStringLiteral("id")).toInt();
    m_sectorName = sector.value(QStringLiteral("name")).toString();
    m_sectorColor = sector.value(QStringLiteral("color")).toString();
    save();
    emit configChanged();
}

void Hub::setStatus(const QString &status, const QString &message)
{
    if (m_status == status && m_message == message)
        return;
    m_status = status;
    m_message = message;
    emit statusChanged();
}

void Hub::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void Hub::forgetToken(const QString &message)
{
    m_token.clear();
    m_lastSentKey.clear();
    m_retry.stop();
    m_debounce.stop();
    save();
    emit configChanged();
    setStatus(QStringLiteral("expired"), message);
}

// ---------- ações ----------

void Hub::fetchSectors(const QString &url)
{
    const QString server = url.isEmpty() ? m_server : normalizeUrl(url);
    if (server.isEmpty())
        return;
    QNetworkReply *reply = request("GET", QStringLiteral("setores"), {}, server);
    connect(reply, &QNetworkReply::finished, this, [this, reply, server] {
        reply->deleteLater();
        const QJsonObject json = readJson(reply);
        if (reply->error() != QNetworkReply::NoError || !json.contains(QStringLiteral("sectors"))) {
            m_sectors.clear();
            emit sectorsChanged();
            if (!connected())
                setStatus(QStringLiteral("off"), errorMessage(reply, json));
            return;
        }
        m_sectors = json.value(QStringLiteral("sectors")).toArray().toVariantList();
        emit sectorsChanged();
        if (!connected() && m_status == QLatin1String("off"))
            setStatus(QStringLiteral("off"));
    });
}

void Hub::connectTo(const QString &url, const QString &name, const QString &teamCode, int sectorId)
{
    const QString server = normalizeUrl(url);
    if (server.isEmpty() || name.trimmed().isEmpty() || teamCode.trimmed().isEmpty() || sectorId <= 0) {
        emit connectFailed(QStringLiteral("Preencha servidor, nome, código da equipe e escolha um setor."));
        return;
    }
    setBusy(true);
    const QJsonObject body{
        {QStringLiteral("name"), name.trimmed()},
        {QStringLiteral("team_code"), teamCode.trimmed()},
        {QStringLiteral("sector_id"), sectorId},
        {QStringLiteral("device"), QSysInfo::machineHostName().left(80)},
    };
    QNetworkReply *reply = request("POST", QStringLiteral("conectar"), body, server);
    connect(reply, &QNetworkReply::finished, this, [this, reply, server] {
        reply->deleteLater();
        setBusy(false);
        const QJsonObject json = readJson(reply);
        const QString token = json.value(QStringLiteral("token")).toString();
        if (reply->error() != QNetworkReply::NoError || token.isEmpty()) {
            const QString msg = errorMessage(reply, json);
            setStatus(QStringLiteral("off"), msg);
            emit connectFailed(msg);
            return;
        }
        m_server = server;
        m_token = token;
        m_failures = 0;
        applyUser(json.value(QStringLiteral("user")).toObject()); // salva e avisa
        setStatus(QStringLiteral("syncing"));
        emit connectSucceeded();
        m_lastSentKey.clear();
        if (!m_pending.isEmpty())
            sendNow();
    });
}

void Hub::changeSector(int sectorId)
{
    if (!connected() || sectorId <= 0 || sectorId == m_sectorId)
        return;
    setBusy(true);
    QNetworkReply *reply = request("PUT", QStringLiteral("setor"), {{QStringLiteral("sector_id"), sectorId}});
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        setBusy(false);
        const QJsonObject json = readJson(reply);
        if (httpCode(reply) == 401) {
            forgetToken(QStringLiteral("O hub não reconhece mais este Foquinho. Conecte de novo."));
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            setStatus(m_status, errorMessage(reply, json));
            return;
        }
        applyUser(json.value(QStringLiteral("user")).toObject());
        setStatus(m_status == QLatin1String("syncing") ? m_status : QStringLiteral("ok"));
    });
}

void Hub::disconnectHub()
{
    if (connected()) {
        // Avisa o hub (sem esperar): o token deixa de valer lá também.
        QNetworkReply *reply = request("POST", QStringLiteral("desconectar"));
        connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
    }
    m_token.clear();
    m_userName.clear();
    m_sectorId = 0;
    m_sectorName.clear();
    m_sectorColor.clear();
    m_lastSentKey.clear();
    m_failures = 0;
    m_retry.stop();
    m_debounce.stop();
    save();
    emit configChanged();
    setStatus(QStringLiteral("off"));
}

void Hub::push(const QString &stateJson)
{
    const QJsonObject state = QJsonDocument::fromJson(stateJson.toUtf8()).object();
    if (state.isEmpty())
        return;
    m_pending = state;
    if (!connected())
        return;

    const QByteArray key = QJsonDocument(state).toJson(QJsonDocument::Compact);
    const bool changed = key != m_lastSentKey;
    const bool heartbeatDue = QDateTime::currentMSecsSinceEpoch() - qint64(m_lastSyncAt) >= kHeartbeatMs;
    if (!changed && !heartbeatDue)
        return;

    m_dirty = true;
    // Esperando para tentar de novo (sem internet)? O retry já vai mandar o estado mais novo.
    if (!m_retry.isActive())
        m_debounce.start();
}

void Hub::retryNow()
{
    m_failures = 0;
    m_retry.stop();
    if (connected()) {
        m_dirty = true;
        sendNow();
    }
}

void Hub::scheduleRetry()
{
    static const int steps[] = {5000, 15000, 30000, 60000};
    const int idx = qMin(m_failures, int(std::size(steps)) - 1);
    m_failures++;
    m_retry.start(steps[idx]);
}

void Hub::sendNow()
{
    if (!connected() || m_pending.isEmpty())
        return;
    if (m_inFlight) {
        m_dirty = true; // manda de novo quando a resposta atual chegar
        return;
    }
    m_dirty = false;
    m_debounce.stop();

    const QByteArray key = QJsonDocument(m_pending).toJson(QJsonDocument::Compact);
    QJsonObject body = m_pending;
    body.insert(QStringLiteral("now"), double(QDateTime::currentMSecsSinceEpoch()));
    if (m_status != QLatin1String("ok"))
        setStatus(QStringLiteral("syncing"), m_message);

    QNetworkReply *reply = request("POST", QStringLiteral("sync"), body);
    m_inFlight = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, key] {
        reply->deleteLater();
        m_inFlight = nullptr;
        const QJsonObject json = readJson(reply);
        const int code = httpCode(reply);

        if (code == 401) {
            forgetToken(QStringLiteral("O hub não reconhece mais este Foquinho. Conecte de novo."));
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            const bool network = code == 0 || code >= 500 || code == 429;
            setStatus(network ? QStringLiteral("offline") : QStringLiteral("error"), errorMessage(reply, json));
            m_dirty = true;
            scheduleRetry();
            return;
        }

        m_failures = 0;
        m_lastSentKey = key;
        m_lastSyncAt = double(QDateTime::currentMSecsSinceEpoch());
        setStatus(QStringLiteral("ok"));
        emit statusChanged(); // lastSyncAt mudou mesmo com o status igual
        if (m_dirty)
            m_debounce.start();
    });
}
