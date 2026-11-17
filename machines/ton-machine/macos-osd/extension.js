import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// gmux_backlight reports an unknown scale; use a perceptual approximation.
const BRIGHTNESS_GAMMA = 2.2;

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

        this._brightnessManager = Main.brightnessManager;
        this._scaleOverrides = new Map();
        this._brightnessChangedId = this._brightnessManager.connect(
            'changed', () => this._patchBrightnessScales());
        this._patchBrightnessScales();
    }

    disable() {
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
