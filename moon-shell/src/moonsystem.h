#pragma once

#include <QObject>

class MoonSettings;

// Power, updates, developer mode, factory reset and config export/import.
//
// The shell runs as the unprivileged "moon" user. Every privileged action is
// either a logind D-Bus call (reboot/poweroff, authorized by polkit rule) or
// starting a root-owned moon-* systemd unit (authorized by the same rule).
// The shell itself never runs anything as root.
class MoonSystem : public QObject
{
    Q_OBJECT
    // "idle" | "running" | "success" | "failed: <detail>"
    Q_PROPERTY(QString updateStatus READ updateStatus NOTIFY updateStatusChanged)
    Q_PROPERTY(QString osVersion READ osVersion CONSTANT)

public:
    explicit MoonSystem(MoonSettings* settings, QObject* parent = nullptr);

    QString updateStatus() const { return m_updateStatus; }
    QString osVersion() const;

    Q_INVOKABLE void reboot();
    Q_INVOKABLE void powerOff();
    Q_INVOKABLE void restartShell();

    Q_INVOKABLE void startUpdate();
    Q_INVOKABLE void refreshUpdateStatus();
    Q_INVOKABLE void startUninstall();

    Q_INVOKABLE void setDeveloperMode(bool enabled);

    // Stages a factory reset flag and reboots; moon-factory-reset.service
    // wipes state early in the next boot, before the shell starts.
    Q_INVOKABLE void factoryReset();

    Q_INVOKABLE void exportConfigToUsb();
    Q_INVOKABLE void importConfigFromUsb();
    // "idle" | "running" | "success: <detail>" | "failed: <detail>"
    Q_INVOKABLE QString configIoStatus() const;

    // Last shell log lines for the developer screen (journalctl, moon user is
    // in systemd-journal). Read-only diagnostics, not a privileged action.
    Q_INVOKABLE QString shellLog(int lines = 300) const;

signals:
    void updateStatusChanged();

private:
    void startUnit(const QString& unitName);
    void logindCall(const QString& method);

    MoonSettings* m_settings;
    QString m_updateStatus = QStringLiteral("idle");
};
