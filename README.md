# nacos-skill-in-one

这是可独立分发的 Codex Skill 包，支持首次配置、GitHub 可达性探测、公开或私有 Git 远端、离线待接入、Skill 同步和目录迁移。

唯一事实来源仍是治理仓库中的：

`E:\Codex\skills-governance\skills\personal\nacos-skill-in-one\SKILL.md`

本目录是发布镜像，不作为日常编辑源。更新时先修改事实来源，再重新生成本镜像并推送。

## 内容

- `SKILL.md`：Skill 入口
- `scripts/`：bootstrap、远端探测、同步、校验和迁移脚本
- `nacos.config.template.json`：配置模板

## 发布

在 GitHub 创建空的 public 仓库后，将本目录设置为 remote 并推送 `main`。
