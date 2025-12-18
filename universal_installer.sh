#!/bin/bash

# ==============================================================================
# TITULO: Universal Installer TUI (UIT)
# DESCRIÇÃO: Script Híbrido (CLI/TUI) para instalação de pacotes
# AUTOR: Gemini
# DEPENDÊNCIAS: whiptail, unzip, tar, sudo, xdg-open
# ==============================================================================

# Cores para logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificação de dependências
check_dependencies() {
    if ! command -v whiptail &> /dev/null; then
        echo -e "${RED}Erro: 'whiptail' não encontrado.${NC}"
        echo "Instalando whiptail..."
        sudo apt-get update && sudo apt-get install whiptail -y
    fi
}

# Função de Ajuda (Modo TUI/Gráfico)
show_help() {
    whiptail --title "Ajuda do Sistema" --msgbox "UNIVERSAL INSTALLER TOOL (UIT)\n\nMODOS DE USO:\n\n1. INTERATIVO:\n   Apenas execute 'uit' (ou uit -gui) para abrir o menu.\n\n2. DIRETO (Linha de Comando):\n   Execute 'uit nome_do_arquivo' para instalação rápida.\n   Ex: uit programa.tar.gz\n\nO script detecta automaticamente a extensão e sugere a instalação.\n\nPressione <OK> para voltar." 18 78
}

# Função de Ajuda (Modo CLI/Terminal)
print_cli_help() {
    echo -e "${GREEN}UNIVERSAL INSTALLER TOOL (UIT)${NC}"
    echo "---------------------------------------------------"
    echo "Ferramenta unificada para instalação e extração de pacotes."
    echo ""
    echo -e "${YELLOW}USO:${NC}"
    echo "  uit [OPÇÃO] [ARQUIVO]"
    echo ""
    echo -e "${YELLOW}OPÇÕES:${NC}"
    echo "  -gui          : Abre a interface interativa (Menu Principal) explicitamente."
    echo "  -help         : Exibe estas instruções de uso no terminal e sai."
    echo "  [ARQUIVO]     : Tenta instalar/extrair o arquivo especificado diretamente."
    echo ""
    echo -e "${YELLOW}EXEMPLOS:${NC}"
    echo "  uit                   # Inicia modo interativo (padrão)"
    echo "  uit -gui              # Força modo interativo"
    echo "  uit -help             # Mostra ajuda rápida"
    echo "  uit app_1.0.deb       # Instala pacote .deb via APT"
    echo "  uit script.tar.gz     # Extrai arquivo compactado"
    echo ""
}

# Função para detectar tipo de arquivo automaticamente baseado na extensão
detect_file_type() {
    local filename="$1"
    if [[ "$filename" == *.deb ]]; then
        echo ".deb"
    elif [[ "$filename" == *.tar.gz ]]; then
        echo ".tar.gz"
    elif [[ "$filename" == *.tar.xz ]]; then
        echo ".tar.xz"
    elif [[ "$filename" == *.zip ]]; then
        echo ".zip"
    elif [[ "$filename" == *.AppImage ]]; then
        echo ".AppImage"
    else
        echo "UNKNOWN"
    fi
}

# Função para listar arquivos (Modo Interativo)
scan_files() {
    local ext=$1
    files_list=()
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            files_list+=("$file" "Arquivo Local")
        fi
    done < <(find . -maxdepth 1 -name "*$ext" -printf "%f\n")
    files_list+=("OUTRO" "Especificar caminho manual")
}

# Menu Principal (Modo Interativo)
main_menu() {
    while true; do
        CHOICE=$(whiptail --title "UIT - Gerenciador de Instalação" --menu "Escolha uma opção:" 15 60 4 \
        "1" "Iniciar Instalação (Buscar Arquivos)" \
        "2" "Ajuda / Sobre" \
        "3" "Sair" 3>&1 1>&2 2>&3)

        if [ $? -eq 0 ]; then
            case $CHOICE in
                1) start_install_flow ;; # Sem argumentos = modo interativo
                2) show_help ;;
                3) exit 0 ;;
            esac
        else
            exit 0
        fi
    done
}

