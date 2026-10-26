const quote = /'/;
const half = 4 / 2 / 1;
const nested = `a ${half ? `x ${"`"}` : "y"} b`;
const jsx = "don't";
import express from "express";

export const x = [quote, half, nested, jsx, express];
