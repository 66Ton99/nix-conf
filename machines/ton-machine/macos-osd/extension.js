import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

// gmux_backlight reports an unknown scale; use a perceptual approximation.
const BRIGHTNESS_GAMMA = 2.2;
const TOUCHPAD_REENABLE_DELAY_MS = 1500;

function clamp(value) {
    return Math.max(0, Math.min(1, value));
}

function toBacklight(value) {
    return Math.pow(clamp(value), BRIGHTNESS_GAMMA);
}

function fromBacklight(value) {
    return Math.pow(clamp(value), 1 / BRIGHTNESS_GAMMA);
}

export default class MacOSOsdExtension extends Extension {
    enable() {
        this._stylesheet = this.dir.get_child('stylesheet.css');
        Main.themeManager.loadStylesheet(this._stylesheet);

        this._touchpadSettings = new Gio.Settings({
            schema_id: 'org.gnome.desktop.peripherals.touchpad',
        });
        // If GNOME Shell was stopped while typing, recover from a stale
        // temporary disable on the next session. This host's declared normal
        // mode is an enabled touchpad.
        if (this._touchpadSettings.get_string('send-events') === 'disabled')
            this._touchpadSettings.set_string('send-events', 'enabled');

        this._keyPressId = global.stage.connect('captured-event', (_stage, event) => {
            if (event.type() === Clutter.EventType.KEY_PRESS)
                this._disableTouchpadWhileTyping();

            return Clutter.EVENT_PROPAGATE;
        });

        this._brightnessManager = Main.brightnessManager;
        this._scaleOverrides = new Map();
        this._brightnessChangedId = this._brightnessManager.connect(
            'changed', () => this._patchBrightnessScales());
        this._patchBrightnessScales();
    }

    disable() {
        if (this._keyPressId) {
            global.stage.disconnect(this._keyPressId);
            this._keyPressId = 0;
        }

        if (this._touchpadReenableSourceId) {
            GLib.source_remove(this._touchpadReenableSourceId);
            this._touchpadReenableSourceId = 0;
        }
        this._restoreTouchpadAfterTyping();
        this._touchpadSettings = null;

        if (this._brightnessChangedId) {
            this._brightnessManager.disconnect(this._brightnessChangedId);
            this._brightnessChangedId = 0;
        }

        for (const [scale, original] of this._scaleOverrides) {
            scale._getRelativeBrightness = original.get;
            scale._setRelativeBrightness = original.set;
            scale._currentBacklightBrightness = -1;
            scale._scaleChanged = true;
        }
        this._scaleOverrides.clear();

        if (this._brightnessManager?._monitorScales.size > 0) {
            this._brightnessManager._globalScaleChanged = false;
            this._brightnessManager._sync({showOSD: false});
        }

        if (this._stylesheet) {
            Main.themeManager.unloadStylesheet(this._stylesheet);
            this._stylesheet = null;
        }
    }

    _disableTouchpadWhileTyping() {
        if (!this._touchpadSettings)
            return;

        const mode = this._touchpadSettings.get_string('send-events');
        if (mode !== 'disabled') {
            this._touchpadModeBeforeTyping = mode;
            this._touchpadSettings.set_string('send-events', 'disabled');
        }

        if (this._touchpadReenableSourceId)
            GLib.source_remove(this._touchpadReenableSourceId);

        this._touchpadReenableSourceId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            TOUCHPAD_REENABLE_DELAY_MS,
            () => {
                this._touchpadReenableSourceId = 0;
                this._restoreTouchpadAfterTyping();
                return GLib.SOURCE_REMOVE;
            });
    }

    _restoreTouchpadAfterTyping() {
        if (this._touchpadModeBeforeTyping && this._touchpadSettings) {
            this._touchpadSettings.set_string(
                'send-events', this._touchpadModeBeforeTyping);
            this._touchpadModeBeforeTyping = null;
        }
    }

    _patchBrightnessScales() {
        let changed = false;

        for (const scale of this._brightnessManager._monitorScales.values()) {
            if (this._scaleOverrides.has(scale))
                continue;

            const getRelativeBrightness = scale._getRelativeBrightness;
            const setRelativeBrightness = scale._setRelativeBrightness;
            scale._getRelativeBrightness = function (backlight) {
                return fromBacklight(getRelativeBrightness.call(this, backlight));
            };
            scale._setRelativeBrightness = function (backlight, value) {
                setRelativeBrightness.call(this, backlight, toBacklight(value));
            };

            this._scaleOverrides.set(scale, {
                get: getRelativeBrightness,
                set: setRelativeBrightness,
            });
            scale._currentBacklightBrightness = -1;
            scale._scaleChanged = true;
            changed = true;
        }

        if (changed) {
            this._brightnessManager._globalScaleChanged = false;
            this._brightnessManager._sync({showOSD: false});
        }
    }
}
