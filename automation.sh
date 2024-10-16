#!/bin/bash

#modo depuracion descomentar el set -x
#set -x

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#variables
TEMP_DIR="tempdir"
DOCKER_IMAGE="cars-management-app"
CONTAINER_NAME="cars-management-container"
PORT=3000
DOCKERFILE_PATH="Dockerfile"

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

check_tools(){
    if command -v $1 &>/dev/null; then 
        print_message $GREEN "$1 está instalado."
    else 
        print_message $RED "$1 no está instalado. Por favor, instale $1 e intente nuevamente."
        exit 1
    fi
}

check_tools docker

#eliminar antiguos contenedores en ejecucion
print_message $YELLOW "Eliminando contenedores antiguos..."
docker rm -f $CONTAINER_NAME &>/dev/null || true
docker rmi -f $DOCKER_IMAGE:$APP_VERSION &>/dev/null || true

#crear la estructura de directorios
print_message $YELLOW "Creando estructura de directorios..."
mkdir -p $TEMP_DIR/{public,src}
cp -r src/* $TEMP_DIR/src/
cp -r public/* $TEMP_DIR/public/
cp package*.json server.js $TEMP_DIR/

#crear dockerfile

print_message $YELLOW "Creando Dockerfile..."
cat <<EOF > $TEMP_DIR/$DOCKERFILE_PATH
FROM node:18-alpine
LABEL org.opencontainers.image.authors="RoxsRoss"
RUN apk add --update python3 make g++\
   && rm -rf /var/cache/apk/*
WORKDIR /app
COPY package*.json ./
RUN npm install 
COPY . .
EXPOSE $PORT
CMD ["npm", "start"]
EOF

####leer version de la aplicacion
if [ -f "$TEMP_DIR/package.json" ]; then
    APP_VERSION=$(jq -r '.version' package.json)
    print_message $YELLOW "Versión de la aplicación: $APP_VERSION"
fi

#crear docker image
print_message $YELLOW "Construyendo imagen Docker..."
docker build -t $DOCKER_IMAGE:$APP_VERSION $TEMP_DIR

#Iniciar el contenedor
print_message $YELLOW "Iniciando contenedor..."
docker run -d -p $PORT:$PORT --name $CONTAINER_NAME $DOCKER_IMAGE:$APP_VERSION

# Listar el contenedor
print_message $YELLOW "Listando contenedores..."
docker ps -a --filter "name=$CONTAINER_NAME"

#ver logs
print_message $YELLOW "Mostrando logs del contenedor..."
sleep 1
docker logs $CONTAINER_NAME

#mostrar ip

print_message $YELLOW "Obteniendo dirección IP del contenedor..."
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_NAME)
print_message $GREEN "Dirección IP del contenedor: $CONTAINER_IP"

###probar la aplicacion
print_message $YELLOW "Probando la aplicación..."
RETRIES=5
for i in $(seq 1 $RETRIES); do
    if curl -s http://localhost:$PORT > /dev/null; then
        print_message $GREEN "La aplicación está corriendo en http://localhost:$PORT"
        break
    else
        print_message $YELLOW "La aplicación no está disponible aún. Reintentando en 5 segundos... ($i/$RETRIES)"
        sleep 5
    fi
    if [ $i -eq $RETRIES ]; then
        print_message $RED "La aplicación no está corriendo después de varios intentos. Por favor, revise los logs para más detalles."
        exit 1
    fi
done

### limpieza del directorio temporal

print_message $GREEN "Limpiando directorio temporal..."
rm -rf $TEMP_DIR

set +x