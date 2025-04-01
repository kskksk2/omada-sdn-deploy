#!/bin/bash
# =====================================
# ✅ Omada SDN AWS 서버 클린 컨피그 (2025.04 최신)
# 목적: AWS EC2 Ubuntu 22.04 + Omada SDN v5.15.20.16 완전 자동 구축
# 도메인: ken-network.online (서브도메인: omada.ken-network.online)
# 서버 IP 예시: 18.179.54.42
# =====================================

# [0] 서버 업데이트 및 기본 패키지
sudo apt update && sudo apt upgrade -y
sudo timedatectl set-timezone Asia/Tokyo
sudo apt install curl wget gnupg lsb-release net-tools -y

# [0.5] SSH 12322 포트 리스닝 추가 ← 요기에 삽입 추천!
sudo sed -i 's/^#Port 22/Port 22\nPort 12322/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# [1] UFW 방화벽 설정 (포트 오픈 및 기본 정책 설정)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 12322/tcp       # SSH 사용자 지정 포트
sudo ufw allow 22/tcp          # SSH 기본 포트도 예비로 허용
sudo ufw allow 80,443,8043,8088/tcp
sudo ufw allow 29810:29813/tcp
sudo ufw --force enable

# [2] OpenJDK 17 & jsvc 설치 (필수!)
sudo apt install openjdk-17-jre-headless jsvc -y

# [3] JAVA_HOME 환경변수 설정 (정확한 명령어)
cat <<EOF | sudo tee -a /etc/profile
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
source /etc/profile

# [4] MongoDB 6.0 설치
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt update && sudo apt install mongodb-org -y
sudo systemctl enable --now mongod

# [5] Omada SDN Controller 설치 (v5.15.20.16)
wget https://static.tp-link.com/upload/software/2025/202503/20250321/Omada_SDN_Controller_v5.15.20.16_linux_x64.deb
sudo dpkg -i Omada_SDN_Controller_v5.15.20.16_linux_x64.deb || sudo apt -f install -y && sudo dpkg -i Omada_SDN_Controller_v5.15.20.16_linux_x64.deb

# [6] Certbot 설치
sudo apt install certbot python3-certbot-nginx -y

# [7] Nginx 설치 및 기본 설정 제거
sudo apt install nginx -y
sudo rm -f /etc/nginx/sites-enabled/default

# [8] Nginx 중지 후 Certbot 사전 인증서 발급 (Nginx 설정 전에)
sudo systemctl stop nginx
sudo certbot certonly --standalone -d omada.ken-network.online --agree-tos -m 1768ksk@gmail.com --no-eff-email --non-interactive

# [9] Nginx 리버스 프록시 설정
sudo tee /etc/nginx/sites-available/omada > /dev/null <<EOF
server {
    listen 80;
    server_name omada.ken-network.online;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name omada.ken-network.online;

    ssl_certificate /etc/letsencrypt/live/omada.ken-network.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/omada.ken-network.online/privkey.pem;

    location / {
        proxy_pass https://localhost:8043;
        proxy_ssl_verify off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/omada /etc/nginx/sites-enabled/omada
sudo nginx -t && sudo systemctl restart nginx

# [10] 인증서 리디렉션 자동 구성 적용 (이미 발급된 경우에도 실행 가능)
sudo certbot --nginx -d omada.ken-network.online --agree-tos -m 1768ksk@gmail.com --no-eff-email --redirect || true

# [11] 자동 갱신 테스트
sudo certbot renew --dry-run

# [💡] 브라우저 접속
# https://omada.ken-network.online
# 최초 로그인 후 Omada 초기 설정 마법사 진행

# 🎉 구축 완료!
echo "[완료] Omada SDN 서버가 성공적으로 설치되었습니다!"
