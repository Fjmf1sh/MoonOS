#pragma once

#include <QObject>
#include <QSet>
#include <QTimer>
#include <QVariantList>

// Native Bluetooth controller management over the BlueZ D-Bus API (org.bluez).
//
// devices: everything BlueZ currently knows about, controllers sorted first.
// Each entry: { path, name, address, icon, paired, connected, trusted,
//               battery (-1 if unknown), isController }
class BluetoothService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY stateChanged)
    Q_PROPERTY(bool powered READ powered NOTIFY stateChanged)
    Q_PROPERTY(bool discovering READ discovering NOTIFY stateChanged)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(int connectedControllerCount READ connectedControllerCount NOTIFY devicesChanged)

public:
    explicit BluetoothService(QObject* parent = nullptr);
    ~BluetoothService() override;

    bool available() const { return !m_adapterPath.isEmpty(); }
    bool powered() const { return m_powered; }
    bool discovering() const { return m_discovering; }
    QVariantList devices() const { return m_devices; }
    int connectedControllerCount() const;

    Q_INVOKABLE void setPowered(bool on);
    Q_INVOKABLE void startScan();
    Q_INVOKABLE void stopScan();
    Q_INVOKABLE void refresh();

    // All async; result arrives via deviceOperationFinished.
    Q_INVOKABLE void pairDevice(const QString& path);
    Q_INVOKABLE void connectDevice(const QString& path);
    Q_INVOKABLE void disconnectDevice(const QString& path);
    Q_INVOKABLE void forgetDevice(const QString& path);

    // Try to reconnect every paired+trusted controller (used at boot).
    Q_INVOKABLE void reconnectControllers();

    // First-boot onboarding: power on, scan, reconnect known controllers, and
    // auto-pair any *new* controller found in pairing mode — so the user only
    // has to hold their controller's pair button, no navigation required.
    // Safe to call repeatedly; each device is only attempted once per session.
    Q_INVOKABLE void startControllerAutoConnect();
    Q_INVOKABLE void stopControllerAutoConnect();

signals:
    void stateChanged();
    void devicesChanged();
    void deviceOperationFinished(const QString& path, bool ok, const QString& errorMessage);

private:
    void findAdapter();
    void registerAgent();
    void refreshAdapterState();
    void trustDevice(const QString& path);
    void callDeviceMethod(const QString& path, const QString& method,
                          bool trustFirst, const QString& friendlyFailure);

    void autoConnectTick();

    QString m_adapterPath;
    bool m_powered = false;
    bool m_discovering = false;
    QVariantList m_devices;
    QObject* m_agent = nullptr;
    QTimer m_pollTimer;
    QTimer m_autoConnectTimer;
    QSet<QString> m_autoPairAttempted; // device paths we've already tried
};
