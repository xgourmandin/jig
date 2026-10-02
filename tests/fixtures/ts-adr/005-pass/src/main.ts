import { routes } from "./adapters/http/routes.js";
import { container } from "./bootstrap/container.js";

routes(container);
