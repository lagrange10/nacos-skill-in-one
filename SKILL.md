---
name: nacos-skill-in-one
description: "Use to bootstrap, configure, rename, upload, and sync a personal Codex Skill repository on GitHub or another Git remote. The agent guides first-time setup, probes reachability, and offers an offline path when the remote is unavailable."
---

# GitHub Skill Sync Workflow

这里的 `nacos-skill-in-one` 是同步治理入口；实际媒介是 GitHub/Git 仓库，不要求运行 Nacos 或购买 MSE。

## Authority

- Repository and path values: `<repo>/nacos.config.json`
- Canonical content: `paths.sourceRoot` in the config
- Local Codex discovery: `paths.codexSkillsRoot/personal` in the config
- Link contract: `<repo>/skill-links.json`

仓库中的个人 Skill 是唯一信源。不要在本机发现目录维护第二份可编辑副本；优先使用 Junction 指向仓库文件。

## Link contract

仓库根目录的 `skill-links.json` 是事实来源清单：仓库 `skills/personal/` 下的每个 Skill 默认必须映射为本机发现目录下的 Junction。未进入仓库的本地 Skill 必须显式列入 `localOnlySkills`，否则视为未治理状态。

同步脚本默认建立 Junction；只有明确需要临时副本时才传入 `-Copy`。

## Mode parameters

Use an explicit mode when the user provides one:

| 参数 | 行为 |
| --- | --- |
| `bootstrap` | 在新电脑初始化或克隆 Skill 仓库，生成配置并准备本地发现目录。 |
| `upload` | 执行上传方流程：校验、提交并推送 GitHub。 |
| `sync` | 执行接入方流程：拉取 GitHub、建立 Junction 并校验本地。 |
| `rename <old> <new>` | 在仓库和本机发现目录同时迁移 Skill 目录；旧 Junction 移到可恢复备份目录。 |

典型调用：`$nacos-skill-in-one upload`、`$nacos-skill-in-one sync`、`$nacos-skill-in-one rename <old> <new>`。

未提供参数时按语境选择：

- 出现“上传、发布、提交、推送、把修改同步给其他电脑”等意图，选择 `upload`。
- 出现“同步、拉取、更新、接入本机、从仓库恢复”等意图，选择 `sync`。
- 出现“改名、重命名目录、迁移 Skill 入口”等意图，选择 `rename`，并自动完成仓库目录与本机 Junction 迁移。
- 只有“修改 Skill”但没有发布或接入意图时，不执行外部变更；先询问用户要上传还是仅保留本地修改。
- 语境同时包含上传和接入两个方向时，按“先上传、再接入”的顺序执行，并在上传完成后重新确认接入目标。

显式参数优先于语境推断；参数与用户明确意图冲突时停止并说明冲突。

## 首次使用

Agent 首次使用时先读取现有 `nacos.config.json`；缺失时只向用户询问仓库 URL（或 owner/name）和本机仓库目录，其余路径使用默认值并展示后再写入。

1. 先用 Git Credential Manager 或 `gh auth login` 完成 GitHub 登录，不把凭证写入配置。
2. 已有仓库时执行：`scripts/bootstrap-skill-repo.ps1 -RepositoryUrl <url> -LocalRoot <local-root>`；公开仓库无需额外凭证。
3. 需要新建 GitHub 仓库时执行：`scripts/bootstrap-skill-repo.ps1 -LocalRoot <local-root> -GitHubName <owner/name> -Visibility public|private -CreateGitHubRepository`；默认 `private`，公开发布必须显式指定 `-Visibility public`。
4. 脚本生成的 `nacos.config.json` 是该电脑的路径配置；跨电脑只需为每台电脑设置自己的 `LocalRoot`，仓库内的相对源目录保持不变。

GitHub 地址先用 `scripts/probe-github-repository.ps1` 探测。不可达时不要反复等待或覆盖本地目录，向用户给出三项选择：修复 VPN/代理后重试、改用可达镜像 URL、或使用 `-Offline` 先建立本地仓库并将 `repository.status` 标记为 `pending`，网络恢复后再绑定远端。

配置至少包含：`repository.url`、`repository.branch`、`repository.visibility`、`repository.status`、`paths.sourceRoot`、`paths.codexSkillsRoot`、`paths.backupRoot` 和 `linkType`。

## 目录迁移

用户要求更名时，`nacos-skill-in-one rename <old> <new>` 必须作为一次迁移完成：

1. 执行 `<repo>\\scripts\\rename-personal-skill.ps1 <old> <new>`。
2. 脚本将仓库目录和 frontmatter 一起改名，将旧 Junction 移到 `%USERPROFILE%\\.codex\\skill-link-backups\\<old>`，再创建指向新目录的 Junction。
3. 运行接入方流程并校验新路径、目标和提交号。

此流程不复制 Skill 内容；迁移后仓库新目录仍是唯一信源。

## 上传方：发布 Skill

上传方负责把变更写入唯一信源：

1. 只在仓库的 `skills/personal/<skill-name>/` 编辑。
2. 确认内容不包含公司代码、内部路径、凭证、Token 或公司专属流程。
3. 使用 `quick_validate.py` 验证 Skill 结构，并检查实际 diff。
4. 确认目标仓库和文件清单后提交并推送到 `main`。
5. 交付提交号、变更的 Skill 名称和验证结果。

## 接入方：获取 Skill

接入方负责把已发布版本接入本机：

1. 在本机仓库执行 `git pull --ff-only`；出现本地冲突时停止，不覆盖本地改动。
2. 运行同步脚本，默认建立或刷新本地 Junction：

```powershell
<repo>\scripts\update-personal-skills.ps1
```

3. 运行严格校验，确认所有受管 Skill 均指向仓库：

```powershell
<repo>\scripts\validate-skill-links.ps1 -Strict
```

4. 读取目标 `SKILL.md` 的实际内容，并记录接入的提交号。

上传方改变 GitHub 内容，接入方只拉取和验证；接入方不得直接编辑发现目录。

## Company adapter

公司 Skill 不进入个人仓库。公司适配层可以引用本地同步后的个人核心，例如：

```text
..\..\personal\unity-code-flow-core\SKILL.md
```

适配层只增加公司上下文，不复制个人核心内容。

## Safety and evidence

- GitHub 认证由用户或 Git Credential Manager 完成；不要索取或记录密码、Token、验证码。
- 推送前确认目标仓库和待提交文件；发现公司内容时停止推送并拆分。
- 同步或迁移完成后检查 Junction 目标、Git 工作区状态和目标 Skill 的实际内容。
- 不要为了 Skill 同步创建云服务器、MSE 实例或 Nacos 服务。
