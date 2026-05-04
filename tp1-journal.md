## Runbook

### Redémarrer le service
```bash
sudo systemctl restart todo-api
sudo systemctl status todo-api
```

### Consulter les logs (50 dernières lignes)
```bash
sudo journalctl -u todo-api -n 50
```

### Déployer une nouvelle version
```bash
cd /opt/todo-api
sudo -u todoapp git pull origin main
sudo npm install --omit=dev
sudo systemctl restart todo-api
sudo systemctl status todo-api
```

### Effectuer un rollback
```bash

# Voir les commits disponibles
sudo -u todoapp git log --oneline -10

# Revenir au dernier commit avant probleme
sudo -u todoapp git checkout <commit-hash>
sudo systemctl restart todo-api
```

### Régénérer le JWT_SECRET
```bash
# Générer un nouveau secret
openssl rand -hex 32

# Mettre à jour le .env
sudo vim /opt/todo-api/.env

# Modifier la ligne JWT_SECRET=...

# Puis redémarrer le service
sudo systemctl restart todo-api
```

### Que faire si Nginx ne démarre plus ?
```bash
# Vérifier la syntaxe
sudo nginx -t

# Voir les erreurs
sudo journalctl -u nginx -n 50

# Identifier le fichier problématique
sudo nginx -T 2>&1 | grep -i error

# desactivé un fichier
sudo mv /etc/nginx/conf.d/todo-api.conf /etc/nginx/conf.d/todo-api.conf.bak

# puis redémarrer nginx
sudo systemctl restart nginx
```
