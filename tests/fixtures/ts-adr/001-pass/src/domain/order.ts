import { randomUUID } from "node:crypto";
import { Money } from "./money.js";
import type { Currency } from "../domain/currency";
import { z } from "zod";

// import express from "express";
/* import { readFileSync } from "node:fs"; */
const doc = "import axios from 'axios'";
const tpl = `require("fs") ${randomUUID()} ${`import("axios")`}`;
const re = /import x from "express"/;

export const Order = { Money, doc, tpl, re, z };
export type C = Currency;
