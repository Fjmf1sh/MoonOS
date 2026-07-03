#pragma once

#include <QObject>

class MoonSettings;

// HDMI-CEC TV remote support via libcec.
//
// The TV remote's navigation cluster is translated into the same Qt key
// events the gamepad navigation produces, so the whole shell is drivable
// from the TV remote with zero extra UI code:
//   Up/Down/Left/Right -> arrow keys
//   Select/OK          -> Return
//   Back/Exit/Return   -> Escape
//
// libcec's adapter connection is opened on a worker thread (it blocks for a
// few seconds) and key callbacks are marshalled onto the Qt main thread.
// When libcec is not present at build time this compiles to an inert stub
// with available == false.
class CecService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit CecService(MoonSettings* settings, QObject* parent = nullptr);
    ~CecService() override;

    bool available() const { return m_available; }

    // "One touch play": wake the TV and switch it to our HDMI input.
    Q_INVOKABLE void powerOnTv();
    Q_INVOKABLE void standbyTv();

    // Invoked (queued) from the libcec callback thread.
    Q_INVOKABLE void handleCecKey(int cecCode, bool isRelease);

signals:
    void availableChanged();

private:
    void openAdapter();
    void closeAdapter();
    void postKey(int qtKey, bool isRelease);

    MoonSettings* m_settings;
    bool m_available = false;
    void* m_adapter = nullptr; // CEC::ICECAdapter* (opaque to keep the header libcec-free)
    void* m_callbacks = nullptr;
    void* m_config = nullptr;
};
