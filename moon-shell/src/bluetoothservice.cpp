#include "bluetoothservice.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>

namespace {

const QString kBluez = QStringLiteral("org.bluez");
const QString kAdapterIface = QStringLiteral("org.bluez.Adapter1");
const QString kDeviceIface = QStringLiteral("org.bluez.Device1");
const QString kBatteryIface = QStringLiteral("org.bluez.Battery1");
const QString kPropsIface = QStringLiteral("org.freedesktop.DBus.Properties");
const QString kAgentPath = QStringLiteral("/org/moonos/agent");

QVariant deviceProp(const QString& path, const QString& iface, const QString& name)
{
    QDBusInterface props(kBluez, path, kPropsIface, QDBusConnection::systemBus());
    QDBusReply<QVariant> reply = props.call(QStringLiteral("Get"), iface, name);
    return reply.isValid() ? reply.value() : QVariant();
}

bool looksLikeController(const QString& icon, const QString& name)
{
    if (icon == QStringLiteral("input-gaming"))
        return true;
    // Common controllers that advertise a generic icon
    static const QStringList hints = {
        QStringLiteral("controller"), QStringLiteral("gamepad"),
        QStringLiteral("dualshock"), QStringLiteral("dualsense"),
        QStringLiteral("xbox"), QStringLiteral("joy-con"), QStringLiteral("pro controller"),
    };
    const QString lower = name.toLower();
    for (const auto& h : hints) {
        if (lower.contains(h))
            return true;
    }
    return false;
}

QString friendlyBtError(const QString& raw)
{
    if (raw.contains(QStringLiteral("AuthenticationFailed"), Qt::CaseInsensitive))
        return QStringLiteral("Pairing was rejected by the controller. Put it back in pairing mode and try again.");
    if (raw.contains(QStringLiteral("AlreadyExists"), Qt::CaseInsensitive))
        return QString(); // already paired — treat as success
    if (raw.contains(QStringLiteral("Page Timeout"), Qt::CaseInsensitive) ||
        raw.contains(QStringLiteral("le-connection-abort"), Qt::CaseInsensitive) ||
        raw.contains(QStringLiteral("Timeout"), Qt::CaseInsensitive))
        return QStringLiteral("The controller did not respond. Make sure it is in pairing mode and nearby.");
    return QStringLiteral("Could not talk to the controller. Try again.");
}

// BlueZ pairing agent. Controllers use "Just Works" pairing; this agent
// auto-accepts confirmation/authorization requests so no keyboard is needed.
// Exported at /org/moonos/agent with capability NoInputNoOutput.
class PairingAgent : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.Agent1")

public:
    using QObject::QObject;

public slots:
    void Release() {}
    QString RequestPinCode(const QDBusObjectPath&) { return QStringLiteral("0000"); }
    void DisplayPinCode(const QDBusObjectPath&, const QString&) {}
    quint32 RequestPasskey(const QDBusObjectPath&) { return 0; }
    void DisplayPasskey(const QDBusObjectPath&, quint32, quint16) {}
    void RequestConfirmation(const QDBusObjectPath&, quint32) {} // empty reply = accept
    void RequestAuthorization(const QDBusObjectPath&) {}
    void AuthorizeService(const QDBusObjectPath&, const QString&) {}
    void Cancel() {}
};

} // namespace

BluetoothService::BluetoothService(QObject* parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<QMap<QString, QVariantMap>>();

    findAdapter();
    registerAgent();
    refresh();

    // BlueZ emits InterfacesAdded/PropertiesChanged constantly during
    // discovery; a 3s poll of GetManagedObjects is simpler and cheap on a
    // local bus, and guarantees the list is right even after missed signals.
    m_pollTimer.setInterval(3000);
    connect(&m_pollTimer, &QTimer::timeout, this, &BluetoothService::refresh);
    m_pollTimer.start();
}

BluetoothService::~BluetoothService()
{
    if (m_agent) {
        QDBusInterface mgr(kBluez, QStringLiteral("/org/bluez"),
                           QStringLiteral("org.bluez.AgentManager1"),
                           QDBusConnection::systemBus());
        mgr.call(QStringLiteral("UnregisterAgent"), QVariant::fromValue(QDBusObjectPath(kAgentPath)));
    }
}

