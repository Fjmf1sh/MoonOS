#include "displayservice.h"
#include "moonsettings.h"

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QScreen>
#include <QTextStream>

#ifdef HAVE_LIBDRM
#include <fcntl.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>
#endif

DisplayService::DisplayService(MoonSettings* settings, QObject* parent)
    : QObject(parent), m_settings(settings)
{
    refresh();
}

QString DisplayService::kmsConfigPath() const
{
    // Write the staged KMS config into the shell-owned, persistent state dir
    // (/var/lib/moonos). The old /etc/moonos location is root-owned, so the
    // unprivileged "moon" user could not write it — the resolution change
    // silently failed to save. start-shell.sh reads this same path on restart.
    return qEnvironmentVariable("MOONOS_KMS_CONFIG",
                                MoonSettings::stateDir() + QStringLiteral("/eglfs-kms.json"));
}

void DisplayService::refresh()
{
    enumerateDrmModes();
    enumerateAudioCards();

    // Current mode from the live Qt screen
    if (auto* screen = QGuiApplication::primaryScreen()) {
        m_currentMode = QStringLiteral("%1x%2@%3")
                            .arg(screen->size().width())
                            .arg(screen->size().height())
                            .arg(qRound(screen->refreshRate()));
    }

    // Pending mode from a previously staged KMS config
    m_pendingMode.clear();
    QFile f(kmsConfigPath());
    if (f.open(QIODevice::ReadOnly)) {
        const auto doc = QJsonDocument::fromJson(f.readAll());
        const auto outputs = doc.object().value(QStringLiteral("outputs")).toArray();
        if (!outputs.isEmpty())
            m_pendingMode = outputs.first().toObject().value(QStringLiteral("mode")).toString();
    }
    if (m_pendingMode == m_currentMode)
        m_pendingMode.clear();

    emit modesChanged();
    emit pendingModeChanged();
}

void DisplayService::enumerateDrmModes()
{
    m_modes.clear();

#ifdef HAVE_LIBDRM
    for (int cardNum = 0; cardNum < 4 && m_modes.isEmpty(); cardNum++) {
        const QString devPath = QStringLiteral("/dev/dri/card%1").arg(cardNum);
        int fd = open(devPath.toLocal8Bit().constData(), O_RDWR | O_CLOEXEC);
        if (fd < 0)
            continue;

        drmModeRes* res = drmModeGetResources(fd);
        if (!res) {
            close(fd);
            continue; // render-only node (e.g. v3d on Pi)
        }

        for (int i = 0; i < res->count_connectors; i++) {
            drmModeConnector* conn = drmModeGetConnector(fd, res->connectors[i]);
            if (!conn)
                continue;
            if (conn->connection == DRM_MODE_CONNECTED && conn->count_modes > 0) {
                // Qt EGLFS names connectors "<TYPE><type_id>", e.g. HDMI1
                if (conn->connector_type == DRM_MODE_CONNECTOR_HDMIA)
                    m_drmOutputName = QStringLiteral("HDMI%1").arg(conn->connector_type_id);

                for (int m = 0; m < conn->count_modes; m++) {
                    const drmModeModeInfo& mi = conn->modes[m];
                    const QString mode = QStringLiteral("%1x%2@%3")
                                             .arg(mi.hdisplay).arg(mi.vdisplay).arg(mi.vrefresh);
                    if (!m_modes.contains(mode))
                        m_modes.append(mode);
                }
                m_drmDevice = devPath;
            }
            drmModeFreeConnector(conn);
        }
        drmModeFreeResources(res);
        close(fd);
    }
#endif

    // Fallback: /sys/class/drm (no refresh rates — assume 60)
    if (m_modes.isEmpty()) {
        QDir drm(QStringLiteral("/sys/class/drm"));
        for (const QString& entry : drm.entryList({QStringLiteral("card*-HDMI-A-*")}, QDir::Dirs)) {
            QFile status(drm.filePath(entry + QStringLiteral("/status")));
            if (!status.open(QIODevice::ReadOnly) ||
                !QString::fromLatin1(status.readAll()).startsWith(QStringLiteral("connected")))
                continue;
            QFile modes(drm.filePath(entry + QStringLiteral("/modes")));
            if (modes.open(QIODevice::ReadOnly)) {
                QTextStream in(&modes);
                QString line;
                while (in.readLineInto(&line)) {
                    const QString mode = line.trimmed() + QStringLiteral("@60");
                    if (!line.trimmed().isEmpty() && !m_modes.contains(mode))
                        m_modes.append(mode);
                }
            }
        }
    }
}

bool DisplayService::setMode(const QString& mode)
{
    // {"device": "...", "outputs": [{"name": "HDMI1", "mode": "1920x1080@60"}]}
    QJsonObject output;
    output[QStringLiteral("name")] = m_drmOutputName.isEmpty() ? QStringLiteral("HDMI1")
                                                               : m_drmOutputName;
    output[QStringLiteral("mode")] = mode;

    QJsonObject root;
    if (!m_drmDevice.isEmpty())
        root[QStringLiteral("device")] = m_drmDevice;
    root[QStringLiteral("outputs")] = QJsonArray{output};

    QSaveFile f(kmsConfigPath());
    if (!f.open(QIODevice::WriteOnly))
        return false;
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    if (!f.commit())
        return false;

    m_pendingMode = mode;
    emit pendingModeChanged();
    return true;
}

void DisplayService::clearModeOverride()
{
    QFile::remove(kmsConfigPath());
    m_pendingMode.clear();
    emit pendingModeChanged();
}

void DisplayService::enumerateAudioCards()
{
    m_audioOutputs.clear();

    // /proc/asound/cards format:
    //  0 [vc4hdmi0       ]: vc4-hdmi - vc4-hdmi-0
    //                       vc4-hdmi-0
    QFile cards(QStringLiteral("/proc/asound/cards"));
    if (cards.open(QIODevice::ReadOnly)) {
        QTextStream in(&cards);
        QString line;
        while (in.readLineInto(&line)) {
            const int open = line.indexOf(QLatin1Char('['));
            const int closeBr = line.indexOf(QLatin1Char(']'));
            if (open < 0 || closeBr <= open)
                continue;
            const QString id = line.mid(open + 1, closeBr - open - 1).trimmed();
            QString desc = line.mid(closeBr + 2).trimmed();
            if (desc.startsWith(QLatin1Char(':')))
                desc = desc.mid(1).trimmed();

            QString friendly = desc;
            if (id.contains(QStringLiteral("hdmi"), Qt::CaseInsensitive))
                friendly = QStringLiteral("HDMI (%1)").arg(id);
            else if (id.contains(QStringLiteral("Headphones"), Qt::CaseInsensitive))
                friendly = QStringLiteral("Headphone jack");

            QVariantMap entry;
            entry[QStringLiteral("id")] = id;
            entry[QStringLiteral("name")] = friendly;
            entry[QStringLiteral("device")] = QStringLiteral("default:CARD=%1").arg(id);
            m_audioOutputs.append(entry);
        }
    }

    emit audioOutputsChanged();
}

void DisplayService::setAudioOutput(const QString& device)
{
    m_settings->setAudioDevice(device);
    applySavedAudioDevice();
}

void DisplayService::applySavedAudioDevice()
{
    const QString device = m_settings->audioDevice();
    if (device.isEmpty())
        return;
    // SDL's ALSA backend reads AUDIODEV each time the stream session opens
    // the audio device, so a process-level setenv is all that is needed.
    qputenv("AUDIODEV", device.toUtf8());
}
