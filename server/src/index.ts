// Punto de entrada del Worker. Solo exporta el handler por defecto: workerd
// trata cualquier otra exportación con nombre como un entrypoint, así que las
// constantes y utilidades viven en handler.ts.
export { default } from "./handler";
export type { Env } from "./handler";