void BluetoothService::findAdapter()
{
    QDBusInterface om(kBluez, QStringLiteral("/"),
                      QStringLiteral("org.freedesktop.DBus.ObjectManager"),
                      QDBusConnection::systemBus());
    QDBusMessage msg = om.call(QStringLiteral("GetManagedObjects"));
    if (msg.type() != QDBusMessage::ReplyMessage || msg.arguments().isEmpty())
        return;

    const QDBusArgument arg = msg.arguments().first().value<QDBusArgument>();
    arg.beginMap();
    while (!arg.atEnd()) {
        arg.beginMapEntry();
        QDBusObjectPath path;
        QMap<QString, QVariantMap> interfaces;
        arg >> path >> interfaces;
        arg.endMapEntry();
        if (interfaces.contains(kAdapterIface) && m_adapterPath.isEmpty())
            m_adapterPath = path.path();
    }
    arg.endMap();
}

void BluetoothService::registerAgent()
{
    if (m_agent)
        return;

    m_agent = new PairingAgent(this);
    QDBusConnection::systemBus().registerObject(kAgentPath, m_agent,
                                                QDBusConnection::ExportAllSlots);

    QDBusInterface mgr(kBluez, QStringLiteral("/org/bluez"),
                       QStringLiteral("org.bluez.AgentManager1"),
                       QDBusConnection::systemBus());
    mgr.call(QStringLiteral("RegisterAgent"),
             QVariant::fromValue(QDBusObjectPath(kAgentPath)),
             QStringLiteral("NoInputNoOutput"));
    mgr.call(QStringLiteral("RequestDefaultAgent"),
             QVariant::fromValue(QDBusObjectPath(kAgentPath)));
}

void BluetoothService::refreshAdapterState()
{
    if (m_adapterPath.isEmpty()) {
        findAdapter();
        if (m_adapterPath.isEmpty())
            return;
    }
    m_powered = deviceProp(m_adapterPath, kAdapterIface, QStringLiteral("Powered")).toBool();
    m_discovering = deviceProp(m_adapterPath, kAdapterIface, QStringLiteral("Discovering")).toBool();
    emit stateChanged();
}

void BluetoothService::refresh()
{
    refreshAdapterState();
    if (m_adapterPath.isEmpty())
        return;

    QDBusInterface om(kBluez, QStringLiteral("/"),
                      QStringLiteral("org.freedesktop.DBus.ObjectManager"),
                      QDBusConnection::systemBus());
    QDBusMessage msg = om.call(QStringLiteral("GetManagedObjects"));
    if (msg.type() != QDBusMessage::ReplyMessage || msg.arguments().isEmpty())
        return;

    QVariantList list;
    const QDBusArgument arg = msg.arguments().first().value<QDBusArgument>();
    arg.beginMap();
    while (!arg.atEnd()) {
        arg.beginMapEntry();
        QDBusObjectPath path;
        QMap<QString, QVariantMap> interfaces;
        arg >> path >> interfaces;
        arg.endMapEntry();

        if (!interfaces.contains(kDeviceIface))
            continue;

        const QVariantMap dev = interfaces.value(kDeviceIface);
        const QString name = dev.value(QStringLiteral("Alias"),
                                       dev.value(QStringLiteral("Name"))).toString();
        if (name.isEmpty())
            continue; // address-only ghosts clutter the pairing screen

        const QString icon = dev.value(QStringLiteral("Icon")).toString();
        int battery = -1;
        if (interfaces.contains(kBatteryIface))
            battery = interfaces.value(kBatteryIface).value(QStringLiteral("Percentage"), -1).toInt();

        QVariantMap entry;
        entry[QStringLiteral("path")] = path.path();
        entry[QStringLiteral("name")] = name;
        entry[QStringLiteral("address")] = dev.value(QStringLiteral("Address")).toString();
        entry[QStringLiteral("icon")] = icon;
        entry[QStringLiteral("paired")] = dev.value(QStringLiteral("Paired")).toBool();
        entry[QStringLiteral("connected")] = dev.value(QStringLiteral("Connected")).toBool();
        entry[QStringLiteral("trusted")] = dev.value(QStringLiteral("Trusted")).toBool();
        entry[QStringLiteral("battery")] = battery;
        entry[QStringLiteral("isController")] = looksLikeController(icon, name);
        list.append(entry);
    }
    arg.endMap();

    std::sort(list.begin(), list.end(), [](const QVariant& a, const QVariant& b) {
        const auto ma = a.toMap(), mb = b.toMap();
        // connected > paired > controllers > rest
        auto rank = [](const QVariantMap& m) {
            if (m[QStringLiteral("connected")].toBool()) return 0;
            if (m[QStringLiteral("paired")].toBool()) return 1;
            if (m[QStringLiteral("isController")].toBool()) return 2;
            return 3;
        };
        const int ra = rank(ma), rb = rank(mb);
        if (ra != rb)
            return ra < rb;
        return ma[QStringLiteral("name")].toString() < mb[QStringLiteral("name")].toString();
    });

    m_devices = list;
    emit devicesChanged();
}

