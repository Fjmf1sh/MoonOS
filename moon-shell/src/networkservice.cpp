#include "networkservice.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>

namespace {

const QString kNmService = QStringLiteral("org.freedesktop.NetworkManager");
const QString kNmPath = QStringLiteral("/org/freedesktop/NetworkManager");
const QString kNmIface = QStringLiteral("org.freedesktop.NetworkManager");
const QString kDeviceIface = QStringLiteral("org.freedesktop.NetworkManager.Device");
const QString kWirelessIface = QStringLiteral("org.freedesktop.NetworkManager.Device.Wireless");
const QString kApIface = QStringLiteral("org.freedesktop.NetworkManager.AccessPoint");
const QString kSettingsPath = QStringLiteral("/org/freedesktop/NetworkManager/Settings");
const QString kSettingsIface = QStringLiteral("org.freedesktop.NetworkManager.Settings");
const QString kConnIface = QStringLiteral("org.freedesktop.NetworkManager.Settings.Connection");
const QString kPropsIface = QStringLiteral("org.freedesktop.DBus.Properties");

// NM_DEVICE_TYPE / NM_DEVICE_STATE constants we care about
const uint kDeviceTypeEthernet = 1;
const uint kDeviceTypeWifi = 2;
const uint kDeviceStateActivated = 100;

using ConnectionSettings = QMap<QString, QVariantMap>;

QVariant getProp(const QString& path, const QString& iface, const QString& name)
{
    QDBusInterface props(kNmService, path, kPropsIface, QDBusConnection::systemBus());
    QDBusReply<QVariant> reply = props.call(QStringLiteral("Get"), iface, name);
    return reply.isValid() ? reply.value() : QVariant();
}

// Recursively unwrap QDBusArgument containers into plain QVariants.
QVariant unwrapDBus(const QVariant& in)
{
    if (in.canConvert<QDBusObjectPath>() && in.userType() == qMetaTypeId<QDBusObjectPath>())
        return in.value<QDBusObjectPath>().path();

    if (in.userType() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument arg = in.value<QDBusArgument>();
        switch (arg.currentType()) {
        case QDBusArgument::MapType: {
            QVariantMap map;
            arg.beginMap();
            while (!arg.atEnd()) {
                arg.beginMapEntry();
                QString key;
                QVariant value;
                arg >> key >> value;
                arg.endMapEntry();
                map.insert(key, unwrapDBus(value));
            }
            arg.endMap();
            return map;
        }
        case QDBusArgument::ArrayType: {
            QVariantList list;
            arg.beginArray();
            while (!arg.atEnd()) {
                QVariant value;
                arg >> value;
                list.append(unwrapDBus(value));
            }
            arg.endArray();
            return list;
        }
        default:
            return QVariant();
        }
    }

    if (in.userType() == QMetaType::QVariant)
        return unwrapDBus(in.value<QVariant>());

    return in;
}

QString friendlyNmError(const QString& raw)
{
    if (raw.contains(QStringLiteral("Secrets were required"), Qt::CaseInsensitive) ||
        raw.contains(QStringLiteral("802-11-wireless-security"), Qt::CaseInsensitive))
        return QStringLiteral("The Wi-Fi password looks incorrect. Please try again.");
    if (raw.contains(QStringLiteral("timeout"), Qt::CaseInsensitive))
        return QStringLiteral("The network did not respond in time. Move closer to your router and try again.");
    return QStringLiteral("Could not join the network. Please try again.");
}

} // namespace

NetworkService::NetworkService(QObject* parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<ConnectionSettings>();

    findDevices();
    refresh();

    // NetworkManager emits granular PropertiesChanged signals, but a light
    // periodic poll keeps status (IP, signal bars) honest with far less
    // subscription plumbing. 5s is imperceptible for a status page.
    m_pollTimer.setInterval(5000);
    connect(&m_pollTimer, &QTimer::timeout, this, &NetworkService::refreshState);
    m_pollTimer.start();
}

