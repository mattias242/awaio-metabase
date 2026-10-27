#!/bin/bash
#
# Awaio Windows/WSL2 Deployment Setup Script
# Kör detta script i WSL2 med Docker Desktop installerat
#
# Användning:
#   chmod +x windows-setup.sh
#   ./windows-setup.sh

set -e

# Färger för output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}
print_success() { echo -e "${GREEN}OK  $1${NC}"; }
print_warning() { echo -e "${YELLOW}!   $1${NC}"; }
print_error()   { echo -e "${RED}ERR $1${NC}"; }
print_info()    { echo -e "${BLUE}... $1${NC}"; }

# Byt till script-katalogen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

clear
print_header "Awaio Windows/WSL2 Deployment Setup"
echo ""
echo "Detta script sätter upp Awaio på Windows 11 via WSL2 och Docker Desktop."
echo ""

# Kontrollera att rätt compose-fil finns
if [ ! -f "docker-compose.yml" ]; then
    print_error "Kan inte hitta docker-compose.yml"
    print_error "Kör scriptet från Awaio-projektmappen!"
    exit 1
fi

# ============================================
# Steg 1: Kontrollera förutsättningar
# ============================================
print_header "Steg 1: Kontrollera förutsättningar"

# Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker är inte installerat eller inte i PATH"
    print_warning "Installera Docker Desktop for Windows och aktivera WSL2-integration"
    exit 1
fi
DOCKER_VERSION=$(docker --version)
print_success "Docker: $DOCKER_VERSION"

# Docker Compose (v2 syntax)
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose v2 saknas ('docker compose' fungerar inte)"
    print_warning "Uppgradera Docker Desktop till version 3.4.0+"
    exit 1
fi
COMPOSE_VERSION=$(docker compose version)
print_success "Compose: $COMPOSE_VERSION"

# Kontrollera att Docker daemon körs
if ! docker info &> /dev/null; then
    print_error "Docker Desktop verkar inte köra"
    print_warning "Starta Docker Desktop och försök igen"
    exit 1
fi
print_success "Docker Desktop körs"

# RAM-kontroll
TOTAL_MEM=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "0")
FREE_MEM=$(free -m 2>/dev/null | awk 'NR==2{print $7}' || echo "0")
if [ "$TOTAL_MEM" -gt 0 ]; then
    print_info "RAM: ${TOTAL_MEM} MB totalt, ${FREE_MEM} MB ledigt"
    if [ "$FREE_MEM" -lt 2000 ]; then
        print_warning "Mindre än 2 GB ledigt — rekommenderar minimal profil"
    fi
fi

# Port-kontroll
echo ""
print_info "Kontrollerar portar..."
for PORT in 5433 3000; do
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} " || netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        print_warning "Port $PORT verkar redan vara upptagen"
    else
        print_success "Port $PORT är ledig"
    fi
done

# ============================================
# Steg 2: Konfigurera .env
# ============================================
print_header "Steg 2: Konfigurera miljövariabler"

if [ -f ".env" ]; then
    print_warning ".env finns redan"
    read -p "Skriv över med .env.example? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp .env.example .env
        print_success ".env kopierad från .env.example"
    else
        print_info "Behåller befintlig .env"
    fi
else
    cp .env.example .env
    print_success ".env skapad från .env.example"
    print_warning "Uppdatera .env med dina Awaio API-credentials (AWAIO_CLIENT_ID / AWAIO_CLIENT_SECRET)"
fi

# ============================================
# Steg 3: Välj deployment-profil
# ============================================
print_header "Steg 3: Välj deployment-profil"

echo ""
echo "Välj vilken profil du vill använda:"
echo ""
echo "1) Minimal  (PostgreSQL + Metabase)       ~3 GB RAM"
echo "2) Admin    (+ pgAdmin)                   ~3.5 GB RAM"
echo "3) AI       (+ MindsDB + Chat)            ~5 GB RAM"
echo "4) Full     (alla tjänster)               ~6 GB RAM"
echo ""
read -p "Välj profil (1-4) [default: 1]: " -n 1 -r PROFILE_CHOICE
echo ""

case $PROFILE_CHOICE in
    2) PROFILE="--profile admin"; PROFILE_NAME="Admin" ;;
    3) PROFILE="--profile ai";    PROFILE_NAME="AI" ;;
    4) PROFILE="--profile full";  PROFILE_NAME="Full" ;;
    *) PROFILE="";                PROFILE_NAME="Minimal" ;;
esac

print_success "Profil: $PROFILE_NAME"

# ============================================
# Steg 4: Skapa kataloger
# ============================================
print_header "Steg 4: Skapa kataloger"

mkdir -p backups logs
chmod +x task_fetch_bookings_windows.sh task_backup_windows.sh 2>/dev/null || true
print_success "Kataloger skapade (backups, logs)"

# ============================================
# Steg 5: Pull och starta containers
# ============================================
print_header "Steg 5: Starta containers"

