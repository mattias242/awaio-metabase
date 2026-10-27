#!/bin/bash
#
# Awaio Windows/WSL2 Deployment Setup Script
# Run this script in WSL2 with Docker Desktop installed
#
# Usage:
#   chmod +x windows-setup.sh
#   ./windows-setup.sh

set -e

# Output colours
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

# Change to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

clear
print_header "Awaio Windows/WSL2 Deployment Setup"
echo ""
echo "This script sets up Awaio on Windows 11 via WSL2 and Docker Desktop."
echo ""

# Check that the compose file exists
if [ ! -f "docker-compose.yml" ]; then
    print_error "Cannot find docker-compose.yml"
    print_error "Run the script from the Awaio project folder!"
    exit 1
fi

# ============================================
# Step 1: Check prerequisites
# ============================================
print_header "Step 1: Check prerequisites"

# Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    print_warning "Install Docker Desktop for Windows and enable WSL2 integration"
    exit 1
fi
DOCKER_VERSION=$(docker --version)
print_success "Docker: $DOCKER_VERSION"

# Docker Compose (v2 syntax)
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose v2 is missing ('docker compose' does not work)"
    print_warning "Upgrade Docker Desktop to version 3.4.0+"
    exit 1
fi
COMPOSE_VERSION=$(docker compose version)
print_success "Compose: $COMPOSE_VERSION"

# Check that the Docker daemon is running
if ! docker info &> /dev/null; then
    print_error "Docker Desktop does not seem to be running"
    print_warning "Start Docker Desktop and try again"
    exit 1
fi
print_success "Docker Desktop is running"

# RAM check
TOTAL_MEM=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "0")
FREE_MEM=$(free -m 2>/dev/null | awk 'NR==2{print $7}' || echo "0")
if [ "$TOTAL_MEM" -gt 0 ]; then
    print_info "RAM: ${TOTAL_MEM} MB total, ${FREE_MEM} MB free"
    if [ "$FREE_MEM" -lt 2000 ]; then
        print_warning "Less than 2 GB free — the minimal profile is recommended"
    fi
fi

# Port check
echo ""
print_info "Checking ports..."
for PORT in 5433 3000; do
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} " || netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        print_warning "Port $PORT seems to be in use already"
    else
        print_success "Port $PORT is free"
    fi
done

# ============================================
# Step 2: Configure .env
# ============================================
print_header "Step 2: Configure environment variables"

if [ -f ".env" ]; then
    print_warning ".env already exists"
    read -p "Overwrite with .env.example? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp .env.example .env
        print_success ".env copied from .env.example"
    else
        print_info "Keeping the existing .env"
    fi
else
    cp .env.example .env
    print_success ".env created from .env.example"
    print_warning "Update .env with your Awaio API credentials (AWAIO_CLIENT_ID / AWAIO_CLIENT_SECRET)"
fi

# ============================================
# Step 3: Choose a deployment profile
# ============================================
print_header "Step 3: Choose a deployment profile"

echo ""
echo "Choose which profile to use:"
echo ""
echo "1) Minimal  (PostgreSQL + Metabase)       ~3 GB RAM"
echo "2) Admin    (+ pgAdmin)                   ~3.5 GB RAM"
echo "3) AI       (+ MindsDB + Chat)            ~5 GB RAM"
echo "4) Full     (all services)               ~6 GB RAM"
echo ""
read -p "Choose profile (1-4) [default: 1]: " -n 1 -r PROFILE_CHOICE
echo ""

case $PROFILE_CHOICE in
    2) PROFILE="--profile admin"; PROFILE_NAME="Admin" ;;
    3) PROFILE="--profile ai";    PROFILE_NAME="AI" ;;
    4) PROFILE="--profile full";  PROFILE_NAME="Full" ;;
    *) PROFILE="";                PROFILE_NAME="Minimal" ;;
esac

print_success "Profile: $PROFILE_NAME"

# ============================================
# Step 4: Create directories
# ============================================
print_header "Step 4: Create directories"

mkdir -p backups logs
chmod +x task_fetch_bookings_windows.sh task_backup_windows.sh 2>/dev/null || true
print_success "Directories created (backups, logs)"

# ============================================
# Step 5: Pull and start containers
# ============================================
print_header "Step 5: Start containers"

echo ""
read -p "Start containers now? (Y/n): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    print_info "Pulling Docker images (may take a few minutes)..."
    docker compose $PROFILE pull

    print_info "Starting containers..."
    docker compose $PROFILE up -d

    echo ""
    print_success "Containers started!"

    print_info "Container-status:"
    docker compose ps
