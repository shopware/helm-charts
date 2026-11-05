# @scope: recv
# Force HTTP -> HTTPS. Fastly only sets Fastly-SSL on TLS connections; plain
# HTTP requests hit error 801, a reserved Fastly code that is turned into a
# 301 redirect to the HTTPS equivalent of the requested URL automatically.
if (!req.http.Fastly-SSL) {
    error 801 "Force SSL";
}

# Static assets don't need any cookie. Stripping them ensures a stable cache
# key when assets are served from the same domain as the storefront, so the
# hash does not vary based on sw-cache-hash or sw-currency.
# This condition could be remove on PaaS native, 
# since we have 2 different services
if (req.url.path ~ "^/(media|thumbnail|theme|bundles)/") {
    unset req.http.Cookie;
}

# Don't allow clients to force a pass
if (req.restarts == 0) {
    unset req.http.x-pass;
}

# Enable Fastly authentification for single purges
set req.http.Fastly-Purge-Requires-Auth = "1";

# Mitigate httpoxy application vulnerability, see: https://httpoxy.org/
unset req.http.Proxy;

# Normalize query arguments
set req.url = querystring.sort(req.url);

# Make sure that the client ip is forwarded to the origin.
# Only do this on the edge POP (fastly.ff.visits_this_service == 0) and on the
# first pass (req.restarts == 0). On the shield node Fastly-Client-IP is the edge
# POP's IP (not the real client), and on restarts the block would run again, so
# without this guard X-Forwarded-For ends up with extra/wrong entries.
if (fastly.ff.visits_this_service == 0 && req.restarts == 0) {
    if (req.http.x-forwarded-for) {
        set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + req.http.Fastly-Client-IP;
    } else {
        set req.http.X-Forwarded-For = req.http.Fastly-Client-IP;
    }
}

# Don't cache Authenticate & Authorization
if (req.http.Authenticate || req.http.Authorization) {
    set req.http.x-pass = "1";
}

# Micro-optimization: Always pass these paths directly to php without caching
# to prevent hashing and cache lookup overhead
# Note: virtual URLs might bypass this rule (e.g. /en/checkout)
if (req.url.path ~ "^/(checkout|account)(/.*)?$") {
    set req.http.x-pass = "1";
}

# Disable stale_while_revalidate feature on SHIELD node to avoid caching issue when both soft-purges and shieding are used.
if (fastly.ff.visits_this_service > 0) {
    set req.max_stale_while_revalidate = 0s;
}