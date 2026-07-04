#pragma once

#include <QObject>

// Watches what the user is actually driving the shell with and reacts to it:
//
//   * pointerActive       — a real mouse moved recently. When it goes false
//                           (any key/controller press) the hardware cursor is
//                           blanked; a mouse move brings it back. Combined with
//                           EGLFS only drawing a cursor when a mouse exists,
//                           this hides the pointer with no mouse AND right after
//                           a controller input. (bug 20)
//   * physicalKeyboard    — the last text input came from a real keyboard, so
//                           the on-screen keyboard can step aside. A synthetic
//                           controller/CEC key flips it back off, which brings
//                           the on-screen keyboard back. (bug 21)
//   * lastInput           — "mouse" | "keyboard" | "gamepad", for anything that
//                           just wants to know the current input style.
//
// It works by filtering the application's input events. Real hardware key/mouse
// events are spontaneous; the SDL gamepad and CEC remote synthesize key events
// (posted, non-spontaneous, and carrying no text), so the two are told apart
// without any device enumeration.
class InputService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool pointerActive READ pointerActive NOTIFY pointerActiveChanged)
    Q_PROPERTY(bool physicalKeyboard READ physicalKeyboard NOTIFY physicalKeyboardChanged)
    Q_PROPERTY(QString lastInput READ lastInput NOTIFY lastInputChanged)

public:
    explicit InputService(QObject* parent = nullptr);

    bool pointerActive() const { return m_pointerActive; }
    bool physicalKeyboard() const { return m_physicalKeyboard; }
    QString lastInput() const { return m_lastInput; }

signals:
    void pointerActiveChanged();
    void physicalKeyboardChanged();
    void lastInputChanged();

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    void setPointerActive(bool active);
    void setPhysicalKeyboard(bool physical);
    void setLastInput(const QString& source);
    void applyCursor();

    bool m_pointerActive = true;
    bool m_physicalKeyboard = false;
    bool m_cursorHidden = false;
    QString m_lastInput = QStringLiteral("gamepad");
};
