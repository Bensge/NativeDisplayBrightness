# NativeDisplayBrightness

*Control your desktop monitor brightness just like on a MacBook!*

![native brightness UI](https://raw.githubusercontent.com/Ivan-Alone/NativeDisplayBrightness/master/nativeUI_Dark.png)

This a utility application to control monitor brightness with the F1, F2 keys (**configurable now!**). It utilizes DDC/CI, but this app doesn't have the freezing issues that similar aplications tend to suffer from.

This app also shows the **native** system UI when changing brightness! It uses the private `BezelServices` framework for this.

Needless to say, your monitor needs to support DDC/CI for this app to work.

## Configuration

If you want to change brightness buttons layout, just edit `NativeDisplayBrightness.app/Contents/Resources/config.json` config file. 

Open downloaded application with RMB -> Show Package Contents, go to this path, open `config.json` with TextEdit (or text editor you prefer) and map your own keys layout to increase/decrease brightness.

For example, this configuration means that brightness will increase/decrease by pressing Cmd+ArrowUp / Cmd+ArrowDown:

```json
{
    "buttonBrightnessUp": {
        "keyCode": "VK_ARROW_UP",
        "isCmd": true
    },
    "buttonBrightnessDown": {
        "keyCode": "VK_ARROW_DOWN",
        "isCmd": true
    }
}
```

You can find more information about key combinations in the same `config.json` file. In `macOSKeyCodes.json` contains all mostly supported keys constants. You can edit it if you understand what you doing, at one's own risk.

Also you can write `keyCode` as simple integer value, but text IDs is more readable.

## License

This application uses code borrowed from [ddcctl](https://github.com/kfix/ddcctl) which uses code from [DDC-CI-Tools](https://github.com/jontaylor/DDC-CI-Tools-for-OS-X)

GNU GENERAL PUBLIC LICENSE