int BluetoothService::connectedControllerCount() const
{
    int n = 0;
    for (const auto& v : m_devices) {
        const auto m = v.toMap();
        if (m[QStringLiteral("connected")].toBool() && m[QStringLiteral("isController")].toBool())
            n++;
    }
    return n;
}

void BluetoothService::setPowered(bool on)
{
    if (m_adapterPath.isEmpty())
        return;
    QDBusInterface props(kBluez, m_adapterPath, kPropsIface, QDBusConnection::systemBus());
    props.call(QStringLiteral("Set"), kAdapterIface, QStringLiteral("Powered"),
               QVariant::fromValue(QDBusVariant(on)));
    refreshAdapterState();
}

void BluetoothService::startScan()
{
    if (m_adapterPath.isEmpty())
        return;
    if (!m_powered)
        setPowered(true);
    QDBusInterface adapter(kBluez, m_adapterPath, kAdapterIface, QDBusConnection::systemBus());
    adapter.asyncCall(QStringLiteral("StartDiscovery"));
    QTimer::singleShot(500, this, &BluetoothService::refreshAdapterState);
}

void BluetoothService::stopScan()
{
    if (m_adapterPath.isEmpty())
        return;
    QDBusInterface adapter(kBluez, m_adapterPath, kAdapterIface, QDBusConnection::systemBus());
    adapter.asyncCall(QStringLiteral("StopDiscovery"));
    QTimer::singleShot(500, this, &BluetoothService::refreshAdapterState);
}

void BluetoothService::trustDevice(const QString& path)
{
    QDBusInterface props(kBluez, path, kPropsIface, QDBusConnection::systemBus());
    props.call(QStringLiteral("Set"), kDeviceIface, QStringLiteral("Trusted"),
               QVariant::fromValue(QDBusVariant(true)));
}

void BluetoothService::callDeviceMethod(const QString& path, const QString& method,
                                        bool trustFirst, const QString& friendlyFailure)
{
    if (trustFirst)
        trustDevice(path);

    QDBusInterface device(kBluez, path, kDeviceIface, QDBusConnection::systemBus());
    device.setTimeout(45000); // controller pairing can legitimately take a while
    QDBusPendingCall call = device.asyncCall(method);
    auto* watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, path, friendlyFailure](QDBusPendingCallWatcher* w) {
        QDBusPendingReply<> reply = *w;
        w->deleteLater();
        refresh();
        if (reply.isError()) {
            const QString friendly = friendlyBtError(reply.error().message());
            if (friendly.isEmpty()) { // e.g. AlreadyExists
                emit deviceOperationFinished(path, true, QString());
                return;
            }
            emit deviceOperationFinished(path, false,
                friendlyFailure.isEmpty() ? friendly : friendlyFailure + QStringLiteral(" ") + friendly);
            return;
        }
        emit deviceOperationFinished(path, true, QString());
    });
}

