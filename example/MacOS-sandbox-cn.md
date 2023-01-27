<!--
 * @CreateTime: 2023-01-16 11:46:51
 * @Editor: Martin
 * @EditTime: 2023-01-16 11:48:24
 * @FilePath: /xterm.dart/example/MacOS-sandbox-cn.md
-->

# 无法打开/etc/shells，没有权限，参考 apple 沙箱机制，新版 flutter 创建的 macos 目录 com.apple.security.app-sandbox 为 true

macos -> DebugProfile.entitlements & Release.entitlements 修改为 false

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```
