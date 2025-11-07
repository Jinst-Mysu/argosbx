#!/bin/sh
export LANG=en_US.UTF-8

# Variables for X-Ray protocols
[ -z "${vlpt+x}" ] || vlp=yes
[ -z "${vxpt+x}" ] || vxp=yes
[ -z "${xhpt+x}" ] || xhp=yes

# Directory setup
mkdir -p "$HOME/agsbx/xrk"

installxray(){
  echo
  echo "=========启用xray内核========="
  mkdir -p "$HOME/agsbx/xrk"
  if [ ! -e "$HOME/agsbx/xray" ]; then
    url="https://github.com/yonggekkk/argosbx/releases/download/argosbx/xray-$cpu"
    out="$HOME/agsbx/xray"
    # Download xray binary
    (command -v curl >/dev/null 2>&1 && curl -Lo "$out" -# --retry 2 "$url") || (command -v wget >/dev/null 2>&1 && wget -qO "$out" "$url")
    chmod +x "$HOME/agsbx/xray"
    sbcore=$("$HOME/agsbx/xray" version 2>/dev/null | awk '/^Xray/{print $2}')
    echo "已安装Xray正式版内核：$sbcore"
  fi
  
  # Basic X-Ray config
  cat > "$HOME/agsbx/xr.json" <<EOF
{
  "log": {
    "loglevel": "none"
  },
  "dns": {
    "servers": [
      "${xsdns}"
    ]
  },
  "inbounds": [
EOF

  # Generate UUID if not exists
  if [ -z "$uuid" ] && [ ! -e "$HOME/agsbx/uuid" ]; then
    uuid=$("$HOME/agsbx/xray" uuid)
    echo "$uuid" > "$HOME/agsbx/uuid"
  elif [ -n "$uuid" ]; then
    echo "$uuid" > "$HOME/agsbx/uuid"
  fi
  uuid=$(cat "$HOME/agsbx/uuid")
  echo "UUID密码：$uuid"

  # Handle Reality configuration
  if [ -n "$xhp" ] || [ -n "$vlp" ]; then
    if [ -z "$ym_vl_re" ]; then
      ym_vl_re=apple.com
    fi
    echo "$ym_vl_re" > "$HOME/agsbx/ym_vl_re"
    echo "Reality域名：$ym_vl_re"
    
    # Generate Reality keys if not exist
    if [ ! -e "$HOME/agsbx/xrk/private_key" ]; then
      key_pair=$("$HOME/agsbx/xray" x25519)
      private_key=$(echo "$key_pair" | grep "PrivateKey" | awk '{print $2}')
      public_key=$(echo "$key_pair" | grep "Password" | awk '{print $2}')
      short_id=$(date +%s%N | sha256sum | cut -c 1-8)
      echo "$private_key" > "$HOME/agsbx/xrk/private_key"
      echo "$public_key" > "$HOME/agsbx/xrk/public_key"
      echo "$short_id" > "$HOME/agsbx/xrk/short_id"
    fi
    private_key_x=$(cat "$HOME/agsbx/xrk/private_key")
    public_key_x=$(cat "$HOME/agsbx/xrk/public_key")
    short_id_x=$(cat "$HOME/agsbx/xrk/short_id")
  fi

  # Handle VLESS configurations  
  if [ -n "$xhp" ] || [ -n "$vxp" ]; then
    if [ ! -e "$HOME/agsbx/xrk/dekey" ]; then
      vlkey=$("$HOME/agsbx/xray" vlessenc)
      dekey=$(echo "$vlkey" | grep '"decryption":' | sed -n '2p' | cut -d' ' -f2- | tr -d '"')
      enkey=$(echo "$vlkey" | grep '"encryption":' | sed -n '2p' | cut -d' ' -f2- | tr -d '"')
      echo "$dekey" > "$HOME/agsbx/xrk/dekey"
      echo "$enkey" > "$HOME/agsbx/xrk/enkey"
    fi
    dekey=$(cat "$HOME/agsbx/xrk/dekey")
    enkey=$(cat "$HOME/agsbx/xrk/enkey")
  fi

  # Configure VLESS-XHTTP-REALITY
  if [ -n "$xhp" ]; then
    xhp=xhpt
    if [ -z "$port_xh" ] && [ ! -e "$HOME/agsbx/port_xh" ]; then
      port_xh=$(shuf -i 10000-65535 -n 1)
      echo "$port_xh" > "$HOME/agsbx/port_xh"
    elif [ -n "$port_xh" ]; then
      echo "$port_xh" > "$HOME/agsbx/port_xh"
    fi
    port_xh=$(cat "$HOME/agsbx/port_xh")
    echo "Vless-xhttp-reality-v端口：$port_xh"
    
    cat >> "$HOME/agsbx/xr.json" <<EOF
    {
      "tag":"xhttp-reality",
      "listen": "::",
      "port": ${port_xh},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "${dekey}"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "reality",
        "realitySettings": {
          "fingerprint": "chrome",
          "target": "${ym_vl_re}:443",
          "serverNames": [
            "${ym_vl_re}"
          ],
          "privateKey": "$private_key_x",
          "shortIds": ["$short_id_x"]
        },
        "xhttpSettings": {
          "host": "",
          "path": "${uuid}-xh",
          "mode": "auto"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
  else
    xhp=xhptargo
  fi

  # Configure VLESS-XHTTP
  if [ -n "$vxp" ]; then
    vxp=vxpt
    if [ -z "$port_vx" ] && [ ! -e "$HOME/agsbx/port_vx" ]; then
      port_vx=$(shuf -i 10000-65535 -n 1)
      echo "$port_vx" > "$HOME/agsbx/port_vx"
    elif [ -n "$port_vx" ]; then
      echo "$port_vx" > "$HOME/agsbx/port_vx"
    fi
    port_vx=$(cat "$HOME/agsbx/port_vx")
    echo "Vless-xhttp-v端口：$port_vx"
    
    cat >> "$HOME/agsbx/xr.json" <<EOF
    {
      "tag":"vless-xhttp",
      "listen": "::",
      "port": ${port_vx},
      "protocol": "vless", 
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "${dekey}"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "host": "",
          "path": "${uuid}-vx",
          "mode": "auto"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
  else
    vxp=vxptargo
  fi

  # Configure VLESS-TCP-REALITY
  if [ -n "$vlp" ]; then
    vlp=vlpt
    if [ -z "$port_vl_re" ] && [ ! -e "$HOME/agsbx/port_vl_re" ]; then
      port_vl_re=$(shuf -i 10000-65535 -n 1)
      echo "$port_vl_re" > "$HOME/agsbx/port_vl_re"
    elif [ -n "$port_vl_re" ]; then
      echo "$port_vl_re" > "$HOME/agsbx/port_vl_re"
    fi
    port_vl_re=$(cat "$HOME/agsbx/port_vl_re")
    echo "Vless-tcp-reality-v端口：$port_vl_re"
    
    cat >> "$HOME/agsbx/xr.json" <<EOF
    {
      "tag":"reality-vision",
      "listen": "::",
      "port": $port_vl_re,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "fingerprint": "chrome",
          "dest": "${ym_vl_re}:443",
          "serverNames": [
            "${ym_vl_re}"
          ],
          "privateKey": "$private_key_x",
          "shortIds": ["$short_id_x"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
  else
    vlp=vlptargo
  fi

  # Complete the configuration
  sed -i '${s/,\s*$//}' "$HOME/agsbx/xr.json"
  cat >> "$HOME/agsbx/xr.json" <<EOF
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {
        "domainStrategy":"${xryx}"
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "direct"
      }
    ]
  }
}
EOF

  # Setup systemd service if applicable
  if pidof systemd >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
    cat > /etc/systemd/system/xr.service <<EOF
[Unit]
Description=xr service
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/root/agsbx/xray run -c /root/agsbx/xr.json
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable xr >/dev/null 2>&1
    systemctl start xr >/dev/null 2>&1
  else
    nohup "$HOME/agsbx/xray" run -c "$HOME/agsbx/xr.json" >/dev/null 2>&1 &
  fi
}

# Main execution
installxray
