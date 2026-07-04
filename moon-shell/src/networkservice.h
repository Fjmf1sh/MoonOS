#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>

class QDBusObjectPath;

// Native Wi-Fi / Ethernet management over the NetworkManager D-Bus API
// (org.freedesktop.NetworkManager). No nmcli shell-outs.
//
// networks:      current scan results, deduped by SSID, strongest first.
//                Each entry: { ssid, strength (0-100), secured, saved, active }
// savedNetworks: SSIDs with stored NetworkManager profiles.
class NetworkService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool wifiAvailable READ wifiAvailable NOTIFY stateChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY stateChanged)
    Q_PROPERTY(bool ethernetConnected READ ethernetConnected NOTIFY stateChanged)
    Q_PROPERTY(bool online READ online NOTIFY stateChanged)
    Q_PROPERTY(QString ipAddress READ ipAddress NOTIFY stateChanged)
    Q_PROPERTY(QString gateway READ gateway NOTIFY stateChanged)
    Q_PROPERTY(QStringList dnsServers READ dnsServers NOTIFY stateChanged)
    Q_PROPERTY(QString macAddress READ macAddress NOTIFY stateChanged)
    Q_PROPERTY(QString currentSsid READ currentSsid NOTIFY stateChanged)
    Q_PROPERTY(int signalStrength READ signalStrength NOTIFY stateChanged)
    Q_PROPERTY(QVariantList networks READ networks NOTIFY networksChanged)
    Q_PROPERTY(QStringList savedNetworks READ savedNetworks NOTIFY networksChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool connecting READ connecting NOTIFY connectingChanged)

public:
    explicit NetworkService(QObject* parent = nullptr);

    bool wifiAvailable() const { return !m_wifiDevice.isEmpty(); }
    bool wifiEnabled() const { return m_wifiEnabled; }
    bool ethernetConnected() const { return m_ethernetConnected; }
    bool online() const { return m_online; }
    QString ipAddress() const { return m_ipAddress; }
    QString gateway() const { return m_gateway; }
    QStringList dnsServers() const { return m_dnsServers; }
    QString macAddress() const { return m_macAddress; }
    QString currentSsid() const { return m_currentSsid; }
    int signalStrength() const { return m_signalStrength; }
    QVariantList networks() const { return m_networks; }
    QStringList savedNetworks() const { return m_savedSsids; }
    bool scanning() const { return m_scanning; }
    bool connecting() const { return m_connecting; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void scan();
    Q_INVOKABLE void setWifiEnabled(bool enabled);
    Q_INVOKABLE void connectToNetwork(const QString& ssid, const QString& password);
    Q_INVOKABLE void connectToSaved(const QString& ssid);
    Q_INVOKABLE void forgetNetwork(const QString& ssid);

signals:
    void stateChanged();
    void networksChanged();
    void scanningChanged();
    void connectingChanged();
    // ok=false carries a human-readable (already softened) error message
    void connectFinished(bool ok, const QString& errorMessage);

private:
    void findDevices();
    void refreshState();
    void refreshAccessPoints();
    void refreshSavedConnections();
    QString accessPointPathForSsid(const QString& ssid) const;
    QString savedConnectionPathForSsid(const QString& ssid) const;
    void watchActivation(const QDBusObjectPath& activeConnPath);
    void setConnecting(bool value);

    QString m_wifiDevice;      // D-Bus object path of the first Wi-Fi device
    QString m_ethernetDevice;  // D-Bus object path of the first Ethernet device
    bool m_wifiEnabled = false;
    bool m_ethernetConnected = false;
    bool m_online = false;
    QString m_ipAddress;
    QString m_gateway;
    QStringList m_dnsServers;
    QString m_macAddress;
    QString m_currentSsid;
    int m_signalStrength = 0;
    QVariantList m_networks;
    QStringList m_savedSsids;
    QHash<QString, QString> m_apPathBySsid;    // strongest AP per SSID
    QHash<QString, QString> m_savedPathBySsid; // settings connection per SSID
    bool m_scanning = false;
    bool m_connecting = false;
    QTimer m_pollTimer;
};
