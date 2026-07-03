#include "moonregister.h"

#include "moonsettings.h"
#include "networkservice.h"
#include "bluetoothservice.h"
#include "displayservice.h"
#include "moonsystem.h"
#include "cecservice.h"

#include <QQmlApplicationEngine>
#include <QQmlContext>

namespace Moon {

void registerTypes(QQmlApplicationEngine* engine)
{
    auto* settings  = new MoonSettings(engine);
    auto* network   = new NetworkService(engine);
    auto* bluetooth = new BluetoothService(engine);
    auto* display   = new DisplayService(settings, engine);
    auto* system    = new MoonSystem(settings, engine);
    auto* cec       = new CecService(settings, engine);

    qmlRegisterSingletonInstance("MoonOS", 1, 0, "MoonSettings",  settings);
    qmlRegisterSingletonInstance("MoonOS", 1, 0, "NetworkService", network);
    qmlRegisterSingletonInstance("MoonOS", 1, 0, "BluetoothService", bluetooth);
    qmlRegisterSingletonInstance("MoonOS", 1, 0, "DisplayService", display);
    qmlRegisterSingletonInstance("MoonOS", 1, 0, "MoonSystem", system);
    qmlRegisterSingletonInstance("MoonOS", 1, 0, "CecService", cec);

    // Apply the persisted audio output before any stream starts. SDL's ALSA
    // backend reads AUDIODEV when the audio device is opened at stream start.
    display->applySavedAudioDevice();

    // Bring the TV out of standby and claim the active HDMI input on boot.
    if (settings->cecEnabled())
        cec->powerOnTv();

    // Nudge already-paired controllers to reconnect at startup so they work
    // the moment the home screen appears (the wizard handles first-time
    // pairing; this covers every boot after that).
    bluetooth->reconnectControllers();
}

} // namespace Moon
