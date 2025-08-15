const { execSync } = require('child_process');

// Get all packages that should be released
const packages = [
  'functions_client',
  'gotrue', 
  'postgrest',
  'realtime_client',
  'storage_client',
  'supabase',
  'supabase_flutter',
  'yet_another_json_isolate'
];

// Determine which package we're releasing based on changed files
const getPackageFromChangedFiles = () => {
  // This will be set by the GitHub Action workflow
  const packageName = process.env.PACKAGE_NAME;
  if (packageName && packages.includes(packageName)) {
    return packageName;
  }
  
  // Fallback: try to detect from git changes
  try {
    const changedFiles = execSync('git diff --name-only HEAD~1 HEAD', { encoding: 'utf8' });
    const packageMatch = changedFiles.match(/packages\/([^\/]+)/);
    return packageMatch ? packageMatch[1] : null;
  } catch {
    return null;
  }
};

const currentPackage = getPackageFromChangedFiles();

if (!currentPackage) {
  console.log('No package detected for release');
  process.exit(0);
}

console.log(`Configuring semantic-release for package: ${currentPackage}`);

const packageDir = `packages/${currentPackage}`;
const releaseChannel = process.env.RELEASE_CHANNEL || 'stable';

// Branch configuration based on release channel
const branches = releaseChannel === 'rc' 
  ? [
      'main',
      {
        name: 'rc',
        prerelease: 'rc'
      }
    ]
  : ['main'];

// Tag format based on release channel
const tagFormat = releaseChannel === 'rc' 
  ? `${currentPackage}-v\${version}`
  : `${currentPackage}-v\${version}`;

console.log(`Release channel: ${releaseChannel}`);
console.log(`Branches configuration:`, branches);

module.exports = {
  branches,
  repositoryUrl: 'https://github.com/supabase/supabase-flutter.git',
  tagFormat,
  plugins: [
    [
      '@semantic-release/commit-analyzer',
      {
        preset: 'conventionalcommits',
        releaseRules: [
          { type: 'docs', scope: 'README', release: 'patch' },
          { type: 'refactor', release: 'patch' },
          { type: 'style', release: 'patch' },
          { type: 'chore', release: 'patch' },
          { scope: 'no-release', release: false }
        ],
        parserOpts: {
          noteKeywords: ['BREAKING CHANGE', 'BREAKING CHANGES', 'BREAKING']
        }
      }
    ],
    [
      '@semantic-release/release-notes-generator',
      {
        preset: 'conventionalcommits',
        parserOpts: {
          noteKeywords: ['BREAKING CHANGE', 'BREAKING CHANGES', 'BREAKING']
        },
        writerOpts: {
          commitsSort: ['subject', 'scope']
        }
      }
    ],
    [
      '@semantic-release/changelog',
      {
        changelogFile: `${packageDir}/CHANGELOG.md`,
        changelogTitle: `# Changelog\n\nAll notable changes to this project will be documented in this file.\n\nThe format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),\nand this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n`
      }
    ],
    [
      '@semantic-release/exec',
      {
        verifyConditionsCmd: `test -f ${packageDir}/pubspec.yaml`,
        prepareCmd: `node scripts/update-package-version.js ${currentPackage} \${nextRelease.version}`,
        publishCmd: `cd ${packageDir} && dart pub publish --force`,
        successCmd: `echo "Successfully released ${currentPackage} v\${nextRelease.version} on ${releaseChannel} channel"`
      }
    ],
    [
      '@semantic-release/git',
      {
        assets: [
          `${packageDir}/pubspec.yaml`,
          `${packageDir}/lib/src/version.dart`,
          `${packageDir}/CHANGELOG.md`
        ],
        message: `chore(${currentPackage}): release v\${nextRelease.version} [skip ci]\n\n\${nextRelease.notes}`
      }
    ],
    [
      '@semantic-release/github',
      {
        assets: [
          {
            path: `${packageDir}/CHANGELOG.md`,
            label: 'Changelog'
          }
        ],
        discussionCategoryName: releaseChannel === 'rc' ? false : 'Announcements',
        releasedLabels: releaseChannel === 'rc' ? ['released-rc'] : ['released']
      }
    ]
  ]
};