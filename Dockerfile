FROM ollama/ollama:latest

# Variables de entorno para NVIDIA
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV OLLAMA_MODELS=/root/.ollama/models

# Crear los directorios necesarios
RUN mkdir -p /root/.ollama/models

# Script de inicio
RUN echo '#!/bin/bash \n\
set -e \n\
\n\
# Iniciar Ollama en primer plano \n\
echo "Iniciando Ollama..." \n\
ollama serve & \n\
SERVER_PID=$! \n\
\n\
# Esperar a que el servidor esté listo \n\
echo "Esperando a que Ollama inicie..." \n\
until curl -s http://localhost:11434/api/tags > /dev/null 2>&1; do \n\
  sleep 1 \n\
done \n\
\n\
# Verificar si el modelo existe \n\
if ! ollama list | grep -q "gemma3:4b"; then \n\
  echo "Modelo no encontrado, descargando gemma3:4b..." \n\
  ollama pull gemma3:4b || { \n\
    echo "Error descargando gemma3:4b" \n\
    exit 1 \n\
  } \n\
  echo "Modelo gemma3:4b descargado correctamente" \n\
else \n\
  echo "El modelo gemma3:4b ya está disponible" \n\
fi \n\
\n\
# Mantener el servidor corriendo \n\
wait $SERVER_PID \n\
' > /start.sh && chmod +x /start.sh

# Punto de entrada
ENTRYPOINT ["/start.sh"]