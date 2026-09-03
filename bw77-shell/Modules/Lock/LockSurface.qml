import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.Config
import qs.Common
import qs.Services
import qs.Modules.Wallpaper

/*
 * Session lock. Uses the ext-session-lock protocol, so the compositor keeps the
 * surface on top and blocks input to everything else even if the shell crashes
 * mid-authentication.
 */
WlSessionLock {
    id: lock
    locked: Shell.lockOpen

    property string errorText: ""
    property bool authenticating: false

    WlSessionLockSurface {
        id: surface
        color: "transparent"

        // Shares the desktop's wallpaper surface, so colour mode and gradients
        // appear on the lock screen too rather than only images.
        WallpaperSurface {
            anchors.fill: parent
            visible: !Settings.lock.blurWallpaper
            src: Wallpapers.current
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bgDeep, Settings.lock.blurWallpaper ? 0.94 : 0.7)
        }

        Scanlines { drift: true; anchors.fill: parent; strength: Settings.fx.scanlineOpacity * 2 }

        Column {
            anchors.centerIn: parent
            spacing: Theme.space6

            GlitchText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, Settings.lock.clockFormat)
                role: "headline"
                fontSize: Theme.fontHuge * 2
                color: Theme.accent
            }

            CyberText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd dd MMMM")
                role: "label"
                color: Theme.textDim
            }

            Panel {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 420
                height: 140
                emphasis: lock.errorText !== "" ? "alert" : "normal"
                serialSeed: "lock"
                padding: Theme.space4

                Column {
                    anchors.fill: parent
                    spacing: Theme.space3

                    CyberText {
                        text: Quickshell.env("USER")
                        role: "label"
                        color: Theme.danger
                    }

                    NotchRect {
                        width: parent.width
                        height: 38
                        fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                        strokeColor: password.activeFocus ? Theme.accent : Theme.border
                        notch: Theme.notchSmall

                        TextInput {
                            id: password
                            anchors.fill: parent
                            anchors.margins: Theme.space3
                            verticalAlignment: Text.AlignVCenter
                            focus: true
                            echoMode: TextInput.Password
                            passwordCharacter: "\u25AC"
                            enabled: !lock.authenticating
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontBase

                            onAccepted: {
                                if (text === "") return;
                                lock.errorText = "";
                                lock.authenticating = true;
                                pam.start();
                            }
                        }
                    }

                    CyberText {
                        text: lock.authenticating ? "Checking\u2026"
                            : (lock.errorText !== "" ? lock.errorText : "Enter your password")
                        role: "micro"
                        caps: false
                        color: lock.errorText !== "" ? Theme.danger : Theme.textMuted
                    }
                }
            }
        }

        SystemClock { id: clock; precision: SystemClock.Minutes }

        PamContext {
            id: pam
            config: "login"

            onPamMessage: {
                if (responseRequired) respond(password.text);
            }

            onCompleted: (result) => {
                lock.authenticating = false;
                if (result === PamResult.Success) {
                    password.text = "";
                    Shell.lockOpen = false;
                } else {
                    lock.errorText = "Incorrect password. Try again.";
                    password.text = "";
                    shake.start();
                }
            }
        }

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: surface; property: "x"; to: 6; duration: 40 }
            NumberAnimation { target: surface; property: "x"; to: -6; duration: 40 }
            NumberAnimation { target: surface; property: "x"; to: 0; duration: 40 }
        }
    }
}
