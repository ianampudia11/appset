#!/bin/bash


set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCES_DIR="$SCRIPT_DIR/instances"
MIN_APP_PORT=9000
MAX_APP_PORT=9999
MIN_DB_PORT=5432
MAX_DB_PORT=5532

print_header() {
    cat << EOF
${PURPLE}
╔═══════════════════════════════════════════════════════════════╗
║              PowerChat Plus - Multi-Instance Deploy          ║
║                                                               ║
║  Deploy multiple isolated instances using production build   ║
║  with automatic port detection and conflict resolution.      ║
╚═══════════════════════════════════════════════════════════════╝
${NC}

EOF
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local validator="$4"
    
    while true; do
        if [ -n "$default" ]; then
            echo -n "$prompt [$default]: "
        else
            echo -n "$prompt: "
        fi
        
        read -r input
        if [ -z "$input" ] && [ -n "$default" ]; then
            input="$default"
        fi
        
        if [ -n "$validator" ] && ! $validator "$input"; then
            continue
        fi
        
        eval "$var_name='$input'"
        break
    done
}

validate_instance_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        print_error "Instance name must start with alphanumeric character and contain only letters, numbers, hyphens, and underscores"
        return 1
    fi
    
    if [ ${#name} -lt 3 ] || [ ${#name} -gt 30 ]; then
        print_error "Instance name must be between 3 and 30 characters"
        return 1
    fi
    
    if [ -d "$INSTANCES_DIR/$name" ]; then
        print_error "Instance '$name' already exists"
        return 1
    fi
    
    return 0
}

validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Please enter a valid email address"
        return 1
    fi
    return 0
}

validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
        print_error "Port must be a number between 1024 and 65535"
        return 1
    fi
    return 0
}

is_port_available() {
    local port="$1"
    local docker_cmd="docker"
    if needs_sudo_docker; then
        docker_cmd="sudo docker"
    fi
    ! netstat -tuln 2>/dev/null | grep -q ":$port " && \
    ! $docker_cmd ps --format "table {{.Ports}}" 2>/dev/null | grep -q ":$port->" && \
    ! ss -tuln 2>/dev/null | grep -q ":$port "
}

find_available_port() {
    local start_port="$1"
    local max_port="$2"
    
    for ((port=start_port; port<=max_port; port++)); do
        if is_port_available "$port"; then
            echo "$port"
            return 0
        fi
    done
    
    print_error "No available ports found in range $start_port-$max_port"
    return 1
}

generate_session_secret() {
    openssl rand -base64 32 2>/dev/null | tr -d "=+/" | cut -c1-32
}

generate_encryption_key() {
    openssl rand -hex 32 2>/dev/null
}

generate_password() {
    openssl rand -base64 16 2>/dev/null | tr -d "=+/" | cut -c1-16
}

# Helper to determine if we need sudo for docker commands
needs_sudo_docker() {
    if docker info &> /dev/null 2>&1; then
        return 1  # No sudo needed
    else
        # Check if it's a permission issue
        local error=$(docker info 2>&1)
        if echo "$error" | grep -q "permission denied\|Got permission denied"; then
            return 0  # Sudo needed
        fi
        return 1  # Other error, not permission
    fi
}

# Wrapper for docker compose commands
docker_compose_cmd() {
    if needs_sudo_docker; then
        sudo docker compose "$@"
    else
        docker compose "$@"
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

install_docker() {
    print_step "Installing Docker..."
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        print_status "This operation requires sudo privileges. You may be prompted for your password."
    fi
    
    local os=$(detect_os)
    
    case "$os" in
        ubuntu|debian)
            print_status "Installing Docker on Ubuntu/Debian..."
            # Remove old versions
            sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            
            # Update package index
            sudo apt-get update -qq
            
            # Install prerequisites
            sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release >/dev/null 2>&1
            
            # Add Docker's official GPG key
            sudo install -m 0755 -d /etc/apt/keyrings 2>/dev/null || true
            curl -fsSL https://download.docker.com/linux/$os/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
            sudo chmod a+r /etc/apt/keyrings/docker.gpg 2>/dev/null || true
            
            # Set up repository
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$os \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt-get update -qq
            sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
            
            # Add current user to docker group
            sudo usermod -aG docker $USER 2>/dev/null || true
            
            # Start Docker service
            sudo systemctl start docker 2>/dev/null || true
            sudo systemctl enable docker 2>/dev/null || true
            ;;
        rhel|centos|fedora)
            print_status "Installing Docker on RHEL/CentOS/Fedora..."
            # Remove old versions
            sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
            
            # Install prerequisites
            sudo yum install -y -q yum-utils >/dev/null 2>&1
            
            # Add Docker repository
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
            
            # Install Docker
            sudo yum install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
            
            # Start Docker service
            sudo systemctl start docker 2>/dev/null || true
            sudo systemctl enable docker 2>/dev/null || true
            
            # Add current user to docker group
            sudo usermod -aG docker $USER 2>/dev/null || true
            ;;
        *)
            print_error "Unsupported operating system: $os"
            print_error "Please install Docker manually from https://docs.docker.com/get-docker/"
            return 1
            ;;
    esac
    
    # Wait a moment for Docker to be ready
    sleep 2
    
    # Verify installation
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        print_success "Docker installed successfully"
        print_warning "Note: You may need to log out and log back in for Docker group changes to take effect"
        print_warning "Or run: newgrp docker"
        return 0
    else
        print_error "Docker installation completed but verification failed"
        return 1
    fi
}

