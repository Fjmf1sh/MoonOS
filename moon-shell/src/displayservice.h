#pragma once

#include <QObject>
#include <QVariantList>

class MoonSettings;

// HDMI display and audio-output management for the KMS/EGLFS session.
//
// Modes are enumerated straight from the DRM connectors (libdrm). Applying a
// mode writes the Qt EGLFS KMS config into Moon OS state, which the shell
// reads on its next start — mode changes take effect after a UI
// restart, which the settings screen offers ("Apply & restart interface").
//
// Audio outputs are enumerated from /proc/asound/cards; the selection is
// exported as AUDIODEV for SDL's ALSA backend (used by the stream session).
class DisplayService : public QObject
{
    Q_OBJECT
    // Modes like "1920x1080@60", preferred/current first
    Q_PROPERTY(QStringList modes READ modes NOTIFY modesChanged)
    Q_PROPERTY(QString currentMode READ currentMode NOTIFY modesChanged)
    Q_PROPERTY(QString pendingMode READ pendingMode NOTIFY pendingModeChanged)
    // [{ id, name, device }] e.g. { "vc4hdmi0", "vc4-hdmi-0", "default:CARD=vc4hdmi0" }
    Q_PROPERTY(QVariantList audioOutputs READ audioOutputs NOTIFY audioOutputsChanged)

public:
    explicit DisplayService(MoonSettings* settings, QObject* parent = nullptr);

    QStringList modes() const { return m_modes; }
    QString currentMode() const { return m_currentMode; }
    QString pendingMode() const { return m_pendingMode; }
    QVariantList audioOutputs() const { return m_audioOutputs; }

    Q_INVOKABLE void refresh();

    // Stages a mode into the EGLFS KMS config. Returns false if it could not
    // be written.
    Q_INVOKABLE bool setMode(const QString& mode);
    Q_INVOKABLE void clearModeOverride();

    Q_INVOKABLE void setAudioOutput(const QString& device);
    void applySavedAudioDevice();

signals:
    void modesChanged();
    void pendingModeChanged();
    void audioOutputsChanged();

private:
    void enumerateDrmModes();
    void enumerateAudioCards();
    QString kmsConfigPath() const;
    QString drmOutputName() const { return m_drmOutputName; }

    MoonSettings* m_settings;
    QStringList m_modes;
    QString m_currentMode;
    QString m_pendingMode;
    QString m_drmDevice;     // e.g. /dev/dri/card1
    QString m_drmOutputName; // e.g. HDMI1 (Qt EGLFS naming)
    QVariantList m_audioOutputs;
};
