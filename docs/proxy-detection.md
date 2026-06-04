# Proxy Detection

Proxy detection is read-only. The tool does not modify proxy settings, clear proxy settings, or write proxy settings into npm or Git.

## Windows Sources

- Process, user, and machine proxy environment variables.
- npm proxy config.
- Git proxy config.
- WinHTTP proxy.
- Windows user internet settings.
- Common loopback ports.

When `curl.exe` is available and network checks are enabled, the Windows detector attempts HTTP proxy and SOCKS5 proxy protocol checks. If those checks fail, the tool records the failure and continues.

## WSL / Linux / macOS Sources

- Proxy environment variables.
- npm proxy config.
- Git proxy config.
- Common loopback ports.
- GNOME proxy settings on Linux when `gsettings` exists.
- macOS network services through `networksetup`.

## Recommendation Priority

The report includes a `RecommendedProxy` object. It is selected in this order:

1. Configured environment HTTP/HTTPS proxy.
2. npm or Git HTTP proxy.
3. Operating-system HTTP proxy settings.
4. Loopback HTTP proxy identified by protocol test.
5. Loopback SOCKS5 proxy identified by protocol test.
6. Reachable loopback TCP listener with unknown protocol.

## Sanitization

Proxy credentials are masked before being written to logs or reports. A proxy URL with credentials is shown as:

```text
http://***:***@host:port
```
