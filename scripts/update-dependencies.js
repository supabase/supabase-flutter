#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Package dependency map - defines which packages depend on which
const DEPENDENCY_MAP = {
  'supabase': [
    'functions_client',
    'gotrue',
    'postgrest',
    'realtime_client',
    'storage_client',
    'yet_another_json_isolate'
  ],
  'supabase_flutter': [
    'supabase'
  ]
};

// Read package version from pubspec.yaml
function getPackageVersion(packagePath) {
  const pubspecPath = path.join(packagePath, 'pubspec.yaml');
  const pubspec = fs.readFileSync(pubspecPath, 'utf8');
  const match = pubspec.match(/^version:\s+(.+)$/m);
  return match ? match[1].trim() : null;
}

// Update dependency version in pubspec.yaml
function updateDependencyVersion(packagePath, depName, newVersion) {
  const pubspecPath = path.join(packagePath, 'pubspec.yaml');
  let pubspec = fs.readFileSync(pubspecPath, 'utf8');

  // Update dependency version (exact match)
  const regex = new RegExp(`(\\s+${depName}:\\s+)([\\d\\.]+)`, 'g');
  const updated = pubspec.replace(regex, `$1${newVersion}`);

  if (updated !== pubspec) {
    fs.writeFileSync(pubspecPath, updated);
    console.log(`Updated ${depName} to ${newVersion} in ${packagePath}`);
    return true;
  }

  return false;
}

// Check if any package has been updated by looking at git diff
function getUpdatedPackages() {
  try {
    const diff = execSync('git diff --name-only HEAD~1', { encoding: 'utf8' });
    const updatedPackages = new Set();

    diff.split('\\n').forEach(file => {
      const match = file.match(/^packages\/([^\/]+)\//);
      if (match) {
        updatedPackages.add(match[1]);
      }
    });

    return Array.from(updatedPackages);
  } catch (error) {
    console.log('Could not determine updated packages, assuming all may need updates');
    return Object.keys(DEPENDENCY_MAP).concat(['functions_client', 'gotrue', 'postgrest', 'realtime_client', 'storage_client', 'yet_another_json_isolate']);
  }
}

function main() {
  console.log('Updating package dependencies...');

  const packagesDir = 'packages';
  const updatedPackages = getUpdatedPackages();
  let hasChanges = false;

  // For each package that depends on others
  Object.entries(DEPENDENCY_MAP).forEach(([packageName, dependencies]) => {
    const packagePath = path.join(packagesDir, packageName);

    if (!fs.existsSync(packagePath)) {
      console.log(`Package ${packageName} not found, skipping`);
      return;
    }

    // Check if any of its dependencies were updated
    const updatedDeps = dependencies.filter(dep => updatedPackages.includes(dep));

    if (updatedDeps.length === 0) {
      console.log(`No dependency updates needed for ${packageName}`);
      return;
    }

    console.log(`Updating dependencies for ${packageName}: ${updatedDeps.join(', ')}`);

    // Update each dependency to its new version
    updatedDeps.forEach(depName => {
      const depPath = path.join(packagesDir, depName);
      const newVersion = getPackageVersion(depPath);

      if (newVersion) {
        const updated = updateDependencyVersion(packagePath, depName, newVersion);
        if (updated) {
          hasChanges = true;
        }
      }
    });
  });

  if (hasChanges) {
    console.log('Dependencies updated, changes will be committed automatically');
  } else {
    console.log('No dependency updates were needed');
  }
}

if (require.main === module) {
  main();
}