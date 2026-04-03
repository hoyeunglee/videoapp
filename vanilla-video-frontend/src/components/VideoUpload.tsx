import React, { useState } from "react";
import { api } from "../api";
import { useAuth } from "../context/AuthContext";

export const VideoUpload: React.FC = () => {
  const { userId } = useAuth();
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState("");
  const [status, setStatus] = useState("");

  const upload = async () => {
    if (!file || !userId) return;

    setStatus("Requesting upload URL...");

    const presign = await api.uploadMetadata({
      user_id: userId,
      title,
      filename: file.name
    });

    setStatus("Uploading to S3...");

    await fetch(presign.uploadUrl, {
      method: "PUT",
      body: file
    });

    setStatus("Upload complete.");
  };

  return (
    <div>
      <h2>Upload Video</h2>
      <input
        type="text"
        placeholder="Video title"
        value={title}
        onChange={e => setTitle(e.target.value)}
      /><br />
      <input
        type="file"
        accept="video/*"
        onChange={e => setFile(e.target.files?.[0] || null)}
      /><br />
      <button onClick={upload}>Upload</button>
      <div>{status}</div>
    </div>
  );
};