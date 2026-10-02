import axios from "axios";
export const load = () => fetch("/cart").then(() => axios.get("/x"));