void NetworkService::findDevices()
{
    QDBusInterface nm(kNmService, kNmPath, kNmIface, QDBusConnection::systemBus());
    QDBusReply<QList<QDBusObjectPath>> reply = nm.call(QStringLiteral("GetDevices"));
    if (!reply.isValid())
        return;

    for (const auto& devPath : reply.value()) {
        const uint type = getProp(devPath.path(), kDeviceIface, QStringLiteral("DeviceType")).toUInt();
        if (type == kDeviceTypeWifi && m_wifiDevice.isEmpty())
            m_wifiDevice = devPath.path();
        else if (type == kDeviceTypeEthernet && m_ethernetDevice.isEmpty())
            m_ethernetDevice = devPath.path();
    }
}

void NetworkService::refresh()
{
    refreshSavedConnections();
    refreshAccessPoints();
    refreshState();
}

void NetworkService::refreshState()
{
    m_wifiEnabled = getProp(kNmPath, kNmIface, QStringLiteral("WirelessEnabled")).toBool();

    // NM_STATE_CONNECTED_SITE (60) / _GLOBAL (70) both mean usable LAN
    const uint nmState = getProp(kNmPath, kNmIface, QStringLiteral("State")).toUInt();
    m_online = nmState >= 60;

    m_ethernetConnected = false;
    if (!m_ethernetDevice.isEmpty()) {
        const uint state = getProp(m_ethernetDevice, kDeviceIface, QStringLiteral("State")).toUInt();
        m_ethernetConnected = (state == kDeviceStateActivated);
    }

    // IP details of the primary connection: address, gateway, DNS servers.
    m_ipAddress.clear();
    m_gateway.clear();
    m_dnsServers.clear();
    QString primaryDevice;
    const QString primary = unwrapDBus(getProp(kNmPath, kNmIface, QStringLiteral("PrimaryConnection"))).toString();
    if (!primary.isEmpty() && primary != QStringLiteral("/")) {
        const QString activeIface = QStringLiteral("org.freedesktop.NetworkManager.Connection.Active");
        // Remember which device carries the primary connection so we can read
        // its hardware (MAC) address below.
        const QVariantList devs = unwrapDBus(getProp(primary, activeIface, QStringLiteral("Devices"))).toList();
        if (!devs.isEmpty())
            primaryDevice = devs.first().toString();

        const QString ip4Path = unwrapDBus(
            getProp(primary, activeIface, QStringLiteral("Ip4Config"))).toString();
        if (!ip4Path.isEmpty() && ip4Path != QStringLiteral("/")) {
            const QString ip4Iface = QStringLiteral("org.freedesktop.NetworkManager.IP4Config");
            const QVariantList addrs =
                unwrapDBus(getProp(ip4Path, ip4Iface, QStringLiteral("AddressData"))).toList();
            if (!addrs.isEmpty())
                m_ipAddress = addrs.first().toMap().value(QStringLiteral("address")).toString();

            m_gateway = getProp(ip4Path, ip4Iface, QStringLiteral("Gateway")).toString();

            // NameserverData is a list of { address, ... } maps (NM >= 1.14).
            const QVariantList nsData =
                unwrapDBus(getProp(ip4Path, ip4Iface, QStringLiteral("NameserverData"))).toList();
            for (const QVariant& ns : nsData) {
                const QString addr = ns.toMap().value(QStringLiteral("address")).toString();
                if (!addr.isEmpty())
                    m_dnsServers.append(addr);
            }
        }
    }

    // MAC address of the active interface (falls back to the Wi-Fi device).
    m_macAddress.clear();
    const QString macDevice = !primaryDevice.isEmpty() ? primaryDevice
                            : !m_ethernetDevice.isEmpty() ? m_ethernetDevice
                            : m_wifiDevice;
    if (!macDevice.isEmpty())
        m_macAddress = getProp(macDevice, kDeviceIface, QStringLiteral("HwAddress")).toString();

    // SSID + signal of the active access point
    m_currentSsid.clear();
    m_signalStrength = 0;
    if (!m_wifiDevice.isEmpty()) {
        const QString apPath = unwrapDBus(
            getProp(m_wifiDevice, kWirelessIface, QStringLiteral("ActiveAccessPoint"))).toString();
        if (!apPath.isEmpty() && apPath != QStringLiteral("/")) {
            m_currentSsid = QString::fromUtf8(
                getProp(apPath, kApIface, QStringLiteral("Ssid")).toByteArray());
            m_signalStrength = getProp(apPath, kApIface, QStringLiteral("Strength")).toUInt();
        }
    }

    emit stateChanged();
}

