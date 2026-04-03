// db/aurora.js
import { Pool } from "pg";

const pool = new Pool({
  host: process.env.AURORA_HOST,
  user: process.env.AURORA_USER,
  password: process.env.AURORA_PASSWORD,
  database: process.env.AURORA_DB,
  max: 5
});

export async function query(sql, params) {
  const client = await pool.connect();
  try {
    const res = await client.query(sql, params);
    return res.rows;
  } finally {
    client.release();
  }
}