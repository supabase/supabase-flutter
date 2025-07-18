#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const packageName = process.argv[2];
const newVersion = process.argv[3];

if (!packageName || !newVersion) {
  console.error('Usage: node update-package-version.js <package-name> <version>');
  process.exit(1);
}

const packageDir = path.join(__dirname, '..', 'packages', packageName);
const pubspecPath = path.join(packageDir, 'pubspec.yaml');
const versionPath = path.join(packageDir, 'lib', 'src', 'version.dart');

console.log(`Updating ${packageName} to version ${newVersion}`);

// Update pubspec.yaml
if (fs.existsSync(pubspecPath)) {
  let pubspecContent = fs.readFileSync(pubspecPath, 'utf8');
  pubspecContent = pubspecContent.replace(/^version:\s*.+$/m, `version: ${newVersion}`);
  fs.writeFileSync(pubspecPath, pubspecContent);
  console.log(`Updated ${pubspecPath}`);
} else {
  console.error(`pubspec.yaml not found at ${pubspecPath}`);
  process.exit(1);
}

// Update version.dart if it exists
if (fs.existsSync(versionPath)) {
  const versionContent = `const version = '${newVersion}';`;
  fs.writeFileSync(versionPath, versionContent);
  console.log(`Updated ${versionPath}`);
}

// Update inter-package dependencies in the monorepo
const packagesDir = path.join(__dirname, '..', 'packages');
const allPackages = fs.readdirSync(packagesDir).filter(dir => {
  const stat = fs.statSync(path.join(packagesDir, dir));
  return stat.isDirectory();
});

// Update dependencies in other packages that depend on this one
for (const otherPackage of allPackages) {
  if (otherPackage === packageName) continue;
  
  const otherPubspecPath = path.join(packagesDir, otherPackage, 'pubspec.yaml');
  if (fs.existsSync(otherPubspecPath)) {
    let otherPubspecContent = fs.readFileSync(otherPubspecPath, 'utf8');
    const dependencyRegex = new RegExp(`^(\\s+${packageName}:\\s*)([^\\n]+)$`, 'gm');
    
    if (dependencyRegex.test(otherPubspecContent)) {
      otherPubspecContent = otherPubspecContent.replace(dependencyRegex, `$1${newVersion}`);
      fs.writeFileSync(otherPubspecPath, otherPubspecContent);
      console.log(`Updated dependency in ${otherPackage}/pubspec.yaml`);
    }
  }
}

// Run melos version update script to ensure consistency
try {
  execSync('melos run update-version', { stdio: 'inherit', cwd: path.join(__dirname, '..') });
  console.log('Ran melos update-version successfully');
} catch (error) {
  console.warn('Warning: melos update-version failed:', error.message);
}

console.log(`Version update completed for ${packageName}`);