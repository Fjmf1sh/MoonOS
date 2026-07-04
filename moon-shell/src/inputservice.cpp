#include "inputservice.h"

#include <QCoreApplication>
#include <QCursor>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QMouseEvent>

InputService::InputService(QObject* parent)
    : QObject(parent)
{
    if (qApp)
        qApp->installEventFilter(this);
}

bool InputService::eventFilter(QObject* watched, QEvent* event)
{
    switch (event->type()) {
    case QEvent::KeyPress: {
        auto* ke = static_cast<QKeyEvent*>(event);
        // Real keyboard events are spontaneous and (for printable keys) carry
        // text. The SDL gamepad pump and the CEC remote post synthetic events,
        // which are non-spontaneous and text-less.
        if (event->spontaneous()) {
            setLastInput(QStringLiteral("keyboard"));
            if (!ke->text().trimmed().isEmpty())
                setPhysicalKeyboard(true);
        } else {
            setLastInput(QStringLiteral("gamepad"));
            setPhysicalKeyboard(false);
        }
        // Any key/controller activity means the user isn't pointing — blank
        // the cursor until the mouse moves again.
        setPointerActive(false);
        break;
    }
    case QEvent::MouseMove:
    case QEvent::MouseButtonPress:
        if (event->spontaneous()) {
            setLastInput(QStringLiteral("mouse"));
            setPointerActive(true);
        }
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}

void InputService::setPointerActive(bool active)
{
    if (m_pointerActive != active) {
        m_pointerActive = active;
        emit pointerActiveChanged();
    }
    applyCursor();
}

void InputService::applyCursor()
{
    // Hide the hardware cursor whenever the pointer is inactive. Track our own
    // push/pop so override cursors never stack up.
    const bool wantHidden = !m_pointerActive;
    if (wantHidden == m_cursorHidden)
        return;
    if (wantHidden)
        QGuiApplication::setOverrideCursor(QCursor(Qt::BlankCursor));
    else
        QGuiApplication::restoreOverrideCursor();
    m_cursorHidden = wantHidden;
}

void InputService::setPhysicalKeyboard(bool physical)
{
    if (m_physicalKeyboard == physical)
        return;
    m_physicalKeyboard = physical;
    emit physicalKeyboardChanged();
}

void InputService::setLastInput(const QString& source)
{
    if (m_lastInput == source)
        return;
    m_lastInput = source;
    emit lastInputChanged();
}