void BluetoothService::pairDevice(const QString& path)
{
    // Trust first so BlueZ authorizes the HID service and the controller can
    // auto-reconnect on its own later; then Pair, then Connect.
    trustDevice(path);

    QDBusInterface device(kBluez, path, kDeviceIface, QDBusConnection::systemBus());
    device.setTimeout(60000);
    QDBusPendingCall call = device.asyncCall(QStringLiteral("Pair"));
    auto* watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, path](QDBusPendingCallWatcher* w) {
        QDBusPendingReply<> reply = *w;
        w->deleteLater();
        if (reply.isError()) {
            const QString friendly = friendlyBtError(reply.error().message());
            if (!friendly.isEmpty()) {
                refresh();
                emit deviceOperationFinished(path, false, friendly);
                return;
            }
            // AlreadyExists → fall through to Connect
        }
        callDeviceMethod(path, QStringLiteral("Connect"), true, QString());
    });
}

void BluetoothService::connectDevice(const QString& path)
{
    callDeviceMethod(path, QStringLiteral("Connect"), true, QString());
}

void BluetoothService::disconnectDevice(const QString& path)
{
    callDeviceMethod(path, QStringLiteral("Disconnect"), false, QString());
}

void BluetoothService::forgetDevice(const QString& path)
{
    if (m_adapterPath.isEmpty())
        return;
    QDBusInterface adapter(kBluez, m_adapterPath, kAdapterIface, QDBusConnection::systemBus());
    QDBusPendingCall call = adapter.asyncCall(QStringLiteral("RemoveDevice"),
                                              QVariant::fromValue(QDBusObjectPath(path)));
    auto* watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, path](QDBusPendingCallWatcher* w) {
        w->deleteLater();
        refresh();
        emit deviceOperationFinished(path, true, QString());
    });
}

void BluetoothService::reconnectControllers()
{
    for (const auto& v : m_devices) {
        const auto m = v.toMap();
        if (m[QStringLiteral("paired")].toBool() &&
            m[QStringLiteral("isController")].toBool() &&
            !m[QStringLiteral("connected")].toBool()) {
            QDBusInterface device(kBluez, m[QStringLiteral("path")].toString(),
                                  kDeviceIface, QDBusConnection::systemBus());
            device.asyncCall(QStringLiteral("Connect"));
        }
    }
}

void BluetoothService::startControllerAutoConnect()
{
    m_autoPairAttempted.clear();

    if (!m_adapterPath.isEmpty() && !m_powered)
        setPowered(true);

    reconnectControllers();
    startScan();

    if (!m_autoConnectTimer.isActive()) {
        connect(&m_autoConnectTimer, &QTimer::timeout,
                this, &BluetoothService::autoConnectTick, Qt::UniqueConnection);
        m_autoConnectTimer.setInterval(2500);
        m_autoConnectTimer.start();
    }
}

void BluetoothService::stopControllerAutoConnect()
{
    m_autoConnectTimer.stop();
    stopScan();
}

void BluetoothService::autoConnectTick()
{
    // Keep known controllers reconnecting, and auto-pair any freshly
    // discovered controller sitting in pairing mode. We only ever auto-pair
    // devices that look like game controllers, and only once each, so a
    // neighbour's phone won't get grabbed and a failed attempt won't loop.
    for (const auto& v : m_devices) {
        const auto m = v.toMap();
        if (!m[QStringLiteral("isController")].toBool())
            continue;

        const QString path = m[QStringLiteral("path")].toString();
        const bool paired = m[QStringLiteral("paired")].toBool();
        const bool connected = m[QStringLiteral("connected")].toBool();

        if (connected)
            continue;

        if (paired) {
            // Known controller that dropped — nudge it back.
            QDBusInterface device(kBluez, path, kDeviceIface, QDBusConnection::systemBus());
            device.asyncCall(QStringLiteral("Connect"));
        }
        else if (!m_autoPairAttempted.contains(path)) {
            m_autoPairAttempted.insert(path);
            pairDevice(path);
        }
    }
}

#include "bluetoothservice.moc"