install_docker_compose() {
    print_step "Installing Docker Compose..."
    
    # Docker Compose plugin is usually installed with Docker
    # But if not, we'll install it separately
    if command -v docker &> /dev/null; then
        # Check if compose plugin is available
        if docker compose version &> /dev/null; then
            print_success "Docker Compose plugin is already available"
            return 0
        fi
    fi
    
    # Try to install compose plugin
    local os=$(detect_os)
    
    case "$os" in
        ubuntu|debian)
            sudo apt-get update -qq >/dev/null 2>&1
            sudo apt-get install -y -qq docker-compose-plugin >/dev/null 2>&1
            ;;
        rhel|centos|fedora)
            sudo yum install -y -q docker-compose-plugin >/dev/null 2>&1
            ;;
        *)
            print_error "Could not auto-install Docker Compose plugin"
            print_error "Please install manually: https://docs.docker.com/compose/install/"
            return 1
            ;;
    esac
    
    # Verify installation
    sleep 1
    if docker compose version &> /dev/null; then
        print_success "Docker Compose installed successfully"
        return 0
    else
        print_error "Docker Compose installation completed but verification failed"
        return 1
    fi
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check for OpenSSL
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is required but not installed"
        print_error "Please install OpenSSL: sudo apt-get install openssl (Ubuntu/Debian) or sudo yum install openssl (RHEL/CentOS)"
        exit 1
    fi
    
    # Check and install Docker if needed
    if ! command -v docker &> /dev/null; then
        print_warning "Docker is not installed. Installing automatically..."
        if ! install_docker; then
            print_error "Failed to install Docker automatically"
            print_error "Please install Docker manually from https://docs.docker.com/get-docker/"
            exit 1
        fi
    else
        print_success "Docker is installed"
    fi
    
    # Check and install Docker Compose if needed
    if ! docker compose version &> /dev/null; then
        print_warning "Docker Compose is not installed or not working. Installing automatically..."
        if ! install_docker_compose; then
            print_error "Failed to install Docker Compose automatically"
            print_error "Please install Docker Compose manually from https://docs.docker.com/compose/install/"
            exit 1
        fi
    else
        print_success "Docker Compose is installed"
    fi
    
    # Check if Docker daemon is running and accessible
    if ! docker info &> /dev/null; then
        # Check if it's a permission issue
        local docker_error=$(docker info 2>&1)
        if echo "$docker_error" | grep -q "permission denied\|Got permission denied"; then
            print_warning "Docker group membership not active in current session"
            print_status "Attempting to use sudo for Docker commands..."
            
            # Verify sudo docker works
            if sudo docker info &> /dev/null; then
                print_warning "Using sudo for Docker commands in this session"
                print_warning "After installation, you can run 'newgrp docker' to avoid sudo"
                # Note: We'll need to use sudo docker in subsequent commands
                # The script will handle this by checking if docker works, and using sudo if needed
            else
                print_error "Cannot access Docker even with sudo"
                print_error "Please ensure Docker is properly installed and the daemon is running"
                exit 1
            fi
        else
            # Docker daemon is not running
            print_error "Docker daemon is not running"
            print_status "Attempting to start Docker daemon..."
            
            # Try to start Docker service
            if command -v systemctl &> /dev/null; then
                sudo systemctl start docker 2>/dev/null || {
                    print_error "Could not start Docker daemon automatically"
                    print_error "Please start Docker manually: sudo systemctl start docker"
                    exit 1
                }
            else
                print_error "Please start Docker daemon manually"
                exit 1
            fi
            
            # Wait a moment for Docker to start
            sleep 2
            
            # Verify Docker is running (try with sudo if needed)
            if ! docker info &> /dev/null && ! sudo docker info &> /dev/null; then
                print_error "Docker daemon is still not accessible"
                print_error "Please ensure Docker is installed and running, then try again"
                exit 1
            fi
        fi
    fi
    
    print_success "All prerequisites are met"
}

