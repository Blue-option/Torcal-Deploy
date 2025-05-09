FROM ollama/ollama:latest

# Copiar un script de inicio personalizado
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# Asegurarnos de que Ollama esté en el PATH
ENV PATH="/usr/local/bin:${PATH}"

# Punto de entrada
ENTRYPOINT ["/startup.sh"]