echo ""
read -p "Starta containers nu? (Y/n): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    print_info "Hämtar Docker images (kan ta några minuter)..."
    docker compose $PROFILE pull

    print_info "Startar containers..."
    docker compose $PROFILE up -d

    echo ""
    print_success "Containers startade!"

    print_info "Container-status:"
    docker compose ps
else
    print_info "Starta manuellt med:"
    echo "  docker compose $PROFILE up -d"
fi

# ============================================
# Steg 6: Erbjud Metabase-restore
# ============================================
print_header "Steg 6: Återställ Metabase-konfiguration"

METABASE_BACKUP="metabase/metabase_app_backup.sql.gz"

if [ -f "$METABASE_BACKUP" ]; then
    echo ""
    echo "Hittade Metabase-backup: $METABASE_BACKUP"
    echo "Återställning ger dig befintliga frågor, dashboards och samlingar."
    echo ""
    read -p "Återställ Metabase-konfiguration? (Y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_info "Väntar på att PostgreSQL ska bli redo..."
        RETRIES=0
        until docker compose exec -T postgres \
              pg_isready -U awaio_user &>/dev/null; do
            RETRIES=$((RETRIES+1))
            if [ $RETRIES -gt 30 ]; then
                print_error "PostgreSQL svarar inte efter 5 minuter — avbryter restore"
                break
            fi
            sleep 10
        done

        print_info "Skapar metabase_app-databasen om den inte finns..."
        docker compose exec -T postgres \
            psql -U awaio_user -c "CREATE DATABASE metabase_app OWNER awaio_user;" 2>/dev/null || true

        print_info "Återställer Metabase-data..."
        gunzip -c "$METABASE_BACKUP" | \
            docker compose exec -T postgres \
            psql -U awaio_user -d metabase_app

        if [ $? -eq 0 ]; then
            print_success "Metabase-konfiguration återställd!"
            print_info "Starta om Metabase för att ladda konfigurationen:"
            echo "  docker compose restart metabase"
        else
            print_error "Restore misslyckades — kontrollera loggarna"
        fi
    else
        print_info "Hoppar över Metabase-restore"
        print_info "Du kan återställa manuellt senare med:"
        echo "  gunzip -c $METABASE_BACKUP | docker compose exec -T postgres psql -U awaio_user -d metabase_app"
    fi
else
    print_warning "Ingen Metabase-backup hittad ($METABASE_BACKUP)"
    print_info "Lägg en existerande Metabase-dump i metabase/ för att återställa tidigare dashboards."
fi

# ============================================
# Steg 7: Schemalägg daglig backup (crontab)
# ============================================
print_header "Steg 7: Schemalägg daglig backup"

echo ""
echo "Vill du sätta upp crontab för daglig backup (kl 02:00)?"
echo "Datahämtning (fetch_bookings) körs manuellt — inte schemalagt."
echo ""
read -p "Sätt upp crontab för backup? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    CRON_BACKUP="0 2 * * * cd $SCRIPT_DIR && bash task_backup_windows.sh"

    # Ta bort ev. gammal fetch-cron och backup-cron innan vi lägger in den nya backup-raden
    (crontab -l 2>/dev/null | grep -v "task_fetch_bookings_windows\|task_backup_windows"; \
     echo "$CRON_BACKUP") | crontab -

    print_success "Crontab uppdaterad (backup)"
    crontab -l | grep "task_backup" | while read -r line; do
        echo "  $line"
    done
else
    print_info "Kör backup manuellt vid behov:"
    echo "  bash task_backup_windows.sh"
fi

echo ""
print_info "Hämta bookings manuellt (räknar ut datumintervall från senaste körning):"
echo "  bash task_fetch_bookings_windows.sh"

# ============================================
# Klar!
# ============================================
echo ""
print_header "Installation klar!"

echo ""
print_info "Access-URLer (localhost):"
echo "  Metabase:  http://localhost:3000"
if [[ "$PROFILE" == *"admin"* ]] || [[ "$PROFILE" == *"full"* ]]; then
    echo "  pgAdmin:   http://localhost:5050"
fi
if [[ "$PROFILE" == *"ai"* ]] || [[ "$PROFILE" == *"full"* ]]; then
    echo "  MindsDB:   http://localhost:47334"
    echo "  Chat App:  http://localhost:8501"
fi
echo "  PostgreSQL: localhost:5433 (POSTGRES_PORT=5433 för att undvika konflikt)"
echo ""
print_info "Hämta data från Awaio API:"
echo "  docker compose --profile tools run --rm fetcher python3 fetch_entities.py --stats"
echo "  docker compose --profile tools run --rm fetcher python3 fetch_bookings.py --date 2025-01-01 --days 30 --stats"
echo ""
print_info "Observera:"
echo "  - Docker Desktop måste köra för att containers ska starta"
echo "  - Aktivera 'Start Docker Desktop when you log in' i inställningarna"
echo "  - WSL2 cron: starta med 'sudo service cron start' (eller aktivera WSL autostart)"
echo ""
print_success "Tack för att du använder Awaio!"
echo ""
