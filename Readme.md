# NativeDisplayBrightness

*Control your desktop monitor brightness just like on a MacBook!*

![native brightness UI](https://raw.githubusercontent.com/Bensge/NativeDisplayBrightness/master/nativeUI.png)

This a utility application to control monitor brightness with the F1, F2 keys. It utilizes DDC/CI, but this app doesn't have the freezing issues that similar aplications tend to suffer from.

This app also shows the **native** system UI when changing brightness! It uses the private `BezelServices` framework for this.

Needless to say, your monitor needs to support DDC/CI for this app to work.

## License

This application uses code borrowed from [ddcctl](https://github.com/kfix/ddcctl) which uses code from [DDC-CI-Tools](https://github.com/jontaylor/DDC-CI-Tools-for-OS-X)

GNU GENERAL PUBLIC LICENSE
