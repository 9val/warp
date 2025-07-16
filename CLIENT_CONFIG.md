# Example Shadowsocks Client Configuration

## Client Configuration Examples

### Android/iOS (Shadowsocks Client)
```json
{
  "server": "YOUR_SERVER_IP",
  "server_port": 8388,
  "password": "YOUR_PASSWORD",
  "method": "aes-256-gcm",
  "timeout": 60
}
```

### Windows/macOS/Linux (Shadowsocks Client)
```json
{
  "server": "YOUR_SERVER_IP",
  "server_port": 8388,
  "local_address": "127.0.0.1",
  "local_port": 1080,
  "password": "YOUR_PASSWORD",
  "method": "aes-256-gcm",
  "timeout": 60
}
```

### Browser Configuration (SOCKS5 Proxy)
- **Proxy Type**: SOCKS5
- **Server**: 127.0.0.1
- **Port**: 1080

### Supported Encryption Methods
- aes-256-gcm (recommended)
- aes-192-gcm
- aes-128-gcm
- chacha20-ietf-poly1305
- xchacha20-ietf-poly1305

### Connection Information
After running the script, you can find your connection details in:
- `/var/log/shadowsocks-warp/connection_info.txt`
- Or run: `sudo ./shadowsocks-warp.sh info`

### Testing the Connection
1. Configure your Shadowsocks client with the server details
2. Test connectivity to verify the connection works
3. Check if your IP has changed using: https://whatismyipaddress.com/

## Troubleshooting Client Connections

### Common Client Issues
1. **Connection refused**: Check if server is running and port is open
2. **Timeout**: Verify network connectivity and MTU settings
3. **Authentication failed**: Ensure password and method match exactly
4. **Slow connection**: Check MTU settings and server load

### Testing Commands
```bash
# Test server connectivity
nc -zv YOUR_SERVER_IP 8388

# Test with curl through SOCKS5
curl -x socks5://127.0.0.1:1080 http://httpbin.org/ip

# Test DNS resolution
nslookup google.com 1.1.1.1
```