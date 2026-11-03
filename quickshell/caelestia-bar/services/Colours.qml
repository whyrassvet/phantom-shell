pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Images
import qs.services
import qs.utils

Singleton {
    id: root

    property string scheme
    property string flavour
    readonly property bool light: currentLight
    readonly property color outline: light ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.07)
    property bool currentLight
    readonly property M3Palette palette: current
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property M3Palette current: M3Palette {}
    readonly property Transparency transparency: Transparency {}
    readonly property alias wallLuminance: analyser.luminance

    property bool cooldownPending
    property real lastBaseTransparency
    property string shadowsSchemeData
    property string savedSchemeData

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);
        if (luminance === 0)
            return Qt.rgba(0, 0, 0, a);

        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - transparency.base) * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;

        return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function load(data: string): bool {
        const colours = current;
        let scheme;
        try {
            scheme = JSON.parse(data);
        } catch (error) {
            console.warn("Ignoring invalid phantom-shell colour scheme:", error);
            return false;
        }
        if (!scheme || typeof scheme.colours !== "object" || !scheme.colours || Array.isArray(scheme.colours)) {
            console.warn("Ignoring invalid phantom-shell colour scheme: missing colours object");
            return false;
        }

        root.scheme = typeof scheme.name === "string" ? scheme.name : "";
        flavour = typeof scheme.flavour === "string" ? scheme.flavour : "";
        currentLight = scheme.mode === "light";

        for (const [name, colour] of Object.entries(scheme.colours)) {
            const propName = name.startsWith("term") ? name : `m3${name}`;
            if (colours.hasOwnProperty(propName) && typeof colour === "string" && /^#?(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(colour))
                colours[propName] = colour.startsWith("#") ? colour : `#${colour}`;
        }
        return true;
    }

    function reloadActiveScheme(): void {
        if (shadowsSchemeData && load(shadowsSchemeData))
            return;
        if (savedSchemeData)
            load(savedSchemeData);
    }

    function setMode(mode: string): void {
        Quickshell.execDetached(["caelestia", "scheme", "set", "--notify", "-m", mode]);
    }

    function reloadHyprRules(): void {
        let rule, barRule, trEnabled;
        if (Hypr.usingLua) {
            rule = `eval hl.layer_rule({ match = { namespace = "(caelestia-popouts|phantom-app-launcher)" }, %1 = %2 })`;
            barRule = `eval hl.layer_rule({ match = { namespace = "(caelestia-bar|phantom-corner)" }, %1 = %2 })`;
            trEnabled = transparency.enabled;
        } else {
            rule = "keyword layerrule %1 %2, match:namespace (caelestia-popouts|phantom-app-launcher)";
            barRule = "keyword layerrule %1 %2, match:namespace (caelestia-bar|phantom-corner)";
            trEnabled = transparency.enabled ? 1 : 0;
        }
        // The shared bar surface also contains the hot-corner panels, whose
        // configured opacity can be lower than the bar's transparency base.
        const alpha = Math.max(0, transparency.base - 0.03);
        Hypr.extras.batchMessage([rule.arg("blur").arg(trEnabled), rule.arg("ignore_alpha").arg(alpha), barRule.arg("blur").arg(trEnabled), barRule.arg("ignore_alpha").arg(Math.min(0.1, alpha))]);
    }

    function requestReloadHyprRules(): void {
        if (cooldownTimer.running) {
            root.cooldownPending = true;
        } else {
            root.reloadHyprRules();
            cooldownTimer.restart();
        }
    }

    Component.onCompleted: root.requestReloadHyprRules()

    Connections {
        function onConfigReloaded(): void {
            root.reloadHyprRules();
        }

        target: Hypr
    }

    FileView {
        path: `${Paths.state}/scheme.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.savedSchemeData = text();
            root.reloadActiveScheme();
        }
        onLoadFailed: {
            root.savedSchemeData = "";
            root.reloadActiveScheme();
        }
    }

    // shadows-shell installs its Matugen config in ~/.config/matugen.
    FileView {
        path: `${Paths.home}/.config/matugen/phantom-bar.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.shadowsSchemeData = text();
            root.reloadActiveScheme();
        }
        onLoadFailed: {
            root.shadowsSchemeData = "";
            root.reloadActiveScheme();
        }
    }

    ImageAnalyser {
        id: analyser

        source: Wallpapers.current
    }

    Timer {
        id: cooldownTimer

        interval: 30
        onTriggered: {
            if (root.cooldownPending) {
                root.cooldownPending = false;
                root.reloadHyprRules();
                restart();
            }
        }
    }

    Timer {
        id: cAnimCompleteTimer

        interval: Tokens.anim.durations.expressiveSlowEffects
        onTriggered: root.requestReloadHyprRules()
    }

    component Transparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Math.max(0, Math.min(1, Tokens.transparency.layers))

        onEnabledChanged: {
            if (enabled)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
        }
        onBaseChanged: {
            if (root.lastBaseTransparency > base)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
            root.lastBaseTransparency = base;
        }
    }

    component M3TPalette: QtObject {
        readonly property color m3primary_paletteKeyColor: root.layer(root.palette.m3primary_paletteKeyColor)
        readonly property color m3secondary_paletteKeyColor: root.layer(root.palette.m3secondary_paletteKeyColor)
        readonly property color m3tertiary_paletteKeyColor: root.layer(root.palette.m3tertiary_paletteKeyColor)
        readonly property color m3neutral_paletteKeyColor: root.layer(root.palette.m3neutral_paletteKeyColor)
        readonly property color m3neutral_variant_paletteKeyColor: root.layer(root.palette.m3neutral_variant_paletteKeyColor)
        readonly property color m3background: root.layer(root.palette.m3background, 0)
        readonly property color m3onBackground: root.layer(root.palette.m3onBackground)
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceDim: root.layer(root.palette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(root.palette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.layer(root.palette.m3surfaceContainerLowest)
        readonly property color m3surfaceContainerLow: root.layer(root.palette.m3surfaceContainerLow)
        readonly property color m3surfaceContainer: root.layer(root.palette.m3surfaceContainer)
        readonly property color m3surfaceContainerHigh: root.layer(root.palette.m3surfaceContainerHigh)
        readonly property color m3surfaceContainerHighest: root.layer(root.palette.m3surfaceContainerHighest)
        readonly property color m3onSurface: root.layer(root.palette.m3onSurface)
        readonly property color m3surfaceVariant: root.layer(root.palette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.layer(root.palette.m3onSurfaceVariant)
        readonly property color m3inverseSurface: root.layer(root.palette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.layer(root.palette.m3inverseOnSurface)
        readonly property color m3outline: root.layer(root.palette.m3outline)
        readonly property color m3outlineVariant: root.layer(root.palette.m3outlineVariant)
        readonly property color m3shadow: root.layer(root.palette.m3shadow)
        readonly property color m3scrim: root.layer(root.palette.m3scrim)
        readonly property color m3surfaceTint: root.layer(root.palette.m3surfaceTint)
        readonly property color m3primary: root.layer(root.palette.m3primary)
        readonly property color m3onPrimary: root.layer(root.palette.m3onPrimary)
        readonly property color m3primaryContainer: root.layer(root.palette.m3primaryContainer)
        readonly property color m3onPrimaryContainer: root.layer(root.palette.m3onPrimaryContainer)
        readonly property color m3inversePrimary: root.layer(root.palette.m3inversePrimary)
        readonly property color m3secondary: root.layer(root.palette.m3secondary)
        readonly property color m3onSecondary: root.layer(root.palette.m3onSecondary)
        readonly property color m3secondaryContainer: root.layer(root.palette.m3secondaryContainer)
        readonly property color m3onSecondaryContainer: root.layer(root.palette.m3onSecondaryContainer)
        readonly property color m3tertiary: root.layer(root.palette.m3tertiary)
        readonly property color m3onTertiary: root.layer(root.palette.m3onTertiary)
        readonly property color m3tertiaryContainer: root.layer(root.palette.m3tertiaryContainer)
        readonly property color m3onTertiaryContainer: root.layer(root.palette.m3onTertiaryContainer)
        readonly property color m3error: root.layer(root.palette.m3error)
        readonly property color m3onError: root.layer(root.palette.m3onError)
        readonly property color m3errorContainer: root.layer(root.palette.m3errorContainer)
        readonly property color m3onErrorContainer: root.layer(root.palette.m3onErrorContainer)
        readonly property color m3success: root.layer(root.palette.m3success)
        readonly property color m3onSuccess: root.layer(root.palette.m3onSuccess)
        readonly property color m3successContainer: root.layer(root.palette.m3successContainer)
        readonly property color m3onSuccessContainer: root.layer(root.palette.m3onSuccessContainer)
        readonly property color m3primaryFixed: root.layer(root.palette.m3primaryFixed)
        readonly property color m3primaryFixedDim: root.layer(root.palette.m3primaryFixedDim)
        readonly property color m3onPrimaryFixed: root.layer(root.palette.m3onPrimaryFixed)
        readonly property color m3onPrimaryFixedVariant: root.layer(root.palette.m3onPrimaryFixedVariant)
        readonly property color m3secondaryFixed: root.layer(root.palette.m3secondaryFixed)
        readonly property color m3secondaryFixedDim: root.layer(root.palette.m3secondaryFixedDim)
        readonly property color m3onSecondaryFixed: root.layer(root.palette.m3onSecondaryFixed)
        readonly property color m3onSecondaryFixedVariant: root.layer(root.palette.m3onSecondaryFixedVariant)
        readonly property color m3tertiaryFixed: root.layer(root.palette.m3tertiaryFixed)
        readonly property color m3tertiaryFixedDim: root.layer(root.palette.m3tertiaryFixedDim)
        readonly property color m3onTertiaryFixed: root.layer(root.palette.m3onTertiaryFixed)
        readonly property color m3onTertiaryFixedVariant: root.layer(root.palette.m3onTertiaryFixedVariant)
    }

    component M3Palette: QtObject {
        property color m3primary_paletteKeyColor: "#808080"
        property color m3secondary_paletteKeyColor: "#808080"
        property color m3tertiary_paletteKeyColor: "#808080"
        property color m3neutral_paletteKeyColor: "#808080"
        property color m3neutral_variant_paletteKeyColor: "#808080"
        property color m3background: "#030303"
        property color m3onBackground: "#e4e4e4"
        property color m3surface: "#030303"
        property color m3surfaceDim: "#030303"
        property color m3surfaceBright: "#0d0d0d"
        property color m3surfaceContainerLowest: "#000000"
        property color m3surfaceContainerLow: "#040404"
        property color m3surfaceContainer: "#070707"
        property color m3surfaceContainerHigh: "#090909"
        property color m3surfaceContainerHighest: "#0b0b0b"
        property color m3onSurface: "#e5e5e5"
        property color m3surfaceVariant: "#0b0b0b"
        property color m3onSurfaceVariant: "#ababab"
        property color m3inverseSurface: "#e4e4e4"
        property color m3inverseOnSurface: "#303030"
        property color m3outline: "#757575"
        property color m3outlineVariant: "#484848"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#c6c6c6"
        property color m3primary: "#c6c6c6"
        property color m3onPrimary: "#303030"
        property color m3primaryContainer: "#474747"
        property color m3onPrimaryContainer: "#e4e4e4"
        property color m3inversePrimary: "#606060"
        property color m3secondary: "#9e9e9e"
        property color m3onSecondary: "#303030"
        property color m3secondaryContainer: "#474747"
        property color m3onSecondaryContainer: "#e4e4e4"
        property color m3tertiary: "#c6c6c6"
        property color m3onTertiary: "#303030"
        property color m3tertiaryContainer: "#474747"
        property color m3onTertiaryContainer: "#e4e4e4"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color m3primaryFixed: "#e4e4e4"
        property color m3primaryFixedDim: "#c6c6c6"
        property color m3onPrimaryFixed: "#1b1b1b"
        property color m3onPrimaryFixedVariant: "#474747"
        property color m3secondaryFixed: "#e4e4e4"
        property color m3secondaryFixedDim: "#c6c6c6"
        property color m3onSecondaryFixed: "#1b1b1b"
        property color m3onSecondaryFixedVariant: "#474747"
        property color m3tertiaryFixed: "#e4e4e4"
        property color m3tertiaryFixedDim: "#c6c6c6"
        property color m3onTertiaryFixed: "#1b1b1b"
        property color m3onTertiaryFixedVariant: "#474747"
        property color term0: "#353434"
        property color term1: "#ff4c8a"
        property color term2: "#ffbbb7"
        property color term3: "#ffdedf"
        property color term4: "#b3a2d5"
        property color term5: "#e98fb0"
        property color term6: "#ffba93"
        property color term7: "#eed1d2"
        property color term8: "#b39e9e"
        property color term9: "#ff80a3"
        property color term10: "#ffd3d0"
        property color term11: "#fff1f0"
        property color term12: "#dcbc93"
        property color term13: "#f9a8c2"
        property color term14: "#ffd1c0"
        property color term15: "#ffffff"
    }
}