install_dependencies() {
    print_step "Verifying deployment files..."
    
    # Only check for package.json - node_modules will be installed in Docker
    if [ ! -f "package.json" ]; then
        print_error "package.json not found. Please run this script from the share directory."
        exit 1
    fi
    
    print_success "Deployment files verified (dependencies will be installed in Docker)"
}

verify_deployment_files() {
    print_step "Verifying deployment files..."
    
    local required_files=(
        "dist/index.js"
        "dist/public"
        "package.json"
        "migrations"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -e "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "Missing required files: ${missing_files[*]}"
        echo
        echo "This script must be run from the PowerChat Plus share directory"
        echo "containing the pre-compiled production build."
        echo
        echo "Required files:"
        echo "  - dist/index.js (compiled server)"
        echo "  - dist/public (compiled client)"
        echo "  - package.json (dependencies)"
        echo "  - migrations (database migrations)"
        exit 1
    fi
    
    if [ ! -s "dist/index.js" ]; then
        print_error "dist/index.js is empty. Please ensure you have a valid production build."
        exit 1
    fi
    
    if [ ! -d "dist/public" ] || [ -z "$(ls -A dist/public 2>/dev/null)" ]; then
        print_error "dist/public directory is missing or empty. Please ensure you have a valid client build."
        exit 1
    fi
    
    print_success "All required files are present"
}

collect_instance_config() {
    print_step "Configuring new PowerChat Plus instance..."
    echo

    prompt_with_default "Instance name (3-30 chars, alphanumeric, hyphens, underscores)" "" INSTANCE_NAME validate_instance_name

    local default_db_name=$(echo "$INSTANCE_NAME" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
    prompt_with_default "Database name" "${default_db_name}_db" DATABASE_NAME

    prompt_with_default "Company/Organization name" "My Company" COMPANY_NAME

    prompt_with_default "Admin email address" "admin@${INSTANCE_NAME}.com" ADMIN_EMAIL validate_email
    prompt_with_default "Admin username" "$ADMIN_EMAIL" ADMIN_USERNAME
    prompt_with_default "Admin full name" "Super Admin" ADMIN_FULL_NAME

    local generated_password=$(generate_password)
    prompt_with_default "Admin password" "$generated_password" ADMIN_PASSWORD

    local suggested_app_port=$(find_available_port $MIN_APP_PORT $MAX_APP_PORT)
    local suggested_db_port=$(find_available_port $MIN_DB_PORT $MAX_DB_PORT)

    prompt_with_default "Application port" "$suggested_app_port" APP_PORT validate_port
    prompt_with_default "Database port" "$suggested_db_port" DB_PORT validate_port

    if ! is_port_available "$APP_PORT"; then
        print_error "Port $APP_PORT is no longer available"
        exit 1
    fi

    if ! is_port_available "$DB_PORT"; then
        print_error "Port $DB_PORT is no longer available"
        exit 1
    fi

    SESSION_SECRET=$(generate_session_secret)
    ENCRYPTION_KEY=$(generate_encryption_key)
    DB_PASSWORD=$(generate_password)

    echo
    print_status "Configuration Summary:"
    echo "  Instance Name: $INSTANCE_NAME"
    echo "  Database Name: $DATABASE_NAME"
    echo "  Company Name: $COMPANY_NAME"
    echo "  Admin Email: $ADMIN_EMAIL"
    echo "  Admin Username: $ADMIN_USERNAME"
    echo "  Application Port: $APP_PORT"
    echo "  Database Port: $DB_PORT"
    echo "  Secure secrets: Generated automatically"
    echo
}

confirm_deployment() {
    echo -n "Deploy this PowerChat Plus instance? (Y/n): "
    read -r confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        print_status "Deployment cancelled by user."
        exit 0
    fi
}

create_instance_files() {
    print_step "Creating instance files..."

    mkdir -p "$INSTANCES_DIR/$INSTANCE_NAME"
    local instance_dir="$INSTANCES_DIR/$INSTANCE_NAME"

    cat > "$instance_dir/.env" << EOF

DATABASE_URL=postgresql://powerchat:$DB_PASSWORD@postgres-$INSTANCE_NAME:5432/$DATABASE_NAME
POSTGRES_DB=$DATABASE_NAME
POSTGRES_USER=powerchat
POSTGRES_PASSWORD=$DB_PASSWORD
PGSSLMODE=disable

NODE_ENV=production
PORT=9000
APP_PORT=$APP_PORT
DB_PORT=$DB_PORT

SESSION_SECRET=$SESSION_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY
FORCE_INSECURE_COOKIE=true

ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_FULL_NAME=$ADMIN_FULL_NAME
ADMIN_PASSWORD=$ADMIN_PASSWORD

COMPANY_NAME=$COMPANY_NAME

LOG_LEVEL=INFO

INSTANCE_NAME=$INSTANCE_NAME
CREATED_DATE=$(date -Iseconds)
EOF

    cat > "$instance_dir/docker-compose.yml" << EOF
services:
  postgres-$INSTANCE_NAME:
    image: postgres:16
    container_name: powerchat-postgres-$INSTANCE_NAME
    restart: unless-stopped
    environment:
      POSTGRES_DB: $DATABASE_NAME
      POSTGRES_USER: powerchat
      POSTGRES_PASSWORD: $DB_PASSWORD
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_data_$INSTANCE_NAME:/var/lib/postgresql/data
    ports:
      - "$DB_PORT:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U powerchat -d $DATABASE_NAME"]
      interval: 10s
      timeout: 5s
      retries: 5

  app-$INSTANCE_NAME:
    build:
      context: ../../
      dockerfile: Dockerfile.simple
    container_name: powerchat-app-$INSTANCE_NAME
    restart: unless-stopped
    depends_on:
      postgres-$INSTANCE_NAME:
        condition: service_started
    env_file:
      - .env
    environment:
      - DOCKER_CONTAINER=true
    ports:
      - "$APP_PORT:9000"
    volumes:
      - app_uploads_$INSTANCE_NAME:/app/uploads
      - app_whatsapp_sessions_$INSTANCE_NAME:/app/whatsapp-sessions
      - app_data_$INSTANCE_NAME:/app/data
      - ../../migrations:/app/migrations
   

# Use shared network to avoid subnet exhaustion
networks:
  default:
    external: true
    name: powerchat-shared-network

volumes:
  postgres_data_$INSTANCE_NAME:
    driver: local
    name: powerchat-postgres-data-$INSTANCE_NAME
  app_uploads_$INSTANCE_NAME:
    driver: local
    name: powerchat-app-uploads-$INSTANCE_NAME
  app_whatsapp_sessions_$INSTANCE_NAME:
    driver: local
    name: powerchat-app-whatsapp-sessions-$INSTANCE_NAME
  app_data_$INSTANCE_NAME:
    driver: local
    name: powerchat-app-data-$INSTANCE_NAME
EOF

    cat > "$instance_dir/manage.sh" << 'EOF'

INSTANCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCE_NAME="$(basename "$INSTANCE_DIR")"

case "${1:-status}" in
    "start")
        echo "Starting instance $INSTANCE_NAME..."
        docker compose -f "$INSTANCE_DIR/docker-compose.yml" up -d
        ;;
    "stop")
        echo "Stopping instance $INSTANCE_NAME..."
        docker compose -f "$INSTANCE_DIR/docker-compose.yml" down
        ;;
    "restart")
        echo "Restarting instance $INSTANCE_NAME..."
        docker compose -f "$INSTANCE_DIR/docker-compose.yml" restart
        ;;
    "logs")
        docker compose -f "$INSTANCE_DIR/docker-compose.yml" logs -f
        ;;
    "status")
        docker compose -f "$INSTANCE_DIR/docker-compose.yml" ps
        ;;
    "clean")
        echo "WARNING: This will remove all data for instance $INSTANCE_NAME"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker compose -f "$INSTANCE_DIR/docker-compose.yml" down -v --rmi all
            echo "Instance $INSTANCE_NAME cleaned"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|clean}"
        exit 1
        ;;
