Sub Main

xsh.Screen.Synchronous = true

xsh.Screen.Send "su"
xsh.Screen.Send VbCr
xsh.Session.Sleep 500

xsh.Screen.Send "Huawei@CLOUD8!"
xsh.Screen.Send VbCr
xsh.Session.Sleep 500

xsh.Screen.Send "source set_env"
xsh.Screen.Send VbCr
xsh.Session.Sleep 500

xsh.Screen.Send "1"
xsh.Screen.Send VbCr
xsh.Session.Sleep 500

xsh.Screen.Send "FusionSphere123"
xsh.Screen.Send VbCr
xsh.Session.Sleep 500

End Sub