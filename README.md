
XHTTP + Reality + Cloudflare 部署脚本

一个 工程化的一键部署脚本，用于在 VPS 上部署 Xray（VLESS + xhttp + Reality），并支持：

上行使用 xhttp + Cloudflare CDN

下行使用 Reality 直连

完整的 CLI 参数体系

固定 / 随机身份模式

身份落盘、可复现、可卸载

自动生成客户端可用的分享链接与订阅

架构概览
客户端
 ├─ 上行：xhttp → Cloudflare → VPS :80
 └─ 下行：reality → VPS :443

系统要求

操作系统：

Debian 10+

Ubuntu 20.04+

架构：

amd64 / x86_64

arm64 / aarch64

需要 root 权限

systemd 环境

快速开始
安装（随机身份，推荐）
./xhttp-reality.sh -i -d your.domain


示例：

./xhttp-reality.sh -i -d xh.example.com

安装（固定身份模式）
./xhttp-reality.sh -i -d your.domain -m fixed

CLI 参数说明
参数	说明
-i, --install	安装并部署
-u, --uninstall	卸载并清理
-s, --status	查看运行状态
-d, --domain	Cloudflare 域名（必填）
-m, --mode	身份模式：random / fixed
--uuid-xhttp	fixed 模式指定 xhttp UUID
--uuid-reality	fixed 模式指定 reality UUID
--xhttp-port	xhttp 监听端口（默认 80）
--reality-port	reality 监听端口（默认 443）
身份管理（Identity Lifecycle）

脚本使用 identity.json 作为唯一真实状态：

/usr/local/etc/xray/identity.json

random（默认）

首次安装随机生成

以后复用

忽略命令行身份参数

fixed

使用固定配置

不生成随机值

参数不完整直接失败

Cloudflare 注意事项

Cloudflare 橙云仅回源 80 / 443

xhttp 套 CDN 时必须监听 80（或经 443 fallback）

8880 不能直接用于橙云回源

客户端使用

安装完成后会生成：

/usr/local/etc/xray/client-link.txt


包含 vless:// 分享链接，可直接导入：

v2rayN

sing-box

Clash Meta（新版本）

查看状态
./xhttp-reality.sh -s

卸载
./xhttp-reality.sh -u

设计理念

Identity as State

fixed / random 行为边界清晰

可复现、可审计、可维护

免责声明

本项目仅用于技术研究与合法用途，请遵守当地法律法规。
