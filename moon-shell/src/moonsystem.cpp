#include "moonsystem.h"
#include "moonsettings.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QFile>
#include <QProcess>
#include <QTimer>

namespace {

const QString kSystemd = QStringLiteral("org.freedesktop.systemd1");
const QString kSystemdPath = QStringLiteral("/org/freedesktop/systemd1");
const QString kSystemdMgr = QStringLiteral("org.freedesktop.systemd1.Manager");
const QString kLogind = QStringLiteral("org.freedesktop.login1");
const QString kLogindPath = QStringLiteral("/org/freedesktop/login1");
const QString kLogindMgr = QStringLiteral("org.freedesktop.login1.Manager");

QString statusFile(const QString& name)
{
    return MoonSettings::stateDir() + QLatin1Char('/') + name;
}

QString readStatusFile(const QString& name)
{
    QFile f(statusFile(name));
    if (!f.open(QIODevice::ReadOnly))
        return QStringLiteral("idle");
    const QString s = QString::fromUtf8(f.readAll()).trimmed();
    return s.isEmpty() ? QStringLiteral("idle") : s;
}

} // namespace

MoonSystem::MoonSystem(MoonSettings* settings, QObject* parent)
    : QObject(parent), m_settings(settings)
{
    refreshUpdateStatus();
}

QString MoonSystem::osVersion() const
{
    QFile f(QStringLiteral("/etc/moonos/version"));
    if (f.open(QIODevice::ReadOnly))
        return QString::fromUtf8(f.readAll()).trimmed();
    return QStringLiteral("development");
}

void MoonSystem::logindCall(const QString& method)
{
    QDBusInterface logind(kLogind, kLogindPath, kLogindMgr, QDBusConnection::systemBus());
    logind.asyncCall(method, false /* non-interactive: rely on polkit rule */);
}

void MoonSystem::reboot()
{
    logindCall(QStringLiteral("Reboot"));
}

void MoonSystem::powerOff()
{
    logindCall(QStringLiteral("PowerOff"));
}

void MoonSystem::startUnit(const QString& unitName)
{
    QDBusInterface systemd(kSystemd, kSystemdPath, kSystemdMgr, QDBusConnection::systemBus());
    systemd.asyncCall(QStringLiteral("StartUnit"), unitName, QStringLiteral("replace"));
}

void MoonSystem::restartShell()
{
    // Restarting our own unit terminates this process; systemd brings the
    // shell straight back with the new display/KMS configuration.
    QDBusInterface systemd(kSystemd, kSystemdPath, kSystemdMgr, QDBusConnection::systemBus());
    systemd.asyncCall(QStringLiteral("RestartUnit"),
                      QStringLiteral("moon-shell.service"), QStringLiteral("replace"));
}

void MoonSystem::startUpdate()
{
    m_updateStatus = QStringLiteral("running");
    emit updateStatusChanged();
    startUnit(QStringLiteral("moon-update.service"));

    // moon-update.service writes its progress to the status file; poll it
    // until the run settles.
    auto* timer = new QTimer(this);
    timer->setInterval(2000);
    connect(timer, &QTimer::timeout, this, [this, timer] {
        refreshUpdateStatus();
        if (m_updateStatus != QStringLiteral("running"))
            timer->deleteLater();
    });
    timer->start();
}

void MoonSystem::refreshUpdateStatus()
{
    const QString s = readStatusFile(QStringLiteral("update-status"));
    if (s != m_updateStatus) {
        m_updateStatus = s;
        emit updateStatusChanged();
    }
}

void MoonSystem::setDeveloperMode(bool enabled)
{
    startUnit(enabled ? QStringLiteral("moon-devmode-on.service")
                      : QStringLiteral("moon-devmode-off.service"));
    // The unit creates/removes the flag file; give it a moment then re-read.
    QTimer::singleShot(2000, m_settings, &MoonSettings::refreshDeveloperMode);
}

void MoonSystem::factoryReset()
{
    QFile flag(statusFile(QStringLiteral(".factory-reset")));
    if (flag.open(QIODevice::WriteOnly))
        flag.write("requested\n");
    reboot();
}

void MoonSystem::exportConfigToUsb()
{
    startUnit(QStringLiteral("moon-config-export.service"));
}

void MoonSystem::importConfigFromUsb()
{
    startUnit(QStringLiteral("moon-config-import.service"));
}

QString MoonSystem::configIoStatus() const
{
    return readStatusFile(QStringLiteral("config-io-status"));
}

QString MoonSystem::shellLog(int lines) const
{
    QProcess p;
    p.start(QStringLiteral("journalctl"),
            {QStringLiteral("-u"), QStringLiteral("moon-shell.service"),
             QStringLiteral("-n"), QString::number(qBound(50, lines, 2000)),
             QStringLiteral("--no-pager"), QStringLiteral("-o"), QStringLiteral("short")});
    if (!p.waitForFinished(5000))
        return QStringLiteral("(could not read journal)");
    return QString::fromUtf8(p.readAllStandardOutput());
}
