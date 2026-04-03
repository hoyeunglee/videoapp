import React, { createContext, useContext, useState } from "react";
import { setToken } from "../api";

type AuthState = {
  userId: string | null;
  token: string | null;
  login: (uid: string, token: string) => void;
  logout: () => void;
};

const AuthCtx = createContext<AuthState | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [userId, setUserId] = useState<string | null>(null);
  const [jwt, setJwt] = useState<string | null>(null);

  const login = (uid: string, t: string) => {
    setUserId(uid);
    setJwt(t);
    setToken(t);
  };

  const logout = () => {
    setUserId(null);
    setJwt(null);
    setToken(null);
  };

  return (
    <AuthCtx.Provider value={{ userId, token: jwt, login, logout }}>
      {children}
    </AuthCtx.Provider>
  );
};

export function useAuth() {
  const ctx = useContext(AuthCtx);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}