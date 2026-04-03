// handlers/graph-sync.js
import { query } from "../db/aurora.js";
import { graph } from "../db/neptune.js";

/**
 * This Lambda is triggered by:
 * - EventBridge (CDC events)
 * - Manual sync calls
 * - Batch nightly sync
 *
 * It ensures Aurora → Neptune consistency.
 */
export async function sync(event) {
  const type = event.detail?.type;
  const payload = event.detail?.payload;

  if (!type) {
    return { statusCode: 400, body: "Missing sync type" };
  }

  switch (type) {
    case "USER_CREATED":
      return await syncUser(payload.user_id);

    case "CHANNEL_CREATED":
      return await syncChannel(payload.channel_id);

    case "VIDEO_CREATED":
      return await syncVideo(payload.video_id);

    case "SUBSCRIPTION_CREATED":
      return await syncSubscription(payload.user_id, payload.channel_id);

    case "VIDEO_VIEWED":
      return await syncView(payload.user_id, payload.video_id, payload.watch_sec);

    case "VIDEO_LIKED":
      return await syncLike(payload.user_id, payload.video_id);

    default:
      return { statusCode: 400, body: "Unknown sync type" };
  }
}


async function syncUser(userId) {
  const rows = await query(
    `SELECT user_id, country_code, status
     FROM user_profile
     JOIN users ON users.id = user_profile.user_id
     WHERE users.user_id=$1`,
    [userId]
  );

  if (rows.length === 0) return;

  const u = rows[0];
  const g = graph();

  await g.V().has("User", "user_id", u.user_id)
    .fold()
    .coalesce(
      __.unfold(),
      __.addV("User")
        .property("user_id", u.user_id)
        .property("country_code", u.country_code)
        .property("account_status", u.status)
    )
    .next();

  return { ok: true };
}

async function syncChannel(channelId) {
  const rows = await query(
    `SELECT channel_id, owner_user_id, title, country_code, category
     FROM channels
     WHERE channel_id=$1`,
    [channelId]
  );

  if (rows.length === 0) return;

  const c = rows[0];
  const g = graph();

  // Ensure channel node
  await g.V().has("Channel", "channel_id", c.channel_id)
    .fold()
    .coalesce(
      __.unfold(),
      __.addV("Channel")
        .property("channel_id", c.channel_id)
        .property("title", c.title)
        .property("country_code", c.country_code)
    )
    .next();

  // Ensure owner relationship
  await g.V().has("User", "user_id", c.owner_user_id)
    .addE("OWNS_CHANNEL")
    .to(g.V().has("Channel", "channel_id", c.channel_id))
    .next();

  return { ok: true };
}

async function syncVideo(videoId) {
  const rows = await query(
    `SELECT v.video_id, c.channel_id, v.title, v.duration_sec, v.visibility
     FROM videos v
     JOIN channels c ON c.id = v.channel_id
     WHERE v.video_id=$1`,
    [videoId]
  );

  if (rows.length === 0) return;

  const v = rows[0];
  const g = graph();

  await g.V().has("Video", "video_id", v.video_id)
    .fold()
    .coalesce(
      __.unfold(),
      __.addV("Video")
        .property("video_id", v.video_id)
        .property("title", v.title)
        .property("duration_sec", v.duration_sec)
        .property("visibility", v.visibility)
    )
    .next();

  await g.V().has("Channel", "channel_id", v.channel_id)
    .addE("UPLOADED")
    .to(g.V().has("Video", "video_id", v.video_id))
    .next();

  return { ok: true };
}

async function syncSubscription(userId, channelId) {
  const g = graph();

  await g.V().has("User", "user_id", userId)
    .addE("SUBSCRIBES")
    .to(g.V().has("Channel", "channel_id", channelId))
    .property("since", Date.now())
    .next();

  return { ok: true };
}

async function syncView(userId, videoId, watchSec) {
  const g = graph();

  await g.V().has("User", "user_id", userId)
    .addE("VIEWED")
    .to(g.V().has("Video", "video_id", videoId))
    .property("watch_sec", watchSec)
    .property("view_at", Date.now())
    .next();

  return { ok: true };
}

async function syncLike(userId, videoId) {
  const g = graph();

  await g.V().has("User", "user_id", userId)
    .addE("LIKED")
    .to(g.V().has("Video", "video_id", videoId))
    .property("at", Date.now())
    .next();

  return { ok: true };
}

