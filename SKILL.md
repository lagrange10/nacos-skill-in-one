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
| `upload` | 执行上传方流程；由 AI 预检并自动选择安全可行的上传媒介。 |
| `adopt <skill>` | 将本机现有的本地 Skill 纳入仓库治理，迁入唯一信源、建立 Junction，并默认提交推送到 GitHub。 |
| `sync` | 执行接入方流程：拉取 GitHub、建立 Junction 并校验本地。 |
| `rename <old> <new>` | 在仓库和本机发现目录同时迁移 Skill 目录；旧 Junction 移到可恢复备份目录。 |

典型调用：`$nacos-skill-in-one upload`、`$nacos-skill-in-one adopt <skill>`、`$nacos-skill-in-one sync`、`$nacos-skill-in-one rename <old> <new>`。

未提供参数时按语境选择：

- 出现“上传、发布、提交、推送、把修改同步给其他电脑”等意图，选择 `upload`。
- 出现“纳入治理、加入仓库、接管本地 Skill、登记 Skill”等意图，选择 `adopt <skill>`。
- 出现“同步、拉取、更新、接入本机、从仓库恢复”等意图，选择 `sync`。
- 出现“改名、重命名目录、迁移 Skill 入口”等意图，选择 `rename`，并自动完成仓库目录与本机 Junction 迁移。
- 只有“修改 Skill”但没有发布或接入意图时，不执行外部变更；先询问用户要上传还是仅保留本地修改。
- 语境同时包含上传和接入两个方向时，按“先上传、再接入”的顺序执行，并在上传完成后重新确认接入目标。

显式参数优先于语境推断；参数与用户明确意图冲突时停止并说明冲突。

任何会改变仓库 Skill 集合或本机发现入口的流程，都必须自动维护 `skill-links.json`；`upload`、`adopt`、`rename` 和 `sync` 在结束前都要重新检查清单，不能只修改 Skill 文件而留下过期登记。

## 纳入治理：adopt

`adopt <skill>` 用于把当前 Codex 发现目录中的本地 Skill 接入仓库治理。它只处理指定 Skill，不扫描或迁移其他本地 Skill；默认完成本地接入、校验、有限范围的 Git 提交与 GitHub 推送。只有用户明确说“仅本地纳管”“不要上传”或等价指令时，才保留待上传变更而不推送。

1. 将 `<skill>` 解析为 Skill 名称或本地 Skill 目录。优先检查用户给出的路径，其次检查 `<paths.codexSkillsRoot>\personal\<skill>`；目录名必须符合小写字母、数字和连字符组成的 Skill 命名规则。
2. 如果目标已经位于 `<paths.sourceRoot>\<skill>`，先校验它已经是仓库信源；如果发现目录已是指向该路径的 Junction，报告“已纳入治理”并停止，不重复迁移。
3. 读取目标目录的 `SKILL.md` 并运行 `quick_validate.py`。缺少 `SKILL.md`、frontmatter 无效或目录不符合 Skill 结构时停止，不把不完整目录纳入治理。
4. 检查仓库工作区和目标路径。仓库中已存在同名 Skill 时停止，不覆盖现有信源；发现其他未提交改动时保留它们，只对本次目标建立明确的变更清单。
5. 将本地 Skill 内容写入 `<paths.sourceRoot>\<skill>`，逐文件校验内容与原目录一致。原发现目录不得继续作为第二份可编辑信源。
6. 将原发现目录或原 Junction 移到 `<paths.backupRoot>\<skill>-<timestamp>` 作为可恢复备份；不得删除原目录，也不得删除 Junction 指向的外部目标。跨卷移动时先复制并校验，再保留原位置的可恢复备份。
7. 在 `<paths.codexSkillsRoot>\personal\<skill>` 创建指向仓库源目录的 Junction，并用 `validate-skill-links.ps1` 验证目标、链接类型和内容。
8. 从 `skill-links.json.localOnlySkills` 移除该 Skill（如果存在），再执行 `reconcile`；保留其他真实存在的 `localOnlySkills`，不得为了纳入一个 Skill 改写无关条目。
9. 运行 `git diff --check` 和目标 Skill 校验，只暂存新 Skill 目录及 `skill-links.json`；随后按“上传共同预检”和 Git 优先策略完成该目标的提交与推送。提交前说明目标仓库、分支、文件清单和选定媒介；远端已前进、认证失败、内容审查失败或推送被拒绝时停止，不把失败静默降级为本地完成。

