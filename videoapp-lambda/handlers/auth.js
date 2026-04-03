// handlers/auth.js
import { query } from "../db/aurora.js";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

export async function login(event) {
  const { email, password } = JSON.parse(event.body);

  const rows = await query(
    "SELECT id, user_id, password_hash FROM users WHERE email=$1",
    [email]
  );

  if (rows.length === 0) {
    return { statusCode: 401, body: "Invalid credentials" };
  }

  const user = rows[0];

  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) {
    return { statusCode: 401, body: "Invalid credentials" };
  }

  const token = jwt.sign(
    { uid: user.user_id },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );

  return {
    statusCode: 200,
    body: JSON.stringify({ token })
  };
}