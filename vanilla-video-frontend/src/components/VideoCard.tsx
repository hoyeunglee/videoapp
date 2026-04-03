import React from "react";
import { Link } from "react-router-dom";

export const VideoCard: React.FC<{ video: any }> = ({ video }) => {
  return (
    <Link to={`/watch/${video.video_id}`} className="video-card">
      <img src={video.thumbnail_url} className="thumb" />
      <div className="info">
        <h4>{video.title}</h4>
        <p>{video.channel_title}</p>
      </div>
    </Link>
  );
};