`adopt` 是显式的本地迁移操作。若原目录存在未保存的编辑器内容、目标路径冲突、内容校验不一致或备份无法创建，停止并报告阻塞点，不强行覆盖或删除。

## 自动维护 `skill-links.json`

Skill 内部自动执行清单对账，让 `skill-links.json` 与当前本机发现目录保持一致；该步骤不作为用户命令，不迁移 Skill、不删除文件、不自动推送远端。

1. 读取 `nacos.config.json`、`skill-links.json`、仓库 `paths.sourceRoot` 和发现目录 `<paths.codexSkillsRoot>\personal`。
2. 枚举仓库源目录下的个人 Skill，以及发现目录下的一级 Skill 目录；忽略 `legacyPaths` 指向的历史入口和仓库外无关目录。
3. 对每个仓库 Skill 校验发现目录是否为指向对应源目录的 Junction；缺失、普通副本或目标错误只报告问题，由 `adopt` 或 `sync` 修复，不在 `reconcile` 中强行覆盖。
4. 将“存在于发现目录、但不在仓库源目录”的 Skill 名称去重、排序后写入 `localOnlySkills`；已不存在的旧条目移除。保留 `schemaVersion`、路径、链接类型和 `legacyPaths` 等无关字段。
5. 清单内容没有变化时不写文件；有变化时只修改 `skill-links.json`，随后运行 `validate-skill-links.ps1` 并报告新增、移除和未解决的链接问题。
6. `upload` 必须在检查待上传文件前自动执行清单对账；如果清单发生变化，将 `skill-links.json` 与本次 Skill 变更放入同一次提交。`adopt`、`rename` 和 `sync` 完成本地处理后也必须自动执行它。

清单对账只登记实际存在的本地额外 Skill，不把不存在的名称长期留在 `localOnlySkills`，也不把仓库 Skill 同时登记为 `localOnlySkills`。

## 首次使用

Agent 首次使用时先读取现有 `nacos.config.json`；缺失时只向用户询问仓库 URL（或 owner/name）和本机仓库目录，其余路径使用默认值并展示后再写入。

1. 先用 Git Credential Manager 或 `gh auth login` 完成 GitHub 登录，不把凭证写入配置。
2. 已有仓库时执行：`scripts/bootstrap-skill-repo.ps1 -RepositoryUrl <url> -LocalRoot <local-root>`；公开仓库无需额外凭证。
3. 需要新建 GitHub 仓库时执行：`scripts/bootstrap-skill-repo.ps1 -LocalRoot <local-root> -GitHubName <owner/name> -Visibility public|private -CreateGitHubRepository`；默认 `private`，公开发布必须显式指定 `-Visibility public`。
4. 脚本生成的 `nacos.config.json` 是该电脑的路径配置；跨电脑只需为每台电脑设置自己的 `LocalRoot`，仓库内的相对源目录保持不变。

GitHub 地址先用 `scripts/probe-github-repository.ps1` 探测。不可达时不要反复等待或覆盖本地目录，向用户给出三项选择：修复 VPN/代理后重试、改用可达镜像 URL、或使用 `-Offline` 先建立本地仓库并将 `repository.status` 标记为 `pending`，网络恢复后再绑定远端。

配置至少包含：`repository.url`、`repository.branch`、`repository.visibility`、`repository.status`、`paths.sourceRoot`、`paths.codexSkillsRoot`、`paths.backupRoot` 和 `linkType`。

## 上传内部策略

