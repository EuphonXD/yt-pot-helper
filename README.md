# yt-pot-helper · YouTube PoToken 一键助手

给 **yt-dlp**（以及 Beat Saber Cinema 的内置下载）在本机跑一个 **PoToken 提供者**，
缓解 / 绕过 YouTube 的 “Sign in to confirm you’re not a bot”。

> [!IMPORTANT]
> **本仓库不包含上游代码**，只是一个安装 / 启动助手。
> PoToken 能力来自 **[Brainicism/bgutil-ytdlp-pot-provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider)**（GPL-3.0），
> 脚本会在安装时**从上游 GitHub 下载**。

---

## 配套项目

本工具通常和下面这个项目一起用（同一个作者）：

- **[beat-saber-video-tool](https://github.com/EuphonXD/beat-saber-video-tool)**（网页版视频工具）
  它用 **yt-dlp** 批量下载 YouTube 视频；如果下载时报 `Sign in to confirm you’re not a bot`，
  就用本仓库的 `setup-pot.ps1` 在本机起一个 PoToken 提供者，再回到下载工具里重试。
- **[SetlistChallenge](https://github.com/EuphonXD/SetlistChallenge)**（Beat Saber 无缝连打 mod）
  同属这套 Beat Saber 工具链。

---

## 它解决什么

YouTube 会对机房 / 代理 IP 做风险控制，yt-dlp 下载时可能报：

```
ERROR: [youtube] xxx: Sign in to confirm you’re not a bot.
```

PoToken（Proof-of-Origin Token）是 YouTube 用来区分“真实浏览器”的凭证。
本地跑一个生成服务、yt-dlp 通过插件取用，就不必每次都靠 cookies。

---

## 快速开始

前提：**Node.js 18+**。

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-pot.ps1
```

脚本会：

1. 检查 Node.js
2. 从上游 GitHub 下载最新发布包并解压到 `-InstallDir`（默认 `%LOCALAPPDATA%\yt-pot`）
3. 缺少 `server/build/main.js` 时自动 `npm ci` + `npm run build`
4. 生成 `start-pot.bat`（自动填好 node 与 main.js 路径）
5. 注册计划任务 `BgutilPOT`（登录时自启）并启动
6. 轮询 `http://127.0.0.1:4416/ping` 直到就绪

### 参数

| 参数 | 默认 | 说明 |
|---|---|---|
| `-Port` | `4416` | 本机监听端口 |
| `-InstallDir` | `%LOCALAPPDATA%\yt-pot` | 安装目录 |
| `-NoTask` | 关 | 只安装，不注册计划任务 |

---

## 验证

```powershell
curl.exe http://127.0.0.1:4416/ping
```

返回 JSON（含 `server_uptime`）就是正常。

## 与 yt-dlp 对接

```
yt-dlp --extractor-args "youtube:fetch_pot=always" <URL>
```

上游的 yt-dlp 插件需要装到 yt-dlp 的 plugin 目录，详见：
<https://github.com/Brainicism/bgutil-ytdlp-pot-provider>

## 🍪 YouTube Cookie Sync（推送到视频工具）

批量下载 YouTube 视频时，除了 PoToken，通常还需要一份登录态 **cookies**。
本仓库自带一个小脚本：从本机浏览器导出 YouTube cookies，
**自动 POST 到 beat-saber-video-tool 的 `/api/cookies/import`**。

前提：

- `beat-saber-video-tool` 正在运行（默认 `http://127.0.0.1:8770`）
- 你已在浏览器里登录 YouTube（上传的就是这个登录态）
- 本目录有 `bin\yt-dlp.exe`（或用 `-Ytdlp` 指定）

### 用法

```powershell
# 默认：从 Edge 导出，推到 http://127.0.0.1:8770
powershell -ExecutionPolicy Bypass -File .\sync-cookies.ps1

# 指定浏览器 / 工具地址
.\sync-cookies.ps1 -Browser firefox -ToolUrl http://127.0.0.1:8770

# 已有 cookies.txt，直接上传
.\sync-cookies.ps1 -CookiesFile .\cookies.txt
```

也可以直接双击 `sync-cookies.bat`。

| 参数 | 默认 | 说明 |
|---|---|---|
| `-Browser` | `edge` | firefox / edge / chrome / brave / opera / vivaldi / chromium |
| `-ToolUrl` | `http://127.0.0.1:8770` | beat-saber-video-tool 的地址 |
| `-CookiesFile` | 空 | 直接上传已有的 Netscape cookies.txt |
| `-Ytdlp` | 自动查找 | yt-dlp.exe 路径 |
| `-KeepFile` | 关 | 保留导出的临时文件 |

推送成功后会自动调用 `/api/cookies/detect` 做一次检测。

> **安全**：cookies 等价于登录态。脚本只会 POST 到你本机运行的视频工具，不会发送给任何第三方；临时文件默认用完即删。

---

## 卸载

```bat
schtasks /Delete /TN BgutilPOT /F
taskkill /F /IM node.exe
rmdir /S /Q "%LOCALAPPDATA%\yt-pot"
```

---

## 注意

- 服务**只监听本机**（127.0.0.1），不对局域网开放
- PoToken **不保证**一定能绕过风控；代理 IP 太差时还是要配 cookies
- 上游升级后请重跑 `setup-pot.ps1`

## License

本仓库脚本：**MIT**。
上游 [bgutil-ytdlp-pot-provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider) 为 **GPL-3.0**，本仓库不再分发其代码。