void NetworkService::scan()
{
    if (m_wifiDevice.isEmpty() || m_scanning)
        return;

    m_scanning = true;
    emit scanningChanged();

    QDBusInterface wireless(kNmService, m_wifiDevice, kWirelessIface, QDBusConnection::systemBus());
    wireless.asyncCall(QStringLiteral("RequestScan"), QVariantMap());

    // NM has no completion callback for RequestScan; APs usually settle
    // within a few seconds. Refresh twice to catch late beacons.
    QTimer::singleShot(2500, this, [this] { refreshAccessPoints(); });
    QTimer::singleShot(6000, this, [this] {
        refreshAccessPoints();
        m_scanning = false;
        emit scanningChanged();
    });
}

void NetworkService::refreshAccessPoints()
{
    if (m_wifiDevice.isEmpty())
        return;

    QDBusInterface wireless(kNmService, m_wifiDevice, kWirelessIface, QDBusConnection::systemBus());
    QDBusReply<QList<QDBusObjectPath>> reply = wireless.call(QStringLiteral("GetAllAccessPoints"));
    if (!reply.isValid())
        return;

    const QString activeAp = unwrapDBus(
        getProp(m_wifiDevice, kWirelessIface, QStringLiteral("ActiveAccessPoint"))).toString();

    struct ApInfo { QString path; int strength; bool secured; bool active; };
    QHash<QString, ApInfo> bestBySsid;

    for (const auto& apPath : reply.value()) {
        const QString path = apPath.path();
        const QString ssid = QString::fromUtf8(
            getProp(path, kApIface, QStringLiteral("Ssid")).toByteArray());
        if (ssid.isEmpty())
            continue; // hidden network

        const int strength = getProp(path, kApIface, QStringLiteral("Strength")).toUInt();
        const uint flags = getProp(path, kApIface, QStringLiteral("Flags")).toUInt();
        const uint wpa = getProp(path, kApIface, QStringLiteral("WpaFlags")).toUInt();
        const uint rsn = getProp(path, kApIface, QStringLiteral("RsnFlags")).toUInt();
        const bool secured = (flags & 0x1) || wpa != 0 || rsn != 0;
        const bool active = (path == activeAp);

        auto it = bestBySsid.find(ssid);
        if (it == bestBySsid.end() || strength > it->strength || active)
            bestBySsid[ssid] = ApInfo{path, strength, secured, active};
    }

    m_apPathBySsid.clear();
    QVariantList list;
    for (auto it = bestBySsid.constBegin(); it != bestBySsid.constEnd(); ++it) {
        m_apPathBySsid[it.key()] = it->path;
        QVariantMap entry;
        entry[QStringLiteral("ssid")] = it.key();
        entry[QStringLiteral("strength")] = it->strength;
        entry[QStringLiteral("secured")] = it->secured;
        entry[QStringLiteral("saved")] = m_savedSsids.contains(it.key());
        entry[QStringLiteral("active")] = it->active;
        list.append(entry);
    }
    // Order: the connected network first, then remembered (saved) networks,
    // then everything else — each tier strongest-signal-first — so the networks
    // people actually use sit at the top instead of buried in the scan list.
    std::sort(list.begin(), list.end(), [](const QVariant& a, const QVariant& b) {
        const auto ma = a.toMap(), mb = b.toMap();
        if (ma[QStringLiteral("active")].toBool() != mb[QStringLiteral("active")].toBool())
            return ma[QStringLiteral("active")].toBool();
        if (ma[QStringLiteral("saved")].toBool() != mb[QStringLiteral("saved")].toBool())
            return ma[QStringLiteral("saved")].toBool();
        return ma[QStringLiteral("strength")].toInt() > mb[QStringLiteral("strength")].toInt();
    });

    m_networks = list;
    emit networksChanged();
}

