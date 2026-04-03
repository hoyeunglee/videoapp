// handlers/videos.js
import { query } from "../db/aurora.js";
import { graph } from "../db/neptune.js";

export async function createVideo(event) {
  const { channel_id, title, description, duration_sec, visibility, s3_key } =
    JSON.parse(event.body);

  // 1. Insert into Aurora
  const rows = await query(
    `INSERT INTO videos (video_id, channel_id, title, description, duration_sec, visibility)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5)
     RETURNING video_id`,
    [channel_id, title, description, duration_sec, visibility]
  );

  const videoId = rows[0].video_id;

  await query(
    `INSERT INTO video_files (video_id, storage_key, resolution)
     VALUES ((SELECT id FROM videos WHERE video_id=$1), $2, 'source')`,
    [videoId, s3_key]
  );

  // 2. Mirror into Neptune graph
  const g = graph();
  await g.addV("Video")
    .property("video_id", videoId)
    .property("title", title)
    .property("duration_sec", duration_sec)
    .property("visibility", visibility)
    .next();

  await g.V().has("Channel", "channel_id", channel_id)
    .addE("UPLOADED")
    .to(g.V().has("Video", "video_id", videoId))
    .next();

  return {
    statusCode: 200,
    body: JSON.stringify({ videoId })
  };
}

// handlers/videos.js
export async function recordView(event) {
  const { video_id, user_id, watch_sec, device_type, country_code } =
    JSON.parse(event.body);

  // Aurora
  await query(
    `INSERT INTO video_views (video_id, user_id, watch_sec, device_type, country_code)
     VALUES (
       (SELECT id FROM videos WHERE video_id=$1),
       (SELECT id FROM users WHERE user_id=$2),
       $3, $4, $5
     )`,
    [video_id, user_id, watch_sec, device_type, country_code]
  );

  // Neptune
  const g = graph();
  await g.V().has("User", "user_id", user_id)
    .addE("VIEWED")
    .to(g.V().has("Video", "video_id", video_id))
    .property("watch_sec", watch_sec)
    .property("device_type", device_type)
    .next();

  return {
    statusCode: 200,
    body: JSON.stringify({ ok: true })
  };
}