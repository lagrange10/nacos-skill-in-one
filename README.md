# nacos-skill-in-one

`nacos-skill-in-one` 是一个可独立分发的 Codex Skill，用 Git/GitHub 作为 Skill 同步媒介，覆盖首次配置、上传、接入、目录迁移和网络不可达降级。

## 权威来源

本仓库是公开发布镜像，不是日常编辑源。唯一事实来源仍是用户本地治理仓库中同名 Skill 目录；修改时先更新本地事实来源，再重新生成镜像并推送。

镜像不包含任何密码、Token、验证码或公司专属内容。

## 能力

| 模式 | 行为 |
| --- | --- |
| `bootstrap` | 在新电脑初始化或克隆 Skill 仓库，生成配置并准备发现目录 |
| `upload` | 校验唯一信源，提交并推送远端 |
| `sync` | 拉取远端，建立或刷新本机 Junction 并校验 |
| `rename <old> <new>` | 同步迁移仓库目录、frontmatter 和本机 Junction |

不带模式时，由 Agent 根据语境判断是上传、接入还是迁移；只有单纯修改内容而未表达发布意图时，不自动推送。

## 首次使用

Agent 会先读取 `<repo>/nacos.config.json`。如果不存在，只询问远端地址（或 GitHub `owner/name`）和本机仓库目录，其余路径使用默认值并展示后写入。

已有仓库：

```powershell
<repo>\scripts\bootstrap-skill-repo.ps1 `
  -RepositoryUrl <url> `
  -LocalRoot <local-root>
```

新建 GitHub 仓库：

```powershell
<repo>\scripts\bootstrap-skill-repo.ps1 `
  -LocalRoot <local-root> `
  -GitHubName <owner/name> `
  -Visibility public `
  -CreateGitHubRepository
```

`-Visibility` 支持 `public` 和 `private`，默认 `private`。公开仓库可以直接克隆，无需额外凭证。

## GitHub 不可达时

Agent 先运行 `scripts/probe-github-repository.ps1`，不会在远端不可达时反复等待、覆盖本地目录或伪造成功。

可选处理：

1. 修复 VPN、代理或 DNS 后重试。
2. 改用可达的 Git 镜像 URL。
3. 使用 `-Offline` 先建立本地仓库；配置会写入 `repository.status=pending`，网络恢复后再绑定远端。

## 配置

配置文件：`<repo>/nacos.config.json`

```json
{
  "repository": {
    "url": "<git-url>",
    "branch": "main",
    "visibility": "public",
    "status": "verified"
  },
  "paths": {
    "sourceRoot": "skills/personal",
    "codexSkillsRoot": "%USERPROFILE%/.codex/skills",
    "backupRoot": "%USERPROFILE%/.codex/skill-link-backups"
  },
  "linkType": "junction"
}
```

路径可以按电脑调整；仓库内的相对源目录建议保持一致。凭证只由 Git Credential Manager 或 `gh auth login` 管理，不写入配置。

## 日常同步

```powershell
<repo>\scripts\update-personal-skills.ps1
<repo>\scripts\validate-skill-links.ps1 -Strict
```

默认关系：

```text
<repo>\skills\personal\<skill-name>
    ↓ Junction
%USERPROFILE%\.codex\skills\personal\<skill-name>
```

本机发现目录不维护第二份可编辑副本；正确的 Junction 会被同步脚本识别为 `Already linked`，不会无条件删除重建。

## 目录迁移

```powershell
<repo>\scripts\rename-personal-skill.ps1 <old> <new>
```

脚本会移动唯一信源目录、同步 `SKILL.md` 的 `name`，把旧 Junction 移到可恢复备份目录，再建立新 Junction，不复制 Skill 内容。

## 文件说明

- `SKILL.md`：Codex Skill 入口和决策规则
- `scripts/bootstrap-skill-repo.ps1`：首次初始化/克隆
- `scripts/probe-github-repository.ps1`：远端可达性探测
- `scripts/sync-personal-skills.ps1`：建立或刷新 Junction
- `scripts/update-personal-skills.ps1`：拉取、同步、校验
- `scripts/validate-skill-links.ps1`：唯一信源与链接校验
- `scripts/rename-personal-skill.ps1`：目录迁移
- `nacos.config.template.json`：配置模板