esac
EOF

    chmod +x "$instance_dir/manage.sh"

    cat > "$instance_dir/backup.sh" << EOF
#!/bin/bash

set -e

# --------------------------------------------
# Docker Backup & Restore Tool
# Full: Volumes + DB + Images + Compose
# Tailored for $INSTANCE_NAME
# --------------------------------------------

BACKUP_DIR="./backup"
COMPOSE_FILE="docker-compose.yml"
TIMESTAMP=\$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="\$BACKUP_DIR/backup_\$TIMESTAMP"

# Postgres details
DB_NAME="$DATABASE_NAME"
DB_USER="powerchat"

# Docker volumes to backup
VOLUMES=(
  "powerchat-postgres-data-$INSTANCE_NAME"
  "powerchat-app-uploads-$INSTANCE_NAME"
  "powerchat-app-whatsapp-sessions-$INSTANCE_NAME"
  "powerchat-app-data-$INSTANCE_NAME"
)

# Docker containers to save images
CONTAINERS=(
  "powerchat-postgres-$INSTANCE_NAME"
  "powerchat-app-$INSTANCE_NAME"
)

mkdir -p "\$BACKUP_DIR"

show_menu() {
  clear
  echo "=============================="
  echo " Docker Backup & Restore Tool"
  echo "=============================="
  echo "1) Create Backup"
  echo "2) Restore Backup"
  echo "3) Exit"
  echo "------------------------------"
}

