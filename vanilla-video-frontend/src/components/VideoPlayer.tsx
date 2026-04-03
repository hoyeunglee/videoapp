import React from "react";

export const VideoPlayer: React.FC<{ url: string }> = ({ url }) => {
  return (
    <video
      src={url}
      controls
      style={{ width: "100%", borderRadius: "8px" }}
    />
  );
};