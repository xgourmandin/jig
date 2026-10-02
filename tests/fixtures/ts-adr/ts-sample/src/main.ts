import { build } from "./bootstrap/container.js";

const { app, port } = build();
app.listen(port);
