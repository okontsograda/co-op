# Web Export Guide

## 1. Export Settings

### In Godot:
1. Go to **Project → Export**
2. Add **HTML5** export template
3. Configure settings:

### HTML5 Export Settings:
- **Export Path**: `builds/web/index.html`
- **Custom HTML Shell**: Leave default
- **Variant**: Release
- **Export Mode**: Export all resources
- **Features**: HTML5

## 2. Export the Game

1. **Export Client**: Use `client.tscn` as main scene
2. **Export Server**: Use `dedicated_server.tscn` as main scene

## 3. Web-Specific Considerations

### Update Network Handler for Web:
```gdscript
# In network_handler.gd
const IP_ADDRESS: String = "your-server-ip.com"  # Your server's domain/IP
const PORT: int = 42069
```

### Web Limitations:
- **WebRTC recommended** for browser-to-browser
- **WebSocket fallback** for server connections
- **CORS issues** may need server configuration

## 4. Hosting Options

### Free Options:
- **GitHub Pages**: Free static hosting
- **Netlify**: Free with custom domains
- **Vercel**: Free with custom domains
- **Itch.io**: Free game hosting

### Paid Options:
- **AWS S3 + CloudFront**: Scalable
- **Google Cloud Storage**: Global CDN
- **Azure Static Web Apps**: Integrated with Azure

## 5. Server Deployment

### For Web Games:
1. **Deploy server** to VPS (see deploy_server.md)
2. **Update client** with server IP
3. **Export web version**
4. **Upload to hosting service**

### Example Deployment:
```bash
# 1. Export web version
# 2. Upload to Netlify
# 3. Configure server IP
# 4. Share the URL!
```
