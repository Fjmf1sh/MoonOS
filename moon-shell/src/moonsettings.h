#pragma once

#include <QObject>
#include <QSettings>
#include <QVariantList>

// Moon OS console state, separate from moonlight-qt's own StreamingPreferences.
// Persisted to $MOONOS_STATE_DIR/moon.ini (default /var/lib/moonos).
//
// Owns: first-run flag, safe-area, CEC toggle, audio output, recent games,
// and per-host snapshots of the upstream StreamingPreferences.
class MoonSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool setupComplete READ setupComplete WRITE setSetupComplete NOTIFY setupCompleteChanged)
    Q_PROPERTY(int safeAreaPct READ safeAreaPct WRITE setSafeAreaPct NOTIFY safeAreaPctChanged)
    Q_PROPERTY(bool cecEnabled READ cecEnabled WRITE setCecEnabled NOTIFY cecEnabledChanged)
    Q_PROPERTY(bool tvPowerSync READ tvPowerSync WRITE setTvPowerSync NOTIFY tvPowerSyncChanged)
    Q_PROPERTY(QString audioDevice READ audioDevice WRITE setAudioDevice NOTIFY audioDeviceChanged)
    Q_PROPERTY(QVariantList recentGames READ recentGames NOTIFY recentGamesChanged)
    Q_PROPERTY(bool developerMode READ developerMode NOTIFY developerModeChanged)
    Q_PROPERTY(bool recoveryMode READ recoveryMode CONSTANT)

public:
    explicit MoonSettings(QObject* parent = nullptr);

    static QString stateDir();

    bool setupComplete() const;
    void setSetupComplete(bool value);

    int safeAreaPct() const;
    void setSafeAreaPct(int pct);

    bool cecEnabled() const;
    void setCecEnabled(bool value);

    bool tvPowerSync() const;
    void setTvPowerSync(bool value);

    QString audioDevice() const;
    void setAudioDevice(const QString& device);

    bool developerMode() const;
    Q_INVOKABLE void refreshDeveloperMode();

    bool recoveryMode() const;

    // Recent games shown on the Home screen. Each entry:
    // { hostUuid, hostName, appId, appName, lastPlayed (ISO string) }
    QVariantList recentGames() const;
    Q_INVOKABLE void addRecentGame(const QString& hostUuid, const QString& hostName,
                                   int appId, const QString& appName);
    Q_INVOKABLE void removeRecentGamesForHost(const QString& hostUuid);
    Q_INVOKABLE void clearRecentGames();

    // Per-host stream profiles: snapshot/restore the global upstream
    // StreamingPreferences so each PC can keep its own resolution/fps/bitrate.
    Q_INVOKABLE bool hasStreamProfile(const QString& hostUuid) const;
    Q_INVOKABLE void saveStreamProfileForHost(const QString& hostUuid);
    Q_INVOKABLE bool loadStreamProfileForHost(const QString& hostUuid);

signals:
    void setupCompleteChanged();
    void safeAreaPctChanged();
    void cecEnabledChanged();
    void tvPowerSyncChanged();
    void audioDeviceChanged();
    void recentGamesChanged();
    void developerModeChanged();

private:
    void writeRecentGames(const QVariantList& list);

    mutable QSettings m_settings;
    bool m_developerMode = false;
    bool m_recoveryMode = false;
};
