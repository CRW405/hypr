pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared style tokens (colors/font/radius/spacing) for hyprland.lua and the rofi menus.
// Reads style/style.json live; defaults below only apply until it loads.
QtObject {
	id: root

	property QtObject color: QtObject {
		property color primary: "#5c9dff"
		property color secondary: "#b39dff"
		property color danger: "#ff6b6b"
		property color warning: "#ff5c5c" // Previous orange: #ffcc00
		property color ok: "#4caf50"
		property color active: "#45454e"
		property color inactive: "#6a6a72"
		property color background: "#1c1c1e"
		property color background_light: "#3a3a40"
		property color background_dark: "#2a2a2e"
		property color border: "#6e6e78"
		property color border_light: "#5a6b9c"
		property color border_dark: "#241b40"
		property color text: "#d4d4d8"
		property color text_secondary: "#6a6a72"
		property color text_light: "#ffffff"
		property color text_dark: "#1c1c1e"
	}

	property QtObject font: QtObject {
		property string family: "Monospace"
		property int size: 12
	}

	property int radius: 10

	property QtObject spacing: QtObject {
		property int gap: 5
		property int padding: 10
	}

	property bool _styleErrorNotified: false

	function _reportStyleError(message) {
		if (root._styleErrorNotified)
			return
		root._styleErrorNotified = true
		root._errorNotification.command = [
			"bash",
			Quickshell.shellDir + "/../hypr/scripts/NotifyError.sh",
			"notify",
			"HyprQS configuration error",
			"Could not load style/style.json: " + message
		]
		root._errorNotification.running = true
	}

	property Process _errorNotification: Process {}

	property FileView _file: FileView {
		// Qt.resolvedUrl resolves against Quickshell's virtual -p root, not this
		// file's real path; Quickshell.shellDir keeps this correct regardless of checkout location.
		path: Quickshell.shellDir + "/../style/style.json"
		watchChanges: true
		onFileChanged: reload()
		onLoaded: {
			try {
				root._apply(JSON.parse(root._stripComments(text())))
				root._styleErrorNotified = false
			} catch (e) {
				root._reportStyleError(String(e))
			}
		}
		onLoadFailed: error => root._reportStyleError(String(error))
	}

	// strips // and /* */ comments outside of string literals so style.json can support JSONC
	function _stripComments(s) {
		let out = ""
		let inString = false
		let inLine = false
		let inBlock = false
		for (let i = 0; i < s.length; i++) {
			const c = s[i]
			const next = s[i + 1]
			if (inLine) {
				if (c === "\n") { inLine = false; out += c }
				continue
			}
			if (inBlock) {
				if (c === "*" && next === "/") { inBlock = false; i++ }
				continue
			}
			if (inString) {
				out += c
				if (c === "\\") { out += next; i++ }
				else if (c === "\"") inString = false
				continue
			}
			if (c === "\"") { inString = true; out += c }
			else if (c === "/" && next === "/") { inLine = true; i++ }
			else if (c === "/" && next === "*") { inBlock = true; i++ }
			else out += c
		}
		return out
	}

	function _apply(data) {
		if (data.color) {
			for (const key in data.color) {
				if (root.color.hasOwnProperty(key)) {
					root.color[key] = "#" + data.color[key]
				}
			}
		}
		if (data.font) {
			if (data.font.family)
				root.font.family = data.font.family
			if (data.font.size)
				root.font.size = data.font.size
		}
		if (data.radius !== undefined)
			root.radius = data.radius
		if (data.spacing) {
			if (data.spacing.gap !== undefined)
				root.spacing.gap = data.spacing.gap
			if (data.spacing.padding !== undefined)
				root.spacing.padding = data.spacing.padding
		}
	}
}
