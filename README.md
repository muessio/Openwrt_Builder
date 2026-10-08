# OpenWrt & ImmortalWrt Builder

This is a GitHub Actions-based firmware build repository for the **GL-MT5000 (Brume 3)**, specifically designed to automatically pull source code, integrate custom packages and optimizations, and build and publish clean firmware images for **both OpenWrt and ImmortalWrt**.

### Supported Firmware Variants & Devices

* **GL-MT5000 (Brume 3)** – Default IP: `192.168.100.1`
  * **OpenWrt** (via `Build filogic.yml`)
  * **ImmortalWrt** (via `Build immortalwrt.yml`)

### Directory Structure

* `.github/workflows/`: Contains the automated build and release pipelines for OpenWrt and ImmortalWrt.
* `.github/actions/`: Local composite actions used during the release and upload phases.
* `config/`: Contains the device-specific `.config` file for the GL-MT5000 (`mt5000.config`).
* `sh/scripts-part1.sh`: Device-specific source code modifications executed before feed updates.
* `sh/scripts-part2.sh`: Custom scripts executed after feed installation to inject custom packages and handle dependencies.
* `default-settings-m0eak/`: Custom default settings package for your personal configurations.
* `files/`: Rootfs overlay copied directly into the build tree (`openwrt/files`).

### Build Workflow

1. Trigger the respective workflow (OpenWrt or ImmortalWrt) via GitHub Actions (manually or scheduled).
2. Clone the corresponding source code base (OpenWrt or ImmortalWrt).
3. Execute `sh/scripts-part1.sh` for source code preparations and patches.
4. Update and install package feeds.
5. Inject `default-settings-m0eak`, the `files/` folder, and `mt5000.config`.
6. Execute `sh/scripts-part2.sh` to add further individual packages.
7. Compile (`make defconfig`, download dependencies, execute build) and automatically upload the finished artifacts and releases.

### Local Verification

In a Bash environment, you can perform a syntax check on the scripts beforehand:

```bash
bash -n sh/scripts-part1.sh
bash -n sh/scripts-part2.sh
```
Due to resource requirements, actual firmware compilation should be executed directly within GitHub Actions.

### Acknowledgments

* **m0eak** (for the excellent base structure and OpenWrt Builder template)
* **P3TERX/Actions-OpenWrt**
* **OpenWrt Project**
* **ImmortalWrt Project**

### License

MIT
