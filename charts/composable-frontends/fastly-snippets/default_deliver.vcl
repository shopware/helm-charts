# @scope: deliver

# HSTS: instruct browsers to only ever use HTTPS for this domain.
# Only sent over TLS (per the spec, HSTS on plain HTTP must be ignored).
# max-age=604800 = 1 week. Remove `preload` unless the domain is submitted
# to hstspreload.org, and review `includeSubDomains` if any subdomain still
# needs plain HTTP.
if (req.http.Fastly-SSL) {
    set resp.http.Strict-Transport-Security = "max-age=604800";
}

# Enable Fastly dynamic (edge) compression. Fastly picks brotli or gzip
# from the client's Accept-Encoding and skips responses already encoded.
# Only compress on the node that answers the real client: with shielding,
# the shield's client is the edge POP, so we skip compression there.
if (fastly.ff.visits_this_service == 0
    && resp.http.Content-Type ~ "^(text/|application/(javascript|x-javascript|json|xml|manifest\+json|vnd\.ms-fontobject)|image/(svg\+xml|x-icon)|font/(otf|ttf|eot))") {
  set resp.http.X-Compress-Hint = "on";
}