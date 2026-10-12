# Configuration Traefik v3 (Remplacement de Nginx)

Ce dépôt contient la configuration complète de **Traefik v3** sous Docker pour remplacer votre reverse proxy Nginx actuel sur votre VM.

---

## 📁 Structure des fichiers

```text
ricofilm-traefik/
├── docker-compose.yml     # Lancement du conteneur Traefik
├── traefik.yml            # Configuration statique (ports 80/443, ACME Let's Encrypt, providers)
├── dynamic/
│   └── routes.yml         # Configuration dynamique (routeurs, services, middlewares SSE et upload)
├── letsencrypt/
│   └── acme.json          # Stockage chiffré des certificats SSL générés automatiquement (chmod 600)
└── .gitignore             # Exclusion des certificats et secrets
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
| `ricohoho.fr` | Pas de proxy défini | `ricohoho-svc` | Certificat généré, configurable vers l'app de votre choix |
| `traefik.ricohoho.fr` | *(Nouveau)* | `api@internal` | Dashboard Traefik sécurisé par BasicAuth |
| **HTTP (Port 80)** | `return 404` | **Redirection globale vers HTTPS (443)** | Défi ACME Let's Encrypt géré automatiquement |

---

## 🚀 Guide de migration pas à pas

### 1. Préparer l'adresse email Let's Encrypt
Ouvrez [traefik.yml](file:///home/efassel/ricofilm/ricofilm-traefik/traefik.yml) et modifiez l'adresse email pour les notifications de renouvellement SSL :
```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: "votre-vrai-email@domaine.com"
```

### 2. (Optionnel) Changer le mot de passe du Dashboard Traefik
Dans [dynamic/routes.yml](file:///home/efassel/ricofilm/ricofilm-traefik/dynamic/routes.yml), le dashboard est protégé par mot de passe HTTP BasicAuth.
Par défaut : identifiant `admin`, mot de passe `admin`.

Pour générer votre propre mot de passe sécurisé :
```bash
# Exemple pour créer l'utilisateur 'admin' avec un mot de passe personnalisé :
echo $(htpasswd -nb admin MON_MOT_DE_PASSE_SECRET)
```
Copiez la ligne générée dans le middleware `auth-dashboard` de `dynamic/routes.yml`.

### 3. Libérer les ports 80 et 443 (Arrêter Nginx)
Sur votre VM (`davic`), arrêtez Nginx afin que Traefik puisse écouter sur les ports 80 et 443 :
```bash
sudo systemctl stop nginx
sudo systemctl disable nginx
```

### 4. Démarrer Traefik
Depuis le dossier `ricofilm-traefik` :
```bash
docker compose up -d
```

### 5. Vérifier les logs et les certificats
Consultez les logs de Traefik pour voir la génération automatique des certificats SSL Let's Encrypt :
```bash
docker compose logs -f traefik
```
Dès que les premiers visiteurs se connectent à vos domaines (ou dès le démarrage), Traefik effectue le challenge HTTP-01 via Let's Encrypt et stocke les certificats dans `letsencrypt/acme.json`.

---

## ⚡ Avantages clés de cette configuration

1. **Rechargement à chaud (Hot-Reload) :**
   Vous pouvez modifier [dynamic/routes.yml](file:///home/efassel/ricofilm/ricofilm-traefik/dynamic/routes.yml) à tout moment (ajouter un sous-domaine, changer un port). Traefik recharge la configuration instantanément **sans redémarrer le conteneur** et **sans coupure de service**.

2. **Aucune modification de vos conteneurs existants requise :**
   Grâce à `host.docker.internal`, Traefik dans Docker peut discuter directement avec vos applications existantes qui écoutent sur les ports de l'hôte (`localhost:83`, `localhost:4200`, etc.).

3. **Prêt pour les Labels Docker (Transition future) :**
   Le provider Docker est déjà activé. Si à l'avenir vous souhaitez déclarer le routage d'un conteneur directement dans son propre `docker-compose.yml`, il vous suffira de lui ajouter le réseau `traefik-net` et des labels comme ceci :
   ```yaml
   services:
     mon-app:
       image: mon-app:latest
       networks:
         - traefik-net
       labels:
         - "traefik.enable=true"
         - "traefik.http.routers.mon-app.rule=Host(`app.ricohoho.fr`)"
         - "traefik.http.routers.mon-app.entrypoints=websecure"
   ```
