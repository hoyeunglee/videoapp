const API_BASE = import.meta.env.VITE_API_BASE as string;

let token: string | null = null;

export function setToken(t: string | null) {
  token = t;
}

async function request(path: string, options: RequestInit = {}) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string> || {})
  };

  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || res.statusText);
  }

  return res.json();
}

export const api = {
  login: (email: string, password: string) =>
    request("/auth/login", {
      method: "POST",
      body: JSON.stringify({ email, password })
    }),

  listVideos: () =>
    request("/videos/list", { method: "GET" }),

  getVideo: (video_id: string) =>
    request(`/videos/get/${video_id}`, { method: "GET" }),

  uploadMetadata: (data: any) =>
    request("/videos/create", {
      method: "POST",
      body: JSON.stringify(data)
    }),

  comment: (data: any) =>
    request("/comments/create", {
      method: "POST",
      body: JSON.stringify(data)
    }),

  listComments: (video_id: string) =>
    request(`/comments/list/${video_id}`, { method: "GET" }),

  subscribe: (user_id: string, channel_id: string) =>
    request("/subscriptions/add", {
      method: "POST",
      body: JSON.stringify({ user_id, channel_id })
    }),

  getAds: (region: string) =>
    request("/ads/list", {
      method: "POST",
      body: JSON.stringify({ region })
    })
};