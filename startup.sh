#!/bin/bash
set -e

# Depuración: mostrar la ubicación del binario ollama
echo "Buscando el binario ollama..."
find / -name ollama -type f 2>/dev/null || echo "No se encontró el binario ollama"

# Verificar si podemos ejecutar ollama
if command -v ollama >/dev/null 2>&1; then
    echo "Ollama encontrado, iniciando servicio..."
    # Iniciar Ollama en primer plano para ver cualquier error
    exec ollama serve
else
    echo "ERROR: Comando ollama no encontrado en el PATH"
    echo "PATH actual: $PATH"
    echo "Contenido del directorio /usr/local/bin:"
    ls -la /usr/local/bin
    exit 1
fi