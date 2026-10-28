#!/bin/bash

clear
echo "=================================================="
echo "       Gerenciador Scrcpy Wi-Fi & Multi-Dispositivo"
echo "=================================================="

# 1. Verifica se há algum aparelho conectado via USB para ativar o modo TCP/IP (porta 5555)
USB_DEVICE=$(adb devices | grep -w "device" | grep -v "tcpip" | awk '{print $1}')

if [ -n "$USB_DEVICE" ]; then
    echo "📱 Dispositivo via USB detectado! Ativando porta TCP/IP (5555)..."
    adb -s "$USB_DEVICE" tcpip 5555
    sleep 2
fi

# 2. Varre a rede e lista todos os dispositivos ADB conectados (tanto via USB quanto Wi-Fi)
echo "🔍 Verificando aparelhos Motorola ativos na rede..."
echo ""

# Cria um array com os IPs encontrados
mapfile -t DEVICES < <(adb devices | grep -E "device$" | awk '{print $1}')

if [ ${#DEVICES[@]} -eq 0 ]; then
    echo "❌ Nenhum dispositivo ADB encontrado! Conecte via USB ou verifique o Wi-Fi."
    exit 1
fi

echo "Selecione o aparelho para espelhar:"
echo "--------------------------------------------------"
for i in "${!DEVICES[@]}"; do
    DEV="${DEVICES[$i]}"
    # Pega o modelo amigável do celular se possível
    MODEL=$(adb -s "$DEV" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    [ -z "$MODEL" ] && MODEL="Dispositivo $DEV"
    
    # Se for IP, exibe limpo; se for serial USB, avisa
    if [[ "$DEV" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        IP_PURA="$DEV"
    else
        # Tenta pegar o IP local caso esteja conectado só por USB
        IP_PURA=$(adb -s "$DEV" shell ip route 2>/dev/null | awk '{print $9}' | tail -n 1)
        [ -z "$IP_PURA" ] && IP_PURA="$DEV"
    fi

    echo " [$((i+1))] $MODEL (IP: $IP_PURA)"
done
echo "--------------------------------------------------"

# Lê a escolha do usuário com segurança
read -p "Digite o número da opção [1-${#DEVICES[@]}]: " ESCOLHA

# Valida se a entrada é um número válido
if ! [[ "$ESCOLHA" =~ ^[0-9]+$ ]] || [ "$ESCOLHA" -lt 1 ] || [ "$ESCOLHA" -gt "${#DEVICES[@]}" ]; then
    echo "❌ Opção inválida!"
    exit 1
fi

# Define o alvo com base na escolha
SELECIONADO="${DEVICES[$((ESCOLHA-1))]}"

# Extrai apenas o IP puro caso venha com a porta junto
IP_SELECIONADO=$(echo "$SELECIONADO" | cut -d: -f1)

# Se o item selecionado for um identificador USB e não um IP, tenta descobrir o IP atribuído a ele
if ! [[ "$IP_SELECIONADO" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    IP_SELECIONADO=$(adb -s "$SELECIONADO" shell ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
fi

if [ -z "$IP_SELECIONADO" ]; then
    # Fallback: pega o IP direto da conexão ADB se falhar no wlan0
    IP_SELECIONADO=$(adb -s "$SELECIONADO" get-serialno | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
fi

if [ -z "$IP_SELECIONADO" ]; then
    echo "❌ Não foi possível determinar o IP Wi-Fi do aparelho selecionado."
    exit 1
fi

echo ""
echo "🌐 Conectando via ADB em $IP_SELECIONADO:5555..."
adb connect "$IP_SELECIONADO:5555"
sleep 1

echo "🚀 Iniciando o scrcpy para $IP_SELECIONADO (Modo Estável sem Áudio)..."
scrcpy -s "$IP_SELECIONADO:5555" --no-audio --max-size=1080 --video-bit-rate=12M --max-fps=60