void NetworkService::refreshSavedConnections()
{
    QDBusInterface settings(kNmService, kSettingsPath, kSettingsIface, QDBusConnection::systemBus());
    QDBusReply<QList<QDBusObjectPath>> reply = settings.call(QStringLiteral("ListConnections"));
    if (!reply.isValid())
        return;

    m_savedSsids.clear();
    m_savedPathBySsid.clear();

    for (const auto& connPath : reply.value()) {
        QDBusInterface conn(kNmService, connPath.path(), kConnIface, QDBusConnection::systemBus());
        QDBusMessage msg = conn.call(QStringLiteral("GetSettings"));
        if (msg.type() != QDBusMessage::ReplyMessage || msg.arguments().isEmpty())
            continue;

        const QVariantMap all = unwrapDBus(msg.arguments().first()).toMap();
        const QVariantMap connSection = all.value(QStringLiteral("connection")).toMap();
        if (connSection.value(QStringLiteral("type")).toString() != QStringLiteral("802-11-wireless"))
            continue;

        const QVariantMap wifiSection = all.value(QStringLiteral("802-11-wireless")).toMap();
        const QString ssid = QString::fromUtf8(wifiSection.value(QStringLiteral("ssid")).toByteArray());
        if (ssid.isEmpty())
            continue;

        m_savedSsids.append(ssid);
        m_savedPathBySsid[ssid] = connPath.path();
    }

    emit networksChanged();
}

QString NetworkService::accessPointPathForSsid(const QString& ssid) const
{
    return m_apPathBySsid.value(ssid);
}

QString NetworkService::savedConnectionPathForSsid(const QString& ssid) const
{
    return m_savedPathBySsid.value(ssid);
}

void NetworkService::setWifiEnabled(bool enabled)
{
    QDBusInterface props(kNmService, kNmPath, kPropsIface, QDBusConnection::systemBus());
    props.call(QStringLiteral("Set"), kNmIface, QStringLiteral("WirelessEnabled"),
               QVariant::fromValue(QDBusVariant(enabled)));
    refreshState();
}

void NetworkService::setConnecting(bool value)
{
    if (m_connecting == value)
        return;
    m_connecting = value;
    emit connectingChanged();
}

