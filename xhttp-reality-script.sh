#!/usr/bin/env bash
set -e

# ================= 元信息 =================
SCRIPT_NAME="xhttp-reality-script"
SCRIPT_VERSION="1.0.0"

# ================= 路径 =================
XRAY_BIN="/usr/local/bin/xray"
XRAY_DIR="/usr/local/etc/xray"
CONFIG_FILE="$XRAY_DIR/config.json"
IDENTITY_FILE="$XRAY_DIR/identity.json"
SERVICE_FILE="/etc/systemd/system/xray.service"

# ================= 默认参数 =================
ACTION=""
MODE="random"
CF_DOMAIN=""
UUID_XHTTP=""
UUID_REALITY=""
PORT_XHTTP=80
PORT_REALITY=443
DOMAIN_SNI=""

# 生成客户端配置连接时，服务器地址填写的默认优选CDN域名
YOUXUAN_DOMAIN="www.visa.com.hk"

# ================= Fixed Identity Defaults =================
# 仅在 -m fixed 且 identity.json 不存在时使用
# random 模式永远不会使用这些值

DEFAULT_UUID_XHTTP="64c4dd3f-5c99-46dc-b6b8-1bde9cb98edd"
DEFAULT_UUID_REALITY="bff34330-9f5f-4efc-90f1-1fc73d9fb12b"
DEFAULT_XHTTP_PATH="/fc73d9fb12b"
DEFAULT_PRIVATE_KEY="8O9iwbAbCAFg4fMWgTTaTpyFsboKSFD__VGFEb8RiHU"
DEFAULT_PUBLIC_KEY="bKtUFakQNVC3onraxo0Z3_nu6DRuCB70_9djSpRJkyM"
DEFAULT_SHORT_ID="adba013e"
DEFAULT_DOMAIN_SNI="www.icloud.com"



# ================= 工具函数 =================
require_root() {
  [[ $(id -u) -eq 0 ]] || { echo "请使用 root 运行"; exit 1; }
}

log() {
  echo -e "[${SCRIPT_NAME}] $*"
}

# ================= 参数解析 =================
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--install) ACTION="install"; shift ;;
    -u|--uninstall) ACTION="uninstall"; shift ;;
    -s|--status) ACTION="status"; shift ;;
    -d|--domain) CF_DOMAIN="$2"; shift 2 ;;
    -m|--mode) MODE="$2"; shift 2 ;;
    --uuid-xhttp) UUID_XHTTP="$2"; shift 2 ;;
    --uuid-reality) UUID_REALITY="$2"; shift 2 ;;
    --domain-sni) DOMAIN_SNI="$2"; shift 2 ;;
    version) echo "$SCRIPT_NAME $SCRIPT_VERSION"; exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ================= 依赖 =================
install_deps() {
  apt -o Acquire::http::Timeout=5 update
  apt install -y curl unzip jq uuid-runtime openssl
}

# ================= 架构检测 =================
detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "64" ;;
    aarch64|arm64) echo "arm64-v8a" ;;
    *) log "不支持的架构"; exit 1 ;;
  esac
}

# ================= 身份管理 =================

read_identity() {
  UUID_XHTTP=$(jq -r .uuid_xhttp "$IDENTITY_FILE")
  UUID_REALITY=$(jq -r .uuid_reality "$IDENTITY_FILE")
  XHTTP_PATH=$(jq -r .xhttp_path "$IDENTITY_FILE")
  PRIVATE_KEY=$(jq -r .private_key "$IDENTITY_FILE")
  PUBLIC_KEY=$(jq -r .public_key "$IDENTITY_FILE")
  SHORT_ID=$(jq -r .short_id "$IDENTITY_FILE")
  DOMAIN_SNI=$(jq -r .domain_sni "$IDENTITY_FILE")

}


