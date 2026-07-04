#include "moonsettings.h"

#include "settings/streamingpreferences.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {
const int kMaxRecentGames = 10;
}

QString MoonSettings::stateDir()
{
    QString dir = qEnvironmentVariable("MOONOS_STATE_DIR", QStringLiteral("/var/lib/moonos"));
    QDir().mkpath(dir);
    return dir;
}

MoonSettings::MoonSettings(QObject* parent)
    : QObject(parent),
      m_settings(stateDir() + QStringLiteral("/moon.ini"), QSettings::IniFormat)
{
    refreshDeveloperMode();
    m_recoveryMode = qEnvironmentVariableIsSet("MOONOS_RECOVERY");
}

bool MoonSettings::setupComplete() const
{
    return m_settings.value(QStringLiteral("setupComplete"), false).toBool();
}

void MoonSettings::setSetupComplete(bool value)
{
    if (value == setupComplete())
        return;
    m_settings.setValue(QStringLiteral("setupComplete"), value);
    m_settings.sync();
    emit setupCompleteChanged();
}

int MoonSettings::safeAreaPct() const
{
    return qBound(80, m_settings.value(QStringLiteral("safeAreaPct"), 100).toInt(), 100);
}

void MoonSettings::setSafeAreaPct(int pct)
{
    pct = qBound(80, pct, 100);
    if (pct == safeAreaPct())
        return;
    m_settings.setValue(QStringLiteral("safeAreaPct"), pct);
    m_settings.sync();
    emit safeAreaPctChanged();
}

bool MoonSettings::cecEnabled() const
{
    return m_settings.value(QStringLiteral("cecEnabled"), true).toBool();
}

void MoonSettings::setCecEnabled(bool value)
{
    if (value == cecEnabled())
        return;
    m_settings.setValue(QStringLiteral("cecEnabled"), value);
    m_settings.sync();
    emit cecEnabledChanged();
}

bool MoonSettings::tvPowerSync() const
{
    return m_settings.value(QStringLiteral("tvPowerSync"), false).toBool();
}

void MoonSettings::setTvPowerSync(bool value)
{
    if (value == tvPowerSync())
        return;
    m_settings.setValue(QStringLiteral("tvPowerSync"), value);
    m_settings.sync();
    emit tvPowerSyncChanged();
}

QString MoonSettings::audioDevice() const
{
    return m_settings.value(QStringLiteral("audioDevice")).toString();
}

void MoonSettings::setAudioDevice(const QString& device)
{
    if (device == audioDevice())
        return;
    m_settings.setValue(QStringLiteral("audioDevice"), device);
    m_settings.sync();
    emit audioDeviceChanged();
}

bool MoonSettings::developerMode() const
{
    return m_developerMode;
}

void MoonSettings::refreshDeveloperMode()
{
    // Flag file is managed by moon-devmode-{on,off}.service (root); the shell
    // only ever reads it.
    bool enabled = QFile::exists(stateDir() + QStringLiteral("/devmode"));
    if (enabled != m_developerMode) {
        m_developerMode = enabled;
        emit developerModeChanged();
    }
}

bool MoonSettings::recoveryMode() const
{
    return m_recoveryMode;
}

QVariantList MoonSettings::recentGames() const
{
    const auto raw = m_settings.value(QStringLiteral("recentGames")).toString().toUtf8();
    const auto doc = QJsonDocument::fromJson(raw);
    QVariantList list;
    for (const auto& v : doc.array())
        list.append(v.toObject().toVariantMap());
    return list;
}

void MoonSettings::addRecentGame(const QString& hostUuid, const QString& hostName,
                                 int appId, const QString& appName)
{
    QVariantList list = recentGames();
    for (int i = list.size() - 1; i >= 0; i--) {
        const auto m = list[i].toMap();
        if (m.value(QStringLiteral("hostUuid")) == hostUuid &&
            m.value(QStringLiteral("appId")).toInt() == appId) {
            list.removeAt(i);
        }
    }

    QVariantMap entry;
    entry[QStringLiteral("hostUuid")] = hostUuid;
    entry[QStringLiteral("hostName")] = hostName;
    entry[QStringLiteral("appId")] = appId;
    entry[QStringLiteral("appName")] = appName;
    entry[QStringLiteral("lastPlayed")] = QDateTime::currentDateTime().toString(Qt::ISODate);
    list.prepend(entry);

    while (list.size() > kMaxRecentGames)
        list.removeLast();

    writeRecentGames(list);
}

