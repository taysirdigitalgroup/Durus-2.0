# Signer et publier une release

## 1. Keystore (une seule fois)

```bash
keytool -genkey -v \
  -keystore android/app/durus2-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias durus2
```

⚠️ **Sauvegardez le fichier `.jks` et son mot de passe en lieu sûr** (gestionnaire
de mots de passe + backup chiffré), en dehors de ce dépôt. Sans eux, impossible
de publier une mise à jour signée avec la même identité — les utilisateurs
devraient désinstaller l'app avant toute nouvelle installation.

## 2. `android/key.properties` (local, jamais commité)

```bash
cat > android/key.properties << 'EOF'
storePassword=VOTRE_MOT_DE_PASSE
keyPassword=VOTRE_MOT_DE_PASSE
keyAlias=durus2
storeFile=durus2-release.jks
EOF
```

Voir `android/key.properties.example` pour le gabarit. `*.jks`,
`android/key.properties` et `release/` sont exclus par `.gitignore` — vérifiez
toujours avec `git status` avant de committer qu'aucun secret n'apparaît.

## 3. Build

```bash
flutter clean
flutter pub get
flutter build apk --release
```

APK dans `build/app/outputs/flutter-apk/`.

## 4. Publier sur GitHub Releases

### Manuellement

1. Repo → onglet **Releases** → **Draft a new release**.
2. Tag : `v1.0.0` (nouveau tag).
3. Titre : `Durus 2.0 - v1.0.0`.
4. Glissez le(s) `.apk` dans la zone de dépôt de binaires.
5. **Publish release**.

### Automatiquement (`.github/workflows/release.yml`)

Un workflow build + publie automatiquement l'APK signé à chaque push d'un tag
`v*.*.*`. Il attend 4 secrets dans **Settings → Secrets and variables →
Actions** :

| Secret | Valeur |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 durus2-release.jks` |
| `ANDROID_STORE_PASSWORD` | Mot de passe du keystore |
| `ANDROID_KEY_PASSWORD` | Mot de passe de la clé |
| `ANDROID_KEY_ALIAS` | `durus2` |

Puis :

```bash
git tag v1.0.0
git push origin v1.0.0
```
