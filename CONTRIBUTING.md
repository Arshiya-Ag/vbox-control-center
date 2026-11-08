# Contributing to VirtualBox Control Center

Thank you for your interest in improving **VirtualBox Control Center**! Contributions from the community are warmly welcome.

## Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/<your-username>/vbox-control-center.git
   cd vbox-control-center
   ```

2. **Install locally for testing**:
   ```bash
   ./install.sh
   ```

3. **Run in a standalone preview window**:
   ```bash
   plasmawindowed org.kde.plasma.vboxcontrolcenter
   ```

## Running Unit Tests

The backend test suite verifies UUID validation, parsing of `VBoxManage` machine-readable outputs, and state mappings:

```bash
python3 contents/backend/test_vbox_service.py
```

All new backend features or bug fixes should include corresponding test cases in `test_vbox_service.py`.

## Coding Style & Guidelines

- **QML**: Use declarative Plasma 6 / Kirigami / QtQuick 2 APIs. Keep styling aligned with the Tokyo Night palette defined in `contents/ui/main.qml`.
- **Python**: Follow PEP 8 guidelines. Avoid shell string formatting (`shell=True`). Always pass explicit token arrays (`["VBoxManage", ...]`) with UUID validation.
- **Safety First**: Destructive VM operations (force power-off, delete, reset) are intentionally restricted to protect lab environments.

## Submitting Pull Requests

1. Fork the repository and create your feature branch:
   ```bash
   git checkout -b feature/my-new-feature
   ```
2. Commit your changes with clear, descriptive commit messages.
3. Verify that tests pass.
4. Push to your fork and submit a Pull Request against `main`.
