import React, { useEffect, useState } from "react";
import { api } from "../api";
import { VideoCard } from "../components/VideoCard";

export const Home: React.FC = () => {
  const [videos, setVideos] = useState<any[]>([]);

  useEffect(() => {
    (async () => {
      const res = await api.listVideos();
      setVideos(res.videos || []);
    })();
  }, []);

  return (
    <div>
      <h2>Latest Videos</h2>
      <div className="video-grid">
        {videos.map(v => <VideoCard key={v.video_id} video={v} />)}
      </div>
    </div>
  );
};