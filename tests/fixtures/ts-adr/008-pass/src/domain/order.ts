// console.log("comment");
const doc = "fetch('x')";

export async function load(): Promise<Response> {
  console.log(doc);
  return await fetch("https://example.com");
}

export const handler = async () => {
  await load();
};
export const timeout = (cb: () => void) => setTimeout(cb, 1);
