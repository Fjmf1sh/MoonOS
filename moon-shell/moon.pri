# moon.pri — Moon OS integration for the moonlight-qt fork.
#
# This file is included from app/app.pro (see fork/0001-moon-os-fork.patch).
# It turns the upstream Moonlight build into the Moon Shell binary:
#   * renames the target to moon-shell
#   * compiles the Moon OS services (network, bluetooth, display, power, CEC)
#   * bundles the Moon Shell QML frontend which replaces qrc:/gui entirely
#
# Everything lives under app/moon/ inside the moonlight-qt tree; the
# prepare-fork.sh script copies this directory in from the Moon OS repo.

TARGET = moon-shell

DEFINES += MOON_OS
QT += dbus

INCLUDEPATH += $$PWD

SOURCES += \
    $$PWD/src/moonregister.cpp \
    $$PWD/src/moonsettings.cpp \
    $$PWD/src/networkservice.cpp \
    $$PWD/src/bluetoothservice.cpp \
    $$PWD/src/displayservice.cpp \
    $$PWD/src/moonsystem.cpp \
    $$PWD/src/cecservice.cpp \
    $$PWD/src/inputservice.cpp

HEADERS += \
    $$PWD/src/moonregister.h \
    $$PWD/src/moonsettings.h \
    $$PWD/src/networkservice.h \
    $$PWD/src/bluetoothservice.h \
    $$PWD/src/displayservice.h \
    $$PWD/src/moonsystem.h \
    $$PWD/src/cecservice.h \
    $$PWD/src/inputservice.h

RESOURCES += $$PWD/moon.qrc

# HDMI-CEC support (TV remote control) via libcec. Optional at build time so
# the fork still builds on dev machines without libcec; the Moon OS image
# always ships it.
packagesExist(libcec) {
    PKGCONFIG += libcec
    DEFINES += HAVE_LIBCEC
}

# Display mode enumeration uses libdrm directly (already a moonlight dependency
# on the KMS render path, but declare it explicitly since we call it ourselves).
packagesExist(libdrm) {
    PKGCONFIG += libdrm
    DEFINES += HAVE_LIBDRM
}
