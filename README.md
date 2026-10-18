# Configuration Traefik v3 (Remplacement de Nginx) & Déploiement CI/CD

Ce dépôt contient la configuration complète de **Traefik v3** sous Docker pour remplacer le reverse proxy Nginx actuel sur la VM OVH (`ricohoho.fr`).

Il intègre un pipeline CI/CD automatisé avec **GitHub Actions** et **GitHub Container Registry (GHCR)** pour construire l'image Docker et la déployer automatiquement sur le serveur OVH via SSH (exactement selon le même modèle que [`ricofilm-web`](file:///home/efassel/ricofilm/ricofilm-web/.github/workflows/back-ci-cd-runner.yml)).

---

## 📁 Structure des fichiers

```text
ricofilm-traefik/
├── .github/
│   └── workflows/
│       └── traefik-ci-cd.yml # Pipeline GitHub Actions (Build image GHCR + Déploiement SSH)
├── Dockerfile                # Image Docker Traefik embarquant traefik.yml et dynamic/
├── docker-compose.yml        # Pour tester en local ou lancer via docker-compose
├── traefik.yml               # Configuration statique (ports 80/443, ACME Let's Encrypt, email)
├── dynamic/
│   └── routes.yml            # Configuration dynamique (redirections, SSE /mcp/, limite 10Mo)
├── .dockerignore             # Exclusion des fichiers inutiles lors du build
├── .gitignore                # Exclusion des secrets et certificats
└── README.md
```

---

## 🔄 Correspondance Nginx ➡️ Traefik

| Domaine / URL | Nginx (Ancien) | Traefik (Nouveau) | Détails |
| :--- | :--- | :--- | :--- |
| `solidage.ricohoho.fr` | `http://localhost:83/` | `solidage-svc` (`host.docker.internal:83`) | HTTPS automatique |
| `emby.ricohoho.fr` | `http://localhost:8096/` | `emby-svc` (`host.docker.internal:8096`) | HTTPS automatique |
| `jellyfin.ricohoho.fr` | `http://172.19.0.2:8096/` | `jellyfin-svc` (`172.19.0.2:8096`) | HTTPS automatique |
| `film.ricohoho.fr/mcp/` | `http://localhost:3000/mcp/` | `film-mcp-svc` (`host.docker.internal:3000`) | Priorité haute, SSE / Streaming sans buffering, timeout 24h |
| `film.ricohoho.fr/` | `http://localhost:4200/` | `film-svc` (`host.docker.internal:4200`) | Frontend principal |
| `savm.ricohoho.fr` | `http://localhost:81/` | `savm-svc` (`host.docker.internal:81`) | HTTPS automatique |
| `biscoto.ricohoho.fr` | `http://localhost:82/` | `biscoto-svc` (`host.docker.internal:82`) | HTTPS automatique |
| `shareurl.ricohoho.fr` | `http://localhost:3001/` (max 10M) | `shareurl-svc` (`host.docker.internal:3001`) | Middleware `shareurl-body-limit` (10 Mo) |
| `ricohoho.fr` | Pas de proxy défini | `ricohoho-svc` | Certificat généré |
| `traefik.ricohoho.fr` | *(Nouveau)* | `api@internal` | Dashboard Traefik sécurisé par BasicAuth |
| **HTTP (Port 80)** | `return 404` | **Redirection globale vers HTTPS (443)** | Défi ACME Let's Encrypt géré automatiquement |

---

## ⚙️ Configuration GitHub Actions & Secrets

Le workflow `.github/workflows/traefik-ci-cd.yml` utilise l'environnement GitHub **`ricofilm`**.

Il réutilise les mêmes secrets et variables déjà configurés pour vos autres projets (`ricofilm-web`, `AngularRicofilm`) :
- **Secrets :**
  - `GHCR_TOKEN` : Token GitHub avec droits de lecture/écriture sur les packages (`packages: write/read`).
  - `SERVER_SSH_KEY` : Clé privée SSH pour se connecter au serveur OVH.
- **Variables :**
  - `SERVER_IP` : Adresse IP ou nom d'hôte de la VM OVH (`ricohoho.fr`).
  - `SERVER_USER` : Nom de l'utilisateur SSH sur la VM OVH.

---

## 🚀 Première bascule Nginx ➡️ Traefik sur la VM OVH

Pour la première exécution, Nginx tourne encore sur la VM et écoute sur les ports 80 et 443. Il faut donc l'arrêter pour permettre à Docker de lier les ports 80 et 443 :

1. Connectez-vous en SSH sur la VM OVH :
   ```bash
   ssh <votre-user>@ricohoho.fr
   ```

2. Arrêtez et désactivez le service Nginx :
   ```bash
   sudo systemctl stop nginx
   sudo systemctl disable nginx
   ```

3. Déclenchez le déploiement :
   Faites un `git push` sur `main` ou lancez le workflow manuellement via **GitHub Actions** > **Traefik CI/CD runner** > **Run workflow**.

---

## 🔐 Persistance des certificats SSL (Let's Encrypt)

Les certificats SSL générés par Traefik sont stockés dans le volume Docker nommé **`traefik-certificates`**.
Ce volume est **indépendant du cycle de vie du conteneur** : à chaque nouveau déploiement (nouveau `docker pull` et recréation du conteneur), le volume est conservé intact, ce qui évite de redemander les certificats à Let's Encrypt et d'atteindre les limites de quota (rate-limits).