get_images() {
  IMAGES=()
  for c in "\${CONTAINERS[@]}"; do
    if docker inspect "\$c" >/dev/null 2>&1; then
      img=\$(docker inspect "\$c" -f '{{.Image}}')
      IMAGES+=("\$img")
      echo "✔️ Found image: \$img"
    else
      echo "⚠️ Container not found: \$c (skipping image)"
    fi
  done
}

backup() {
  mkdir -p "\$BACKUP_PATH"
  echo ""
  echo "➡️  Creating DB dump..."

  # Start Postgres temporarily for backup
  docker compose up -d "postgres-$INSTANCE_NAME"

  echo "⏳ Waiting for PostgreSQL to be ready..."
  POSTGRES_CONTAINER="powerchat-postgres-$INSTANCE_NAME"
  until docker exec \$POSTGRES_CONTAINER pg_isready -U \$DB_USER -d \$DB_NAME >/dev/null 2>&1; do
    sleep 2
  done

  docker exec \$POSTGRES_CONTAINER pg_dump -U \$DB_USER \$DB_NAME > "\$BACKUP_PATH/db_backup.sql"
  echo "✔️ Database backup saved as db_backup.sql"

  echo ""
  echo "➡️  Stopping containers..."
  docker compose down

  echo ""
  echo "➡️  Saving Docker images..."
  get_images
  for img in "\${IMAGES[@]}"; do
    safe_img=\$(echo "\$img" | tr "/:" "_")
    docker save "\$img" -o "\$BACKUP_PATH/image_\$safe_img.tar"
    echo "✔️ Image saved: \$img"
  done

  echo ""
  echo "➡️  Backing up volumes..."
  mkdir -p "\$BACKUP_PATH/volumes"
  for vol in "\${VOLUMES[@]}"; do
    echo "   📦 Exporting \$vol ..."
    docker run --rm -v "\$vol:/source" -v "\$BACKUP_PATH/volumes:/backup" alpine sh -c "tar czf /backup/\$vol.tar.gz -C /source ."
  done

  echo ""
  echo "➡️  Copying compose + env..."
  cp "\$COMPOSE_FILE" "\$BACKUP_PATH/"
  [[ -f ".env" ]] && cp ".env" "\$BACKUP_PATH/"

  echo ""
  echo "🎉 Backup completed successfully!"
  echo "📍 Backup location: \$BACKUP_PATH"
}

