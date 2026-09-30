// .releaserc.js — tags vX.Y.Z on main from conventional commits and
// publishes a GitHub release. Consumers reference the module by tag:
//   source = "git::https://github.com/mcowser-p/can-my-server-reach.git?ref=v1.0.0"
module.exports = {
  branches: ["main"],
  tagFormat: `v\${version}`,
  plugins: [
    [
      "@semantic-release/commit-analyzer",
      {
        preset: "angular",
        releaseRules: [
          // Ignore commits without <scope>
          { scope: null, release: false },
          { breaking: true, release: "major" },
          { type: "feat", release: "minor" },
          { type: "fix", release: "patch" },
          { type: "docs", release: "patch" },
          { type: "patch", release: "patch" },
          { type: "chore", release: false },
        ],
      },
    ],
    [
      // `types` must cover every type releaseRules can release on, or that
      // release ships with an empty body (a docs-only patch, for instance).
      // conventionalcommits preset pinned to v9 — v10 needs a newer
      // changelog writer than this plugin ships.
      "@semantic-release/release-notes-generator",
      {
        preset: "conventionalcommits",
        presetConfig: {
          types: [
            { type: "feat", section: "Features" },
            { type: "fix", section: "Bug Fixes" },
            { type: "docs", section: "Documentation" },
            { type: "patch", section: "Patches" },
            { type: "perf", section: "Performance" },
            { type: "chore", hidden: true },
            { type: "ci", hidden: true },
            { type: "test", hidden: true },
            { type: "refactor", hidden: true },
            { type: "style", hidden: true },
            { type: "build", hidden: true },
          ],
        },
      },
    ],
    [
      "@semantic-release/github",
      {
        successCommentCondition: false,
        failCommentCondition: false,
      },
    ],
  ],
};
