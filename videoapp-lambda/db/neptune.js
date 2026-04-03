// db/neptune.js
import gremlin from "gremlin";

const { DriverRemoteConnection } = gremlin.driver;
const { Graph } = gremlin.structure;

let conn = null;
let g = null;

export function graph() {
  if (!conn) {
    conn = new DriverRemoteConnection(
      process.env.NEPTUNE_ENDPOINT,
      { mimeType: "application/vnd.gremlin-v2.0+json" }
    );
    g = new Graph().traversal().withRemote(conn);
  }
  return g;
}