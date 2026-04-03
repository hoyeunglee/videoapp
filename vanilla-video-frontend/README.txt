vanilla-video-frontend/
│
├── index.html
├── package.json
├── tsconfig.json
├── vite.config.ts
├── .env
│
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   │
│   ├── api/
│   │   ├── index.ts
│   │   ├── auth.ts
│   │   ├── videos.ts
│   │   ├── comments.ts
│   │   ├── channels.ts
│   │   ├── subscriptions.ts
│   │   └── ads.ts
│   │
│   ├── components/
│   │   ├── VideoCard.tsx
│   │   ├── VideoPlayer.tsx
│   │   ├── VideoUpload.tsx
│   │   ├── CommentBox.tsx
│   │   ├── CommentList.tsx
│   │   ├── ChannelHeader.tsx
│   │   ├── Navbar.tsx
│   │   └── AdsPanel.tsx
│   │
│   ├── pages/
│   │   ├── Home.tsx
│   │   ├── Watch.tsx
│   │   ├── Upload.tsx
│   │   ├── Channel.tsx
│   │   └── Login.tsx
│   │
│   ├── context/
│   │   └── AuthContext.tsx
│   │
│   ├── hooks/
│   │   ├── useAuth.ts
│   │   └── useFetch.ts
│   │
│   ├── styles/
│   │   ├── globals.css
│   │   └── video.css
│   │
│   └── assets/
│       └── logo.svg
│
└── public/
    └── favicon.ico


npm create vite@latest vanilla-video-frontend -- --template react-ts
cd vanilla-video-frontend


npm install react-router-dom


npm install axios


npm run dev


http://localhost:5173

