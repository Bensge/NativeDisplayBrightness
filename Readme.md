# NativeDisplayBrightness

*Control your desktop monitor brightness just like on a MacBook!*

![native brightness UI](https://raw.githubusercontent.com/Bensge/NativeDisplayBrightness/master/nativeUI.png)

This a utility application to control monitor brightness with the F1, F2 keys. It utilizes DDC/CI, but this app doesn't have the freezing issues that similar aplications tend to suffer from.

This app also shows the **native** system UI when changing brightness! It uses the private `BezelServices` framework for this.

## Monitors compatibility

Your monitor needs to support DDC/CI for this app to work. If you don't see the brightness system UI displayed on your monitor when pressing the F1 / F2 keys, this means that your monitor is not supported.

If your monitor supports reading the current brightness value from  DDC/CI, the app increments / decrements the brigness staring from the monitor current brightness value. This allows you to set the brighness using the monitor's OSD and to adjust it later with the app

## Multiple monitors support

If you have multiple external monitors connected to your Mac, the brighness adjustment is done on the monitor with the currently active window, and the brightness system UI is displayed on the adjusted monitor.

## License

This application uses code borrowed from [ddcctl](https://github.com/kfix/ddcctl) which uses code from [DDC-CI-Tools](https://github.com/jontaylor/DDC-CI-Tools-for-OS-X)

GNU GENERAL PUBLIC LICENSE
