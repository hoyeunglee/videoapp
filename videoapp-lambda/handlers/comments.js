// handlers/comments.js
import { query } from "../db/aurora.js";

export async function postComment(event) {
  const { video_id, user_id, body } = JSON.parse(event.body);

  await query(
    `INSERT INTO comments (video_id, user_id, body)
     VALUES (
       (SELECT id FROM videos WHERE video_id=$1),
       (SELECT id FROM users WHERE user_id=$2),
       $3
     )`,
    [video_id, user_id, body]
  );

  return {
    statusCode: 200,
    body: JSON.stringify({ ok: true })
  };
}