# Fluxo de Instalação (Unificado)
start_install_flow() {
    local input_file="$1" # Recebe argumento opcional
    
    # === ETAPA 1 e 2: DEFINIÇÃO DO ARQUIVO E TIPO ===
    
    if [ -n "$input_file" ]; then
        # MODO DIRETO: Arquivo passado via linha de comando
        if [ ! -f "$input_file" ]; then
            whiptail --title "Erro" --msgbox "O arquivo especificado não foi encontrado:\n$input_file" 10 60
            exit 1
        fi
        
        SELECTED_FILE="$input_file"
        FILE_TYPE=$(detect_file_type "$SELECTED_FILE")
        
        if [ "$FILE_TYPE" == "UNKNOWN" ]; then
            whiptail --title "Erro" --msgbox "Tipo de arquivo não suportado ou desconhecido.\nExtensões suportadas: .deb, .zip, .tar.gz, .tar.xz, .AppImage" 12 60
            exit 1
        fi
        
    else
        # MODO INTERATIVO: Pergunta tipo e lista arquivos
        FILE_TYPE=$(whiptail --title "Tipo de Arquivo" --menu "Qual a extensão do arquivo?" 15 60 5 \
        ".deb" "Pacote Debian" \
        ".tar.gz" "Arquivo GZip" \
        ".zip" "Arquivo Zip" \
        ".AppImage" "Executável Portátil" \
        ".tar.xz" "Arquivo XZ" 3>&1 1>&2 2>&3)

        if [ -z "$FILE_TYPE" ]; then return; fi

        scan_files "$FILE_TYPE"
        
        if [ ${#files_list[@]} -le 2 ]; then
             whiptail --title "Aviso" --msgbox "Nenhum arquivo $FILE_TYPE na pasta atual." 10 60
             SELECTED_FILE="OUTRO"
        else
            SELECTED_FILE=$(whiptail --title "Seleção de Arquivo" --menu "Selecione o arquivo:" 15 70 5 "${files_list[@]}" 3>&1 1>&2 2>&3)
        fi

        if [ "$SELECTED_FILE" == "OUTRO" ]; then
            SELECTED_FILE=$(whiptail --title "Caminho Manual" --inputbox "Digite o caminho completo:" 10 60 3>&1 1>&2 2>&3)
            if [ ! -f "$SELECTED_FILE" ]; then
                whiptail --title "Erro" --msgbox "Arquivo não encontrado!" 10 60
                return
            fi
        fi
    fi

    # === ETAPA 3: DESTINO ===
    
    DEFAULT_DEST="/opt"
    if [[ "$FILE_TYPE" == ".deb" ]]; then
        DESTINATION="/" 
        MSG_DEST="Pacote .deb detectado. Instalação será global via APT."
    else
        MSG_DEST="Destino da instalação para $SELECTED_FILE:"
    fi

    if [[ "$FILE_TYPE" != ".deb" ]]; then
        DESTINATION=$(whiptail --title "Diretório de Destino" --inputbox "$MSG_DEST" 10 60 "$DEFAULT_DEST" 3>&1 1>&2 2>&3)
    else
        whiptail --title "Confirmação" --msgbox "$MSG_DEST" 10 60
    fi
    
    if [ $? -ne 0 ]; then return; fi # Cancelado pelo usuário

    # === ETAPA 4: CONFIRMAÇÃO FINAL ===
    
    if (whiptail --title "Confirmar Instalação" --yesno "Resumo:\n\nArquivo: $SELECTED_FILE\nTipo: $FILE_TYPE\nDestino: $DESTINATION\n\nProceder?" 15 60); then
        perform_installation "$FILE_TYPE" "$SELECTED_FILE" "$DESTINATION"
    else
        # Se estiver no modo direto e cancelar, sai do script
        if [ -n "$input_file" ]; then exit 0; else return; fi
    fi
}

perform_installation() {
    local type=$1
    local file=$2
    local dest=$3
    
    clear
    echo -e "${GREEN}>>> INICIANDO OPERAÇÃO (UIT)${NC}"
    echo "---------------------------------------------------"
    echo -e "Alvo: ${YELLOW}$file${NC}"
    echo -e "Destino: ${YELLOW}$dest${NC}"
    echo "---------------------------------------------------"

    # Criação de pasta (se necessário e não for .deb)
    if [[ "$type" != ".deb" ]]; then
        if [ ! -d "$dest" ]; then
            echo -e "Criando diretório: $dest"
            # Se falhar mkdir normal, tenta sudo
            mkdir -p "$dest" 2>/dev/null || sudo mkdir -p "$dest"
        fi
    fi

    case $type in
        ".deb")
            sudo apt install "$file" -y
            ;;
        ".tar.gz"|".tar.xz")
            sudo tar -xvf "$file" -C "$dest"
            ;;
        ".zip")
            sudo unzip "$file" -d "$dest"
            ;;
        ".AppImage")
            sudo chmod +x "$file"
            sudo cp "$file" "$dest/"
            ;;
    esac

    EXIT_CODE=$?

    echo "---------------------------------------------------"
    read -p "Processo finalizado. Pressione [ENTER]..."

    if [ $EXIT_CODE -eq 0 ]; then
        post_install_actions "$dest" "Sucesso" "Operação concluída com sucesso!"
    else
        post_install_actions "$dest" "Erro" "Ocorreu um erro (Código $EXIT_CODE)."
    fi
}

post_install_actions() {
    local dest=$1
    local title=$2
    local msg=$3

    whiptail --title "$title" --msgbox "$msg" 10 60

    if (whiptail --title "Explorar" --yesno "Abrir pasta de instalação?" 10 60); then
        # Tenta abrir como usuário normal mesmo se script for sudo
        if [ -n "$SUDO_USER" ]; then
            sudo -u "$SUDO_USER" xdg-open "$dest" > /dev/null 2>&1 &
        else
            xdg-open "$dest" > /dev/null 2>&1 &
        fi
    fi
    
    clear
    exit 0
}

# === PONTO DE ENTRADA DO SCRIPT ===

# Verifica primeiro se é help (para não exigir whiptail apenas para ver o help)
if [[ "$1" == "-help" || "$1" == "--help" || "$1" == "-h" ]]; then
    print_cli_help
    exit 0
fi

check_dependencies

case "$1" in
    "-gui")
        # Força o modo interativo explicitamente
        main_menu
        ;;
    "")
        # Sem argumentos, também inicia o modo interativo
        main_menu
        ;;
    *)
        # Qualquer outro argumento é tratado como arquivo para instalação
        start_install_flow "$1"
        ;;
esac
