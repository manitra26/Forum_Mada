# Backend Dart local pour ForumMada

Ce backend est écrit en Dart et se connecte à PostgreSQL localement.
Il est conçu pour être utilisé sans Docker.

## Prérequis
- Dart SDK installé
- PostgreSQL déjà créé et accessible via pgAdmin

## Installation
Depuis le dossier `backend` :

```bash
cd backend
dart pub get
```

## Configuration
Copiez le fichier `.env.example` en `.env` et adaptez les valeurs :

```bash
copy .env.example .env
```

Modifier ensuite :
- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `PORT`

## Lancer le serveur

```bash
dart run bin/server.dart
```

Le backend répondra sur :
- `http://localhost:8080/api/ping`
- `http://localhost:8080/api/topics`

## Utiliser depuis Flutter

Pour un émulateur Android :
- `http://10.0.2.2:8080/api/`

Pour un simulateur iOS ou desktop :
- `http://localhost:8080/api/`

Exemple dans `ApiService` :

```dart
final api = ApiService(baseUrl: 'http://10.0.2.2:8080/api/');
```

## Notes
- Les tables sont créées automatiquement si elles n'existent pas.
- Vous pouvez utiliser `DATABASE_URL` à la place des variables séparées.
