# Changelog

## [Unreleased](https://github.com/codex-storage/nim-serde/tree/HEAD)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/v.1.2.2...HEAD)

**Merged pull requests:**

- Update chronicles [\#33](https://github.com/codex-storage/nim-serde/pull/33) ([markspanbroek](https://github.com/markspanbroek))
- fix loglevel and add log scope to allow filtering and avoid log pollution [\#30](https://github.com/codex-storage/nim-serde/pull/30) ([dryajov](https://github.com/dryajov))
- ci: add matrix status job [\#29](https://github.com/codex-storage/nim-serde/pull/29) ([veaceslavdoina](https://github.com/veaceslavdoina))

## [v.1.2.2](https://github.com/codex-storage/nim-serde/tree/v.1.2.2) (2024-10-23)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/v1.2.1...v.1.2.2)

**Merged pull requests:**

- v1.2.2 [\#28](https://github.com/codex-storage/nim-serde/pull/28) ([emizzle](https://github.com/emizzle))
- chore: bumps nim from 1.6.16 to 1.6.20 in ci [\#27](https://github.com/codex-storage/nim-serde/pull/27) ([emizzle](https://github.com/emizzle))
- chore: remove unneeded echos [\#26](https://github.com/codex-storage/nim-serde/pull/26) ([emizzle](https://github.com/emizzle))

## [v1.2.1](https://github.com/codex-storage/nim-serde/tree/v1.2.1) (2024-05-21)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/v1.2.0...v1.2.1)

**Merged pull requests:**

- v1.2.1 [\#25](https://github.com/codex-storage/nim-serde/pull/25) ([emizzle](https://github.com/emizzle))
- fix: force symbol resolution for types that serde de/serializes  [\#24](https://github.com/codex-storage/nim-serde/pull/24) ([emizzle](https://github.com/emizzle))
- feat: improve deserialization from string [\#23](https://github.com/codex-storage/nim-serde/pull/23) ([emizzle](https://github.com/emizzle))
- feat: improve stint parsing [\#22](https://github.com/codex-storage/nim-serde/pull/22) ([emizzle](https://github.com/emizzle))

## [v1.2.0](https://github.com/codex-storage/nim-serde/tree/v1.2.0) (2024-05-14)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/v1.1.1...v1.2.0)

**Merged pull requests:**

- chore: v1.2.0 [\#21](https://github.com/codex-storage/nim-serde/pull/21) ([emizzle](https://github.com/emizzle))
- fix: add missing test update [\#20](https://github.com/codex-storage/nim-serde/pull/20) ([emizzle](https://github.com/emizzle))
- chore: reorganize deserialize tests [\#19](https://github.com/codex-storage/nim-serde/pull/19) ([emizzle](https://github.com/emizzle))
- fix: UInt256 not correctly deserializing from string [\#18](https://github.com/codex-storage/nim-serde/pull/18) ([emizzle](https://github.com/emizzle))

## [v1.1.1](https://github.com/codex-storage/nim-serde/tree/v1.1.1) (2024-05-13)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/v1.1.0...v1.1.1)

**Merged pull requests:**

- chore: v.1.1.1 [\#17](https://github.com/codex-storage/nim-serde/pull/17) ([emizzle](https://github.com/emizzle))
- chore\[formatting\]: update formatting [\#16](https://github.com/codex-storage/nim-serde/pull/16) ([emizzle](https://github.com/emizzle))
- add empty string test for UInt256 [\#15](https://github.com/codex-storage/nim-serde/pull/15) ([emizzle](https://github.com/emizzle))
- Fix log topics [\#14](https://github.com/codex-storage/nim-serde/pull/14) ([benbierens](https://github.com/benbierens))
- run changelog workflow on release [\#12](https://github.com/codex-storage/nim-serde/pull/12) ([emizzle](https://github.com/emizzle))

## [v1.1.0](https://github.com/codex-storage/nim-serde/tree/v1.1.0) (2024-02-14)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/v1.0.0...v1.1.0)

**Merged pull requests:**

- chore: v1.1.0 [\#11](https://github.com/codex-storage/nim-serde/pull/11) ([emizzle](https://github.com/emizzle))
- deserialize non-prefixed stuint [\#10](https://github.com/codex-storage/nim-serde/pull/10) ([emizzle](https://github.com/emizzle))
- deserialize seq\[T\] and Option\[T\] from string [\#9](https://github.com/codex-storage/nim-serde/pull/9) ([emizzle](https://github.com/emizzle))

## [v1.0.0](https://github.com/codex-storage/nim-serde/tree/v1.0.0) (2024-02-13)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/v0.1.2...v1.0.0)

**Merged pull requests:**

- v1.0.0 [\#8](https://github.com/codex-storage/nim-serde/pull/8) ([emizzle](https://github.com/emizzle))
- fix: change serializer funcs to procs  [\#7](https://github.com/codex-storage/nim-serde/pull/7) ([emizzle](https://github.com/emizzle))
- Use token for changelog generator [\#6](https://github.com/codex-storage/nim-serde/pull/6) ([veaceslavdoina](https://github.com/veaceslavdoina))
- Adjust workflows for changelog generation [\#5](https://github.com/codex-storage/nim-serde/pull/5) ([veaceslavdoina](https://github.com/veaceslavdoina))
- Change parseJson to JsonNode.parse [\#4](https://github.com/codex-storage/nim-serde/pull/4) ([emizzle](https://github.com/emizzle))
- Add CI workflow [\#3](https://github.com/codex-storage/nim-serde/pull/3) ([emizzle](https://github.com/emizzle))
- Fix deserialization of openArray\[byte\] [\#2](https://github.com/codex-storage/nim-serde/pull/2) ([emizzle](https://github.com/emizzle))

## [v0.1.2](https://github.com/codex-storage/nim-serde/tree/v0.1.2) (2024-02-08)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/v0.1.1...v0.1.2)

## [v0.1.1](https://github.com/codex-storage/nim-serde/tree/v0.1.1) (2024-02-07)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/v0.1.0...v0.1.1)

## [v0.1.0](https://github.com/codex-storage/nim-serde/tree/v0.1.0) (2024-02-07)

[Full Changelog](https://github.com/codex-storage/nim-serde/compare/5a8e85449d9320d2277bc9aadf1daae61c7f057b...v0.1.0)



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
