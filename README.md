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


xhttp：负责上行流量，可套 Cloudflare CDN

Reality：负责下行流量，直连 VPS

Cloudflare 橙云：仅代理 HTTP(S)，回源端口为 80 / 443

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
1️⃣ 克隆或下载脚本
git clone https://github.com/你的用户名/你的仓库.git
cd xhttp-reality
chmod +x xhttp-reality.sh

2️⃣ 安装（随机身份，推荐）
./xhttp-reality.sh -i -d your.domain


示例：

./xhttp-reality.sh -i -d xh.example.com


脚本会自动：

安装 Xray

生成随机身份

写入配置并启动服务

输出客户端可用的 vless:// 分享链接

3️⃣ 安装（固定身份模式）
./xhttp-reality.sh -i -d your.domain -m fixed


fixed 模式用于 可复现部署

身份来自：

命令行参数

或脚本内置的 DEFAULT_* 配置

不会生成随机值

CLI 参数说明
参数	说明
-i, --install	安装并部署
-u, --uninstall	卸载并清理
-s, --status	查看运行状态
-d, --domain	Cloudflare 域名（必填）
-m, --mode	身份模式：random（默认） / fixed
--uuid-xhttp	固定模式下指定 xhttp UUID
--uuid-reality	固定模式下指定 reality UUID
--domain-sni	reality使用的sni域名
version	输出脚本版本

身份管理（重要）

脚本引入了 Identity Lifecycle 的概念。

identity.json

部署后会生成：

/usr/local/etc/xray/identity.json


该文件包含：

xhttp UUID

reality UUID

xhttp path

reality private / public key

shortId

这是 系统的唯一真实状态（state）。

身份模式说明
🎲 random（默认）

若 identity.json 不存在 → 随机生成

若存在 → 复用

忽略所有命令行传入的身份参数

适合：

日常使用

自动化部署

不关心身份可预测性

🔒 fixed

若 identity.json 存在 → 直接使用

若不存在 → 使用固定配置初始化

不会生成随机值

参数不完整将直接报错

适合：

可复现部署

多节点一致配置

调试 / 回滚场景

Cloudflare 注意事项（必读）

Cloudflare 橙云 只回源 80 / 443

xhttp 若需套 CDN：

必须监听 80（或通过 443 fallback）

8880 等端口 不能直接用于橙云回源

推荐配置：

xhttp：80

reality：443

客户端使用
v2rayN / sing-box

脚本会在安装完成后输出：

vless:// 分享链接

Base64 订阅内容

并写入：

/usr/local/etc/xray/client-link.txt


直接复制即可使用。

Clash Meta / sing-box 原生配置

脚本会生成：

/usr/local/etc/xray/client-singbox.json
/usr/local/etc/xray/client-clash.yaml


可直接导入。

状态与卸载
查看状态
./xhttp-reality.sh -s


显示：

Xray systemd 状态

xhttp / reality 端口监听情况

卸载
./xhttp-reality.sh -u


将会：

停止并移除 Xray

删除配置目录

删除 identity.json

设计理念

本项目并非“参数堆砌脚本”，而是基于以下原则设计：

Identity as State

明确 fixed / random 行为边界

可复现、可审计、可卸载

避免隐式随机或隐式覆盖

如果你在寻找的是 一个可长期维护的部署工具，而不是一次性脚本，这个项目适合你。

免责声明

本项目仅用于：

技术研究

网络协议学习

合法合规用途

请遵守你所在地区的法律法规。
