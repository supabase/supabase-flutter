#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Get changed files from git
const getChangedFiles = () => {
  try {
    const changedFiles = execSync('git diff --name-only HEAD~1 HEAD', { encoding: 'utf8' });
    return changedFiles.trim().split('\n').filter(file => file.length > 0);
  } catch (error) {
    console.error('Error getting changed files:', error.message);
    return [];
  }
};

// Get all packages
const getPackages = () => {
  const packagesDir = path.join(__dirname, '..', 'packages');
  return fs.readdirSync(packagesDir).filter(dir => {
    const stat = fs.statSync(path.join(packagesDir, dir));
    return stat.isDirectory() && fs.existsSync(path.join(packagesDir, dir, 'pubspec.yaml'));
  });
};

// Check if package has changes
const hasPackageChanges = (packageName, changedFiles) => {
  const packagePrefix = `packages/${packageName}/`;
  return changedFiles.some(file => file.startsWith(packagePrefix));
};

// Get dependency graph
const getDependencyGraph = () => {
  const packages = getPackages();
  const graph = {};
  
  packages.forEach(packageName => {
    const pubspecPath = path.join(__dirname, '..', 'packages', packageName, 'pubspec.yaml');
    const pubspecContent = fs.readFileSync(pubspecPath, 'utf8');
    
    graph[packageName] = {
      dependencies: [],
      dependents: []
    };
    
    // Extract dependencies on other packages in the monorepo
    packages.forEach(otherPackage => {
      if (otherPackage !== packageName) {
        const depRegex = new RegExp(`^\\s+${otherPackage}:\\s*`, 'm');
        if (depRegex.test(pubspecContent)) {
          graph[packageName].dependencies.push(otherPackage);
        }
      }
    });
  });
  
  // Build reverse dependencies
  Object.keys(graph).forEach(packageName => {
    graph[packageName].dependencies.forEach(dep => {
      if (graph[dep]) {
        graph[dep].dependents.push(packageName);
      }
    });
  });
  
  return graph;
};

// Get packages that need to be released
const getPackagesToRelease = () => {
  const changedFiles = getChangedFiles();
  const packages = getPackages();
  const dependencyGraph = getDependencyGraph();
  
  if (changedFiles.length === 0) {
    console.log('No changed files detected');
    return [];
  }
  
  const changedPackages = packages.filter(pkg => hasPackageChanges(pkg, changedFiles));
  
  if (changedPackages.length === 0) {
    console.log('No package changes detected');
    return [];
  }
  
  // Include dependent packages that need to be released
  const packagesToRelease = new Set(changedPackages);
  
  // Add packages that depend on changed packages
  changedPackages.forEach(changedPkg => {
    if (dependencyGraph[changedPkg]) {
      dependencyGraph[changedPkg].dependents.forEach(dependent => {
        packagesToRelease.add(dependent);
      });
    }
  });
  
  return Array.from(packagesToRelease);
};

// Main execution
const packagesToRelease = getPackagesToRelease();

if (process.argv.includes('--json')) {
  console.log(JSON.stringify(packagesToRelease));
} else {
  console.log('Packages to release:', packagesToRelease.join(', '));
}

// Set GitHub Actions output
if (process.env.GITHUB_OUTPUT) {
  const output = packagesToRelease.length > 0 ? JSON.stringify(packagesToRelease) : '[]';
  fs.appendFileSync(process.env.GITHUB_OUTPUT, `packages=${output}\n`);
}