用户视角只有 `upload`。用户请求上传后，AI 先完成只读预检，再自动选择上传媒介；不要要求用户选择 `browser`、`gh` 或 `git`，也不要把内部媒介名当作命令参数暴露给用户。

| 方式 | 适用条件 | 行为和取舍 |
| --- | --- | --- |
| `git` | 本地仓库可访问，或可以在本机完成 Git 配置 | 首选；优先帮助用户确认 Git、PATH、仓库 remote 和凭证，再用标准 Git 提交流程。 |
| `gh` | Git 配置或 Git 上传无法完成，且 GitHub remote 的 `gh auth status` 通过 | 最后命令行兜底；使用 GitHub API 上传，不要求本地 Git checkout。 |
| `browser` | Git 与 `gh` 都无法完成，且已有登录的 GitHub 浏览器会话 | 最后兜底；通过网页查看 diff 并提交。 |

选择顺序固定为：先检查并配置 `git`，再使用 `git`；Git 配置或上传确实无法完成时，进入 `gh`；`gh` 仍无法完成时，最后进入 `browser`。每个候选最多处理一次明确的失败原因，不循环重试同一失败路径。最终交付中说明实际采用的媒介和失败候选，但不要求用户参与媒介决策。

## Git 优先配置流程

进入 `upload` 后，先检查 `git --version`、仓库根目录、当前分支、remote 和认证状态。

1. Git 命令不在 PATH 时，先查找本机已有安装并为当前流程补齐 PATH；如果确实未安装，优先引导或协助安装到用户指定的 E 盘位置，再重新检查。安装过程不得覆盖已有 Git 配置，也不得索取或记录密码、Token。
2. Git 可执行但仓库未初始化时，确认目标仓库和本地根目录后初始化或绑定 remote；已有仓库不得覆盖未提交改动。
3. remote 存在但认证失败时，优先使用 Git Credential Manager 或用户已配置的凭证完成 `git ls-remote` 验证；不要把凭证拼入命令参数。
4. Git 配置成功后，回到上传共同预检和 `git` 上传流程；只有安装受阻、用户拒绝配置、认证无法完成或远端明确拒绝时，才进入 `gh`。

Git 配置检查只对当前任务需要的仓库生效。不要因为一次上传失败修改全局 Git 用户身份、代理或其他无关配置；需要用户凭证或选择时暂停并说明具体阻塞点。

## 上传共同预检

无论使用哪种方式，都必须先执行：

1. 读取 `<repo>\nacos.config.json`，解析远端 URL、分支、`paths.sourceRoot` 和目标 Skill 相对路径；上传源只能是仓库信源目录，不能是 `.codex\skills` 发现目录的副本。
2. 先执行 `reconcile`；如果 `skill-links.json` 发生变化，将它纳入本次变更清单。
3. 确认目标文件清单：单目标上传只包含该 Skill 目录内的预期文件及必要的 `skill-links.json`；全量上传包含所有检测到变更的个人 Skill 目录及清单文件，除此之外不得混入其他文件。没有实际变更时停止上传。
4. 运行仓库提供的 `quick_validate.py`；若仓库没有该脚本，执行等价的 frontmatter、文件存在性和脚本语法校验，并明确记录替代校验。
5. 检查 diff 或待上传内容，不得包含公司代码、内部路径、凭证、Token 或不属于本 Skill 的文件。
6. 读取远端当前提交或目标文件版本，发现远端已前进且本地基于旧版本时停止，不覆盖远端改动。
7. 在实际提交前向用户说明目标仓库、分支、文件清单和 AI 选定的上传方式；提交后记录 commit SHA、Skill 名称和验证结果。

### 上传目标解析

用户只提供 `upload` 而未指定 Skill 时，按以下顺序解析目标：