validate_identity() {
  [[ "$UUID_XHTTP" =~ ^[0-9a-fA-F-]{36}$ ]] || return 1
  [[ "$UUID_REALITY" =~ ^[0-9a-fA-F-]{36}$ ]] || return 1
  [[ "$XHTTP_PATH" =~ ^/[0-9a-zA-Z._-]+$ ]] || return 1
  [[ -n "$PRIVATE_KEY" ]] || return 1
  [[ -n "$PUBLIC_KEY" ]] || return 1
  [[ "$SHORT_ID" =~ ^[0-9a-fA-F]{2,16}$ ]] || return 1
  return 0
}


load_fixed_identity() {
  log "身份模式：fixed"
  mkdir -p "$XRAY_DIR"

  # 情况 1：已有落盘配置 → 直接使用
  if [[ -f "$IDENTITY_FILE" ]]; then
    log "读取已存在的固定身份"
    read_identity

    if ! validate_identity; then
      log "错误：落盘身份文件无效或不完整"
      exit 1
    fi
    return
  fi

  # 情况 2：首次初始化 → 使用固定来源
  log "未发现身份文件，使用固定配置初始化"

  UUID_XHTTP=${UUID_XHTTP:-"$DEFAULT_UUID_XHTTP"}
  UUID_REALITY=${UUID_REALITY:-"$DEFAULT_UUID_REALITY"}
  XHTTP_PATH=${XHTTP_PATH:-"$DEFAULT_XHTTP_PATH"}
  PRIVATE_KEY=${PRIVATE_KEY:-"$DEFAULT_PRIVATE_KEY"}
  PUBLIC_KEY=${PUBLIC_KEY:-"$DEFAULT_PUBLIC_KEY"}
  SHORT_ID=${SHORT_ID:-"$DEFAULT_SHORT_ID"}
  DOMAIN_SNI=${DOMAIN_SNI:-"$DEFAULT_DOMAIN_SNI"}

  if ! validate_identity; then
    log "错误：fixed 模式下身份参数缺失或非法"
    exit 1
  fi

  cat > "$IDENTITY_FILE" <<EOF
{
  "uuid_xhttp": "$UUID_XHTTP",
  "uuid_reality": "$UUID_REALITY",
  "xhttp_path": "$XHTTP_PATH",
  "private_key": "$PRIVATE_KEY",
  "public_key": "$PUBLIC_KEY",
  "short_id": "$SHORT_ID"
  "domain_sni": "$DOMAIN_SNI"
}
EOF

  log "固定身份已初始化并保存"
}


load_or_generate_random_identity() {
  log "身份模式：random"
  mkdir -p "$XRAY_DIR"

  # 情况 1：已有落盘配置 → 复用
  if [[ -f "$IDENTITY_FILE" ]]; then
    log "复用已有随机身份"
    read_identity

    if ! validate_identity; then
      log "错误：落盘随机身份损坏"
      exit 1
    fi
    return
  fi

  # 情况 2：首次生成 → 全随机
  log "生成全新随机身份"

  UUID_XHTTP=$(cat /proc/sys/kernel/random/uuid)
  UUID_REALITY=$(cat /proc/sys/kernel/random/uuid)
  XHTTP_PATH="/$(echo "$UUID_XHTTP" | cut -d- -f1)"

  KEYS=$("$XRAY_BIN" x25519)
  PRIVATE_KEY=$(echo "$KEYS" | awk '/PrivateKey|Private key/{print $NF}')
  PUBLIC_KEY=$(echo "$KEYS" | awk '/Password|Public key/{print $NF}')
  SHORT_ID=$(openssl rand -hex 4)
  DOMAIN_SNI="www.icloud.com"

  if ! validate_identity; then
    log "错误：随机身份生成失败"
    exit 1
  fi

  cat > "$IDENTITY_FILE" <<EOF
{
  "uuid_xhttp": "$UUID_XHTTP",
  "uuid_reality": "$UUID_REALITY",
  "xhttp_path": "$XHTTP_PATH",
  "private_key": "$PRIVATE_KEY",
  "public_key": "$PUBLIC_KEY",
  "short_id": "$SHORT_ID"
  "domain_sni": "$DOMAIN_SNI"
}
EOF

  log "随机身份已生成并保存"
}


