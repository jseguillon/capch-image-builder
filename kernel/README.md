# Kernel configuration maintenance

The files `linux-config-aarch64` and `linux-config-x86_64` are snapshots of the
kernel configuration used when building guest kernels for CAPCH images.  When
upgrading to a newer kernel release you should refresh these configs so that any
new Kconfig options are either accepted with their defaults or explicitly set.

## Refreshing the x86_64 configuration

1. Download the kernel source for the desired release, for example from
   <https://cdn.kernel.org/pub/linux/kernel/>.  Extract the tarball and change
   into the kernel source directory.
2. Copy the existing configuration from this repository into the tree:
   ```bash
   cp /path/to/capch-image-builder/kernel/linux-config-x86_64 .config
   ```
3. Update the configuration to the new release defaults:
   ```bash
   make ARCH=x86_64 olddefconfig
   ```
   This command answers any new configuration prompts using the upstream
   defaults.
4. Review the changes, e.g. with `./scripts/diffconfig`, and decide whether any
   new options need to be toggled away from their defaults.
5. Once satisfied, save the refreshed configuration back into the repository:
   ```bash
   cp .config /path/to/capch-image-builder/kernel/linux-config-x86_64
   ```

Repeat the same workflow with `linux-config-aarch64`, replacing the architecture
in the `make` invocation with `ARCH=arm64`.
