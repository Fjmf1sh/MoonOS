pragma Singleton
import QtQuick 2.15

// Central handle for the icon font used by MIcon. The Material Icons TTF is
// installed system-wide by the image build (see os-image .../02-build-shell)
// and resolved by fontconfig via its family name, so no font asset has to be
// embedded in the binary. Everything reads Icons.family in one place, so the
// icon set can be swapped by changing this single string.
QtObject {
    readonly property string family: "Material Icons"
}
