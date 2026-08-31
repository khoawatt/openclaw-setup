# Contributing to openclaw-setup

Thank you for your interest in contributing!

---

## Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Akbi47/openclaw-setup.git
   cd openclaw-setup
   ```

2. **Verify no secrets are present**:
   ```bash
   bash scripts/verify-no-secrets.sh
   ```

3. **Run watcher tests**:
   ```bash
   bash watcher/tests/run-tests.sh
   ```

---

## Pull Request Guidelines

1. **Secrets-free**: Never commit real credentials, tokens, or `openclaw.json`. Templates must use placeholders (`__*_TOKEN__`).
2. **Keep it focused**: One feature or fix per PR.
3. **Preserve permissions**: Installer must `chmod 600` any file that can hold secrets.
4. **Test before pushing**: `verify-no-secrets.sh` and `watcher/tests/run-tests.sh` must pass.

---

## Code of Conduct

Be respectful and constructive. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

---

## Security

See [SECURITY.md](SECURITY.md).

---

## Author & Maintainer

* **Akbi47** ([@Akbi47](https://github.com/Akbi47)) — Author & Maintainer
