// Validates the Kenney asset manifest against the packs and selection files.
// Machine-checkable only: visual quality stays a manual QA step.
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const godotRoot = join(repo, 'game', 'godot');
const manifestPath = join(godotRoot, 'assets', 'third_party', 'kenney', 'manifest.json');

const errors = [];
const check = (ok, message) => {
  if (!ok) errors.push(message);
};

const readJson = (path) => JSON.parse(readFileSync(path, 'utf8'));
const packs = readJson(join(repo, 'tools', 'assets', 'kenney-packs.json'));
const selection = readJson(join(repo, 'tools', 'assets', 'kenney-selection.json'));
const manifest = readJson(manifestPath);

const packSlugs = new Set(packs.packs.map((pack) => pack.slug));
const selectedIds = new Set();
const categories = new Set(Object.keys(selection.normalization.category_scale));

check(packs.packs.length === 8, `expected 8 source packs, found ${packs.packs.length}`);
check(packs.license.id === 'CC0-1.0', `unexpected license ${packs.license.id}`);

for (const pack of packs.packs) {
  check(/^[a-z0-9-]+$/.test(pack.slug), `bad pack slug ${pack.slug}`);
  check(/^[0-9a-f]{64}$/.test(pack.sha256), `bad SHA-256 for ${pack.slug}`);
  check(pack.author === 'Kenney', `unexpected author for ${pack.slug}`);
  check(pack.source_url.startsWith('https://kenney.nl/assets/'), `non-Kenney source for ${pack.slug}`);
  check(typeof pack.version === 'string' && pack.version.length > 0, `missing version for ${pack.slug}`);
}

for (const asset of selection.assets) {
  check(/^[a-z0-9]+(_[a-z0-9]+)*$/.test(asset.id), `asset id is not snake_case: ${asset.id}`);
  check(!selectedIds.has(asset.id), `duplicate asset id: ${asset.id}`);
  selectedIds.add(asset.id);
  check(packSlugs.has(asset.pack), `asset ${asset.id} references unknown pack ${asset.pack}`);
  check(categories.has(asset.category), `asset ${asset.id} has unknown category ${asset.category}`);
  check(typeof asset.collision === 'boolean', `asset ${asset.id} needs a boolean collision flag`);
}

const manifestIds = new Set();
check(Array.isArray(manifest.assets), 'manifest.assets must be an array');
check(manifest.assets.length === selectedIds.size, 'manifest asset count does not match selection');
check(manifest.packs.length === packs.packs.length, 'manifest pack count does not match kenney-packs.json');

for (const pack of manifest.packs) {
  const source = packs.packs.find((entry) => entry.slug === pack.slug);
  check(source !== undefined, `manifest lists unknown pack ${pack.slug}`);
  if (source) {
    check(source.sha256 === pack.sha256, `manifest SHA-256 differs for ${pack.slug}`);
    check(source.version === pack.version, `manifest version differs for ${pack.slug}`);
  }
}

for (const asset of manifest.assets) {
  check(!manifestIds.has(asset.id), `duplicate manifest id: ${asset.id}`);
  manifestIds.add(asset.id);
  const selected = selection.assets.find((entry) => entry.id === asset.id);
  check(selected !== undefined, `manifest asset not in selection: ${asset.id}`);
  if (selected) {
    check(asset.pack === selected.pack && asset.category === selected.category && asset.source_file === selected.source,
      `manifest source differs for ${asset.id}`);
    check(JSON.stringify(asset.animations) === JSON.stringify(selected.animations),
      `manifest animation list differs for ${asset.id}`);
  }
  check(asset.license === packs.license.id, `asset ${asset.id} license ${asset.license}`);
  check(typeof asset.scale === 'number' && asset.scale > 0, `asset ${asset.id} has no positive scale`);
  check(asset.imported_path === `assets/third_party/kenney/${asset.pack}/models/${asset.id}.glb`,
    `asset ${asset.id} import path is not canonical: ${asset.imported_path}`);

  const absolute = join(godotRoot, asset.imported_path);
  if (!existsSync(absolute)) {
    errors.push(`missing imported file for ${asset.id}: ${asset.imported_path}`);
    continue;
  }
  const bytes = readFileSync(absolute);
  check(bytes.subarray(0, 4).toString('ascii') === 'glTF', `${asset.id} is not a GLB`);
  check(statSync(absolute).size === asset.bytes, `${asset.id} byte size differs from manifest`);
  check(createHash('sha256').update(bytes).digest('hex') === asset.sha256, `${asset.id} SHA-256 differs from manifest`);

  if (asset.animations) {
    const jsonLength = bytes.readUInt32LE(12);
    const gltf = JSON.parse(bytes.subarray(20, 20 + jsonLength).toString('utf8'));
    const clips = gltf.animations ?? [];
    for (const expected of asset.animations) {
      const clip = clips.find((entry) => entry.name === expected);
      check(clip !== undefined, `${asset.id} is missing animation ${expected}`);
      if (clip) {
        const keyed = clip.samplers.some((sampler) => gltf.accessors[sampler.input].count > 1);
        check(keyed, `${asset.id} animation ${expected} has one key per track`);
      }
    }
    check((gltf.skins ?? []).length > 0, `${asset.id} has no skin`);
  }
}

for (const pack of packs.packs.filter((entry) => entry.models_root !== null)) {
  const license = join(godotRoot, 'assets', 'third_party', 'kenney', pack.slug, 'LICENSE.txt');
  if (!existsSync(license)) {
    errors.push(`missing LICENSE.txt for ${pack.slug}`);
    continue;
  }
  const text = readFileSync(license, 'utf8');
  check(/kenney/i.test(text), `${pack.slug}/LICENSE.txt does not name Kenney`);
  check(/CC0|public domain|Creative Commons Zero/i.test(text), `${pack.slug}/LICENSE.txt is not CC0`);
}

if (errors.length > 0) {
  console.error(`Kenney asset validation failed with ${errors.length} error(s):`);
  for (const error of errors) console.error(`  - ${error}`);
  process.exit(1);
}

const counts = manifest.assets.reduce((totals, asset) => {
  totals[asset.category] = (totals[asset.category] ?? 0) + 1;
  return totals;
}, {});
console.log(`Kenney asset validation passed: ${manifest.assets.length} assets, ${manifest.packs.length} packs.`);
console.log(`  ${Object.entries(counts).map(([category, count]) => `${category} ${count}`).join(', ')}`);
