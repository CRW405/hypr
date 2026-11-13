import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../common"
import "../../theme" as Theme

// Controls live in MediaControls.qml, not here.
RowLayout {
    id: root

    property color textColor: Theme.Theme.fg
    property color mutedColor: Theme.Theme.muted
    property int fontSize: Theme.Theme.fontSize
    property int scrollWidth: 160
    readonly property var activePlayer: {
        const players = Mpris.players.values;
        if (!players || players.length === 0)
            return null;

        const playing = players.find((p) => {
            return p.playbackState === MprisPlaybackState.Playing;
        });
        return playing || players[0];
    }

    spacing: Theme.Theme.gap
    visible: activePlayer !== null

    StyledText {
        text: root.activePlayer && root.activePlayer.isPlaying ? "[>>]" : "[||]"
        textColor: root.textColor
        fontSize: root.fontSize
    }

    ScrollingText {
        maxWidth: root.scrollWidth
        textColor: root.textColor
        fontSize: root.fontSize
        text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown") + " — " + (root.activePlayer.trackArtist || "Unknown") : ""
    }

}
