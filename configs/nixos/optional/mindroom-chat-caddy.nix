# Caddy site directives that serve a MindRoom Chat static build
# (github.com/mindroom-ai/mindroom-chat) from `root`, a `current` symlink that a
# publish flips atomically between releases/<ts>-<ref>-<sha> directories. Not a
# NixOS module: import it with the root and put the result in a vhost's extraConfig.
{ root }:
''
  root * ${root}
  encode zstd gzip
  # The pairing approval page must never render inside another site's frame; the rest
  # only inside this origin. Caddy's path matcher ignores case, decodes escapes and
  # merges repeated slashes, so this covers every spelling the router renders.
  @connect path /connect /connect/
  route {
    header Content-Security-Policy "frame-ancestors 'self'"
    header X-Frame-Options "SAMEORIGIN"
    header @connect Content-Security-Policy "frame-ancestors 'none'"
    header @connect X-Frame-Options "DENY"
    # Hashed build files never change. A missing one is a 404, not the app shell.
    handle /assets/* {
      @exists file
      header @exists Cache-Control "public, max-age=31536000, immutable"
      file_server
    }
    handle /.well-known/apple-app-site-association {
      header Cache-Control "no-cache"
      header Content-Type application/json
      file_server
    }
    # Everything else revalidates: the app shell, sw.js, config.json, version.json,
    # runtime-config.js. Paths that are not files answer with the app shell.
    handle {
      header Cache-Control "no-cache"
      try_files {path} /index.html
      file_server
    }
  }
''