1. 使用用户消息、Skill mention、文件路径或最近明确上下文中指向的 Skill；编辑器截图只能作为线索，不能替代已保存的本地文件。
2. 没有明确目标时，优先用 `git status --short -- <paths.sourceRoot>` 和 `git diff` 识别仓库信源目录下发生变化的 Skill，忽略 `.codex\skills` 发现目录副本。
3. 只有一个 Skill 有变更时自动选定；多个 Skill 有变更时全部纳入本次上传，并在提交前列出 Skill 名称和文件清单作为审计记录，不询问用户是否缩小范围。
4. Git 尚未配置完成时，先完成 Git 优先配置流程；随后重新执行目标解析。若 Git 仍不可用，才用远端文件版本与本地信源对比作为降级检测。
5. 没有已保存变更时停止上传并报告“未发现可上传变更”。不得因为当前加载的是 `nacos-skill-in-one` 就默认把治理入口自身当作上传目标。

未保存的编辑器内容无法被 Git 或远端对比感知；发现编辑器有未保存标记时，提示用户保存后再继续。

## Browser 内部上传

AI 进入 `browser` 兜底路径时：

1. 使用已登录的 GitHub 浏览器会话打开目标仓库和目标分支；不要索取、读取或记录密码、Token、验证码。
2. 逐个查看目标文件的远端版本，使用网页编辑或新增文件功能写入本地信源内容；不要通过网页修改其他文件。
3. 在提交前查看网页 diff，确认文件路径、内容和行数正确；目标分支允许直接提交时提交配置分支，否则创建分支并发起 PR。
4. 提交成功后重新打开目标文件或提交详情，确认 commit SHA 和文件范围。

浏览器未登录、无法访问仓库或网页提交失败时，记录失败原因并停止，不重复点击或循环重试。

## gh 内部上传

AI 只有在 Git 配置或 Git 上传无法完成时才进入 `gh` 命令行路径：

1. 先执行 `gh auth status`，并根据 `repository.url` 确认 host、owner、repo 和目标分支；认证失败时停止，不读取认证信息。
2. 优先使用 GitHub Contents API：先读取目标文件当前 `sha`，再以 UTF-8 文件内容的 Base64 作为 `content`，调用 `PUT /repos/{owner}/{repo}/contents/{path}`；更新时必须带远端 `sha`，新增文件不得伪造 `sha`。
3. 多文件或需要分支/PR 时，使用 GitHub Git Database API 创建 blobs、tree、commit 和 ref，或明确改用 `git`；不得用多个独立提交掩盖一次 Skill 更新。
4. API 返回成功后重新读取目标文件和提交详情，确认目标分支、commit SHA、文件路径及文件数量；目标分支受保护时创建分支并发起 PR。

不要把 Token、完整认证配置或未经审查的本地目录内容拼入命令参数。API 返回冲突、权限不足、非 GitHub remote 或网络失败时记录原因并进入下一候选或报告阻塞。

## git 内部上传

AI 进入 `git` 首选路径时：

1. 确认 `git --version`、仓库 remote、当前分支和工作区状态；先用 `git diff --check` 检查空白错误。
2. 只对目标 Skill 文件及 `reconcile` 产生的 `skill-links.json` 执行 `git add -- <paths>`，再次检查 `git diff --cached --name-status` 和 staged diff，禁止混入其他工作区改动。
3. 远端分支有更新时先执行 `git pull --ff-only`；出现分叉、冲突或认证失败时停止，不使用 force push。
4. 创建清晰提交并推送配置中的目标分支；目标分支受保护或 push 被拒绝时，记录原因并进入 `gh`，必要时再进入 `browser` 创建分支和 PR。
5. 推送后读取远端 log 或 PR，确认 commit SHA、Skill 名称、文件清单和验证结果。

Git 配置、Git 上传和 `gh` 均不可用时，记录各自失败原因，最后检查 `browser` 是否适用；remote 不是 GitHub 时跳过 `gh`，直接检查 `browser` 是否适用。

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
3. 按“上传内部策略”和“上传共同预检”完成媒介选择与校验。
4. 确认目标仓库和文件清单后，按 AI 选定的方式提交；配置分支通常为 `main`，受保护时自动改走分支/PR流程。
5. 交付提交号、变更的 Skill 名称、实际上传方式和验证结果。

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