void MoonSettings::removeRecentGamesForHost(const QString& hostUuid)
{
    QVariantList list = recentGames();
    for (int i = list.size() - 1; i >= 0; i--) {
        if (list[i].toMap().value(QStringLiteral("hostUuid")) == hostUuid)
            list.removeAt(i);
    }
    writeRecentGames(list);
}

void MoonSettings::clearRecentGames()
{
    writeRecentGames({});
}

void MoonSettings::writeRecentGames(const QVariantList& list)
{
    QJsonArray arr;
    for (const auto& v : list)
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    m_settings.setValue(QStringLiteral("recentGames"),
                        QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
    m_settings.sync();
    emit recentGamesChanged();
}

bool MoonSettings::hasStreamProfile(const QString& hostUuid) const
{
    return m_settings.childGroups().contains(QStringLiteral("host-") + hostUuid);
}

void MoonSettings::saveStreamProfileForHost(const QString& hostUuid)
{
    if (hostUuid.isEmpty())
        return;

    auto* prefs = StreamingPreferences::get();
    m_settings.beginGroup(QStringLiteral("host-") + hostUuid);
    m_settings.setValue(QStringLiteral("width"), prefs->width);
    m_settings.setValue(QStringLiteral("height"), prefs->height);
    m_settings.setValue(QStringLiteral("fps"), prefs->fps);
    m_settings.setValue(QStringLiteral("bitrateKbps"), prefs->bitrateKbps);
    m_settings.setValue(QStringLiteral("enableVsync"), prefs->enableVsync);
    m_settings.setValue(QStringLiteral("framePacing"), prefs->framePacing);
    m_settings.setValue(QStringLiteral("audioConfig"), (int)prefs->audioConfig);
    m_settings.setValue(QStringLiteral("videoCodecConfig"), (int)prefs->videoCodecConfig);
    m_settings.setValue(QStringLiteral("enableHdr"), prefs->enableHdr);
    m_settings.setValue(QStringLiteral("multiController"), prefs->multiController);
    m_settings.setValue(QStringLiteral("playAudioOnHost"), prefs->playAudioOnHost);
    m_settings.setValue(QStringLiteral("gameOptimizations"), prefs->gameOptimizations);
    m_settings.endGroup();
    m_settings.sync();
}

bool MoonSettings::loadStreamProfileForHost(const QString& hostUuid)
{
    if (!hasStreamProfile(hostUuid))
        return false;

    auto* prefs = StreamingPreferences::get();
    m_settings.beginGroup(QStringLiteral("host-") + hostUuid);
    prefs->width = m_settings.value(QStringLiteral("width"), prefs->width).toInt();
    prefs->height = m_settings.value(QStringLiteral("height"), prefs->height).toInt();
    prefs->fps = m_settings.value(QStringLiteral("fps"), prefs->fps).toInt();
    prefs->bitrateKbps = m_settings.value(QStringLiteral("bitrateKbps"), prefs->bitrateKbps).toInt();
    prefs->enableVsync = m_settings.value(QStringLiteral("enableVsync"), prefs->enableVsync).toBool();
    prefs->framePacing = m_settings.value(QStringLiteral("framePacing"), prefs->framePacing).toBool();
    prefs->audioConfig = (StreamingPreferences::AudioConfig)
            m_settings.value(QStringLiteral("audioConfig"), (int)prefs->audioConfig).toInt();
    prefs->videoCodecConfig = (StreamingPreferences::VideoCodecConfig)
            m_settings.value(QStringLiteral("videoCodecConfig"), (int)prefs->videoCodecConfig).toInt();
    prefs->enableHdr = m_settings.value(QStringLiteral("enableHdr"), prefs->enableHdr).toBool();
    prefs->multiController = m_settings.value(QStringLiteral("multiController"), prefs->multiController).toBool();
    prefs->playAudioOnHost = m_settings.value(QStringLiteral("playAudioOnHost"), prefs->playAudioOnHost).toBool();
    prefs->gameOptimizations = m_settings.value(QStringLiteral("gameOptimizations"), prefs->gameOptimizations).toBool();
    m_settings.endGroup();

    prefs->save();
    return true;
}