restore() {
  echo ""
  echo "📂 Available backups:"
  
  if [ -z "\$(ls -A "\$BACKUP_DIR" 2>/dev/null)" ]; then
      echo "No backups found in \$BACKUP_DIR"
      return
  fi

  select folder in \$(ls -t "\$BACKUP_DIR"); do
    if [ -n "\$folder" ]; then
      RESTORE_PATH="\$BACKUP_DIR/\$folder"
      break
    else
      echo "Invalid selection. Please try again."
    fi
  done

  echo ""
  echo "➡️  Stopping containers..."
  docker compose down || true

  echo ""
  echo "➡️  Restoring volumes..."
  for archive in "\$RESTORE_PATH/volumes"/*.tar.gz; do
    [ -e "\$archive" ] || continue
    VOLUME_NAME=\$(basename "\$archive" .tar.gz)
    echo "   🔄 Restoring \$VOLUME_NAME ..."
    docker volume rm -f "\$VOLUME_NAME" >/dev/null 2>&1 || true
    docker volume create "\$VOLUME_NAME" >/dev/null
    docker run --rm -v "\$VOLUME_NAME:/restore" -v "\$RESTORE_PATH/volumes:/backup" alpine sh -c "tar xzf /backup/\$(basename "\$archive") -C /restore"
  done

  echo ""
  echo "➡️  Restoring Docker images..."
  for file in "\$RESTORE_PATH"/image_*.tar; do
    [ -e "\$file" ] || continue
    docker load -i "\$file"
    echo "✔️ Image loaded: \$(basename "\$file")"
  done

  echo ""
  echo "➡️  Restoring docker-compose + env..."
  cp "\$RESTORE_PATH/docker-compose.yml" "\$COMPOSE_FILE"
  [[ -f "\$RESTORE_PATH/.env" ]] && cp "\$RESTORE_PATH/.env" .env

  echo ""
  echo "➡️  Starting all services from restored compose..."
  docker compose up -d

  # Drop & recreate DB before restoring
  POSTGRES_CONTAINER="powerchat-postgres-$INSTANCE_NAME"
  echo "⏳ Waiting for PostgreSQL to be fully ready..."
  until docker exec -i \$POSTGRES_CONTAINER pg_isready -U \$DB_USER -d \$DB_NAME >/dev/null 2>&1; do
      sleep 2
  done

  echo "➡️ Dropping existing database (if exists)..."
  docker exec -i \$POSTGRES_CONTAINER psql -U \$DB_USER -d postgres -c "DROP DATABASE IF EXISTS \$DB_NAME;"

  echo "➡️ Creating fresh database..."
  docker exec -i \$POSTGRES_CONTAINER psql -U \$DB_USER -d postgres -c "CREATE DATABASE \$DB_NAME;"

  echo "➡️ Restoring database from backup..."
  docker exec -i \$POSTGRES_CONTAINER psql -U \$DB_USER -d \$DB_NAME < "\$RESTORE_PATH/db_backup.sql"
  echo "✔️ Database restored"

  echo ""
  echo "➡️ Starting full stack..."
  docker compose up -d --build

  echo ""
  echo "🎉 Restore completed successfully!"
}

while true; do
  show_menu
  read -p "Select an option: " OPTION
  case \$OPTION in
    1) backup ;;
    2) restore ;;
    3) exit 0 ;;
    *) echo "Invalid option"; sleep 1 ;;
  esac
  read -p "Press Enter to continue..."
done
EOF
    chmod +x "$instance_dir/backup.sh"

    print_success "Instance files created in $instance_dir"
}

# Function to create shared network
create_shared_network() {
    local network_name="powerchat-shared-network"

    # Helper function for docker network commands
    local docker_network_cmd="docker"
    if needs_sudo_docker; then
        docker_network_cmd="sudo docker"
    fi
    
    # Check if shared network exists
    if ! $docker_network_cmd network inspect "$network_name" >/dev/null 2>&1; then
        print_status "Creating shared PowerChat network..."
        $docker_network_cmd network create "$network_name" --driver bridge --subnet=172.20.0.0/16 2>/dev/null || {
            print_warning "Failed to create network with custom subnet, trying default..."
            $docker_network_cmd network create "$network_name" --driver bridge 2>/dev/null || {
                print_error "Failed to create shared network. Trying cleanup first..."
                $docker_network_cmd network prune -f 2>/dev/null || true
                $docker_network_cmd network create "$network_name" --driver bridge || {
                    print_error "Cannot create shared network. Please run: docker network prune -f"
                    return 1
                }
            }
        }
        print_success "Shared network created: $network_name"
    else
        print_status "Using existing shared network: $network_name"
    fi
}

# Function to clean up unused Docker resources
cleanup_docker_resources() {
    print_status "Cleaning up unused Docker resources to free up network space..."

    # Helper function for docker commands
    local docker_cmd="docker"
    if needs_sudo_docker; then
        docker_cmd="sudo docker"
    fi

    # Stop any exited containers first
    $docker_cmd container prune -f 2>/dev/null || true

    # Remove unused networks (this is the key fix)
    print_status "Removing unused Docker networks..."
    $docker_cmd network prune -f 2>/dev/null || true

    # Remove any orphaned PowerChat networks that might be stuck
    print_status "Removing orphaned PowerChat networks..."
    $docker_cmd network ls --format "{{.Name}}" | grep -E "(powerchat-network-|_default)" | while read network; do
        # Skip the shared network
        if [ "$network" != "powerchat-shared-network" ]; then
            # Check if network is actually in use
            if ! $docker_cmd network inspect "$network" --format "{{.Containers}}" 2>/dev/null | grep -q "."; then
                print_status "Removing unused network: $network"
                $docker_cmd network rm "$network" 2>/dev/null || true
            fi
        fi
    done

    # Remove unused images to free up space
    $docker_cmd image prune -f 2>/dev/null || true

    print_status "Docker cleanup completed"
}

deploy_instance() {
    print_step "Deploying PowerChat Plus instance '$INSTANCE_NAME'..."

    local instance_dir="$INSTANCES_DIR/$INSTANCE_NAME"

    # Clean up Docker resources first to free up networks
    cleanup_docker_resources

    # Create shared network for all instances
    create_shared_network

    print_status "Building Docker image..."
    cd "$instance_dir"

    if [ ! -f "../../Dockerfile.simple" ]; then
        print_error "Dockerfile.simple not found. Please ensure it exists in the share directory."
        return 1
    fi

    if [ ! -d "../../dist" ]; then
        print_error "dist directory not found. Please ensure you have a pre-built application."
        return 1
    fi

    # node_modules will be installed during Docker build, no need to check locally

    if docker_compose_cmd build --no-cache; then
        print_success "Docker image built successfully"
    else
        print_error "Failed to build Docker image"
        return 1
    fi

    print_status "Starting services..."
    if docker_compose_cmd up -d; then
        print_success "Services started successfully"
    else
        print_error "Failed to start services"
        return 1
    fi

    print_status "Waiting for services to start..."
    sleep 10

    print_success "Services started successfully"
    print_status "Database migrations will be handled automatically by the application..."
    print_status "The application will retry database connections until PostgreSQL is ready."
}

run_migrations() {
    local migrations_dir="/www/wwwroot/default/migrations"
    if [ ! -d "$migrations_dir" ]; then
        print_status "Migrations directory not found ($migrations_dir), skipping SQL migrations."
        return 0
    fi
    local sql_count=$(find "$migrations_dir" -maxdepth 1 -name "*.sql" 2>/dev/null | wc -l)
    if [ "$sql_count" -eq 0 ]; then
        print_status "No .sql files in $migrations_dir, skipping SQL migrations."
        return 0
    fi
    local docker_cmd="docker"
    if needs_sudo_docker; then
        docker_cmd="sudo docker"
    fi
    local postgres_container="powerchat-postgres-$INSTANCE_NAME"
    print_step "Running SQL migrations from $migrations_dir..."
    for file in "$migrations_dir"/*.sql; do
        [ -f "$file" ] || continue
        echo "Running $file..."
        if $docker_cmd exec -i "$postgres_container" psql -U powerchat -d "$DATABASE_NAME" < "$file"; then
            print_success "Applied $(basename "$file")"
        else
            print_error "Failed to apply $(basename "$file")"
            return 1
        fi
    done
    print_success "All migrations completed."
}

show_deployment_results() {
    print_step "Deployment completed successfully!"

    cat << EOF

${GREEN}🎉 PowerChat Plus instance '$INSTANCE_NAME' deployed successfully!${NC}

${BLUE}Access Information:${NC}
  🌐 Application URL: ${YELLOW}http://localhost:$APP_PORT${NC}
  🗄️  Database: ${YELLOW}localhost:$DB_PORT${NC}
  📁 Admin Panel: ${YELLOW}http://localhost:$APP_PORT/admin${NC}

${BLUE}Admin Credentials:${NC}
  📧 Email: ${YELLOW}$ADMIN_EMAIL${NC}
  👤 Username: ${YELLOW}$ADMIN_USERNAME${NC}
  🔑 Password: ${YELLOW}$ADMIN_PASSWORD${NC}

${BLUE}Instance Management:${NC}
  📊 Status: ${YELLOW}$INSTANCES_DIR/$INSTANCE_NAME/manage.sh status${NC}
  📋 Logs: ${YELLOW}$INSTANCES_DIR/$INSTANCE_NAME/manage.sh logs${NC}
  🔄 Restart: ${YELLOW}$INSTANCES_DIR/$INSTANCE_NAME/manage.sh restart${NC}
  🛑 Stop: ${YELLOW}$INSTANCES_DIR/$INSTANCE_NAME/manage.sh stop${NC}
  💾 Backup: ${YELLOW}$INSTANCES_DIR/$INSTANCE_NAME/backup.sh${NC}

${BLUE}Next Steps:${NC}
1. Wait 1-2 minutes for the application to fully start
2. Open ${YELLOW}http://localhost:$APP_PORT${NC} in your browser
3. Login with the admin credentials above
4. Configure your WhatsApp and other channels
5. Create your first chatbot flow

${BLUE}Deploy Additional Instances:${NC}
  ${YELLOW}./multi-instance-deploy.sh${NC}

${GREEN}Happy chatting! 🚀${NC}

EOF
}

list_instances() {
    print_step "Listing PowerChat Plus instances..."

    if [ ! -d "$INSTANCES_DIR" ] || [ -z "$(ls -A "$INSTANCES_DIR" 2>/dev/null)" ]; then
        print_status "No instances found."
        echo
        echo "Deploy your first instance with: ./multi-instance-deploy.sh"
        return 0
    fi

    echo
    printf "%-20s %-10s %-10s %-15s %-30s\n" "INSTANCE" "APP_PORT" "DB_PORT" "STATUS" "URL"
    printf "%-20s %-10s %-10s %-15s %-30s\n" "--------" "--------" "-------" "------" "---"

    for instance_dir in "$INSTANCES_DIR"/*; do
        if [ -d "$instance_dir" ]; then
            local instance_name=$(basename "$instance_dir")
            local env_file="$instance_dir/.env"

            if [ -f "$env_file" ]; then
                local app_port=$(grep "^APP_PORT=" "$env_file" | cut -d'=' -f2)
                local db_port=$(grep "^DB_PORT=" "$env_file" | cut -d'=' -f2)

                local status="Stopped"
                if docker compose -f "$instance_dir/docker-compose.yml" ps | grep -q "Up"; then
                    status="Running"
                fi

                local url="http://localhost:$app_port"

                printf "%-20s %-10s %-10s %-15s %-30s\n" "$instance_name" "$app_port" "$db_port" "$status" "$url"
            fi
        fi
    done
    echo
}

main() {
    print_header

    cd "$SCRIPT_DIR"

    check_prerequisites
    verify_deployment_files
    install_dependencies
    collect_instance_config
    confirm_deployment

    create_instance_files
    deploy_instance
    run_migrations
    show_deployment_results

    print_success "Multi-instance deployment completed! 🎉"
}

case "${1:-}" in
    "help"|"-h"|"--help")
        cat << EOF
PowerChat Plus Multi-Instance Docker Deployment

Usage: $0 [command]

Commands:
  (no args)  Deploy a new instance (interactive)
  list       List all deployed instances
  status     Show status of all instances
  logs       Show logs for all instances
  stop       Stop all instances
  clean      Remove all instances and data
  help       Show this help message

Examples:
  $0                    # Deploy new instance
  $0 list              # List all instances
  $0 status            # Show instance status

Instance Management:
  Each instance can be managed individually:
  ./instances/INSTANCE_NAME/manage.sh {start|stop|restart|logs|status|clean}

EOF
        exit 0
        ;;
    "list")
        list_instances
        exit 0
        ;;
    "status")
        print_step "Showing status of all instances..."
        if [ ! -d "$INSTANCES_DIR" ] || [ -z "$(ls -A "$INSTANCES_DIR" 2>/dev/null)" ]; then
            print_status "No instances found."
        else
            for instance_dir in "$INSTANCES_DIR"/*; do
                if [ -d "$instance_dir" ]; then
                    local instance_name=$(basename "$instance_dir")
                    echo
                    print_status "Instance: $instance_name"
                    docker compose -f "$instance_dir/docker-compose.yml" ps
                fi
            done
        fi
        exit 0
        ;;
    "logs")
        print_step "Showing logs of all instances..."
        if [ ! -d "$INSTANCES_DIR" ] || [ -z "$(ls -A "$INSTANCES_DIR" 2>/dev/null)" ]; then
            print_status "No instances found."
        else
            echo "Press Ctrl+C to stop following logs"
            echo
            local compose_files=()
            for instance_dir in "$INSTANCES_DIR"/*; do
                if [ -d "$instance_dir" ]; then
                    compose_files+=("-f" "$instance_dir/docker-compose.yml")
                fi
            done
            if [ ${#compose_files[@]} -gt 0 ]; then
                docker compose "${compose_files[@]}" logs -f
            fi
        fi
        exit 0
        ;;
    "stop")
        print_step "Stopping all PowerChat Plus instances..."
        if [ ! -d "$INSTANCES_DIR" ] || [ -z "$(ls -A "$INSTANCES_DIR" 2>/dev/null)" ]; then
            print_status "No instances found."
        else
            for instance_dir in "$INSTANCES_DIR"/*; do
                if [ -d "$instance_dir" ]; then
                    local instance_name=$(basename "$instance_dir")
                    print_status "Stopping instance: $instance_name"
                    docker compose -f "$instance_dir/docker-compose.yml" down
                fi
            done
            print_success "All instances stopped"
        fi
        exit 0
        ;;
    "clean")
        print_warning "This will remove ALL PowerChat Plus instances and their data!"
        echo "This action cannot be undone."
        echo
        if [ ! -d "$INSTANCES_DIR" ] || [ -z "$(ls -A "$INSTANCES_DIR" 2>/dev/null)" ]; then
            print_status "No instances found."
            exit 0
        fi
        echo "Instances to be removed:"
        for instance_dir in "$INSTANCES_DIR"/*; do
            if [ -d "$instance_dir" ]; then
                local instance_name=$(basename "$instance_dir")
                echo "  - $instance_name"
            fi
        done
        echo
        echo -n "Are you absolutely sure? Type 'DELETE ALL' to confirm: "
        read -r confirm
        if [ "$confirm" != "DELETE ALL" ]; then
            print_status "Cleanup cancelled."
            exit 0
        fi
        print_step "Removing all instances..."
        for instance_dir in "$INSTANCES_DIR"/*; do
            if [ -d "$instance_dir" ]; then
                local instance_name=$(basename "$instance_dir")
                print_status "Removing instance: $instance_name"
                docker compose -f "$instance_dir/docker-compose.yml" down -v --rmi all 2>/dev/null || true
                rm -rf "$instance_dir"
            fi
        done
        if [ -d "$INSTANCES_DIR" ] && [ -z "$(ls -A "$INSTANCES_DIR" 2>/dev/null)" ]; then
            rmdir "$INSTANCES_DIR"
        fi
        print_success "All instances removed"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
