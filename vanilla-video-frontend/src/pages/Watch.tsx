import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { api } from "../api";
import { VideoPlayer } from "../components/VideoPlayer";
import { CommentBox } from "../components/CommentBox";
import { CommentList } from "../components/CommentList";

export const Watch: React.FC = () => {
  const { id } = useParams();
  const [video, setVideo] = useState<any>(null);

  useEffect(() => {
    (async () => {
      const res = await api.getVideo(id!);
      setVideo(res.video);
    })();
  }, [id]);

  if (!video) return <div>Loading...</div>;

  return (
    <div>
      <VideoPlayer url={video.stream_url} />
      <h2>{video.title}</h2>
      <p>{video.description}</p>

      <CommentBox video_id={id!} />
      <CommentList video_id={id!} />
    </div>
  );
};