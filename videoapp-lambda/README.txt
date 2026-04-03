/lambda
  /handlers
      auth.js
      videos.js
      comments.js
      playlists.js
      graph-sync.js
  /db
      aurora.js
      neptune.js
  package.json
  serverless.yml (optional)


npm init -y
npm install aws-sdk @aws-sdk/client-secrets-manager pg gremlin bcryptjs jsonwebtoken uuid
npm install --save-dev esbuild

zip -r function.zip .

LAMBDA ENVIRONMENT VARIABLE

AURORA_HOST=your-aurora-endpoint
AURORA_USER=your-db-user
AURORA_PASSWORD=your-db-password
AURORA_DB=your-db-name

NEPTUNE_ENDPOINT=wss://your-neptune-endpoint:8182/gremlin

JWT_SECRET=your-secret-key
