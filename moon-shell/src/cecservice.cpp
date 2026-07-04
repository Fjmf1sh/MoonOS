#include "cecservice.h"
#include "moonsettings.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QThread>
#include <QWindow>

#ifdef HAVE_LIBCEC
#include <libcec/cec.h>
using namespace CEC;

namespace {

// libcec invokes this on its own thread; hop to the Qt main thread.
void onCecKeyPress(void* param, const cec_keypress* key)
{
    auto* self = static_cast<CecService*>(param);
    QMetaObject::invokeMethod(self, "handleCecKey", Qt::QueuedConnection,
                              Q_ARG(int, (int)key->keycode),
                              Q_ARG(bool, key->duration > 0));
}

// Watch the CEC bus for the TV powering off (Standby) and for our HDMI input
// being made the active source (Set Stream Path / Active Source), so the
// console can follow the TV's power state.
void onCecCommand(void* param, const cec_command* command)
{
    auto* self = static_cast<CecService*>(param);
    int pa = -1;
    if ((command->opcode == CEC_OPCODE_SET_STREAM_PATH ||
         command->opcode == CEC_OPCODE_ACTIVE_SOURCE) &&
        command->parameters.size >= 2) {
        pa = (command->parameters.data[0] << 8) | command->parameters.data[1];
    }
    QMetaObject::invokeMethod(self, "handleCecCommand", Qt::QueuedConnection,
                              Q_ARG(int, (int)command->opcode),
                              Q_ARG(int, pa));
}

} // namespace
#endif

CecService::CecService(MoonSettings* settings, QObject* parent)
    : QObject(parent), m_settings(settings)
{
#ifdef HAVE_LIBCEC
    if (m_settings->cecEnabled())
        openAdapter();

    connect(m_settings, &MoonSettings::cecEnabledChanged, this, [this] {
        if (m_settings->cecEnabled())
            openAdapter();
        else
            closeAdapter();
    });
#endif
}

CecService::~CecService()
{
    closeAdapter();
}

void CecService::openAdapter()
{
#ifdef HAVE_LIBCEC
    if (m_adapter)
        return;

    auto* callbacks = new ICECCallbacks();
    callbacks->Clear();
    callbacks->keyPress = &onCecKeyPress;
    callbacks->commandReceived = &onCecCommand;

    auto* config = new libcec_configuration();
    config->Clear();
    qsnprintf(config->strDeviceName, sizeof(config->strDeviceName), "Moon OS");
    config->clientVersion = LIBCEC_VERSION_CURRENT;
    config->deviceTypes.Add(CEC_DEVICE_TYPE_PLAYBACK_DEVICE);
    config->bActivateSource = 0; // we call SetActiveSource explicitly
    config->callbacks = callbacks;
    config->callbackParam = this;

    m_callbacks = callbacks;
    m_config = config;

    // DetectAdapters/Open block for several seconds on the Pi's kernel CEC
    // device — never on the UI thread.
    QThread* worker = QThread::create([this, config] {
        ICECAdapter* adapter = CECInitialise(config);
        if (!adapter)
            return;
        adapter->InitVideoStandalone();

        cec_adapter_descriptor devices[8];
        const int8_t found = adapter->DetectAdapters(devices, 8, nullptr, true);
        if (found <= 0 || !adapter->Open(devices[0].strComName)) {
            CECDestroy(adapter);
            return;
        }

        // Our own HDMI physical address, used to recognise when the TV routes
        // back to this console's input.
        const cec_logical_addresses la = adapter->GetLogicalAddresses();
        const int pa = adapter->GetDevicePhysicalAddress(la.primary);

        QMetaObject::invokeMethod(this, [this, adapter, pa] {
            m_adapter = adapter;
            m_physicalAddress = pa;
            m_available = true;
            emit availableChanged();
        }, Qt::QueuedConnection);
    });
    connect(worker, &QThread::finished, worker, &QObject::deleteLater);
    worker->start();
#endif
}

