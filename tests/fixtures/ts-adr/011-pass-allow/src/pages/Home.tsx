// archgate-ignore TS-011/ui-uses-application-not-adapters Next route handler lives under pages/api, server side
import { db } from "../adapters/postgres/db";
export const Home = () => String(db);
