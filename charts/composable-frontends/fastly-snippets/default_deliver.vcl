# @scope: deliver

# HSTS: instruct browsers to only ever use HTTPS for this domain.
# Only sent over TLS (per the spec, HSTS on plain HTTP must be ignored).
# max-age=604800 = 1 week. Remove `preload` unless the domain is submitted
# to hstspreload.org, and review `includeSubDomains` if any subdomain still
# needs plain HTTP.
if (req.http.Fastly-SSL) {
    set resp.http.Strict-Transport-Security = "max-age=604800";
}