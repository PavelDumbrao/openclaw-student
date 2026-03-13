#!/bin/bash
set -e

# ============================================================
#  OpenClaw — установка для студентов (Hostinger VPS)
#  Требования: Ubuntu 20.04/22.04/24.04
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        OpenClaw — Установка              ║${NC}"
echo -e "${BLUE}║     Персональный AI-ассистент            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# --- Проверка root ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Запусти скрипт от root: sudo bash install.sh${NC}"
  exit 1
fi

# --- Установка Docker ---
if ! command -v docker &> /dev/null; then
  echo -e "${YELLOW}Устанавливаю Docker...${NC}"
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
  echo -e "${GREEN}Docker установлен ✓${NC}"
else
  echo -e "${GREEN}Docker уже установлен ✓${NC}"
fi

# --- Установка docker compose plugin ---
if ! docker compose version &> /dev/null; then
  echo -e "${YELLOW}Устанавливаю Docker Compose...${NC}"
  apt-get install -y docker-compose-plugin 2>/dev/null || true
fi

# --- Запрос OpenRouter API ключа ---
echo ""
echo -e "${YELLOW}Нужен OpenRouter API ключ.${NC}"
echo -e "Получи бесплатно на: ${BLUE}https://openrouter.ai/keys${NC}"
echo ""
read -rp "Вставь OpenRouter API ключ: " OPENROUTER_KEY

if [ -z "$OPENROUTER_KEY" ]; then
  echo -e "${RED}Ключ не введён. Установка прервана.${NC}"
  exit 1
fi

# --- Генерация gateway токена ---
GATEWAY_TOKEN=$(openssl rand -hex 32)

# --- Создание директорий ---
echo ""
echo -e "${YELLOW}Создаю директории...${NC}"
mkdir -p /opt/openclaw/workspace
mkdir -p /opt/openclaw/home

# --- Запись openclaw.json ---
cat > /opt/openclaw/home/openclaw.json << JSONEOF
{
  "meta": {"lastTouchedVersion": "2026.3.12"},
  "models": {
    "mode": "merge",
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "apiKey": "${OPENROUTER_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "openrouter/hunter-alpha",
            "name": "Hunter Alpha (OpenRouter)",
            "reasoning": false,
            "input": ["text"],
            "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
            "contextWindow": 128000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/openrouter/hunter-alpha",
        "fallbacks": []
      },
      "models": {
        "openrouter/openrouter/hunter-alpha": {"alias": "Hunter Alpha"}
      },
      "workspace": "/home/node/.openclaw/workspace",
      "compaction": {"mode": "safeguard"}
    }
  },
  "tools": {"profile": "full"},
  "commands": {"native": "auto", "nativeSkills": "auto", "restart": true, "ownerDisplay": "raw"},
  "session": {"dmScope": "per-channel-peer"},
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "allowedOrigins": ["http://localhost:18789"],
      "dangerouslyDisableDeviceAuth": true
    },
    "auth": {"mode": "token", "token": "${GATEWAY_TOKEN}"},
    "tailscale": {"mode": "off", "resetOnExit": false}
  }
}
JSONEOF

chmod 600 /opt/openclaw/home/openclaw.json

# --- Запись BOOTSTRAP.md ---
cat > /opt/openclaw/workspace/BOOTSTRAP.md << 'MDEOF'
# BOOTSTRAP — Первый запуск

Ты только что запустился на новом сервере. Это твой первый запуск.
Следуй этому сценарию строго по шагам. После завершения удали этот файл.

## Шаг 1 — Знакомство

Поприветствуй пользователя на русском языке:

«Привет! Я твой персональный AI-ассистент.
Прежде чем начать — давай познакомимся.

**Как тебя зовут?** И **чем ты занимаешься** — учёба, работа, проекты?»

Дождись ответа. Запомни имя и сферу деятельности.

## Шаг 2 — Представься

«Приятно познакомиться, [имя]! Можешь придумать мне имя или я буду просто Ассистент.

Я умею:
- 🔍 Искать информацию в интернете (нужен Brave API — расскажу ниже)
- 💻 Писать и запускать код
- 📁 Работать с файлами на сервере
- 🤖 Автоматизировать задачи
- 💬 Отвечать на вопросы и помогать с обучением

Сейчас я работаю на модели **Hunter Alpha** через OpenRouter.
Если захочешь другую модель — просто скажи, я сам переключусь.»

## Шаг 3 — Предложи Brave Search

«Чтобы я мог искать в интернете в реальном времени, нужен **Brave Search API**.
Это бесплатно — 2000 запросов в месяц.

👉 Получи ключ: https://api.search.brave.com/

1. Зайди по ссылке
2. Зарегистрируйся (можно через Google)
3. Создай API ключ в разделе "API Keys"
4. Скопируй и отправь мне

Хочешь сделать это сейчас?»

## Шаг 4 — Завершение

«Всё готово! Я настроен и готов к работе.
Что хочешь сделать первым делом, [имя]?»

После этого удали этот файл BOOTSTRAP.md.
MDEOF

# --- Запись docker-compose.yml ---
cat > /opt/openclaw/docker-compose.yml << COMPOSEEOF
services:
  openclaw:
    image: openclaw/openclaw:latest
    container_name: openclaw-student
    restart: unless-stopped
    ports:
      - "18789:18789"
    volumes:
      - /opt/openclaw/home:/home/node/.openclaw
      - /opt/openclaw/workspace:/home/node/.openclaw/workspace
    environment:
      - OPENROUTER_API_KEY=${OPENROUTER_KEY}
      - OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
COMPOSEEOF

# --- Запуск ---
echo -e "${YELLOW}Запускаю OpenClaw...${NC}"
cd /opt/openclaw
docker compose pull
docker compose up -d

# --- Ожидание запуска ---
echo -e "${YELLOW}Жду запуска (15 сек)...${NC}"
sleep 15

# --- Получение IP ---
SERVER_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

# --- Итог ---
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           OpenClaw успешно установлен! ✓             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Открой в браузере:"
echo -e "  ${BLUE}http://${SERVER_IP}:18789/#token=${GATEWAY_TOKEN}${NC}"
echo ""
echo -e "  Сохрани эту ссылку — она нужна для входа."
echo ""
echo -e "${YELLOW}  При первом запуске ассистент познакомится с тобой${NC}"
echo -e "${YELLOW}  и поможет настроить Brave Search.${NC}"
echo ""