else
    print_info "Start manually with:"
    echo "  docker compose $PROFILE up -d"
fi

# ============================================
# Step 6: Offer a Metabase restore
# ============================================
print_header "Step 6: Restore the Metabase configuration"

METABASE_BACKUP="metabase/metabase_app_backup.sql.gz"

if [ -f "$METABASE_BACKUP" ]; then
    echo ""
    echo "Found a Metabase backup: $METABASE_BACKUP"
    echo "Restoring gives you the existing questions, dashboards and collections."
    echo ""
    read -p "Restore the Metabase configuration? (Y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_info "Waiting for PostgreSQL to become ready..."
        RETRIES=0
        until docker compose exec -T postgres \
              pg_isready -U awaio_user &>/dev/null; do
            RETRIES=$((RETRIES+1))
            if [ $RETRIES -gt 30 ]; then
                print_error "PostgreSQL not responding after 5 minutes — aborting restore"
                break
            fi
            sleep 10
        done

        print_info "Creating the metabase_app database if it does not exist..."
        docker compose exec -T postgres \
            psql -U awaio_user -c "CREATE DATABASE metabase_app OWNER awaio_user;" 2>/dev/null || true

        print_info "Restoring Metabase data..."
        gunzip -c "$METABASE_BACKUP" | \
            docker compose exec -T postgres \
            psql -U awaio_user -d metabase_app

        if [ $? -eq 0 ]; then
            print_success "Metabase configuration restored!"
            print_info "Restart Metabase to load the configuration:"
            echo "  docker compose restart metabase"
        else
            print_error "Restore failed — check the logs"
        fi
    else
        print_info "Skipping the Metabase restore"
        print_info "You can restore manually later with:"
        echo "  gunzip -c $METABASE_BACKUP | docker compose exec -T postgres psql -U awaio_user -d metabase_app"
    fi
else
    print_warning "No Metabase backup found ($METABASE_BACKUP)"
    print_info "Put an existing Metabase dump in metabase/ to restore earlier dashboards."
fi

# ============================================
# Step 7: Schedule a daily backup (crontab)
# ============================================
print_header "Step 7: Schedule a daily backup"

echo ""
echo "Do you want to set up a crontab entry for a daily backup (at 02:00)?"
echo "Data fetching (fetch_bookings) is run by the scheduler container, not here."
echo ""
read -p "Set up a crontab entry for backups? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    CRON_BACKUP="0 2 * * * cd $SCRIPT_DIR && bash task_backup_windows.sh"

    # Remove any old fetch and backup cron lines before adding the new backup line
    (crontab -l 2>/dev/null | grep -v "task_fetch_bookings_windows\|task_backup_windows"; \
     echo "$CRON_BACKUP") | crontab -

    print_success "Crontab updated (backup)"
    crontab -l | grep "task_backup" | while read -r line; do
        echo "  $line"
    done
else
    print_info "Run the backup manually when needed:"
    echo "  bash task_backup_windows.sh"
fi

echo ""
print_info "Fetch bookings manually (works out the date range from the last run):"
echo "  bash task_fetch_bookings_windows.sh"

# ============================================
# Done!
# ============================================
echo ""
print_header "Installation complete!"

echo ""
print_info "Access URLs (localhost):"
echo "  Metabase:  http://localhost:3000"
if [[ "$PROFILE" == *"admin"* ]] || [[ "$PROFILE" == *"full"* ]]; then
    echo "  pgAdmin:   http://localhost:5050"
fi
if [[ "$PROFILE" == *"ai"* ]] || [[ "$PROFILE" == *"full"* ]]; then
    echo "  MindsDB:   http://localhost:47334"
    echo "  Chat App:  http://localhost:8501"
fi
echo "  PostgreSQL: localhost:5433 (POSTGRES_PORT=5433 to avoid a conflict)"
echo ""
print_info "Fetch data from the Awaio API:"
echo "  docker compose --profile tools run --rm fetcher python3 fetch_entities.py --stats"
echo "  docker compose --profile tools run --rm fetcher python3 fetch_bookings.py --date 2025-01-01 --days 30 --stats"
echo ""
print_info "Note:"
echo "  - Docker Desktop must be running for the containers to start"
echo "  - Enable 'Start Docker Desktop when you log in' in the settings"
echo "  - WSL2 cron: start it with 'sudo service cron start' (or enable WSL autostart)"
echo ""
print_success "Thanks for using Awaio!"
echo ""
