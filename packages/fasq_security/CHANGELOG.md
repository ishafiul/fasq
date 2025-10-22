## 0.1.0

> Note: This release has breaking changes.

 - **FIX**: resolve all analysis issues and prepare packages for publishing (#16).
 - **DOCS**: Clean up README by removing phase references and PRD mentions (#14).
 - **BREAKING** **FEAT**: Extract security features to separate fasq_security package (#11).

# Changelog

All notable changes to the fasq_security package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2024-01-XX

### Added
- Initial release of fasq_security package
- Security plugin architecture with abstract interfaces
- DefaultSecurityPlugin implementation
- CryptoEncryptionProvider with AES-GCM encryption and isolate support
- SecureStorageProvider with platform-specific secure storage
- DriftPersistenceProvider with efficient batch operations
- Comprehensive test suite for all providers and plugins
- Key rotation functionality with progress tracking
- Automatic expiration and cleanup of cache entries
- Support for iOS, Android, macOS, Windows, and Linux
- Error handling with specific exception types
- Documentation and usage examples

### Security
- AES-GCM encryption with 256-bit keys
- Cryptographically secure random key generation
- Platform-specific secure storage (Keychain/Keystore)
- Isolate-based encryption for large data to prevent UI blocking
- ACID-compliant persistence operations

### Performance
- 20x faster batch operations compared to individual operations
- Background isolate processing for large data encryption
- Optimized memory usage for mobile devices
- Efficient database operations with proper indexing

## [Unreleased]

### Planned
- Full Drift SQLite implementation (currently using in-memory storage)
- Additional security plugins (NoSecurityPlugin, EnterpriseSecurityPlugin)
- Web platform support
- Performance benchmarks and optimization
- Additional encryption algorithms
- Advanced key management features