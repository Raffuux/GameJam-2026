// Exports every catalog asset to public/models/<id>.glb so they can be used
// outside the Three.js code (Blender, Godot, Unity...). Run: npm run export:glb
import { mkdir, writeFile } from 'node:fs/promises';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { CATALOG } from '../src/assets/index.js';

// GLTFExporter reads blobs through FileReader, which Node does not ship.
globalThis.FileReader ??= class {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then((buffer) => {
      this.result = buffer;
      this.onloadend?.();
    });
  }
  readAsDataURL(blob) {
    blob.arrayBuffer().then((buffer) => {
      this.result = `data:${blob.type};base64,${Buffer.from(buffer).toString('base64')}`;
      this.onloadend?.();
    });
  }
};

const outDir = new URL('../public/models/', import.meta.url);
await mkdir(outDir, { recursive: true });
const exporter = new GLTFExporter();

for (const entry of CATALOG) {
  const object = entry.create();
  object.traverse((o) => delete o.userData.update);
  const glb = await exporter.parseAsync(object, { binary: true });
  await writeFile(new URL(`${entry.id}.glb`, outDir), Buffer.from(glb));
  console.log(`${entry.id}.glb  ${(glb.byteLength / 1024).toFixed(1)} KB`);
}
