---
description: Execute the full release workflow for yapyap (version bump, changelog, tag, push)
---

# Release Workflow

Execute the complete release workflow for yapyap. User input: $ARGUMENTS

Follow each step strictly. If any step fails, stop immediately and report the error in Chinese.

---

## Step 1: Pre-flight Checks

Run these three checks. If any fails, stop and tell the user in Chinese:

1. **Branch check**: Run `git branch --show-current`. Must be `master`. If not:
   > "当前不在 master 分支（当前: {branch}），请先切换到 master 分支再发版。"

2. **Clean working tree**: Run `git status --porcelain`. Output must be empty. If not:
   > "工作区有未提交的更改，请先处理后再发版：\n{output}"

3. **Sync with remote**: Run `git pull origin master`. If it fails:
   > "拉取远程代码失败，请手动解决后重试。"

---

## Step 2: Determine Version

1. Read the current version from `version.txt` in the project root. If it doesn't exist, read from `yapyap/Resources/Info.plist` (the `CFBundleShortVersionString` value). Store as `CURRENT_VERSION`.

2. Parse user input (`$ARGUMENTS`) to determine the bump type:
   - Contains "大版本" / "breaking" / "major" → **MAJOR** bump (X+1.0.0)
   - Contains "新功能" / "feature" / "minor" → **MINOR** bump (X.Y+1.0)
   - Contains "修复" / "fix" / "patch" or is empty → **PATCH** bump (X.Y.Z+1)
   - If input matches a version pattern like `v1.2.3` or `1.2.3` → use that exact version

3. Calculate `NEW_VERSION` based on the bump type applied to `CURRENT_VERSION`.

4. **MANDATORY**: Display to the user and ask for confirmation before proceeding:
   > "版本号变更: {CURRENT_VERSION} → {NEW_VERSION}\n确认发布吗？(yes/no)"

   If the user does not confirm, stop.

---

## Step 3: Update Version Numbers

Update the version in ALL of these locations:

1. **`version.txt`** (project root): Write the new version string (just the version, e.g. `1.2.0`).

2. **`yapyap/Resources/Info.plist`**: Update both:
   - `CFBundleShortVersionString` → `NEW_VERSION`
   - `CFBundleVersion` → increment the existing integer build number by 1

---

## Step 4: Generate CHANGELOG

1. Get commits since last tag:
   ```bash
   git log $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD --oneline
   ```

2. Categorize each commit by its conventional commit prefix:
   - `feat:` → **Added**
   - `fix:` → **Fixed**
   - `refactor:` → **Changed**
   - `docs:` → **Documentation**
   - `chore:` / `build:` / `ci:` → **Maintenance**
   - No prefix or `update` → **Changed**

3. Insert a new version section at the top of `CHANGELOG.md`, right after `## [Unreleased]`:

   ```markdown
   ## [{NEW_VERSION}] - {YYYY-MM-DD}

   ### Added
   - commit description 1
   - commit description 2

   ### Fixed
   - commit description 3

   ### Changed
   - commit description 4
   ```

   Only include categories that have entries. Remove the commit hash prefix, keep just the description.

---

## Step 5: Commit, Tag, and Push

Execute these commands sequentially. If any fails, stop and report in Chinese:

```bash
git add version.txt CHANGELOG.md yapyap/Resources/Info.plist
git commit -m "chore: release v{NEW_VERSION}"
git tag release-v{NEW_VERSION}
git push origin master
git push origin release-v{NEW_VERSION}
```

**Error handling for push**:
- If push fails:
  > "推送失败，可能需要先 pull 或解决冲突。请勿使用 force push。"
- Never use `--force` or `--force-with-lease`.

---

## Step 6: Report

After everything succeeds, display a summary in Chinese:

> "发版完成!
>
> - 版本号: v{NEW_VERSION}
> - Tag: release-v{NEW_VERSION}
> - 推送状态: 已推送到 origin/master
> - CI: 已触发 GitHub Actions release workflow（如已配置）
>
> 可在 GitHub Actions 页面查看构建状态。"
