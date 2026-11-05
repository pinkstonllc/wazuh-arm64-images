# Wazuh images for Raspberry Pi 4 (arm64, Debian 12)

The official `wazuh/*` images (4.8 and later) are built on Amazon Linux 2023,
whose arm64 build needs an ARMv8.2 CPU. A Raspberry Pi 4 (Cortex-A72) is
ARMv8.0, so they exit at once with *"This version of Amazon Linux requires a
newer ARM64 processor"*.

These images are the same thing on **Debian 12**:

- **Wazuh's own arm64 packages** (`wazuh-indexer`, `wazuh-manager`,
  `wazuh-dashboard`, `filebeat`) from `packages.wazuh.com`, verified with
  Wazuh's signing key.
- **Wazuh's own start-up scripts and config files**, copied unchanged from
  [wazuh-docker](https://github.com/wazuh/wazuh-docker) at the matching tag
  (`*/config/`). Environment variables, mounts and behaviour match the
  official images, so the official Kubernetes manifests work as-is.

Only the Dockerfiles and `common/wazuh-apt.sh` are new.

## Images

```
ghcr.io/<owner>/wazuh-indexer:<version>
ghcr.io/<owner>/wazuh-manager:<version>
ghcr.io/<owner>/wazuh-dashboard:<version>
```

Built by [.github/workflows/build.yml](.github/workflows/build.yml) on every
push to `main` (or by hand: Actions → *Build Wazuh arm64 images* → *Run
workflow*). Each build ends with a smoke test that starts the image's main
binary.

## Upgrading Wazuh

1. Check that the new version's arm64 `.deb` packages exist in Wazuh's apt
   repository.
2. Copy the new `build-docker-images/<component>/config/` files from
   wazuh-docker at the matching tag, leaving out `check_repository.sh` and
   `filebeat_module.sh`. Diff the official Dockerfiles against the previous
   tag and carry any changes over.
3. Bump `WAZUH_VERSION` (and `FILEBEAT_TEMPLATE_BRANCH`) in
   [versions.env](versions.env), then push.

## License

GPL-2.0, like wazuh-docker, from which the `*/config/` files come
(Copyright (C) 2017 Wazuh Inc.). See [LICENSE](LICENSE).
