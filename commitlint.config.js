// Commit messages drive releases here — semantic-release parses them to pick
// the next version (see .releaserc.js), so a malformed message silently costs
// you a release. This enforces the same shape CI and semantic-release expect.
//
// Run it locally on any platform: `npx commitlint --edit .git/COMMIT_EDITMSG`,
// or let the .husky/commit-msg hook do it on every commit.
module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    // semantic-release ignores commits with no scope (`{ scope: null,
    // release: false }`), so a scopeless commit is a silently dropped
    // release. Require one.
    "scope-empty": [2, "never"],
    // Keep the type list in step with the releaseRules in .releaserc.js.
    "type-enum": [
      2,
      "always",
      ["feat", "fix", "docs", "patch", "chore", "refactor", "test", "ci", "perf", "build", "style", "revert"],
    ],
    // The default 100 is fine for the subject; bodies wrap by hand here and
    // sometimes carry log output or URLs that cannot be split.
    "body-max-line-length": [0, "always"],
    "footer-max-line-length": [0, "always"],
  },
};
