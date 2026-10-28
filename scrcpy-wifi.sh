#!/bin/bash

echo "=================================================="
echo "       Gerenciador Scrcpy Wi-Fi & Multi-Dispositivo"
echo "=================================================="

# 1. Se houver um celular no cabo USB, ativa o modo TCP/IP automaticamente
if adb devices | grep -q "device$"; then
    echo "📱 Dispositivo via USB detectado! Ativando porta TCP/IP (5555)..."
    adb tcpip 5555 >/dev/null 2>&1
    sleep 2
fi

# 2. Lista pré-configurada dos seus aparelhos Motorola na rede
# Você pode adicionar mais IPs/MACs aqui conforme necessário
declare -A DEVICES
DEVICES=(
    ["192.168.29.9"]="Moto G54 Principal"
    ["192.168.29.17"]="Segundo Aparelho Motorola"
)

# Descobre quais estão ativos na rede usando o comando ip neighbor / arp cache
echo "🔍 Verificando aparelhos Motorola ativos na rede..."

ACTIVE_IPS=()
for ip in "${!DEVICES[@]}"; do
    # Dá um ping rápido silencioso para garantir que o IP responda
    ping -c 1 -W 1 "$ip" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        ACTIVE_IPS+=("$ip")
    fi
done

# Se nenhum ping responder, tenta listar os IPs conhecidos mesmo assim
if [ ${#ACTIVE_IPS[@]} -eq 0 ]; then
    ACTIVE_IPS=("192.168.29.9" "192.168.29.17")
fi

# 3. Exibe o menu interativo
echo ""
echo "Selecione o aparelho para espelhar:"
echo "--------------------------------------------------"

i=1
declare -A MENU_MAP
for ip in "${ACTIVE_IPS[@]}"; do
    name="${DEVICES[$ip]:-Dispositivo Motorola}"
    MENU_MAP[$i]="$ip"
    echo " [$i] $name (IP: $ip)"
    ((i++))
done

echo "--------------------------------------------------"
read -rp "Digite o número da opção [1-$((i-1))]: " CHOICE

SELECTED_IP="${MENU_MAP[$CHOICE]}"

if [ -z "$SELECTED_IP" ]; then
    echo "❌ Opção inválida!"
    exit 1
fi

echo ""
echo "🌐 Conectando via ADB em $SELECTED_IP:5555..."
adb connect "$SELECTED_IP:5555"

# Verifica se a conexão foi bem sucedida antes de abrir o scrcpy
if ! adb devices | grep -q "$SELECTED_IP:5555.*device"; then
    echo "❌ Falha ao conectar em $SELECTED_IP."
    echo "Dica: Conecte o aparelho via USB e execute 'adb tcpip 5555' primeiro."
    exit 1
fi

echo "🔊 Reiniciando serviços de áudio (PipeWire)..."
systemctl --user restart pipewire pipewire-pulse wireplumber >/dev/null 2>&1

echo "🚀 Iniciando o scrcpy para $SELECTED_IP..."
scrcpy -s "$SELECTED_IP:5555"