void CecService::closeAdapter()
{
#ifdef HAVE_LIBCEC
    if (m_adapter) {
        auto* adapter = static_cast<ICECAdapter*>(m_adapter);
        adapter->Close();
        CECDestroy(adapter);
        m_adapter = nullptr;
    }
    delete static_cast<ICECCallbacks*>(m_callbacks);
    delete static_cast<libcec_configuration*>(m_config);
    m_callbacks = nullptr;
    m_config = nullptr;
    if (m_available) {
        m_available = false;
        emit availableChanged();
    }
#endif
}

void CecService::powerOnTv()
{
#ifdef HAVE_LIBCEC
    if (!m_adapter) {
        // Adapter may still be opening; retry once it is up.
        connect(this, &CecService::availableChanged, this, [this] {
            if (m_available)
                powerOnTv();
        }, Qt::SingleShotConnection);
        return;
    }
    auto* adapter = static_cast<ICECAdapter*>(m_adapter);
    QThread* worker = QThread::create([adapter] {
        adapter->PowerOnDevices(CECDEVICE_TV);
        adapter->SetActiveSource();
    });
    connect(worker, &QThread::finished, worker, &QObject::deleteLater);
    worker->start();
#endif
}

void CecService::standbyTv()
{
#ifdef HAVE_LIBCEC
    if (!m_adapter)
        return;
    static_cast<ICECAdapter*>(m_adapter)->StandbyDevices(CECDEVICE_TV);
#endif
}

void CecService::handleCecCommand(int opcode, int physicalAddress)
{
#ifdef HAVE_LIBCEC
    // Only follow the TV's power when the user opted in.
    if (!m_settings->tvPowerSync())
        return;

    switch (opcode) {
    case CEC_OPCODE_STANDBY:
        // The TV (or the whole HDMI chain) is powering off.
        emit tvWentToStandby();
        break;
    case CEC_OPCODE_SET_STREAM_PATH:
    case CEC_OPCODE_ACTIVE_SOURCE:
        // The TV switched to an input. If it's ours, come back; if we can't
        // tell (unknown address), assume it's us rather than stay dark.
        if (physicalAddress < 0 || m_physicalAddress < 0 ||
            physicalAddress == m_physicalAddress)
            emit tvSelectedThisInput();
        break;
    default:
        break;
    }
#else
    Q_UNUSED(opcode);
    Q_UNUSED(physicalAddress);
#endif
}

void CecService::postKey(int qtKey, bool isRelease)
{
    QWindow* window = QGuiApplication::focusWindow();
    if (!window)
        return;
    QCoreApplication::postEvent(window,
        new QKeyEvent(isRelease ? QEvent::KeyRelease : QEvent::KeyPress,
                      qtKey, Qt::NoModifier));
}

void CecService::handleCecKey(int cecCode, bool isRelease)
{
#ifdef HAVE_LIBCEC
    int qtKey = 0;
    switch (cecCode) {
    case CEC_USER_CONTROL_CODE_SELECT:       qtKey = Qt::Key_Return; break;
    case CEC_USER_CONTROL_CODE_UP:           qtKey = Qt::Key_Up; break;
    case CEC_USER_CONTROL_CODE_DOWN:         qtKey = Qt::Key_Down; break;
    case CEC_USER_CONTROL_CODE_LEFT:         qtKey = Qt::Key_Left; break;
    case CEC_USER_CONTROL_CODE_RIGHT:        qtKey = Qt::Key_Right; break;
    case CEC_USER_CONTROL_CODE_EXIT:
    case CEC_USER_CONTROL_CODE_ROOT_MENU:
    case CEC_USER_CONTROL_CODE_AN_RETURN:    qtKey = Qt::Key_Escape; break;
    default:
        return; // media keys etc. are ignored in the shell
    }
    postKey(qtKey, isRelease);
#else
    Q_UNUSED(cecCode);
    Q_UNUSED(isRelease);
#endif
}