void NetworkService::connectToNetwork(const QString& ssid, const QString& password)
{
    if (m_wifiDevice.isEmpty()) {
        emit connectFinished(false, QStringLiteral("No Wi-Fi adapter was found."));
        return;
    }

    // Reuse a saved profile when one exists — NM keeps the stored password.
    const QString saved = savedConnectionPathForSsid(ssid);
    if (!saved.isEmpty() && password.isEmpty()) {
        connectToSaved(ssid);
        return;
    }

    ConnectionSettings settings;
    QVariantMap connection;
    connection[QStringLiteral("id")] = ssid;
    connection[QStringLiteral("type")] = QStringLiteral("802-11-wireless");
    settings[QStringLiteral("connection")] = connection;

    QVariantMap wireless;
    wireless[QStringLiteral("ssid")] = ssid.toUtf8();
    wireless[QStringLiteral("mode")] = QStringLiteral("infrastructure");
    settings[QStringLiteral("802-11-wireless")] = wireless;

    if (!password.isEmpty()) {
        QVariantMap security;
        security[QStringLiteral("key-mgmt")] = QStringLiteral("wpa-psk");
        security[QStringLiteral("psk")] = password;
        settings[QStringLiteral("802-11-wireless-security")] = security;
    }

    const QString apPath = accessPointPathForSsid(ssid);

    setConnecting(true);
    QDBusInterface nm(kNmService, kNmPath, kNmIface, QDBusConnection::systemBus());
    QDBusPendingCall call = nm.asyncCall(QStringLiteral("AddAndActivateConnection"),
        QVariant::fromValue(settings),
        QVariant::fromValue(QDBusObjectPath(m_wifiDevice)),
        QVariant::fromValue(QDBusObjectPath(apPath.isEmpty() ? QStringLiteral("/") : apPath)));

    auto* watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this](QDBusPendingCallWatcher* w) {
        QDBusPendingReply<QDBusObjectPath, QDBusObjectPath> reply = *w;
        w->deleteLater();
        if (reply.isError()) {
            setConnecting(false);
            emit connectFinished(false, friendlyNmError(reply.error().message()));
            return;
        }
        watchActivation(reply.argumentAt<1>());
    });
}

void NetworkService::connectToSaved(const QString& ssid)
{
    const QString connPath = savedConnectionPathForSsid(ssid);
    if (connPath.isEmpty() || m_wifiDevice.isEmpty()) {
        emit connectFinished(false, QStringLiteral("That network is no longer saved."));
        return;
    }

    setConnecting(true);
    QDBusInterface nm(kNmService, kNmPath, kNmIface, QDBusConnection::systemBus());
    QDBusPendingCall call = nm.asyncCall(QStringLiteral("ActivateConnection"),
        QVariant::fromValue(QDBusObjectPath(connPath)),
        QVariant::fromValue(QDBusObjectPath(m_wifiDevice)),
        QVariant::fromValue(QDBusObjectPath(QStringLiteral("/"))));

    auto* watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this](QDBusPendingCallWatcher* w) {
        QDBusPendingReply<QDBusObjectPath> reply = *w;
        w->deleteLater();
        if (reply.isError()) {
            setConnecting(false);
            emit connectFinished(false, friendlyNmError(reply.error().message()));
            return;
        }
        watchActivation(reply.argumentAt<0>());
    });
}

void NetworkService::watchActivation(const QDBusObjectPath& activeConnPath)
{
    // Poll the ActiveConnection state until it activates (2) or fails (4).
    const QString path = activeConnPath.path();
    auto* timer = new QTimer(this);
    auto* attempts = new int(0);
    timer->setInterval(500);
    connect(timer, &QTimer::timeout, this, [this, timer, attempts, path] {
        const uint state = getProp(path,
            QStringLiteral("org.freedesktop.NetworkManager.Connection.Active"),
            QStringLiteral("State")).toUInt();

        const bool timedOut = ++(*attempts) > 60; // 30 seconds
        if (state == 2) { // NM_ACTIVE_CONNECTION_STATE_ACTIVATED
            timer->deleteLater();
            delete attempts;
            setConnecting(false);
            refresh();
            emit connectFinished(true, QString());
        }
        else if (state == 4 || state == 0 || timedOut) { // DEACTIVATED / gone
            timer->deleteLater();
            delete attempts;
            setConnecting(false);
            refresh();
            emit connectFinished(false,
                QStringLiteral("Could not join the network. Check the password and try again."));
        }
    });
    timer->start();
}

void NetworkService::forgetNetwork(const QString& ssid)
{
    const QString connPath = savedConnectionPathForSsid(ssid);
    if (connPath.isEmpty())
        return;

    QDBusInterface conn(kNmService, connPath, kConnIface, QDBusConnection::systemBus());
    conn.call(QStringLiteral("Delete"));
    refresh();
}
