# Releasing on CurseForge

## Connect the project once

Use [CurseForge automatic packaging](https://support.curseforge.com/support/solutions/articles/9000197281) for the WoW project. The root `.pkgmeta` names the install folder `QoLToolkit` and excludes development files from the package.

1. Set the CurseForge packaging preference to tagged commits only.
2. In GitHub repository settings, add the CurseForge webhook for the push event. Follow the CurseForge guide for the payload URL. Keep the URL with its token in GitHub's webhook settings and keep TLS verification enabled.
3. Check the first file in CurseForge for the **Forever** flavor, game version **1.60.1**, and install path `QoLToolkit/QoLToolkit.toc`. The native packager's Forever detection needs verification on that first file.

New projects need a file for moderation. See [CurseForge project submission](https://support.curseforge.com/support/solutions/articles/9000197241) if the portal requires the first file to be submitted separately.

## Protect the release source

- Set a ruleset for `main` that blocks force pushes and branch deletion. Require pull requests. A solo maintainer can use zero required approvals. Make **Lua 5.1 checks** required after GitHub has run it successfully.
- Add a tag ruleset matching `v*` to block deletion and force pushes. Keep creation limited to trusted maintainers with write access.
- Enable secret scanning and push protection under **Settings > Security**. Keep the default Actions token permissions read-only and require approval for fork workflows.

See [GitHub rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets), [secret protection](https://docs.github.com/en/code-security/getting-started/quickstart-for-securing-your-repository), and [Actions settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).

## Publish an update

1. Update `## Version` in `QoLToolkit.toc` and merge the change into `main` after the checks pass.
2. Create an annotated tag on the reviewed commit, matching the manifest version. For example, use `v0.1.0` for `0.1.0`.
3. Push that tag when ready to publish. CurseForge packages the tagged source. Check the file status and game version in the author dashboard.

Ordinary commits are for development. A stable tag requests a public Release when the webhook is active.