# ================= 安装 =================
install_xray() {
  require_root
  [[ -n "$CF_DOMAIN" ]] || { log "缺少 -d <domain>"; exit 1; }

  install_deps
  ARCH=$(detect_arch)

  log "安装 Xray ($ARCH)"
  curl -fsSL https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${ARCH}.zip -o /tmp/xray.zip
  unzip -qo /tmp/xray.zip -d /tmp/xray
  install -m 755 /tmp/xray/xray "$XRAY_BIN"

  [[ "$MODE" == "fixed" ]] && load_fixed_identity || load_or_generate_random_identity


  VPS_IP=$(curl -fsSL https://api.ipify.org)

  cat > "$CONFIG_FILE" <<EOF
{
  "inbounds": [
    {
      "port": $PORT_XHTTP,
      "protocol": "vless",
      "settings": { "clients": [{ "id": "$UUID_XHTTP" }], "decryption": "none" },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": { "path": "$XHTTP_PATH", "mode": "auto" }
      }
    },
    {
      "port": $PORT_REALITY,
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "$UUID_REALITY", "flow": "xtls-rprx-vision" }],
        "decryption": "none",
        "fallbacks": [{ "dest": $PORT_XHTTP }]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "privateKey": "$PRIVATE_KEY",
          "serverNames": ["$DOMAIN_SNI"],
          "shortIds": ["$SHORT_ID"],
          "target": "$DOMAIN_SNI:443"
        }
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$XRAY_BIN run -c $CONFIG_FILE
Restart=on-failure
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable xray
  systemctl restart xray

  # ===== 分享链接 =====
  EXTRA_JSON=$(cat <<EOJ
{"downloadSettings":{"address":"$VPS_IP","port":443,"network":"xhttp","xhttpSettings":{"path":"$XHTTP_PATH","mode":"auto"},"security":"reality","realitySettings":{"serverName":"$DOMAIN_SNI","fingerprint":"chrome","show":false,"publicKey":"$PUBLIC_KEY","shortId":"$SHORT_ID","spiderX":"/","mldsa65Verify":""}}}
EOJ
)
  EXTRA_ENCODED=$(echo "$EXTRA_JSON" | jq -sRr @uri)
  PATH_ENCODED=$(printf '%s' "$XHTTP_PATH" | jq -sRr @uri)

  VLESS_LINK="vless://${UUID_XHTTP}@${YOUXUAN_DOMAIN}:443?encryption=none&security=tls&sni=${CF_DOMAIN}&type=xhttp&host=${CF_DOMAIN}&path=${PATH_ENCODED}&mode=auto&extra=${EXTRA_ENCODED}#xhttp-reality"
  echo ""
  echo "============================= 安装完成 ========================================"
  echo ""
  echo "📎 v2rayN / sing-box 分享链接："
  echo "！！！服务器地址默认使用www.visa.com.hk，可自行修改为其他套CF的域名或优选IP！！！"
  echo ""
  echo "$VLESS_LINK"
  echo ""
  log "================================================================================"
  echo "$VLESS_LINK" | tee "$XRAY_DIR/client-link.txt"
  log "====================================="
}

# ================= 卸载 =================
uninstall_xray() {
  require_root
  log "卸载 Xray"
  systemctl stop xray 2>/dev/null || true
  systemctl disable xray 2>/dev/null || true
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  rm -rf "$XRAY_DIR" "$XRAY_BIN"
}

# ================= 状态 =================
status_xray() {
  systemctl status xray --no-pager || true
  ss -lnt | grep -E ":$PORT_XHTTP |:$PORT_REALITY " || true
}

# ================= 主入口 =================
case "$ACTION" in
  install) install_xray ;;
  uninstall) uninstall_xray ;;
  status) status_xray ;;
  *) echo "用法: -i|-u|-s -d <domain> [-m fixed|random]"; exit 1 ;;
esac
