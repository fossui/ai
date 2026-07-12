// The wrangler Text rule imports *.txt files as string modules.
declare module "*.txt" {
  const content: string;
  export default content;
}
