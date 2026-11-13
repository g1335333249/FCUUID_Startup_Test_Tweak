# FCUUID 启动写入测试 Tweak（Theos / Logos）

用途：在你有授权的第二个测试 App 进程内、AppDelegate 启动回调进入时，将一个已知测试 UUID 写入该 App 自己的 Keychain 与 NSUserDefaults，方便核对后端是否正确检测设备标识重放。

## 修改

1. `Tweak.xm` 内把 `kTestBundleIdentifier` 改成第二份测试 App 的实际 Bundle ID。
2. 将 `kKnownTestIdentifier` 改为测试用的 UUID（32 位十六进制、36 位带连接符，或前缀为 `UID_` 的值）。不要把线上真实设备标识发布到源码仓库。
3. `FCUUIDStartupTest.plist` 的 `Bundles` 同样改成第二份测试 App 的 Bundle ID。

## 编译

需要安装 Theos 和对应 iOS SDK，在可用的 Theos 工具链中运行：

```bash
make clean
make
# 仅在具备兼容的 Substrate/ElleKit 包管理环境时再使用 make package
```

得到 Tweak 动态库；仅在已配置相应包管理环境时才打包成安装包；使用你在测试环境中已经合法部署且与系统兼容的注入框架加载。TrollStore 能安装 IPA，但仅安装 TrollStore 本身，不意味着它提供 Substrate/ElleKit 风格的动态库注入能力。

`control` 文件仅是传统越狱包的示例元数据，不适用于直接通过 TrollStore 安装；不同 rootless/rootful 环境需要调整打包参数。

本仓库没有经过设备实际运行测试，不能保证与特定加载器或 iOS 版本兼容。

## 工作方式

- 只匹配指定第二份 App 的 Bundle ID，避免影响原版。
- 在 `-[AppDelegate application:didFinishLaunchingWithOptions:]` 调用原方法之前写入；此方法在用户提供的主程序元数据中已找到。
- Keychain: generic password, account `fc_uuidForDevice`, service 为第二份 App 当前 Bundle ID，使用其默认授权访问组。
- NSUserDefaults: `fc_uuidForDevice`。
- 先写 Keychain、再写 NSUserDefaults。输出状态码与是否读取一致；不输出真实 UUID。
- 不注入认证服务器、不修改登录响应、不屏蔽反注入或越狱检测、不提供通过设备校验的保证。

## 重要限制

1. 若 FCUUID 在 `didFinishLaunchingWithOptions:` 之前已经被读取并缓存，本 Tweak 只写本地存储，不能刷新该缓存；这时应把初始化前移至你控制的测试 App 源码，而不是在系统构造器中盲目调用 Keychain。
2. Keychain 写入失败时会返回 OSStatus，例如 `-34018` 通常指向 Keychain 权限/签名问题；不要直接修改别的 App 的 Keychain 数据。
3. 若 readback 显示 OK，但服务器仍拒绝登录，说明需要检查客户端实际传出的 `deviceId`（注意 `UID_` 前缀）、服务器终端白名单、额外校验字段等。
4. 如果被注入 App 启动就退出，先用不包含任何业务 Hook 的空 Tweak 对照，核查 dyld/签名/加载器兼容性和系统崩溃日志。

## 安全测试建议

对照：原客户端原 UUID、新客户端新 UUID、新客户端已知测试 UUID。服务端应区分 `deviceId` 相等和真正设备凭证相符，并记录明确拒绝原因。静态可复制的 UUID 不应单独作为强设备认证凭证。
