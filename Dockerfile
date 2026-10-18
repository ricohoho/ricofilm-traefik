FROM traefik:v3

# Copie des configurations statiques et dynamiques Traefik
COPY traefik.yml /etc/traefik/traefik.yml
COPY dynamic /etc/traefik/dynamic

# Dossier pour les certificats SSL Let's Encrypt (persiste via un volume Docker)
RUN mkdir -p /letsencrypt
